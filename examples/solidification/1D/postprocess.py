from matplotlib import pyplot as plt
from matplotlib import colors, cm
import pandas as pd
from pathlib import Path

out_dir = Path("output")
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
    "T",
    "phif_s",
    "nonliquid",
    "porosity",
    "phifl_rate",
    "heat_generate",
    "permeability",
    "P"
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