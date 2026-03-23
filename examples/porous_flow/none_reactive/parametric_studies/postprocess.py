from matplotlib import pyplot as plt
import matplotlib.font_manager as fm
from matplotlib.ticker import AutoMinorLocator
from matplotlib import colors, cm
import pandas as pd
from pathlib import Path

plot_special = True  # whether to plot the special case of porosity vs x with experimental data

out_dir = Path("typical")
plt_dir = Path("plots")
plt_dir.mkdir(exist_ok=True)
nstep = len(list(out_dir.glob("out_value_*.csv")))
summary = pd.read_csv(out_dir / "out.csv")
times = summary["time"]

step = 5

fe = fm.FontEntry(
    fname="/home/tranh/Fonts/arial.ttf", name="Arial"
)
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


tlist = [7, 15, 25, 32] #260 at 30
ls_list = [":", "--", "-.", "-"]
lw_list = [1,1,1,1]

if plot_special:

    fsize = 11
    figsize = (3.2, 2.5)

    # plot porosity vs x with experimental data
    fig, ax = plt.subplots(figsize=figsize)

    qoi = "phif"
    
    for j in range(len(tlist)):
        i = tlist[j]
    #for i in range(1, int(nstep-2), step*20):
        df = pd.read_csv(out_dir / "out_value_{:04d}.csv".format(i))
        ax.plot(df["x"], df[qoi],ls=ls_list[j],lw=lw_list[j] ,color='k') #sm.to_rgba(times.iloc[i]))
    # set a horizontal colorbar

    #fig.colorbar(sm, ax=ax, label="Time [s]", orientation='horizontal')

    ax.set_xlim(0, 1)
    ax.minorticks_on()
    ax.xaxis.set_minor_locator(AutoMinorLocator(2))
    ax.yaxis.set_minor_locator(AutoMinorLocator(2))
    ax.set_ylim(0, 0.5)

    ax.set_xlabel("bar height, z (cm)")
    ax.set_ylabel("{}".format(qoi))

    fig.tight_layout()
    fig.savefig(plt_dir / "{}.png".format(qoi+" special"), dpi=300)

    plt.close(fig)


