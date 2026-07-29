# Copyright 2025, UChicago Argonne, LLC
# All Rights Reserved
# Software Name: PUMA: Powder Utilization Modeling Application
# By: UChicago Argonne, LLC
# OPEN SOURCE LICENSE (MIT)

import os
import subprocess
from pathlib import Path

HERE = Path(__file__).resolve().parent
PUMA = HERE.parents[4] / "puma-opt"
PY_MODELS = HERE.parents[4] / "neml2_models" / "python"
NEML2_MODEL = HERE / "neml2" / "neml2_material.i"
AOTI_STUB = HERE / "neml2" / "aoti" / "model_aoti.i"

CORES = 4
RECOMPILE = False
DEVICES = ["cpu", "cuda"]

MATERIAL = {
    "M_Si": 28.085,
    "M_SiC": 40.11,
    "M_C": 12.011,
    "rho_Si": 2.57,
    "rho_SiC": 3.21,
    "rho_C": 2.26,
    "D_LP": 9.5e-6,
    "l_c": 0.05,
    "h_c": 0.0076,
    "K_nucl_growth": 1.2e-15,
    "mu_Si": 0.01,
    "kk_ref": 1.0e-8,
    "k_C": 1.0,
    "k_SiC": 1.0,
    "D_macro": 0.00007,
    "D_macro_high": 0.0004,
    "D_macro_low": 0.00007,
    "transition_saturation_front": 0.75,
    "transition_saturation_back": 0.45,
    "transition_saturation_back_start": 0.65,
    "phi_noreact": 0.0,
    "reactivity_lowbound": 0.005,
    "reactivity_upbound": 0.05,
    "brooks_corey_threshold": 0.5e5,
    "capillary_pressure_power": 10,
    "phi_L_residual": 0.0,
    "permeability_power": 10.0,
    "initial_product_dummy_thickness": 1.0e-3,
}

MOOSE = {
    "dt": 0.5,
    "total_time": 1800,
    "flux_in": 0.01,
    "flux_out": 0.01,
    "t_ramp": 10,
    "L": 0.6,
    "n": 1000,
    "gravity": 0.0,
    "rho_Si": 2.57,
    "phi0_SiC": 0.00001,
    "phi0_C": 0.83,
}


def neml2_constants(m):
    omega_C = m["M_C"] / m["rho_C"]
    omega_Si = m["M_Si"] / m["rho_Si"]
    omega_SiC = m["M_SiC"] / m["rho_SiC"]
    return {
        "initial_product_dummy_thickness": m["initial_product_dummy_thickness"],
        "reactivity_lowbound": m["reactivity_lowbound"],
        "reactivity_upbound": m["reactivity_upbound"],
        "D": m["D_LP"] / m["l_c"],
        "oP_oL": omega_SiC / omega_Si,
        "K_nucl_growth": m["K_nucl_growth"] / m["l_c"],
        "omega_SiC": omega_SiC,
        "mhcolc": -m["h_c"] / m["l_c"],
        "oSiCm1": 1.0 / omega_SiC,
        "oCm1": 1.0 / omega_C,
        "chem_ratio": m["k_SiC"] / m["k_C"],
        "mchem_P": -m["k_SiC"],
        "omega_Si": omega_Si,
        "rhof": m["rho_Si"],
        "rhof_nu": m["rho_Si"] / m["mu_Si"],
        "rhof2_nu": m["rho_Si"] ** 2 / m["mu_Si"],
        "om_phinoreact": 1.0 - m["phi_noreact"],
        "Dmacro": m["D_macro"],
        "delta_Dscale_front": m["D_macro_high"] - m["D_macro"],
        "delta_Dscale_back": m["D_macro_low"] - m["D_macro"],
        "new_scale": (m["transition_saturation_back"] - m["transition_saturation_back_start"]) / 2.0,
        "transition_saturation_front": m["transition_saturation_front"],
        "transition_saturation_back": m["transition_saturation_back"],
        "transition_saturation_back_start": m["transition_saturation_back_start"],
        "kk_L": m["kk_ref"],
        "permeability_power": m["permeability_power"],
        "phif_residual": m["phi_L_residual"],
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
    args = ["mpiexec", "-n", str(CORES), str(PUMA), "-i", "infiltration.i"]
    args += ["{}={}".format(k, v) for k, v in MOOSE.items()]
    subprocess.run(args, cwd=str(HERE), check=True)


if __name__ == "__main__":
    write_neml2_header(NEML2_MODEL, neml2_constants(MATERIAL))
    if RECOMPILE or not AOTI_STUB.exists():
        compile_model()
    run()
