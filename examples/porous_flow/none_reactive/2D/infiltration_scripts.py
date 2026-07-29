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
DEVICES = ["cpu", "cuda"]

MATERIAL = {
    "rho_PR": 2.57,
    "mu_PR": 10.0,
    "kk_PR": 2.0e-5,
    "permeability_power": 3,
    "brooks_corey_threshold": 1.0e5,
    "capillary_pressure_power": 3,
}

MOOSE = {
    "dt": 5,
    "total_time": 3000,
    "flux_in": 0.1,
    "flux_out": 0.1,
    "t_ramp": 1000,
    "gravity": 980.665,
    "rho_PR": 2.57,
    "D_macro": 0.005,
    "porosity_feature": 0.2,
    "porosity_background": 0.8,
}


def neml2_constants(m):
    return {
        "kk_L": m["kk_PR"],
        "permeability_power": m["permeability_power"],
        "rhof_nu": m["rho_PR"] / m["mu_PR"],
        "rhof2_nu": m["rho_PR"] ** 2 / m["mu_PR"],
        "brooks_corey_threshold": m["brooks_corey_threshold"],
        "capillary_pressure_power": m["capillary_pressure_power"],
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
    args = ["mpiexec", "-n", str(CORES), str(PUMA), "-i", "infiltration_binary.i"]
    args += ["{}={}".format(k, v) for k, v in MOOSE.items()]
    subprocess.run(args, cwd=str(HERE), check=True)


if __name__ == "__main__":
    write_neml2_header(NEML2_MODEL, neml2_constants(MATERIAL))
    if RECOMPILE or not AOTI_STUB.exists():
        compile_model()
    run()
