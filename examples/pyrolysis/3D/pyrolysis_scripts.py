import numpy as np
import subprocess
from generate_random_field import generate_initial_conditions

########################################## Input ##############################################
##                                                                                           ##
## Currently assumed the resin fully filled the open pores gas during polymer infiltration   ##
## all of the gas managed to escaped, pores production based on the amount of initial binder ##
## trapped gas production based on the porosity at the begining of the pyrolysis             ##
##                                                                                           ##
###############################################################################################

save_folder = "main"
corenum = 4  # number of cores used for simulation
puma_run_file = "./../../../puma-opt"


# rate of close pore relative to volume of produced gas
def cp_to_wg_relation(volume_binder):
    return 0.001


# portion of open pores as a function of binder consumed
def op_to_binder_relation(v_nonreactants):
    return 0.8


# gas density as a function of temperature and pressure
def rho_g(T, P):
    return 13  # kg m-3


########################### parts and geometry information ####################################
# geometry
mesh_file = "gold/SiC_core.msh"
reference_mass = 1.0  # reference mass
num_el = 50
L = 0.04  # m

# initial conditions, assumed a binary system (binder and particle) at the begining
mode = "mass_fraction"
min_binder = 0.3
max_binder = 0.8
lc = 0.0015

############################# material and reaction properties ################################
##           Current properties are for phenolic resin inside SiC praticles                  ##

# denisty kgm-3
rho_s = 2260
rho_b = 1250  # 1.2 and 1.4
rho_p = 3210

# heat capacity Jkg-1K-1
cp_s = 1592
cp_b = 1200
cp_p = 750
cp_g = 1e-4

# thermal conductivity W/m-1K-1
k_s = 150
k_b = 279
k_p = 380  # 120 and 490
k_g = 1e-4

# reaction type
Ea = 209015.7262  # J mol-1
A = 1.2727e14  # s-1
R = 8.31446261815324  # JK-1mol-1
hrp = 1.58e6  # e5 J kg-1
Y = 0.5534  # char yield [.]

order = 7.3528

#### stress-strain ####
E = 400e9

# thermal expansion coefficients (degree-1)
Tref = 300  # K
g = 4e-6

# convection coefficients - Wm-2K
htc = 200

# heating profiles for pyrolysis
T0 = 300  # K - starting and cooling temperatures
Tmax = 1400  # K
dTdt = 20  # Kmin-1 heating rate
t_hold = 0.5  # hrs
tcool = 0.5  # hrs

# Simulation parameters
dt = 5

###############################################################################################
##                                                                                           ##
##                                       MAIN                                                ##
##                                                                                           ##
###############################################################################################

# generate the initial conditions
intial_condition = generate_initial_conditions(
    mesh_file,
    lc,
    mode=mode,
    Mref=reference_mass,
    rho_b=rho_b,
    rho_p=rho_p,
    min_binder=min_binder,
    max_binder=max_binder,
    beta_a_binder=2.0,
    beta_b_binder=5.0,
    seed_binder=4562,
    mesh_scale=0.01,
    plot_cond=True,
)

num_file_data = len(intial_condition["z"])

print("\n")

# run the simulation file PR_pyrolysis.i and initical_condition_from_csv.i
subprocess.run(
    [
        "mpiexec",
        "-n",
        str(corenum),
        puma_run_file,
        "-i",
        "pyrolysis.i",
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
        "dTdt={:.9f}".format(dTdt),
        "Tmax={:.9f}".format(Tmax),
        "t_hold={:.9f}".format(t_hold),
        "tcool={:.9f}".format(tcool),
        "T0={:.9f}".format(T0),
        "dTdt={:.9f}".format(dTdt),
        "pyro_mu={:.9f}".format(cp_to_wg_relation(1)),
        "zeta={:.9f}".format(op_to_binder_relation(1)),
        "num_el={:.9f}".format(num_el),
        "L={:.9f}".format(L),
        "Mref={:.9f}".format(reference_mass),
        "num_file_data={}".format(num_file_data),
        # "--parse-neml2-only",
    ],
    stdin=subprocess.DEVNULL,
    stdout=open("pyrolysis.log", "w"),
    stderr=subprocess.STDOUT,
    text=True,
)
