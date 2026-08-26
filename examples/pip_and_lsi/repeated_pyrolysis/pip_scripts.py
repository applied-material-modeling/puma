# Copyright 2025, UChicago Argonne, LLC
# All Rights Reserved
# Software Name: PUMA: Powder Utilization Modeling Application
# By: UChicago Argonne, LLC
# OPEN SOURCE LICENSE (MIT)
#
# NEML2 v3 driver for the pip_and_lsi/repeated_pyrolysis example.
#
#   pyrolysis(cycle 1)  -> pyrolysis(cycle 2) -> ... -> pyrolysis(cycle pip_cycle_n)
#
# A single pyrolysis NEML2 model is authored in neml2/neml2_material.i with a
# bare-name constant header; write_neml2_header() injects the real physical
# constants and compile_model() AOTI-compiles it into neml2/aoti/.
#
# Cycle 1 seeds the initial mass-fraction field from a random field written to
# initial_condition.csv (generate_random_field.py) and read via
# initial_condition_from_csv.i.  Each subsequent cycle hands off the previous
# cycle's exodus output through initial_condition_from_exodus.i.

import os
import sys
import time
import subprocess
from pathlib import Path

from generate_random_field import generate_initial_conditions

HERE = Path(__file__).resolve().parent
PUMA = HERE.parents[2] / "puma-opt"
PY_MODELS = HERE.parents[2] / "neml2_models" / "python"

CORES = 4
RECOMPILE = False           # force AOTI rebuild even if a stub exists
RUN_PIP = True              # run the repeated pyrolysis cycles
DEVICES = ["cpu"]

# ---------------------------------------------------------------------------
# Geometry / driver options
# ---------------------------------------------------------------------------
pip_cycle_n = 10           # number of repeated pyrolysis cycles
save_folder = "main"
mesh_file = "gold/2D_plane.msh"
reference_mass = 1.0
Mref = reference_mass
dt = 5

# BC anchor nodes (roller / fixed point)
width = 0.1
xroll, yroll, zroll = 0.1, 0.0, 0.0
xfix, yfix, zfix = 0.0, 0.0, 0.0

# ---------------------------------------------------------------------------
# Random-field initial condition options (cycle 1)
# ---------------------------------------------------------------------------
mode = "mass_fraction"
min_binder = 0.5
max_binder = 0.7
lc = 5.0
beta_a_binder = 2.0
beta_b_binder = 5.0
seed_binder = 4562
plot_ic = False            # skip matplotlib plotting (avoids font dependency)

# ---------------------------------------------------------------------------
# Physical constants (phenolic resin inside SiC particles)
# ---------------------------------------------------------------------------
R = 8.31446261815324

# densities [kg m-3]
rho_s = 2260.0
rho_b = 1250.0
rho_p = 3210.0
rho_g = 13.0

# heat capacity [J kg-1 K-1]
cp_s = 1592.0
cp_b = 1200.0
cp_p = 750.0
cp_g = 1e-4

# thermal conductivity [W m-1 K-1]
k_s = 150.0
k_b = 279.0
k_p = 380.0
k_g = 1e-4

# pyrolysis reaction
Ea = 21191.61425
A = 0.0421047
hrp = 1.58e5
Y = 0.575                 # char yield
order = 1.0
pyro_mu = 0.001           # close-pore / consumed-binder relation
zeta = 0.8                # open-pore / consumed-binder relation

# stress-strain
E = 400e9
Tref = 300.0
g = 0.0                   # thermal expansion coefficient

# convection
htc = 200.0

# pyrolysis heating profile
T0 = 300.0
Tmax = 1000.0
dTdt = 20.0               # K min-1 heating rate
t_hold = 0.5             # hrs
tcool = 0.5              # hrs


# ---------------------------------------------------------------------------
# NEML2 header constants injected into neml2/neml2_material.i
# ---------------------------------------------------------------------------
def header_params():
    return {
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


def compile_model():
    src = HERE / "neml2" / "neml2_material.i"
    env = dict(os.environ)
    env["CC"] = "x86_64-conda-linux-gnu-gcc"
    env["CXX"] = "x86_64-conda-linux-gnu-g++"
    env["LIBRARY_PATH"] = "/usr/local/cuda/lib64/stubs:" + env.get("LIBRARY_PATH", "")
    subprocess.run(
        ["neml2-compile", "--model", "model", src.name,
         "--dtype", "float64", "--device", *DEVICES,
         "--output-dir", "aoti", "--load", str(PY_MODELS), "-d", ":"],
        cwd=str(HERE / "neml2"), env=env, check=True,
    )


def build_models():
    src = HERE / "neml2" / "neml2_material.i"
    write_neml2_header(src, header_params())
    stub = HERE / "neml2" / "aoti" / "model_aoti.i"
    if RECOMPILE or not stub.exists():
        print("==> compiling pyrolysis", flush=True)
        compile_model()


# ---------------------------------------------------------------------------
# Initial condition (random binder mass-fraction field for cycle 1)
# ---------------------------------------------------------------------------
def generate_ic():
    ic = generate_initial_conditions(
        mesh_file, lc, mode=mode, Mref=reference_mass,
        rho_b=rho_b, rho_p=rho_p,
        min_binder=min_binder, max_binder=max_binder,
        beta_a_binder=beta_a_binder, beta_b_binder=beta_b_binder,
        seed_binder=seed_binder, plot_cond=plot_ic,
    )
    return len(ic["z"])


# ---------------------------------------------------------------------------
# MOOSE stage runner
# ---------------------------------------------------------------------------
def popen_or_fail(step_name, moose_args, log_path=None):
    # --allow-unused: physical constants are now baked into the compiled AOTI
    # model and are only partially referenced by pyrolysis.i / the IC files, so
    # tolerate unused command-line params.
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


def run_pyrolysis(cycle, num_file_data=None, first=False):
    ic_file = "initial_condition_from_csv.i" if first else "initial_condition_from_exodus.i"
    args = ["pyrolysis.i", ic_file]
    args += kv(rho_s=rho_s, rho_b=rho_b, rho_g=rho_g, rho_p=rho_p,
               cp_s=cp_s, cp_b=cp_b, cp_p=cp_p, cp_g=cp_g,
               k_s=k_s, k_b=k_b, k_p=k_p, k_g=k_g,
               Ea=Ea, A=A, R=R, hrp=hrp, Y=Y, order=order,
               E=E, g=g, Tref=Tref, htc=htc,
               Tmax=Tmax, t_hold=t_hold, tcool=tcool, T0=T0, dTdt=dTdt,
               pyro_mu=pyro_mu, zeta=zeta,
               meshfile=mesh_file, xroll=xroll, yroll=yroll, zroll=zroll,
               xfix=xfix, yfix=yfix, zfix=zfix,
               Mref=reference_mass, save_folder=save_folder, cycle=cycle)
    if first:
        args += kv(num_file_data=num_file_data)
    popen_or_fail("Pyrolysis (cycle {})".format(cycle), args,
                  log_path="logs/pyrolysis_cycle{}.log".format(cycle))


# ---------------------------------------------------------------------------
def main():
    t0 = time.perf_counter()
    build_models()

    if RUN_PIP:
        num_file_data = generate_ic()
        run_pyrolysis(1, num_file_data=num_file_data, first=True)
        for i in range(pip_cycle_n - 1):
            run_pyrolysis(i + 2)

    print("\nTotal time: {:.1f} s".format(time.perf_counter() - t0))


if __name__ == "__main__":
    main()
