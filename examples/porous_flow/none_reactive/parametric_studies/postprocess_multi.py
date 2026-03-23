from matplotlib import pyplot as plt
import matplotlib.font_manager as fm
from matplotlib.ticker import AutoMinorLocator
from matplotlib import colors, cm
import pandas as pd
from pathlib import Path

plt_dir = Path("plots")
outname = "different_perm_Power"
plt_dir.mkdir(exist_ok=True)

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

linestyle_tuple = [
     ('loosely dotted',        (0, (1, 10))),
     ('dotted',                (0, (1, 5))),
     ('densely dotted',        (0, (1, 1))),

     ('long dash with offset', (5, (10, 3))),
     ('loosely dashed',        (0, (5, 10))),
     ('dashed',                (0, (5, 5))),
     ('densely dashed',        (0, (5, 1))),

     ('loosely dashdotted',    (0, (3, 10, 1, 10))),
     ('dashdotted',            (0, (3, 5, 1, 5))),
     ('densely dashdotted',    (0, (3, 1, 1, 1))),

     ('dashdotdotted',         (0, (3, 5, 1, 5, 1, 5))),
     ('loosely dashdotdotted', (0, (3, 10, 1, 10, 1, 10))),
     ('densely dashdotdotted', (0, (3, 1, 1, 1, 1, 1)))]

# folder_list = ["p1e5_pow20_permpow8", 
#                "p1e6_pow20_permpow8",
#                "p1e5_pow1_permpow8",
#                "p1e3_pow20_permpow8",
#                "p1e1_pow20_permpow8",
#                "p1e5_pow40_permpow8"]

folder_list = ["p1e5_pow20_permpow8",
               "p1e5_pow20_permpow5",
               "p1e5_pow20_permpow8_phiref05",
               # "p1e5_pow20_permpow8_phiref099",
               "p1e5_pow20_permpow20_phiref09"]

ls_list = ["-", "--", "-.", ":",(0, (5, 1)),(5, (10, 3))]
lw_list = [1,0.75,0.75,0.75,0.75,0.75]

figsize = (3.2, 2.5)

# plot porosity vs x with experimental data
fig, ax = plt.subplots(figsize=figsize)

qoi = "phif"

for j in range(len(folder_list)):
    out_dir = Path(folder_list[j])
    # identify the largest id in out_dir that start with out_value_*
    nid = -1
    for file in out_dir.glob("out_value_*.csv"):
        id_str = file.stem.split("_")[-1]
        id_int = int(id_str)
        if id_int > nid:
            nid = id_int
    df = pd.read_csv(out_dir / "out_value_{:04d}.csv".format(nid))
    ax.plot(df["x"], df[qoi],linestyle=ls_list[j],lw=lw_list[j] ,color='k')

ax.set_xlim(0, 1)
ax.minorticks_on()
ax.xaxis.set_minor_locator(AutoMinorLocator(2))
ax.yaxis.set_minor_locator(AutoMinorLocator(2))
ax.set_ylim(0, 0.5)

ax.set_xlabel("x / L")
ax.set_ylabel("fluid volume fraction, phif")

fig.tight_layout()
fig.savefig(plt_dir / "{}.png".format(outname), dpi=300)

plt.close(fig)


