from matplotlib import pyplot as plt
import pandas as pd
import numpy as np
import matplotlib.font_manager as fm
import os

## INPUT INFORMATION ------------------------------------------------------

postprocess_folder = "main"
base_file = "out_cycle"
plotfolder = "main/postprocess_results"

E = 400e9


## Set up plot ------------------------------------------------------------
fe = fm.FontEntry(
    fname="/usr/share/fonts/truetype/wsttcorefonts/Arial.ttf", name="Arial"
)
fm.fontManager.ttflist.insert(0, fe)

font = {"family": "Arial"}
fsize = 14
figsize = (12, 3.75)
lw = 1

if not os.path.isdir(plotfolder):
    os.mkdir(plotfolder)

plt.rc("font", **font)
plt.rc("font", **font, size=fsize)  # controls default text sizes
plt.rc("axes", titlesize=fsize)  # fontsize of the axes title
plt.rc("axes", labelsize=fsize)  # fontsize clearof the x and y labels
plt.rc("xtick", labelsize=fsize)  # fontsize of the tick labels
plt.rc("ytick", labelsize=fsize)  # fontsize of the tick labels
plt.rc("legend", fontsize=fsize)  # legend fontsize
plt.rc("figure", titlesize=fsize)  # fontsize of the figure title

fig, ax = plt.subplots(1, 3)
fig.set_size_inches(figsize)


## MAIN --------------------------------------------------------------------
def get_statistic(data, keyid):
    return [
        np.min(data[keyid]),
        np.mean(data[keyid]),
        np.max(data[keyid]),
        np.sum(data[keyid]),
    ]


def trim_and_plot(axis, data, removeid, ls="--", mk="x", col="k", maxmin=False):
    data = data[:removeid, :]

    if maxmin:
        axis.fill_between(
            np.linspace(1, i, i),
            data[:, 0],
            data[:, 2],
            alpha=0.2,
            color=col,
            edgecolor="none",
        )
        axis.plot(
            np.linspace(1, i, i),
            data[:, 1],
            linestyle=ls,
            marker=mk,
            color=col,
            markerfacecolor="none",
        )
    else:
        axis.plot(
            np.linspace(1, i, i),
            data[:, 1],
            linestyle=ls,
            marker=mk,
            color=col,
            markerfacecolor="none",
        )
    return data


wb = np.zeros((100000, 4))
wp = np.zeros((100000, 4))
ws = np.zeros((100000, 4))

phip = np.zeros((100000, 4))
phis = np.zeros((100000, 4))
phiop = np.zeros((100000, 4))
phigcp = np.zeros((100000, 4))

vonmises = np.zeros((100000, 4))

for i in range(100000):
    fname = (
        postprocess_folder
        + "/"
        + base_file
        + str(i + 1)
        + "_composition_info_FINAL.csv"
    )
    if not os.path.islink(fname):
        print("Recognize " + str(i) + " cycles")
        break

    postdata = pd.read_csv(os.readlink(fname))

    wb[i, :] = get_statistic(postdata, "wb")
    wp[i, :] = get_statistic(postdata, "wp")
    ws[i, :] = get_statistic(postdata, "ws")

    phip[i, :] = get_statistic(postdata, "phip")
    phis[i, :] = get_statistic(postdata, "phis")
    phiop[i, :] = get_statistic(postdata, "phiop")
    phigcp[i, :] = get_statistic(postdata, "phigcp")

    vonmises[i, :] = get_statistic(postdata, "max_principal_pk1_stress")

# mass
wb = trim_and_plot(ax[0], wb, i, col="k", mk="x")
wp = trim_and_plot(ax[0], wp, i, col="b", mk="d")
ws = trim_and_plot(ax[0], ws, i, col="r", mk="o")
ax[0].set_ylabel("weight fraction")
ax[0].set_xlabel("PIP cycles #")
ax[0].set_xlim((1, i + 1))

# volume fraction
phip = phip[:i, :]
phis = phis[:i, :]
phiop = phiop[:i, :]
phigcp = phigcp[:i, :]

ax[1].stackplot(
    np.linspace(1, i, i),
    phip[:, 2],
    phis[:, 2],
    phigcp[:, 2],
    phiop[:, 2],
    colors=["b", "r", "silver", "whitesmoke"],
)
ax[1].set_ylabel("average volume fraction")
ax[1].set_xlabel("PIP cycles #")
ax[1].set_xlim((1, i + 1))

# stress
vonmises = trim_and_plot(ax[2], vonmises / E, i, col="k", mk="x", maxmin=True)
ax[2].set_ylabel("von_mises_stress/E")
ax[2].set_xlabel("PIP cycles #")
ax[2].set_xlim((1, i + 1))

fig.tight_layout()

plt.savefig(plotfolder + "/out.png", dpi=300)
plt.show()
