# Copyright 2025, UChicago Argonne, LLC
# All Rights Reserved
# Software Name: PUMA: Powder Utilization Modeling Application
# By: UChicago Argonne, LLC
# OPEN SOURCE LICENSE (MIT)

import os
import subprocess
from pathlib import Path

from generate_random_field import generate_initial_conditions

HERE = Path(__file__).resolve().parent
PUMA = HERE / ".." / ".." / ".." / "puma-opt"
NEML2_MODEL = HERE / "neml2" / "neml2_material.i"
AOTI_STUB = HERE / "neml2" / "aoti" / "model_aoti.i"

CORES = 12
RECOMPILE = False
DEVICES = ["cpu"]

MESH_FILE = "gold/SiC_core.msh"
NUM_EL = 50
L = 0.04
LC = 0.0015
MIN_BINDER = 0.3
MAX_BINDER = 0.8


def cp_to_wg_relation(volume_binder):
    return 0.001


def op_to_binder_relation(v_nonreactants):
    return 0.8


def rho_g(T, P):
    return 13.0


MATERIAL = {
    "rho_s": 2260.0,
    "rho_b": 1250.0,
    "rho_p": 3210.0,
    "rho_g": rho_g(1, 1),
    "cp_s": 1592.0,
    "cp_b": 1200.0,
    "cp_p": 750.0,
    "k_s": 150.0,
    "k_b": 279.0,
    "k_p": 380.0,
    "A": 1.2727e14,
    "Ea": 209015.7262,
    "R": 8.31446261815324,
    "hrp": 1.58e6,
    "Y": 0.5534,
    "order": 7.3528,
    "pyro_mu": cp_to_wg_relation(1),
    "zeta": op_to_binder_relation(1),
    "Mref": 1.0,
    "E": 400e9,
    "g": 4e-6,
    "Tref": 300.0,
}

MOOSE = {
    "dt": 5.0,
    "num_el": NUM_EL,
    "L": L,
    "T0": 300.0,
    "Tmax": 1400.0,
    "dTdt": 20.0,
    "t_hold": 0.5,
    "tcool": 0.5,
    "htc": 200.0,
}


def neml2_constants(m):
    Mref = m["Mref"]
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
        "E": m["E"],
        "g": m["g"],
        "Tref": m["Tref"],
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
            "-d",
            "M1:T",
            "-d",
            "M2:T",
            "-d",
            "M3:T",
            "-d",
            "neml2_pk1:T",
            "-d",
            "pk2:deformation_gradient",
        ],
        cwd=str(HERE / "neml2"),
        env=env,
        check=True,
    )


def run(num_file_data):
    args = [
        "mpiexec",
        "-n",
        str(CORES),
        str(PUMA),
        "-i",
        "pyrolysis.i",
        "initial_condition_from_csv.i",
    ]
    args += ["{}={}".format(k, v) for k, v in MOOSE.items()]
    args += ["num_file_data={}".format(num_file_data)]
    subprocess.run(args, cwd=str(HERE), check=True)


if __name__ == "__main__":
    ic = generate_initial_conditions(
        MESH_FILE,
        LC,
        mode="mass_fraction",
        Mref=MATERIAL["Mref"],
        rho_b=MATERIAL["rho_b"],
        rho_p=MATERIAL["rho_p"],
        min_binder=MIN_BINDER,
        max_binder=MAX_BINDER,
        beta_a_binder=2.0,
        beta_b_binder=5.0,
        seed_binder=4562,
        mesh_scale=0.01,
        plot_cond=True,
    )
    write_neml2_header(NEML2_MODEL, neml2_constants(MATERIAL))
    if RECOMPILE or not AOTI_STUB.exists():
        compile_model()
    run(len(ic["z"]))
