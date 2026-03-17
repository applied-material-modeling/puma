import math

from matplotlib import pyplot as plt
from matplotlib import colors, cm
import matplotlib.font_manager as fm
from matplotlib.ticker import AutoMinorLocator
import pandas as pd
from pathlib import Path

plot_special = (
    True  # whether to plot the special case of porosity vs x with experimental data
)

rho_Si = 2.57

out_dir = Path("example")
plt_dir = Path("plots")
plt_dir.mkdir(exist_ok=True)
nstep = len(list(out_dir.glob("out_value_*.csv")))
summary = pd.read_csv(out_dir / "out.csv")
times = summary["time"]

step = 1

fe = fm.FontEntry(fname="/home/tranh/Fonts/arial.ttf", name="Arial")
fm.fontManager.ttflist.insert(0, fe)

font = {"family": "Arial"}
fsize = 11
lw = 1
figsize = (5.22, 3.4)

plt.rc("font", **font)
plt.rc("font", **font, size=fsize)  # controls default text sizes
plt.rc("axes", titlesize=fsize)  # fontsize of the axes title
plt.rc("axes", labelsize=fsize)  # fontsize clearof the x and y labels
plt.rc("xtick", labelsize=fsize)  # fontsize of the tick labels
plt.rc("ytick", labelsize=fsize)  # fontsize of the tick labels
plt.rc("legend", fontsize=fsize)  # legend fontsize
plt.rc("figure", titlesize=fsize)  # fontsize of the figure title

# colormap
norm = colors.Normalize(vmin=times.iloc[0], vmax=times.iloc[-1])
sm = cm.ScalarMappable(norm=norm, cmap="coolwarm")

qois = [
    "phif",
    "phi_C",
    "phi_SiC",
    "porosity",
    "permeability",
    "phi_nonliquid",
    "M2",
    "Seff",
]

for qoi in qois:
    fig, ax = plt.subplots(figsize=figsize)
    for i in range(1, nstep, step):
        df = pd.read_csv(out_dir / "out_value_{:04d}.csv".format(i))
        ax.plot(df["x"], df[qoi], color=sm.to_rgba(times.iloc[i]))
    # set a horizontal colorbar

    fig.colorbar(sm, ax=ax, label="Time [s]")

    # ax.set_xlim(0, 0.15)

    ax.set_ylabel("{}".format(qoi))
    ax.set_xlabel("x")
    fig.tight_layout()
    fig.savefig(plt_dir / "{}.png".format(qoi), dpi=300)
    plt.close(fig)

# plot M2 vs Seff
fig, ax = plt.subplots(figsize=figsize)
for i in range(1, nstep, step):
    df = pd.read_csv(out_dir / "out_value_{:04d}.csv".format(i))
    ax.plot(df["Seff"], df["M2"] / rho_Si, color=sm.to_rgba(times.iloc[i]))
# set a horizontal colorbar
fig.colorbar(sm, ax=ax, label="Time [s]")
ax.set_xlabel("Seff")
ax.set_ylabel("Deff")
fig.savefig(plt_dir / "Deff_vs_Seff.png", dpi=300)
plt.close(fig)

# special case
n_tlist = 3
ls_list = [":", "--", "-.", "-"]
lw_list = [1, 1, 1, 1.5]

tlist = [math.floor(k * (nstep - 1) / n_tlist) for k in range(n_tlist)]
tlist[0] = tlist[0] + 1
if (nstep - 1) not in tlist:
    tlist.append(nstep - 1)
print(f"Time steps to plot for porosity are: {tlist}")

if plot_special:

    fsize = 14
    figsize = (3.8, 3.2)

    # plot porosity vs x with experimental data
    fig, ax = plt.subplots(figsize=figsize)

    # use pd to load porosity_result.csv file
    porosity_result = pd.read_csv("porosity_result.csv")
    # plot the porosity_result data
    ax.plot(
        porosity_result["height"] / 10,
        porosity_result["ratio_choice"] + 0.02,
        "x",
        color="black",
        label="Experimental data",
        markersize=3,
    )

    qoi = "porosity"

    for j in range(len(tlist)):
        i = tlist[j]
        # for i in range(1, int(nstep-2), step*20):
        df = pd.read_csv(out_dir / "out_value_{:04d}.csv".format(i))
        ax.plot(
            df["x"], df[qoi], ls=ls_list[j], lw=lw_list[j], color="blue"
        )  # sm.to_rgba(times.iloc[i]))
    # set a horizontal colorbar

    # fig.colorbar(sm, ax=ax, label="Time [s]", orientation='horizontal')

    ax.set_xlim(0, 6)
    ax.minorticks_on()
    ax.xaxis.set_minor_locator(AutoMinorLocator(2))
    ax.yaxis.set_minor_locator(AutoMinorLocator(2))
    # ax.set_ylim(0, 0.6)

    ax.set_xlabel("bar height, z (cm)")
    ax.set_ylabel("{}".format(qoi))

    fig.tight_layout()
    fig.savefig(plt_dir / "{}.png".format(qoi + " special"), dpi=300)

    plt.close(fig)
