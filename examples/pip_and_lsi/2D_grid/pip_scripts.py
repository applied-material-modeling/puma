# Copyright 2025, UChicago Argonne, LLC
# All Rights Reserved
# Software Name: PUMA: Powder Utilization Modeling Application
# By: UChicago Argonne, LLC
# OPEN SOURCE LICENSE (MIT)
#
# NEML2 v3 driver for the pip_and_lsi/2D_grid example.
#
#   pyrolysis(cycle 1)
#   -> [ infiltration -> curing -> pyrolysis ] x (pip_cycle_n - 1)
#   -> LSI infiltration (infiltration_lsi.i / reactive_flow model)
#   -> LSI solidification
#
# Each of the 5 NEML2 models is authored in neml2/<stage>.i with a bare-name
# constant header; write_neml2_header() injects the real physical constants and
# compile_model() AOTI-compiles it into neml2/aoti_<stage>/.

import os
import sys
import time
import subprocess
from pathlib import Path

HERE = Path(__file__).resolve().parent
PUMA = HERE.parents[2] / "puma-opt"
PY_MODELS = HERE.parents[2] / "neml2_models" / "python"

CORES = 4
RECOMPILE = False           # force AOTI rebuild even if a stub exists
RUN_PIP = True              # run the pyrolysis/infiltration/curing cycles
DEVICES = ["cpu"]

STAGES = ["pyrolysis", "curing", "infiltration", "reactive_flow", "solidification"]

# ---------------------------------------------------------------------------
# Geometry / driver options
# ---------------------------------------------------------------------------
num_el_x = 51
num_el_y = 101
L = 0.1                     # m
reference_mass = 1.0
Mref = reference_mass
pip_cycle_n = 3
save_folder = "main"
dt = 5

# ---------------------------------------------------------------------------
# Physical constants (PUMA PIP resin + LSI silicon values)
# ---------------------------------------------------------------------------
R = 8.31446261815324

# densities [kg m-3]
rho_s = 2260.0
rho_b = 1250.0
rho_p = 3210.0
rho_g = 13.0
rho_Si = 2570.0            # liquid Si
rho_SiC = rho_p
rho_C = rho_s
rho_Si_s = 2370.0         # solid Si

# molar mass [kg mol-1]
M_Si = 0.028085
M_SiC = 0.04011
M_C = 0.012011

# heat capacity [J kg-1 K-1]
cp_s = 1592.0
cp_b = 1200.0
cp_p = 750.0
cp_g = 1e-4
cp_Si = 705.0
cp_SiC = cp_p
cp_C = cp_s
cp_Si_s = 500.0

# thermal conductivity [W m-1 K-1]
k_s = 150.0
k_b = 279.0
k_p = 380.0
k_g = 1e-4
kappa_Si = 148.0
kappa_SiC = k_p
kappa_C = k_s
kappa_Si_s = 140.0

# pyrolysis reaction
Ea = 208170.0
A = 0.7e14
hrp = 1.58e5
Y = 0.55
order = 7.4496
pyro_mu = 0.001           # gas / consumed-binder relation
zeta = 1.5               # open-pore / consumed-binder relation

# curing reaction
Ea_cur = 98000.0
A_cur = 1e12
hrp_cur = 1.58e5
Y_cur = 0.25
order_cur = 1.0
pyro_mu_cur = 0.0
zeta_cur = 0.95

# stress-strain
E = 400e9
nu = 0.3
E_Si = 160e9
E_C = 400e9
nu_Si = 0.3
nu_C = 0.3
Tref = 300.0
g = 1e-6                  # thermal expansion coefficient

# resin porous flow (pip infiltration)
flux_in = 0.01
flux_out = 0.2
brooks_corey_threshold = 1e3
capillary_pressure_power = 8
phi_L_residual = 0.0
permeability_power = 8
mu_b = 10.0
kk_b = 2e-5
hf = 0.0
D_macro = 0.0001
gravity = 0.0

# LSI porous flow
mu_Si = 0.1
perm_ref = 1e-7
D_macro_lsi = 2e-8
D_macro_high = 1e-7
D_macro_low = 2e-8
transition_saturation_front = 0.75
transition_saturation_back = 0.45
transition_saturation_back_start = 0.65

# reactive infiltration
D_LP = 9.5e-6
l_c = 0.1
h_c = 0.0076
K_nucl_growth = 1.2e-15
k_C = 1.0
k_SiC = 1.0
reactivity_upbound = 0.1
reactivity_lowbound = 0.001

# solidification
phif_min = 0.0001
Ts = 1667.0
Tf = Ts + 40.0
H_latent = 1787e3
solidification_rate = 0.002

# convection
htc = 40.0

# pip heating profiles [hrs for hold/cool, K min-1 for rate]
T0 = 300.0
Tmax = 1400.0
dTdt = 20.0
t_hold = 0.5
tcool = 2.0
T0_cur = 300.0
Tmax_cur = 420.0
dTdt_cur = 20.0
t_hold_cur = 0.5
tcool_cur = 2.0
T0_flow = 300.0
Tmax_flow = 400.0
dTdt_flow = 20.0
t_hold_flow = 0.5
tcool_flow = 2.0

# LSI heating / cooling profiles [K s-1]
T0_lsi = Tref
Tmax_lsi = 1720.0
dTdt_lsi = 10.0
theat_lsi = (Tmax_lsi - T0_lsi) / dTdt_lsi
tinfiltrate = 7200.0
flux_in_lsi = 0.05
flux_out_lsi = 0.01
t_ramp_lsi = theat_lsi + 500.0
dTdt_cool_lsi = -1.0
tcool_lsi = (Tmax_lsi - Tref) / (-dTdt_cool_lsi)
twait_lsi = 7200.0

# derived molar volumes
omega_C = M_C / rho_C
omega_Si = M_Si / rho_Si
omega_SiC = M_SiC / rho_SiC


# ---------------------------------------------------------------------------
# Per-stage NEML2 header constants (physical values injected into neml2/<stage>.i)
# ---------------------------------------------------------------------------
def header_params():
    pyro = {
        "A": A, "Ea": Ea, "R": R, "order": order,
        "mY": -Y, "mu": pyro_mu, "mzeta": -zeta, "Mref": Mref,
        "rho_s": rho_s, "rho_b": rho_b, "rho_p": rho_p, "rho_g": rho_g,
        "rho_sm1M": Mref / rho_s, "rho_bm1M": Mref / rho_b,
        "rho_pm1M": Mref / rho_p, "rho_gm1M": Mref / rho_g,
        "cp_s": cp_s, "cp_b": cp_b, "cp_p": cp_p,
        "k_s": k_s, "k_b": k_b, "k_p": k_p,
        "source_coeff": -rho_s * hrp, "Tref": Tref, "g": g, "E": E,
        # algebraic mass-fraction coefficients: ws=ws0+cws*wb0*a,
        # wgcp=wgcp0+cwgcp*wb0*a, phiop=phiop0+cphiop*wb0*a
        "cws": Y, "cwgcp": pyro_mu * (1.0 - Y), "cphiop": zeta,
    }
    cur = dict(pyro)
    cur.update({
        "A": A_cur, "Ea": Ea_cur, "order": order_cur,
        "mY": -Y_cur, "mu": pyro_mu_cur, "mzeta": -zeta_cur,
        "source_coeff": -rho_s * hrp_cur,
        "cws": Y_cur, "cwgcp": pyro_mu_cur * (1.0 - Y_cur), "cphiop": zeta_cur,
    })
    infil = {
        "rho_f": rho_b, "Tref": Tref, "therm_expansion": g,
        "swelling_coefficient": 0.0,
        "kk_L": kk_b, "permeability_power": permeability_power,
        "rhof_nu": rho_b / mu_b, "hf_rhof_nu": hf * rho_b / mu_b,
        "rhof2_nu": rho_b ** 2 / mu_b, "hf_rhof2_nu": hf * rho_b ** 2 / mu_b,
        "brooks_corey_threshold": brooks_corey_threshold,
        "capillary_pressure_power": capillary_pressure_power,
    }
    reactive = {
        "initial_product_dummy_thickness": 1e-3,
        "reactivity_lowbound": reactivity_lowbound,
        "reactivity_upbound": reactivity_upbound,
        "D": D_LP / l_c, "oP_oL": omega_SiC / omega_Si,
        "K_nucl_growth": K_nucl_growth * l_c, "omega_SiC": omega_SiC,
        "mhcolc": -h_c / l_c, "oSiCm1": 1.0 / omega_SiC, "oCm1": 1.0 / omega_C,
        "chem_ratio": k_SiC / k_C, "mchem_P": -k_SiC, "omega_Si": omega_Si,
        "rho_f": rho_Si, "rhof_nu": rho_Si / mu_Si, "rhof2_nu": rho_Si ** 2 / mu_Si,
        "Dmacro": D_macro_lsi,
        "delta_Dscale_front": D_macro_high - D_macro_lsi,
        "delta_Dscale_back": D_macro_low - D_macro_lsi,
        "new_scale": (transition_saturation_back - transition_saturation_back_start) / 2.0,
        "transition_saturation_front": transition_saturation_front,
        "transition_saturation_back": transition_saturation_back,
        "transition_saturation_back_start": transition_saturation_back_start,
        "kk_L": perm_ref, "permeability_power": permeability_power,
        "brooks_corey_threshold": brooks_corey_threshold,
        "capillary_pressure_power": capillary_pressure_power,
        "rhocp_Si": rho_Si * cp_Si, "rhocp_SiC": rho_SiC * cp_SiC,
        "rhocp_C": rho_C * cp_C,
        "kap_Si": kappa_Si, "kap_SiC": kappa_SiC, "kap_C": kappa_C,
        "E": E, "therm_expansion": g, "Tref": T0_lsi,
    }
    solid = {
        "cp_rhofl": cp_Si * rho_Si, "cp_rhofs": cp_Si_s * rho_Si_s,
        "cp_rhos": cp_C * rho_C, "cp_rhop": cp_SiC * rho_SiC,
        "kap_fl": kappa_Si, "kap_fs": kappa_Si_s, "kap_s": kappa_C, "kap_p": kappa_SiC,
        "Ts": Ts, "Tl": Tf, "mphi_min": -phif_min,
        "m_solidification_rate": -solidification_rate,
        "mOfs_Ofl": -rho_Si / rho_Si_s,
        "brooks_corey_threshold": brooks_corey_threshold,
        "capillary_pressure_power": capillary_pressure_power,
        "kk_L": perm_ref, "permeability_power": permeability_power,
        "rho_f": rho_Si, "rhof_nu": rho_Si / mu_Si, "rhof2_nu": rho_Si ** 2 / mu_Si,
        "hf_rhof_onu": H_latent * rho_Si / mu_Si,
        "hf_rhof2_onu": H_latent * rho_Si ** 2 / mu_Si,
        "mhf_rhof": -H_latent * rho_Si,
        "therm_expansion": g, "Tref": Tref,
        "E": E, "E_fs": E_Si, "E_m": E_C, "nu_fs": nu_Si, "nu_m": nu_C,
        "delta_Omega": rho_Si / rho_Si_s - 1.0,
    }
    return {
        "pyrolysis": pyro, "curing": cur, "infiltration": infil,
        "reactive_flow": reactive, "solidification": solid,
    }


# ---------------------------------------------------------------------------
# NEML2 header injection + AOTI compilation
# ---------------------------------------------------------------------------
def write_neml2_header(path, params):
    out, in_header = [], True
    for line in path.read_text().splitlines():
        if line.lstrip().startswith("["):
            in_header = False
        stripped = line.strip()
        if in_header and stripped and "=" in stripped and not stripped.startswith("#"):
            key = stripped.split("=", 1)[0].strip()
            if key in params:
                comment = "  #" + line.split("#", 1)[1] if "#" in line else ""
                out.append("{} = {!r}{}".format(key, params[key], comment))
                continue
        out.append(line)
    path.write_text("\n".join(out) + "\n")


def compile_model(stage):
    src = HERE / "neml2" / "{}.i".format(stage)
    out_dir = "aoti_{}".format(stage)
    env = dict(os.environ)
    env["CC"] = "x86_64-conda-linux-gnu-gcc"
    env["CXX"] = "x86_64-conda-linux-gnu-g++"
    env["LIBRARY_PATH"] = "/usr/local/cuda/lib64/stubs:" + env.get("LIBRARY_PATH", "")
    subprocess.run(
        ["neml2-compile", "--model", "model", src.name,
         "--dtype", "float64", "--device", *DEVICES,
         "--output-dir", out_dir, "--load", str(PY_MODELS), "-d", ":"],
        cwd=str(HERE / "neml2"), env=env, check=True,
    )


def build_models():
    params = header_params()
    for stage in STAGES:
        src = HERE / "neml2" / "{}.i".format(stage)
        write_neml2_header(src, params[stage])
        stub = HERE / "neml2" / "aoti_{}".format(stage) / "model_aoti.i"
        if RECOMPILE or not stub.exists():
            print("==> compiling {}".format(stage), flush=True)
            compile_model(stage)


# ---------------------------------------------------------------------------
# MOOSE stage runners
# ---------------------------------------------------------------------------
def num_rows(csv):
    with open(csv) as f:
        return sum(1 for _ in f)


def popen_or_fail(step_name, moose_args, log_path=None):
    # --allow-unused: several globals are passed for the IC/handoff files and are
    # not referenced by every stage (the NEML2 constants are now baked into the
    # compiled AOTI model), so tolerate unused command-line params.
    argv = ["mpiexec", "-n", str(CORES), str(PUMA), "--allow-unused", "-i"] + moose_args
    print("\n==> {}\n    {}".format(step_name, " ".join(argv)), flush=True)
    if log_path:
        Path(log_path).parent.mkdir(parents=True, exist_ok=True)
        with open(log_path, "w") as lf:
            proc = subprocess.Popen(argv, stdin=subprocess.DEVNULL,
                                    stdout=lf, stderr=subprocess.STDOUT, text=True,
                                    cwd=str(HERE))
            proc.wait()
    else:
        proc = subprocess.Popen(argv, stdin=subprocess.DEVNULL,
                                stdout=subprocess.PIPE, stderr=subprocess.STDOUT,
                                text=True, cwd=str(HERE))
        for line in proc.stdout:
            print(line, end="")
        proc.wait()
    if proc.returncode != 0:
        print("ERROR: {} failed with code {}".format(step_name, proc.returncode),
              file=sys.stderr)
        sys.exit(proc.returncode)


def kv(**kw):
    return ["{}={}".format(k, v) for k, v in kw.items()]


def run_pyrolysis(save_cycle, ic_file, load_cycle=None, load_type=None, first=False):
    args = ["pyrolysis.i", "mesh_input.i", ic_file]
    args += kv(rho_s=rho_s, rho_b=rho_b, rho_g=rho_g, rho_p=rho_p,
               cp_s=cp_s, cp_b=cp_b, cp_p=cp_p, cp_g=cp_p,
               k_s=k_s, k_b=k_b, k_p=k_p, k_g=k_p,
               Ea=Ea, A=A, R=R, hrp=hrp, Y=Y, order=order,
               E=E, g=g, Tref=Tref, htc=htc,
               Tmax=Tmax, t_hold=t_hold, tcool=tcool, T0=T0, dTdt=dTdt,
               pyro_mu=pyro_mu, zeta=zeta,
               num_el_x=num_el_x, num_el_y=num_el_y, L=L, Mref=Mref,
               save_folder=save_folder, save_cycle=save_cycle, save_type="pyrolysis")
    if first:
        args += kv(num_file_data=num_rows(HERE / "initial_condition.csv"))
    else:
        args += kv(load_cycle=load_cycle, load_type=load_type)
    popen_or_fail("Pyrolysis (cycle {})".format(save_cycle), args,
                  log_path="logs/pyrolysis_cycle{}.log".format(save_cycle))


def run_infiltration(cycle):
    args = ["infiltration.i", "mesh_input.i", "initial_condition_from_exodus_3.i"]
    args += kv(flux_in=flux_in, flux_out=flux_out, rho_b=rho_b,
               brooks_corey_threshold=brooks_corey_threshold,
               capillary_pressure_power=capillary_pressure_power,
               permeability_power=permeability_power,
               mu_b=mu_b, kk_b=kk_b, hf=hf, k_b=k_b, cp_b=cp_b,
               D_macro=D_macro, gravity=gravity, E=E, g=g, Tref=Tref, htc=htc,
               dTdt=dTdt_flow, Tmax=Tmax_flow, t_hold=t_hold_flow,
               tcool=tcool_flow, T0=T0_flow,
               num_el_x=num_el_x, num_el_y=num_el_y, L=L,
               save_folder=save_folder, save_cycle=cycle, load_cycle=cycle,
               save_type="infiltration", load_type="pyrolysis")
    popen_or_fail("Infiltration (cycle {})".format(cycle), args,
                  log_path="logs/infiltration_cycle{}.log".format(cycle))


def run_curing(cycle):
    args = ["curing.i", "mesh_input.i", "initial_condition_from_exodus_1.i"]
    args += kv(rho_s=rho_s, rho_b=rho_b, rho_g=rho_g, rho_p=rho_p,
               cp_s=cp_s, cp_b=cp_b, cp_p=cp_p, cp_g=cp_p,
               k_s=k_s, k_b=k_b, k_p=k_p, k_g=k_p,
               Ea=Ea_cur, A=A_cur, R=R, hrp=hrp_cur, Y=Y_cur, order=order_cur,
               E=E, g=g, Tref=Tref, htc=htc,
               dTdt=dTdt_cur, Tmax=Tmax_cur, t_hold=t_hold_cur,
               tcool=tcool_cur, T0=T0_cur,
               pyro_mu=pyro_mu_cur, zeta=zeta_cur,
               num_el_x=num_el_x, num_el_y=num_el_y, L=L, Mref=Mref,
               save_folder=save_folder, save_cycle=cycle, load_cycle=cycle,
               save_type="curing", load_type="infiltration")
    popen_or_fail("Curing (cycle {})".format(cycle), args,
                  log_path="logs/curing_cycle{}.log".format(cycle))


def run_lsi_infiltration(save_cycle, load_cycle):
    args = ["infiltration_lsi.i", "initial_condition_from_exodus_4.i", "mesh_input.i"]
    args += kv(dt=dt, total_time=t_ramp_lsi + tinfiltrate,
               flux_in=flux_in_lsi, flux_out=flux_out_lsi,
               t_ramp=t_ramp_lsi, t_heat=theat_lsi, dTdt=dTdt_lsi,
               brooks_corey_threshold=brooks_corey_threshold,
               capillary_pressure_power=capillary_pressure_power,
               phi_L_residual=phi_L_residual, permeability_power=permeability_power,
               mu_Si=mu_Si, perm_ref=perm_ref, hf=1,
               kappa_Si=kappa_Si, kappa_SiC=kappa_SiC, kappa_C=kappa_C,
               D_macro=D_macro_lsi, D_macro_high=D_macro_high, D_macro_low=D_macro_low,
               transition_saturation_front=transition_saturation_front,
               transition_saturation_back=transition_saturation_back,
               transition_saturation_back_start=transition_saturation_back_start,
               reactivity_upbound=reactivity_upbound,
               reactivity_lowbound=reactivity_lowbound,
               K_nucl_growth=K_nucl_growth, h_c=h_c, htc=htc, phif_min=phif_min,
               E=E, nu=nu, therm_expansion=g, T0=T0, gravity=gravity,
               D_LP=D_LP, l_c=l_c, M_Si=M_Si, M_SiC=M_SiC, M_C=M_C,
               rho_Si=rho_Si, rho_SiC=rho_SiC, rho_C=rho_C,
               cp_Si=cp_Si, cp_SiC=cp_SiC, cp_C=cp_C, k_C=k_C, k_SiC=k_SiC,
               num_el_x=num_el_x, num_el_y=num_el_y, L=L,
               save_folder=save_folder, load_cycle=load_cycle, save_cycle=save_cycle,
               save_type="lsi_infiltration", load_type="pyrolysis")
    popen_or_fail("LSI Infiltration", args,
                  log_path="logs/lsi_infiltration_cycle{}.log".format(save_cycle))


def run_lsi_solidification(save_cycle, load_cycle):
    args = ["solidification.i", "mesh_input.i", "initial_condition_from_exodus_5.i"]
    args += kv(dt=dt, total_time=tcool_lsi + twait_lsi,
               t_ramp=tcool_lsi, dTdt=dTdt_cool_lsi, D_macro=D_macro_lsi,
               brooks_corey_threshold=brooks_corey_threshold,
               capillary_pressure_power=capillary_pressure_power,
               permeability_power=permeability_power,
               mu_Si=mu_Si, kappa_Si=kappa_Si, kappa_Si_s=kappa_Si_s,
               kappa_SiC=kappa_SiC, kappa_C=kappa_C, htc=htc,
               E=E, therm_expansion=g, T0=Tmax_lsi, Tref=Tref,
               Ts=Ts, Tf=Tf, H_latent=H_latent, M_Si=M_Si, phif_min=phif_min,
               solidification_rate=solidification_rate, gravity=gravity,
               rho_Si=rho_Si, rho_Si_s=rho_Si_s, rho_SiC=rho_SiC, rho_C=rho_C,
               E_Si=E_Si, E_C=E_C, nu_Si=nu_Si, nu_C=nu_C,
               cp_Si=cp_Si, cp_Si_s=cp_Si_s, cp_SiC=cp_SiC, cp_C=cp_C,
               num_el_x=num_el_x, num_el_y=num_el_y, kk_Si=perm_ref,
               flux_out=flux_out_lsi, L=L,
               save_folder=save_folder, load_cycle=load_cycle, save_cycle=save_cycle,
               save_type="lsi_solidification", load_type="lsi_infiltration")
    popen_or_fail("LSI Solidification", args,
                  log_path="logs/lsi_solidification_cycle{}.log".format(save_cycle))


# ---------------------------------------------------------------------------
def main():
    t0 = time.perf_counter()
    build_models()

    if RUN_PIP:
        run_pyrolysis(save_cycle=1, ic_file="initial_condition_from_csv.i", first=True)
        for i in range(pip_cycle_n - 1):
            cycle = i + 1
            run_infiltration(cycle)
            run_curing(cycle)
            run_pyrolysis(save_cycle=cycle + 1,
                          ic_file="initial_condition_from_exodus_2.i",
                          load_cycle=cycle, load_type="curing")

    run_lsi_infiltration(save_cycle=pip_cycle_n, load_cycle=pip_cycle_n)
    run_lsi_solidification(save_cycle=pip_cycle_n, load_cycle=pip_cycle_n)

    print("\nTotal time: {:.1f} s".format(time.perf_counter() - t0))


if __name__ == "__main__":
    main()
