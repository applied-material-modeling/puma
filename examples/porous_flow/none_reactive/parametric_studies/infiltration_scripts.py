# Copyright 2025, UChicago Argonne, LLC
# All Rights Reserved
# Software Name: PUMA: Powder Utilization Modeling Application
# By: UChicago Argonne, LLC
# OPEN SOURCE LICENSE (MIT)

import os
import subprocess
import sys
from pathlib import Path

HERE = Path(__file__).resolve().parent
PUMA = HERE.parents[3] / "puma-opt"
PY_MODELS = HERE.parents[3] / "neml2_models" / "python"
NEML2_MODEL = HERE / "neml2" / "neml2_material.i"

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
    "D_LP": 0.0,
    "l_c": 0.01,
    "mu_Si": 0.01,
    "kk_ref": 1.0e-8,
    "k_C": 1.0,
    "k_SiC": 1.0,
    "D_macro": 0.0001,
    "D_macro_high": 0.0001,
    "D_macro_low": 0.0001,
    "transition_saturation_front": 0.75,
    "transition_saturation_back": 0.45,
    "transition_saturation_back_start": 0.65,
    "phi_noreact": 0.5,
    "reactivity_lowbound": 0.005,
    "reactivity_upbound": 0.1,
    # parametric-study defaults (overridden per variant)
    "permeability_power": 8,
    "ref_poro": 0.9,
    "brooks_corey_threshold": 1.0e5,
    "capillary_pressure_power": 20,
    "phif_residual": 0.0,
    "initial_product_dummy_thickness": 1.0e-3,
}

# Parametric study variants (paper Fig. flow_parametric).
#  - "typical" is the reference case; it is panel (a) and the baseline curve in (b)/(c).
#  - panel (b): capillary sweep -> vary brooks_corey_threshold (p_t) and capillary_pressure_power (lambda)
#  - panel (c): permeability sweep -> vary permeability_power (n_k) and ref_poro (phi_0)
# Each variant only needs to list the params it changes from MATERIAL.
VARIANTS = [
    # reference / panel (a) -- run longer so panel (a) can show t = 1 s ... 6 min
    {"name": "typical", "moose": {"total_time": 360}},
    # panel (b): capillary pressure
    {"name": "p1e6_pow20", "brooks_corey_threshold": 1.0e6},
    {"name": "p1e3_pow20", "brooks_corey_threshold": 1.0e3},
    {"name": "p1e1_pow20", "brooks_corey_threshold": 1.0e1},
    {"name": "p1e5_pow1", "capillary_pressure_power": 1},
    {"name": "p1e5_pow40", "capillary_pressure_power": 40},
    # panel (c): permeability
    {"name": "permpow5", "permeability_power": 5},
    {"name": "permpow8_phiref05", "ref_poro": 0.5},
    {"name": "permpow20_phiref09", "permeability_power": 20},
]

MOOSE = {
    "dt": 0.5,
    "total_time": 120,
    "flux_in": 0.2,
    "flux_out": 0.2,
    "t_ramp": 100,
    "gravity": 0,
    "rho_Si": 2.57,
    "phi0_SiC": 0.0,
    "phi0_C": 0.0,
    "L": 1,
    "n": 500,
}


def neml2_constants(m, v):
    """Derived NEML2 header values; v overrides the swept params in m."""
    p = {**m, **v}
    omega_C = p["M_C"] / p["rho_C"]
    omega_Si = p["M_Si"] / p["rho_Si"]
    omega_SiC = p["M_SiC"] / p["rho_SiC"]
    return {
        "initial_product_dummy_thickness": p["initial_product_dummy_thickness"],
        "D": p["D_LP"] / p["l_c"],
        "oP_oL": omega_SiC / omega_Si,
        "omega_Si": omega_Si,
        "oSiCm1": 1.0 / omega_SiC,
        "oCm1": 1.0 / omega_C,
        "chem_ratio": p["k_SiC"] / p["k_C"],
        "mchem_P": -p["k_SiC"],
        "rhof": p["rho_Si"],
        "rhof_nu": p["rho_Si"] / p["mu_Si"],
        "rhof2_nu": p["rho_Si"] ** 2 / p["mu_Si"],
        "om_phinoreact": 1.0 - p["phi_noreact"],
        "Dmacro": p["D_macro"],
        "delta_Dscale_front": p["D_macro_high"] - p["D_macro"],
        "delta_Dscale_back": p["D_macro_low"] - p["D_macro"],
        "new_scale": (p["transition_saturation_back"] - p["transition_saturation_back_start"]) / 2.0,
        "transition_saturation_front": p["transition_saturation_front"],
        "transition_saturation_back": p["transition_saturation_back"],
        "transition_saturation_back_start": p["transition_saturation_back_start"],
        "kk_L": p["kk_ref"],
        "permeability_power": p["permeability_power"],
        "ref_poro": p["ref_poro"],
        "phif_residual": p["phif_residual"],
        "brooks_corey_threshold": p["brooks_corey_threshold"],
        "capillary_pressure_power": p["capillary_pressure_power"],
        "reactivity_lowbound": p["reactivity_lowbound"],
        "reactivity_upbound": p["reactivity_upbound"],
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


def compile_model(name):
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
            "aoti/{}".format(name),
            "--load",
            str(PY_MODELS),
            "-d",
            ":",
        ],
        cwd=str(HERE / "neml2"),
        env=env,
        check=True,
    )


def run(name, moose_over=None):
    moose = {**MOOSE, **(moose_over or {})}
    args = ["mpiexec", "-n", str(CORES), str(PUMA), "-i", "infiltration.i"]
    args += ["NEML2/input=neml2/aoti/{}/model_aoti.i".format(name), "output={}".format(name)]
    args += ["{}={}".format(k, v) for k, v in moose.items()]
    subprocess.run(args, cwd=str(HERE), check=True)


if __name__ == "__main__":
    # optional CLI filter: run only the named variant(s), else run all
    wanted = set(sys.argv[1:])
    variants = [v for v in VARIANTS if not wanted or v["name"] in wanted]
    for variant in variants:
        write_neml2_header(NEML2_MODEL, neml2_constants(MATERIAL, variant))
        stub = HERE / "neml2" / "aoti" / variant["name"] / "model_aoti.i"
        if RECOMPILE or not stub.exists():
            compile_model(variant["name"])
        run(variant["name"], variant.get("moose"))
        print("=== done variant: {} ===".format(variant["name"]), flush=True)
