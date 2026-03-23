import gstools as gs
import matplotlib.pyplot as plt
from matplotlib import colors, cm
import matplotlib.font_manager as fm
import numpy as np
import meshio
import pandas as pd
import os
import scipy as sc
from scipy.stats import (
    norm,
    beta,
)  # check scipy for whatever distributions is needed for pdf/cdf


# currently only for system with pure binder and particle
def generate_initial_conditions(
    meshfile,
    len_scale,
    mode="mass_fraction",
    Mref=1,
    rho_b=1,
    rho_p=1,
    min_binder=1e-4,
    max_binder=1,
    beta_a_binder=2.0,
    beta_b_binder=10.0,
    seed_binder=4562,
    plot_cond=True,
):

    assert min_binder < max_binder
    assert min_binder >= 0 and min_binder <= 1
    assert max_binder >= 0 and max_binder <= 1

    beta_shift_binder = min_binder
    beta_scale_binder = max_binder - min_binder

    # import the desirable mesh
    mesh = meshio.read(meshfile)

    # generated and plot the random fields on mesh
    binder_info = gs.Exponential(dim=2, var=1, len_scale=len_scale)
    srf_binder = gs.SRF(binder_info, mean=1)

    srf_binder.mesh(mesh, points="points", name="binder_info", seed=seed_binder)

    update_binder_info = normal_to_beta(
        mesh,
        "binder_info",
        norm_mean=1,
        norm_var=1,
        b=beta_b_binder,
        a=beta_a_binder,
        beta_shift=beta_shift_binder,
        beta_scale=beta_scale_binder,
    )

    if mode == "mass_fraction":
        update_binder_wf = update_binder_info
        update_binder_phi = 1 / (
            1 + (((1 - update_binder_wf) / update_binder_wf) * (rho_b / rho_p))
        )
    elif mode == "volume_fraction":
        update_binder_phi = update_binder_info
        val = (update_binder_phi * rho_b) / ((1 - update_binder_phi) * rho_p)
        update_binder_wf = val / (1 + val)
    else:
        NameError(
            "mode type has not yet been implemented choose between: 'volume_fraction' or 'mass_fraction'"
        )

    update_particle_wf = 1 - update_binder_wf

    X = mesh.points[:, 0]
    Y = mesh.points[:, 1]
    Z = mesh.points[:, 2]
    data_binder = update_binder_wf
    data_particle = update_particle_wf

    data_Vref = Mref * (data_binder / rho_b + data_particle / rho_p)

    df = pd.DataFrame(
        {
            "x": X,
            "y": Y,
            "z": Z,
            "binder": data_binder,
            "particle": data_particle,
            "reference_volume": 1 / data_Vref,
            "solid": np.zeros_like(data_binder),
            "mwbo_for_gas_model": -data_binder,
        }
    )

    df.to_csv("initial_condition.csv", index=False, header=False)

    if plot_cond:
        plot_check(X, Y, data_binder, data_particle, "mass_fraction")
        plot_check(X, Y, update_binder_phi, 1 - update_binder_phi, "volume_fraction")

    return df


def normal_to_beta(
    mesh_data, typename, norm_mean=1, norm_var=1, a=1, b=1, beta_shift=0, beta_scale=1
):
    data = mesh_data.point_data[typename]

    # convert data to satisfy the new distribution
    cdf_data = norm.cdf(data, loc=norm_mean, scale=norm_var ** (1 / 2))

    update_data = beta.ppf(cdf_data, a, b, loc=beta_shift, scale=beta_scale)

    return update_data


def plot_check(X, Y, data_binder, data_particle, fname):
    fsize = 12
    ## Set up plot ------------------------------------------------------------
    fe = fm.FontEntry(
        fname="/usr/share/fonts/truetype/msttcorefonts/Arial.ttf", name="Arial"
    )
    fm.fontManager.ttflist.insert(0, fe)

    font = {"family": "Arial"}
    fsize = 15
    figsize = (4.83 * 2, 2.1 * 2)
    lw = 1
    # plt.rc("font", **font)
    plt.rc("font", size=fsize)  # controls default text sizes
    plt.rc("axes", titlesize=fsize)  # fontsize of the axes title
    plt.rc("axes", labelsize=fsize)  # fontsize of the x and y labels
    plt.rc("xtick", labelsize=fsize)  # fontsize of the tick labels
    plt.rc("ytick", labelsize=fsize)  # fontsize of the tick labels
    plt.rc("legend", fontsize=fsize)  # legend fontsize
    plt.rc("figure", titlesize=fsize)  # fontsize of the figure title

    fig, axs = plt.subplots(1, 2, figsize=figsize)

    h1 = axs[0].tricontourf(X, Y, data_binder)
    h2 = axs[1].tricontourf(X, Y, data_particle)

    fig.colorbar(h1)
    fig.colorbar(h2)

    fig.tight_layout()
    # plt.xlim([0, 10])
    # plt.ylim([0, 10])

    if not os.path.exists("check_init"):
        os.makedirs("check_init")

    plt.savefig("check_init/" + fname + ".png")
    pass
