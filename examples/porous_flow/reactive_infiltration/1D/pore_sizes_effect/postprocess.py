from matplotlib import pyplot as plt
from matplotlib import colors, cm
import pandas as pd
from pathlib import Path

plot_special = (
    False  # whether to plot the special case of porosity vs x with experimental data
)

out_dir = Path("example")
plt_dir = Path("plots")
plt_dir.mkdir(exist_ok=True)
nstep = len(list(out_dir.glob("out_value_*.csv")))
summary = pd.read_csv(out_dir / "out.csv")
times = summary["time"]

step = 1

font = {"family": "arial"}
fsize = 13
figsize = (5.22, 3.4)
lw = 1

plt.rc("font", size=fsize)  # controls default text sizes
plt.rc("axes", titlesize=fsize)  # fontsize of the axes title
plt.rc("axes", labelsize=fsize)  # fontsize of the x and y labels
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


# special case
tlist = [100, 500, 650, 760]
ls_list = [":", "--", "-.", "-"]
lw_list = [1, 1, 1, 1.5]

if plot_special:

    fsize = 14
    figsize = (3.8, 3.2)

    # plot porosity vs x with experimental data
    fig, ax = plt.subplots(figsize=figsize)

    # use pd to load porosity_result.csv file
    porosity_result = pd.read_csv("porosity_result.csv")
    # plot the porosity_result data
    # ax.plot(porosity_result["height"]/10, porosity_result["ratio_choice"]+0.02,  "x",
    #        color="black", label="Experimental data", markersize=3)

    qoi = "phi_SiC"

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
    # ax.set_ylim(0, 0.6)

    ax.set_xlabel("bar height, z (cm)")
    ax.set_ylabel("{}".format(qoi))

    fig.tight_layout()
    fig.savefig(plt_dir / "{}.png".format(qoi + " special"), dpi=300)

    # plot M2 vs Seff
    fig, ax = plt.subplots(figsize=figsize)
    for i in range(1, nstep, step):
        df = pd.read_csv(out_dir / "out_value_{:04d}.csv".format(i))
        ax.plot(df["Seff"], df["M2"], color=sm.to_rgba(times.iloc[i]))
    # set a horizontal colorbar
    fig.colorbar(sm, ax=ax, label="Time [s]")
    ax.set_ylabel("M2")
    ax.set_xlabel("Seff")
    fig.tight_layout()
    fig.savefig(plt_dir / "M2_vs_Seff.png", dpi=300)

    plt.close(fig)
