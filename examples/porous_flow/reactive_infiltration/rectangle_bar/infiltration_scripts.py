# Copyright 2025, UChicago Argonne, LLC
# All Rights Reserved
# Software Name: PUMA: Powder Utilization Modeling Application
# By: UChicago Argonne, LLC
# OPEN SOURCE LICENSE (MIT)

import os
import subprocess
from pathlib import Path

HERE = Path(__file__).resolve().parent
PUMA = HERE.parents[3] / "puma-opt"
PY_MODELS = HERE.parents[3] / "neml2_models" / "python"
NEML2_MODEL = HERE / "neml2" / "neml2_material.i"
AOTI_STUB = HERE / "neml2" / "aoti" / "model_aoti.i"

CORES = 4
RECOMPILE = False
DEVICES = ["cpu"]

MATERIAL = {
    "M_Si": 28.085,
    "M_SiC": 40.11,
    "M_C": 12.011,
    "rho_Si": 2.57,
    "rho_SiC": 3.21,
    "rho_C": 2.26,
    "D_LP": 2.65e-6,
    "l_c": 1.0,
    "mu_Si": 10.0,
    "kk_ref": 2.0e-5,
    "k_C": 1.0,
    "k_SiC": 1.0,
    "D_macro": 0.001,
    "brooks_corey_threshold": 1.0e6,
    "capillary_pressure_power": 10,
    "permeability_power": 10,
    "phip_noreact": 0.5,
}

MOOSE = {
    "dt": 5,
    "total_time": 3600,
    "flux_in": 0.1,
    "flux_out": 0.1,
    "t_ramp": 1000,
    "gravity": 980.665,
    "rho_Si": 2.57,
    "D_macro": 0.001,
    "phi0_SiC": 0.001,
    "phi0_C": 0.1,
    "h0_pool": 1.3,
    "levelset_smooth_transistion": 0.1,
}


def neml2_constants(m):
    omega_C = m["M_C"] / m["rho_C"]
    omega_Si = m["M_Si"] / m["rho_Si"]
    omega_SiC = m["M_SiC"] / m["rho_SiC"]
    return {
        "D": m["D_LP"] / m["l_c"] ** 2,
        "omega_Si": omega_Si,
        "oSiCm1": 1.0 / omega_SiC,
        "oCm1": 1.0 / omega_C,
        "chem_ratio": m["k_SiC"] / m["k_C"],
        "mchem_P": -m["k_SiC"],
        "rhof": m["rho_Si"],
        "kk_L": m["kk_ref"],
        "permeability_power": m["permeability_power"],
        "rhof_nu": m["rho_Si"] / m["mu_Si"],
        "rhof2_nu": m["rho_Si"] ** 2 / m["mu_Si"],
        "brooks_corey_threshold": m["brooks_corey_threshold"],
        "capillary_pressure_power": m["capillary_pressure_power"],
        "D_macro": m["D_macro"],
        "phip_noreact": m["phip_noreact"],
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
    args = ["mpiexec", "-n", str(CORES), str(PUMA), "-i", "infiltration.i"]
    args += ["{}={}".format(k, v) for k, v in MOOSE.items()]
    subprocess.run(args, cwd=str(HERE), check=True)


if __name__ == "__main__":
    write_neml2_header(NEML2_MODEL, neml2_constants(MATERIAL))
    if RECOMPILE or not AOTI_STUB.exists():
        compile_model()
    run()
