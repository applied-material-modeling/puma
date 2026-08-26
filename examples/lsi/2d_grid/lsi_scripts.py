# Copyright 2025, UChicago Argonne, LLC
# All Rights Reserved
# Software Name: PUMA: Powder Utilization Modeling Application
# By: UChicago Argonne, LLC
# OPEN SOURCE LICENSE (MIT)

import os
import subprocess
from pathlib import Path

HERE = Path(__file__).resolve().parent
PUMA = HERE.parents[2] / "puma-opt"
PY_MODELS = HERE.parents[2] / "neml2_models" / "python"
REACTIVE_MODEL = HERE / "neml2" / "neml2_reactive_flow.i"
SOLID_MODEL = HERE / "neml2" / "neml2_solidification.i"
REACTIVE_STUB = HERE / "neml2" / "aoti_reactive" / "model_aoti.i"
SOLID_STUB = HERE / "neml2" / "aoti_solidification" / "model_aoti.i"

CORES = 6
RECOMPILE = False
RUN_INFILTRATION = False
DEVICES = ["cpu"]

num_el_x = 51
num_el_y = 101
L = 0.1
C_ratio = 0.2
phif_min = 0.0001

MATERIAL = {
    "gravity": 9.806,
    "rho_Si": 2570.0,
    "rho_SiC": 3210.0,
    "rho_C": 2260.0,
    "rho_Si_s": 2370.0,
    "M_Si": 0.028085,
    "M_SiC": 0.04011,
    "M_C": 0.012011,
    "cp_Si": 705.0,
    "cp_Si_s": 500.0,
    "cp_SiC": 690.0,
    "cp_C": 1500.0,
    "kappa_Si": 148.0,
    "kappa_Si_s": 140.0,
    "kappa_SiC": 120.0,
    "kappa_C": 300.0,
    "mu_Si": 0.1,
    "perm_ref": 1e-7,
    "D_macro": 7e-8,
    "D_macro_high": 4e-6,
    "D_macro_low": 7e-8,
    "transition_saturation_front": 0.75,
    "transition_saturation_back": 0.45,
    "transition_saturation_back_start": 0.65,
    "brooks_corey_threshold": 0.5e5,
    "capillary_pressure_power": 10,
    "permeability_power": 20.0,
    "D_LP": 9.5e-6,
    "l_c": 0.1,
    "h_c": 0.0076,
    "K_nucl_growth": 1.2e-15,
    "k_C": 1.0,
    "k_SiC": 1.0,
    "reactivity_upbound": 0.05,
    "reactivity_lowbound": 0.001,
    "Ts": 1667.0,
    "Tf": 1707.0,
    "H_latent": 1787e3,
    "solidification_rate": 0.002,
    "E": 400e9,
    "E_Si": 160e9,
    "E_C": 400e9,
    "nu_Si": 0.3,
    "nu_C": 0.3,
    "therm_expansion": 2.3e-6,
    "Tref": 300.0,
    "Tmax": 1720.0,
}

dt = 5
dTdt = 10.0
T0 = 300.0
Tmax = 1720.0
theat = (Tmax - T0) / dTdt
t_ramp = theat + 500
tinfiltrate = 7200
flux_in = 0.05
flux_out = 0.1
htc = 200
dTdt_cool = -1
tcool = (Tmax - T0) / (-dTdt_cool)
twait = 7200

MOOSE_STAGE1 = {
    "dt": dt,
    "total_time": t_ramp + tinfiltrate,
    "flux_in": flux_in,
    "flux_out": flux_out,
    "t_ramp": t_ramp,
    "t_heat": theat,
    "dTdt": dTdt,
    "htc": htc,
    "T0": T0,
    "gravity": MATERIAL["gravity"],
    "C_ratio": C_ratio,
    "num_el_x": num_el_x,
    "num_el_y": num_el_y,
    "L": L,
}

MOOSE_STAGE2 = {
    "dt": dt,
    "total_time": tcool + twait,
    "t_ramp": tcool,
    "dTdt": dTdt_cool,
    "htc": htc,
    "T0": Tmax,
    "phif_min": phif_min,
    "gravity": MATERIAL["gravity"],
    "flux_out": flux_out,
    "num_el_x": num_el_x,
    "num_el_y": num_el_y,
    "L": L,
    # M2 = D_macro * rho_Si in solidification.i (init_mat); supply both so the
    # ${fparse D_macro*rho_Si} in the stage-2 input resolves from MATERIAL.
    "D_macro": MATERIAL["D_macro"],
    "rho_Si": MATERIAL["rho_Si"],
}


def neml2_constants_reactive(m):
    omega_C = m["M_C"] / m["rho_C"]
    omega_Si = m["M_Si"] / m["rho_Si"]
    omega_SiC = m["M_SiC"] / m["rho_SiC"]
    return {
        "initial_product_dummy_thickness": 1e-3,
        "reactivity_lowbound": m["reactivity_lowbound"],
        "reactivity_upbound": m["reactivity_upbound"],
        "D": m["D_LP"] / m["l_c"],
        "oP_oL": omega_SiC / omega_Si,
        "K_nucl_growth": m["K_nucl_growth"] * m["l_c"],
        "omega_SiC": omega_SiC,
        "mhcolc": -m["h_c"] / m["l_c"],
        "oSiCm1": 1.0 / omega_SiC,
        "oCm1": 1.0 / omega_C,
        "chem_ratio": m["k_SiC"] / m["k_C"],
        "mchem_P": -m["k_SiC"],
        "omega_Si": omega_Si,
        "rho_f": m["rho_Si"],
        "rhof_nu": m["rho_Si"] / m["mu_Si"],
        "rhof2_nu": m["rho_Si"] ** 2 / m["mu_Si"],
        "Dmacro": m["D_macro"],
        "delta_Dscale_front": m["D_macro_high"] - m["D_macro"],
        "delta_Dscale_back": m["D_macro_low"] - m["D_macro"],
        "new_scale": (m["transition_saturation_back"] - m["transition_saturation_back_start"]) / 2.0,
        "transition_saturation_front": m["transition_saturation_front"],
        "transition_saturation_back": m["transition_saturation_back"],
        "transition_saturation_back_start": m["transition_saturation_back_start"],
        "kk_L": m["perm_ref"],
        "permeability_power": m["permeability_power"],
        "brooks_corey_threshold": m["brooks_corey_threshold"],
        "capillary_pressure_power": m["capillary_pressure_power"],
        "rhocp_Si": m["rho_Si"] * m["cp_Si"],
        "rhocp_SiC": m["rho_SiC"] * m["cp_SiC"],
        "rhocp_C": m["rho_C"] * m["cp_C"],
        "kap_Si": m["kappa_Si"],
        "kap_SiC": m["kappa_SiC"],
        "kap_C": m["kappa_C"],
        "E": m["E"],
        "therm_expansion": m["therm_expansion"],
        "Tref": m["Tref"],
    }


def neml2_constants_solidification(m):
    return {
        "cp_rhofl": m["cp_Si"] * m["rho_Si"],
        "cp_rhofs": m["cp_Si_s"] * m["rho_Si_s"],
        "cp_rhos": m["cp_C"] * m["rho_C"],
        "cp_rhop": m["cp_SiC"] * m["rho_SiC"],
        "kap_fl": m["kappa_Si"],
        "kap_fs": m["kappa_Si_s"],
        "kap_s": m["kappa_C"],
        "kap_p": m["kappa_SiC"],
        "Ts": m["Ts"],
        "Tl": m["Tf"],
        "mphi_min": -phif_min,
        "m_solidification_rate": -m["solidification_rate"],
        "mOfs_Ofl": -m["rho_Si"] / m["rho_Si_s"],
        "brooks_corey_threshold": m["brooks_corey_threshold"],
        "capillary_pressure_power": m["capillary_pressure_power"],
        "kk_L": m["perm_ref"],
        "permeability_power": m["permeability_power"],
        "rho_f": m["rho_Si"],
        "rhof_nu": m["rho_Si"] / m["mu_Si"],
        "rhof2_nu": m["rho_Si"] ** 2 / m["mu_Si"],
        "hf_rhof_onu": m["H_latent"] * m["rho_Si"] / m["mu_Si"],
        "hf_rhof2_onu": m["H_latent"] * m["rho_Si"] ** 2 / m["mu_Si"],
        "mhf_rhof": -m["H_latent"] * m["rho_Si"],
        "therm_expansion": m["therm_expansion"],
        "Tref": m["Tref"],
        "Tref_l": m["Tmax"],
        "E": m["E"],
        "E_fs": m["E_Si"],
        "E_m": m["E_C"],
        "nu_fs": m["nu_Si"],
        "nu_m": m["nu_C"],
        "delta_Omega": m["rho_Si"] / m["rho_Si_s"] - 1.0,
    }


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


def compile_model(model_file, out_dir):
    env = dict(os.environ)
    env["CC"] = "x86_64-conda-linux-gnu-gcc"
    env["CXX"] = "x86_64-conda-linux-gnu-g++"
    env["LIBRARY_PATH"] = "/usr/local/cuda/lib64/stubs:" + env.get("LIBRARY_PATH", "")
    subprocess.run(
        [
            "neml2-compile",
            "--model",
            "model",
            model_file.name,
            "--dtype",
            "float64",
            "--device",
            *DEVICES,
            "--output-dir",
            out_dir,
            "--load",
            str(PY_MODELS),
            "-d",
            ":",
        ],
        cwd=str(HERE / "neml2"),
        env=env,
        check=True,
    )


def num_rows(csv):
    with open(csv) as f:
        return sum(1 for _ in f)


def run_stage1():
    args = ["mpiexec", "-n", str(CORES), str(PUMA), "-i",
            "infiltration.i", "initial_condition_from_csv.i", "mesh_input.i"]
    moose = dict(MOOSE_STAGE1)
    moose["num_file_data"] = num_rows(HERE / "initial_condition.csv")
    args += ["{}={}".format(k, v) for k, v in moose.items()]
    subprocess.run(args, cwd=str(HERE), check=True)


def run_stage2():
    args = ["mpiexec", "-n", str(CORES), str(PUMA), "-i",
            "solidification.i", "mesh_input.i", "initial_condition_from_exodus.i"]
    args += ["{}={}".format(k, v) for k, v in MOOSE_STAGE2.items()]
    subprocess.run(args, cwd=str(HERE), check=True)


if __name__ == "__main__":
    write_neml2_header(REACTIVE_MODEL, neml2_constants_reactive(MATERIAL))
    write_neml2_header(SOLID_MODEL, neml2_constants_solidification(MATERIAL))
    if RECOMPILE or not REACTIVE_STUB.exists():
        compile_model(REACTIVE_MODEL, "aoti_reactive")
    if RECOMPILE or not SOLID_STUB.exists():
        compile_model(SOLID_MODEL, "aoti_solidification")
    if RUN_INFILTRATION:
        run_stage1()
    run_stage2()
