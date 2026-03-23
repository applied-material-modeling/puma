import numpy as np
import subprocess
import os
import time
import sys
import subprocess
from pathlib import Path

start_time = time.perf_counter()

def popen_or_fail(step_name, argv, log_path=None):
    """Run argv with Popen; exit immediately on non-zero code."""
    print("\n==> {}".format(step_name), flush=True)
    if log_path:
        Path(log_path).parent.mkdir(parents=True, exist_ok=True)
        with open(log_path, "w") as lf:
            proc = subprocess.Popen(
                argv,
                stdin=subprocess.DEVNULL,
                stdout=lf,
                stderr=subprocess.STDOUT,
                text=True
            )
            proc.wait()
    else:
        proc = subprocess.Popen(
            argv,
            stdin=subprocess.DEVNULL,
            stdout=subprocess.PIPE,
            stderr=subprocess.STDOUT,
            text=True
        )
        for line in proc.stdout:
            print(line, end="")
        proc.wait()

    if proc.returncode != 0:
        print("ERROR: {} failed with code {}".format(step_name, proc.returncode), file=sys.stderr)
        sys.exit(proc.returncode)

########################################## Input ##############################################
##                                                                                           ##
## Currently assumed the resin fully filled the open pores gas during polymer infiltration   ##
## all of the gas managed to escaped, pores production based on the amount of initial binder ##
## trapped gas production based on the porosity at the begining of the pyrolysis             ##
##                                                                                           ##
###############################################################################################

pip_cycle_n = 2  # number of pip cycles
save_folder = "out_2"
corenum = 14  # number of cores used for simulation
puma_run_file = "./../../../puma-opt"

run_pip = True  # run the PIP simulation

# rate of close pore relative to volume of produced gas
def cp_to_wg_relation(volume_binder, relation=0.001):
    return relation


# portion of open pores as a function of binder consumed
def op_to_binder_relation(v_nonreactants, relation=0.99):
    return relation


# gas density as a function of temperature and pressure
def rho_g(T, P):
    return 13  # kg m-3


########################### parts and geometry information ####################################
# geometry
reference_mass = 1.0  # reference mass

meshfile = "gold/core.msh2"

############################# material and reaction properties ################################
##           Current properties are for phenolic resin inside SiC praticles                  ##

# universal constant
R = 8.31446261815324  # JK-1mol-1

# denisty kgm-3
rho_s = 2260
rho_b = 1250  # 1.2 and 1.4
rho_p = 3210
rho_Si = 2570  # density at liquid state
rho_SiC = rho_p
rho_C = rho_s

# Molar Mass # kg mol-1
M_Si = 0.028085
M_SiC = 0.04011
M_C = 0.012011

# heat capacity Jkg-1K-1
cp_s = 1592
cp_b = 1200
cp_p = 750
cp_g = 1e-4
cp_Si = 705
cp_SiC = cp_p
cp_C = cp_s

# thermal conductivity W/m-1K-1
k_s = 150
k_b = 279
k_p = 380  # 120 and 490
k_g = 1e-4
kappa_Si = 148 
kappa_SiC = k_p
kappa_C = k_s

# reaction type for pyrolysis
Ea = 208170  # J mol-1
A = 0.7e14  # s-1
hrp = 1.58e6  # e6 J kg-1
Y = 0.55  # char yield [.]
order = 7.4496

# reaction type for curing
Ea_cur = 98000  # J mol-1
A_cur = 1e12  # s-1
hrp_cur = 1.58e3  # e6 J kg-1
Y_cur = 0.25  # char yield [.]
order_cur = 1.0

# porous flow information
flux_in = 0.005 # volume fraction
flux_out = 0.05
brooks_corey_threshold = 3e4 #Pa
capillary_pressure_power = 8
phi_L_residual = 0.0
permeability_power = 8

mu_b = 10 # liquid viscosity
kk_b = 2e-5 # solid permeability
hf = 0.0
D_macro = 0.000001 #m2 s-1 # macroscopic property
gravity = 0.0# 9.80665

# porous flow properties - lsi
mu_Si = 10  # kg m-1s-1
perm_ref = 2e-5  # permeability
D_macro_lsi = 2e-5 # cm2 s-1
D_macro_high = 1e-6 # cm2 s-1
D_macro_low = 2e-5 #0.003 # cm2 s-1

transition_saturation_front = 0.75
transition_saturation_back = 0.45
transition_saturation_back_start = 0.65

# reactive infiltration properties
D_LP = 9.5e-6 # cm2 s-1
l_c = 0.1 # cm
h_c = 0.0076  # cm
K_nucl_growth = 1.2e-15  # cm s-1
k_C = 1.0
k_SiC = 1.0
reactivity_upbound = 0.1
reactivity_lowbound = 0.001

# solidification information
phif_min = 0.0001
Ts = 1667  # K
Tf = Ts + 40  # K
H_latent = 1787e3  # J/kg
rho_Si_s = 2370  # density at solid state
cp_Si_s = 500 # Jkg-1K-1
kappa_Si_s = 140 # J m-1 s-1 K-1
solidification_rate = 0.002

#### stress-strain ####
E = 400e9
nu = 0.3
E_Si = 160e9
E_C = 400e9 
nu_Si = 0.3
nu_C = 0.3

# thermal expansion coefficients (degree-1)
Tref = 300  # K
g = 1e-6

# convection coefficients - Wm-2K
htc = 40

# heating profiles for pyrolysis
T0 = 300  # K - starting and cooling temperatures
Tmax = 1400  # K
dTdt = 10  # Kmin-1 heating rate
t_hold = 2.0  # hrs
tcool = 2.0  # hrs

# heating profiles for curing
T0_cur = 300  # K - starting and cooling temperatures
Tmax_cur = 420  # K
dTdt_cur = 5  # Kmin-1 heating rate
t_hold_cur = 2.0  # hrs
tcool_cur = 2.0  # hrs

# heating profiles for porous flow
T0_flow = 300  # K - starting and cooling temperatures
Tmax_flow = 400  # K
dTdt_flow = 10  # Kmin-1 heating rate
t_hold_flow = 1.5  # hrs
tcool_flow = 1.0  # hrs

# heating profiles before reactive infiltration
T0_lsi = Tref  # K - starting and cooling temperatures
Tmax_lsi = 1720  # K
dTdt_lsi = 10.0  # Ks-1 heating rate
theat_lsi = (Tmax_lsi - T0_lsi) / dTdt_lsi
tinfiltrate = 3 * 3600  # s
flux_in_lsi = 0.005
flux_out_lsi = 0.005
t_ramp = theat_lsi + 500

# heating profiles during solidification
dTdt_cool_lsi = -1  # deg per s
Tfinal_lsi = Tref  # K
tcool_lsi = (Tmax_lsi - Tfinal_lsi) / (-dTdt_cool_lsi)
twait_lsi = 8 * 3600
t_ramp_lsi = theat_lsi + 500

# Simulation parameters
dt = 5

###############################################################################################
##                                                                                           ##
##                                       MAIN                                                ##
##                                                                                           ##
###############################################################################################

# remove the save folder if it exists
# subprocess.run(["rm", "-rf", save_folder])

# generate the initial conditions
print("\n")

# identify the number of rows in initial_condition.csv file
initial_condition_file = "initial_condition.csv"

if not os.path.exists(initial_condition_file):
    raise FileNotFoundError(f"{initial_condition_file} does not exist. Please generate it first.")
with open(initial_condition_file, "r") as f:
    num_file_data = sum(1 for line in f)

# num_rows = 100000  # For testing purposes, we set a fixed number of rows

print("Identified {} rows in initial_condition.csv \n".format(num_file_data))


print("\n")

# ------------------------------ EXECUTION ------------------------------
if run_pip:
    # ---------------- Pyrolysis cycle 1 ----------------
    popen_or_fail(
        "Pyrolysis (cycle 1)",
        [
            "mpiexec",
            "-n",
            str(corenum),
            puma_run_file,
            "-i",
            "pyrolysis.i",
            "mesh_input.i",
            "initial_condition_from_csv.i",
            "rho_s={:.9f}".format(rho_s),
            "rho_b={:.9f}".format(rho_b),
            "rho_g={:.9f}".format(rho_g(1, 1)),
            "rho_p={:.9f}".format(rho_p),
            "cp_s={:.9f}".format(cp_s),
            "cp_b={:.9f}".format(cp_b),
            "cp_p={:.9f}".format(cp_p),
            "cp_g={:.9f}".format(cp_p),
            "k_s={:.9f}".format(k_s),
            "k_b={:.9f}".format(k_b),
            "k_p={:.9f}".format(k_p),
            "k_g={:.9f}".format(k_p),
            "Ea={:.9f}".format(Ea),
            "A={:.9f}".format(A),
            "R={:.9f}".format(R),
            "hrp={:.9f}".format(hrp),
            "Y={:.9f}".format(Y),
            "order={:.9f}".format(order),
            "E={:.9f}".format(E),
            "g={:.9f}".format(g),
            "Tref={:.9f}".format(Tref),
            "htc={:.9f}".format(htc),
            "Tmax={:.9f}".format(Tmax),
            "t_hold={:.9f}".format(t_hold),
            "tcool={:.9f}".format(tcool),
            "T0={:.9f}".format(T0),
            "dTdt={:.9f}".format(dTdt),
            "pyro_mu={:.9f}".format(cp_to_wg_relation(1)),
            "zeta={:.9f}".format(op_to_binder_relation(1)),
            "meshfile={}".format(meshfile),
            "Mref={:.9f}".format(reference_mass),
            "num_file_data={}".format(num_file_data),
            "save_folder={}".format(save_folder),
            "save_cycle={}".format(str(1)),
            "save_type={}".format("pyrolysis"),
        ],
        log_path="logs/pyrolysis_cycle1.log",
    )

    # ---------------- Remaining PIP cycles ----------------
    for i in range(pip_cycle_n - 1):
        cycle = i + 1
        next_cycle = cycle + 1
        # ----- Infiltration -----
        popen_or_fail(
            "Infiltration (cycle {})".format(cycle),
            [
                "mpiexec",
                "-n",
                str(corenum),
                puma_run_file,
                "-i",
                "infiltration.i",
                "mesh_input.i",
                "initial_condition_from_exodus_3.i",
                "flux_in={:.9f}".format(flux_in),
                "flux_out={:.9f}".format(flux_out),
                "rho_b={:.9f}".format(rho_b),
                "brooks_corey_threshold={:.9f}".format(brooks_corey_threshold),
                "capillary_pressure_power={:.9f}".format(capillary_pressure_power),
                "permeability_power={:.9f}".format(permeability_power),
                "mu_b={:.9f}".format(mu_b),
                "kk_b={:.9f}".format(kk_b),
                "hf={:.9f}".format(hf),
                "k_b={:.9f}".format(k_b),
                "cp_b={:.9f}".format(cp_b),
                "D_macro={:.9f}".format(D_macro),
                "gravity={:.9f}".format(gravity),
                "E={:.9f}".format(E),
                "g={:.9f}".format(g),
                "Tref={:.9f}".format(Tref),
                "htc={:.9f}".format(htc),
                "dTdt={:.9f}".format(dTdt_flow),
                "Tmax={:.9f}".format(Tmax_flow),
                "t_hold={:.9f}".format(t_hold_flow),
                "tcool={:.9f}".format(tcool_flow),
                "T0={:.9f}".format(T0_flow),
                "meshfile={}".format(meshfile),
                "save_folder={}".format(save_folder),
                "save_cycle={}".format(str(cycle)),
                "load_cycle={}".format(str(cycle)),
                "save_type={}".format("infiltration"),
                "load_type={}".format("pyrolysis"),
            ],
            log_path="logs/infiltration_cycle{}.log".format(cycle),
        )

        # ----- Curing -----
        popen_or_fail(
            "Curing (cycle {})".format(cycle),
            [
                "mpiexec",
                "-n",
                str(corenum),
                puma_run_file,
                "-i",
                "curing.i",
                "mesh_input.i",
                "initial_condition_from_exodus_1.i",
                "rho_s={:.9f}".format(rho_s),
                "rho_b={:.9f}".format(rho_b),
                "rho_g={:.9f}".format(rho_g(1, 1)),
                "rho_p={:.9f}".format(rho_p),
                "cp_s={:.9f}".format(cp_s),
                "cp_b={:.9f}".format(cp_b),
                "cp_p={:.9f}".format(cp_p),
                "cp_g={:.9f}".format(cp_p),
                "k_s={:.9f}".format(k_s),
                "k_b={:.9f}".format(k_b),
                "k_p={:.9f}".format(k_p),
                "k_g={:.9f}".format(k_p),
                "Ea={:.9f}".format(Ea_cur),
                "A={:.9f}".format(A_cur),
                "R={:.9f}".format(R),
                "hrp={:.9f}".format(hrp_cur),
                "Y={:.9f}".format(Y_cur),
                "order={:.9f}".format(order_cur),
                "E={:.9f}".format(E),
                "g={:.9f}".format(g),
                "Tref={:.9f}".format(Tref),
                "htc={:.9f}".format(htc),
                "dTdt={:.9f}".format(dTdt_cur),
                "Tmax={:.9f}".format(Tmax_cur),
                "t_hold={:.9f}".format(t_hold_cur),
                "tcool={:.9f}".format(tcool_cur),
                "T0={:.9f}".format(T0_cur),
                "pyro_mu={:.9f}".format(cp_to_wg_relation(1, 0.0)),
                "zeta={:.9f}".format(op_to_binder_relation(1, 0.95)),
                "meshfile={}".format(meshfile),
                "Mref={:.9f}".format(reference_mass),
                "save_folder={}".format(save_folder),
                "save_cycle={}".format(str(cycle)),
                "load_cycle={}".format(str(cycle)),
                "save_type={}".format("curing"),
                "load_type={}".format("infiltration"),
            ],
            log_path="logs/curing_cycle{}.log".format(cycle),
        )

        # ----- Next Pyrolysis -----
        popen_or_fail(
            "Pyrolysis (cycle {})".format(next_cycle),
            [
                "mpiexec",
                "-n",
                str(corenum),
                puma_run_file,
                "-i",
                "pyrolysis.i",
                "mesh_input.i",
                "initial_condition_from_exodus_2.i",
                "rho_s={:.9f}".format(rho_s),
                "rho_b={:.9f}".format(rho_b),
                "rho_g={:.9f}".format(rho_g(1, 1)),
                "rho_p={:.9f}".format(rho_p),
                "cp_s={:.9f}".format(cp_s),
                "cp_b={:.9f}".format(cp_b),
                "cp_p={:.9f}".format(cp_p),
                "cp_g={:.9f}".format(cp_p),
                "k_s={:.9f}".format(k_s),
                "k_b={:.9f}".format(k_b),
                "k_p={:.9f}".format(k_p),
                "k_g={:.9f}".format(k_p),
                "Ea={:.9f}".format(Ea),
                "A={:.9f}".format(A),
                "R={:.9f}".format(R),
                "hrp={:.9f}".format(hrp),
                "Y={:.9f}".format(Y),
                "order={:.9f}".format(order),
                "E={:.9f}".format(E),
                "g={:.9f}".format(g),
                "Tref={:.9f}".format(Tref),
                "htc={:.9f}".format(htc),
                "dTdt={:.9f}".format(dTdt),
                "Tmax={:.9f}".format(Tmax),
                "t_hold={:.9f}".format(t_hold),
                "tcool={:.9f}".format(tcool),
                "T0={:.9f}".format(T0),
                "pyro_mu={:.9f}".format(cp_to_wg_relation(1)),
                "zeta={:.9f}".format(op_to_binder_relation(1)),
                "meshfile={}".format(meshfile),
                "Mref={:.9f}".format(reference_mass),
                "save_folder={}".format(save_folder),
                "load_cycle={}".format(str(cycle)),
                "save_cycle={}".format(str(next_cycle)),
                "save_type={}".format("pyrolysis"),
                "load_type={}".format("curing"),
            ],
            log_path="logs/pyrolysis_cycle{}.log".format(next_cycle),
        )

# ---------------- LSI: Reactive Infiltration ----------------
popen_or_fail(
    "LSI Infiltration",
    [
        "mpiexec",
        "-n",
        str(corenum),
        puma_run_file,
        "-i",
        "infiltration_lsi.i",
        "initial_condition_from_exodus_4.i",
        "mesh_input.i",
        "dt={:.18f}".format(dt),
        "total_time={:.18f}".format(t_ramp_lsi + tinfiltrate),
        "flux_in={:.18f}".format(flux_in_lsi),
        "flux_out={:.18f}".format(flux_out_lsi),
        "t_ramp={:.18f}".format(t_ramp_lsi),
        "t_heat={:.18f}".format(theat_lsi),
        "dTdt={:.18f}".format(dTdt_lsi),
        "brooks_corey_threshold={:.18f}".format(brooks_corey_threshold),
        "capillary_pressure_power={:.18f}".format(capillary_pressure_power),
        "phi_L_residual={:.18f}".format(phi_L_residual),
        "permeability_power={:.18f}".format(permeability_power),
        "mu_Si={:.18f}".format(mu_Si),
        "perm_ref={:.18f}".format(perm_ref),
        "hf={:.18f}".format(1),
        "kappa_Si={:.18f}".format(kappa_Si),
        "kappa_SiC={:.18f}".format(kappa_SiC),
        "kappa_C={:.18f}".format(kappa_C),
        "D_macro={:.18f}".format(D_macro_lsi),
        "D_macro_high={:.18f}".format(D_macro_high),
        "D_macro_low={:.18f}".format(D_macro_low),
        "transition_saturation_front={:.18f}".format(transition_saturation_front),
        "transition_saturation_back={:.18f}".format(transition_saturation_back),
        "transition_saturation_back_start={:.18f}".format(transition_saturation_back_start),
        "reactivity_upbound={:.18f}".format(reactivity_upbound),
        "reactivity_lowbound={:.18f}".format(reactivity_lowbound),
        "htc={:.18f}".format(htc),
        # "phif_min={:.18f}".format(phif_min),
        "K_nucl_growth={:.18f}".format(K_nucl_growth),
        "h_c={:.18f}".format(h_c),
        "E={:.18f}".format(E),
        "nu={:.18f}".format(nu),
        "therm_expansion={:.18f}".format(g),
        "T0={:.18f}".format(T0),
        "gravity={:.18f}".format(gravity),
        "D_LP={:.18f}".format(D_LP),
        "l_c={:.18f}".format(l_c),
        "M_Si={:.18f}".format(M_Si),
        "M_SiC={:.18f}".format(M_SiC),
        "M_C={:.18f}".format(M_C),
        "rho_Si={:.18f}".format(rho_Si),
        "rho_SiC={:.18f}".format(rho_SiC),
        "rho_C={:.18f}".format(rho_C),
        "cp_Si={:.18f}".format(cp_Si),
        "cp_SiC={:.18f}".format(cp_SiC),
        "cp_C={:.18f}".format(cp_C),
        "k_C={:.18f}".format(k_C),
        "k_SiC={:.18f}".format(k_SiC),
        "meshfile={}".format(meshfile),
        "save_folder={}".format(save_folder),
        "load_cycle={}".format(str(pip_cycle_n)),
        "save_cycle={}".format(str(pip_cycle_n)),
        "save_type={}".format("lsi_infiltration"),
        "load_type={}".format("pyrolysis"),
    ],
    log_path="logs/lsi_infiltration_cycle{}.log".format(pip_cycle_n),
)

# ---------------- LSI: Solidification ----------------
popen_or_fail(
    "LSI Solidification",
    [
        "mpiexec",
        "-n",
        str(corenum),
        puma_run_file,
        "-i",
        "solidification.i",
        "mesh_input.i",
        "initial_condition_from_exodus_5.i",
        "dt={:.18f}".format(dt),
        "total_time={:.18f}".format(tcool_lsi + twait_lsi),
        "t_ramp={:.18f}".format(tcool_lsi),
        "dTdt={:.18f}".format(dTdt_cool_lsi),
        "D_macro={:.18f}".format(D_macro_lsi),
        "brooks_corey_threshold={:.18f}".format(brooks_corey_threshold),
        "capillary_pressure_power={:.18f}".format(capillary_pressure_power),
        "permeability_power={:.18f}".format(permeability_power),
        "mu_Si={:.18f}".format(mu_Si),
        "kappa_Si={:.18f}".format(kappa_Si),
        "kappa_Si_s={:.18f}".format(kappa_Si_s),
        "kappa_SiC={:.18f}".format(kappa_SiC),
        "kappa_C={:.18f}".format(kappa_C),
        "htc={:.18f}".format(htc),
        "E={:.18f}".format(E),
        "E_Si={:.18f}".format(E_Si),
        "E_C={:.18f}".format(E_C),
        "nu_Si={:.18f}".format(nu_Si),
        "nu_C={:.18f}".format(nu_C),
        "therm_expansion={:.18f}".format(g),
        "T0={:.18f}".format(Tmax_lsi),
        "Tref={:.18f}".format(Tref),
        "Ts={:.18f}".format(Ts),
        "Tf={:.18f}".format(Tf),
        "H_latent={:.18f}".format(H_latent),
        "M_Si={:.18f}".format(M_Si),
        "phif_min={:.18f}".format(phif_min),
        "solidification_rate={:.18f}".format(solidification_rate),
        "gravity={:.18f}".format(gravity),
        "rho_Si={:.18f}".format(rho_Si),
        "rho_Si_s={:.18f}".format(rho_Si_s),
        "rho_SiC={:.18f}".format(rho_SiC),
        "rho_C={:.18f}".format(rho_C),
        "cp_Si={:.18f}".format(cp_Si),
        "cp_Si_s={:.18f}".format(cp_Si_s),
        "cp_SiC={:.18f}".format(cp_SiC),
        "cp_C={:.18f}".format(cp_C),
        "kk_Si={:.18f}".format(perm_ref),
        "flux_out={:.18f}".format(flux_out_lsi),
        "meshfile={}".format(meshfile),
        "save_folder={}".format(save_folder),
        "load_cycle={}".format(str(pip_cycle_n)),
        "save_cycle={}".format(str(pip_cycle_n)),
        "save_type={}".format("lsi_solidification"),
        "load_type={}".format("lsi_infiltration"),
    ],
    log_path="logs/lsi_solidification_cycle{}.log".format(pip_cycle_n),
)

# ---------------------------------------------------------------------


end_time = time.perf_counter()
print(f"\nTotal time: {end_time - start_time:.2f} seconds")