# Copyright 2025, UChicago Argonne, LLC
# All Rights Reserved
# Software Name: PUMA: Powder Utilization Modeling Application
# By: UChicago Argonne, LLC
# OPEN SOURCE LICENSE (MIT)

import os
import subprocess
from pathlib import Path

HERE = Path(__file__).resolve().parent
PUMA = HERE / ".." / ".." / ".." / "puma-opt"
NEML2_MODEL = HERE / "neml2" / "neml2_material.i"
AOTI_STUB = HERE / "neml2" / "aoti" / "model_aoti.i"

CORES = 4
RECOMPILE = False
DEVICES = ["cpu", "cuda"]

MATERIAL = {
    "rho_s": 2100.0,
    "rho_b": 1250.0,
    "rho_p": 3210.0,
    "rho_g": 13.0,
    "cp_s": 1592.0,
    "cp_b": 1200.0,
    "cp_p": 750.0,
    "k_s": 150.0,
    "k_b": 279.0,
    "k_p": 380.0,
    "A": 0.0421047,
    "Ea": 21191.61425,
    "R": 8.31446261815324,
    "hrp": 1.58e5,
    "Y": 0.575,
    "order": 1.0,
    "pyro_mu": 0.05,
    "zeta": 0.05,
    "ms0": 3.0,
    "mb0": 10.0,
    "mp0": 5.0,
    "mg0": 0.0,
}

MOOSE = {
    "dt": 20.0,
    "nx": 100,
    "xmax": 2.0,
    "T0": 300.0,
    "Tmax": 1100.0,
    "dTdt": 10.0,
    "phiop0": 0.001,
}


def neml2_constants(m):
    Mref = m["ms0"] + m["mb0"] + m["mp0"] + m["mg0"]
    return {
        "A": m["A"],
        "Ea": m["Ea"],
        "R": m["R"],
        "order": m["order"],
        "mY": -m["Y"],
        "mu": m["pyro_mu"],
        "mzeta": -m["zeta"],
        "Mref": Mref,
        "rho_s": m["rho_s"],
        "rho_b": m["rho_b"],
        "rho_p": m["rho_p"],
        "rho_g": m["rho_g"],
        "rho_sm1M": Mref / m["rho_s"],
        "rho_bm1M": Mref / m["rho_b"],
        "rho_pm1M": Mref / m["rho_p"],
        "rho_gm1M": Mref / m["rho_g"],
        "cp_s": m["cp_s"],
        "cp_b": m["cp_b"],
        "cp_p": m["cp_p"],
        "k_s": m["k_s"],
        "k_b": m["k_b"],
        "k_p": m["k_p"],
        "source_coeff": -m["rho_s"] * m["hrp"],
        "wp0": m["mp0"] / Mref,
        "mwb0": -m["mb0"] / Mref,
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
                out.append("{} = {!r}".format(key, params[key]))
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
            "neml2-compile", "--model", "model", "neml2_material.i",
            "--dtype", "float64", "--device", *DEVICES,
            "--output-dir", "aoti", "-d", "M1:T", "-d", "M2:T", "-d", "M3:T",
        ],
        cwd=str(HERE / "neml2"),
        env=env,
        check=True,
    )


def run():
    args = ["mpiexec", "-n", str(CORES), str(PUMA), "-i", "pyrolysis.i"]
    args += ["{}={}".format(k, v) for k, v in MOOSE.items()]
    args += ["{}={}".format(k, MATERIAL[k]) for k in ("ms0", "mb0", "mp0", "mg0")]
    subprocess.run(args, cwd=str(HERE), check=True)


if __name__ == "__main__":
    write_neml2_header(NEML2_MODEL, neml2_constants(MATERIAL))
    if RECOMPILE or not AOTI_STUB.exists():
        compile_model()
    run()
