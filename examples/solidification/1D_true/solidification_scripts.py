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
NEML2_MODEL = HERE / "neml2" / "neml2_material.i"
AOTI_STUB = HERE / "neml2" / "aoti" / "model_aoti.i"

CORES = 4
RECOMPILE = False
DEVICES = ["cpu", "cuda"]

MATERIAL = {
    "M_Si": 28.085,
    "rho_Si": 2.57,
    "rho_Si_s": 2.37,
    "rho_SiC": 3.210,
    "rho_C": 2.260,
    "cp_Si": 0.7e7,
    "cp_Si_s": 0.5e7,
    "cp_SiC": 550e4,
    "cp_C": 1500e4,
    "kappa_Si": 1.4e7,
    "kappa_Si_s": 1.4e7,
    "kappa_SiC": 3e7,
    "kappa_C": 3e8,
    "H_latent": 1.2e8,
    "k_s": 20.0,  # 1D_true: dimensionless solidification rate constant (equilibrium form)
    "Ts": 1687,
    "Tf": 1707,
    "phif_min": 0.002,
    "mu_Si": 0.01,
    "kk_Si": 1e-8,
    "permeability_power": 8,
    "brooks_corey_threshold": 1e4,
    "capillary_pressure_power": 10,
}

MOOSE = {
    "dt": 20,
    "nx": 100,
    "xmax": 200.0,
    "Tmax": 1720,
    "T0": 300,
    "phif_min": 0.002,
    "rho_Si": 2.57,
    "D_macro": 0.001,
    "phi_C": 0.3,
    "phi_SiC": 0.2,
    "phi_Si0": 0.4,
    "flux_out": 0.1,
    "gravity": 0.0,
    "htc": 20000,
    "dTdt": -60,
    "t_hold": 3200,
}


def neml2_constants(m):
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
        "solidification_coef": m["k_s"] / (m["Tf"] - m["Ts"]),
        "mOfs_Ofl": -m["rho_Si"] / m["rho_Si_s"],
        "brooks_corey_threshold": m["brooks_corey_threshold"],
        "capillary_pressure_power": m["capillary_pressure_power"],
        "kk_L": m["kk_Si"],
        "permeability_power": m["permeability_power"],
        "rho_f": m["rho_Si"],
        "rhof_nu": m["rho_Si"] / m["mu_Si"],
        "rhof2_nu": m["rho_Si"] ** 2 / m["mu_Si"],
        "hf_rhof_onu": m["H_latent"] * m["rho_Si"] / m["mu_Si"],
        "hf_rhof2_onu": m["H_latent"] * m["rho_Si"] ** 2 / m["mu_Si"],
        "mhf_rhof": -m["H_latent"] * m["rho_Si"],
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


def compile_model():
    env = dict(os.environ)
    env["CC"] = "x86_64-conda-linux-gnu-gcc"
    env["CXX"] = "x86_64-conda-linux-gnu-g++"
    env["LIBRARY_PATH"] = "/usr/local/cuda/lib64/stubs:" + env.get("LIBRARY_PATH", "")
    subprocess.run(
        [
            "neml2-compile",
            "--model",
            "model",
            "neml2_material.i",
            "--dtype",
            "float64",
            "--device",
            *DEVICES,
            "--output-dir",
            "aoti",
            "--load",
            str(PY_MODELS),
            "-d",
            ":",
        ],
        cwd=str(HERE / "neml2"),
        env=env,
        check=True,
    )


def run():
    args = ["mpiexec", "-n", str(CORES), str(PUMA), "-i", "solidification.i"]
    args += ["{}={}".format(k, v) for k, v in MOOSE.items()]
    subprocess.run(args, cwd=str(HERE), check=True)


if __name__ == "__main__":
    write_neml2_header(NEML2_MODEL, neml2_constants(MATERIAL))
    if RECOMPILE or not AOTI_STUB.exists():
        compile_model()
    run()
