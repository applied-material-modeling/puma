#!/usr/bin/env python
"""End-to-end random-field generation (no PUMA simulation).

Runs the full workflow:

    CT scan -> prepare_ct_scan.py -> data/scans.npy
            -> cobra config.yml     (KL pipeline, all 5 stages)
            -> cobra_to_puma_csv.py -> initial_condition.csv   (feeds PUMA)

The resulting initial_condition.csv is a 4-column (x, y, z, phi0_poro) file ready
to drop into a PUMA example that reads it via PropertyReadFile (see README.md).

Run with the `moose-src` environment active (or any env with `cobra` installed):
    python generate.py [--domain L] [--no-prepare] [--no-plot]
"""
import argparse
import subprocess
import sys
from pathlib import Path

HERE = Path(__file__).resolve().parent
PY = sys.executable


def sh(*cmd, **kw):
    print(f"\n$ {' '.join(str(c) for c in cmd)}")
    subprocess.run([str(c) for c in cmd], cwd=str(HERE), check=True, **kw)


def plot_sample(sample_e: Path, png: Path) -> None:
    import numpy as np
    import matplotlib
    matplotlib.use("Agg")
    import matplotlib.pyplot as plt
    from cobra.utils.io import Sample

    s = Sample.from_file(str(sample_e))
    nx, ny = s.shape[0], s.shape[1]
    field = np.asarray(s.values).reshape(nx, ny)
    fig, ax = plt.subplots(figsize=(4.2, 3.6))
    im = ax.imshow(field.T, origin="lower", cmap="viridis", vmin=0, vmax=1)
    fig.colorbar(im, ax=ax, label="porosity phi0_poro")
    ax.set_title("CoBRA sampled porosity field")
    fig.tight_layout()
    fig.savefig(png, dpi=150)
    print(f"wrote {png}")


def main() -> None:
    p = argparse.ArgumentParser(description=__doc__)
    p.add_argument("--domain", type=float, default=None,
                   help="rescale CSV x,y to a square [0, DOMAIN] matching the FE mesh extent")
    p.add_argument("--no-prepare", action="store_true",
                   help="skip CT extraction (reuse the committed data/scans.npy)")
    p.add_argument("--no-plot", action="store_true", help="skip the field preview PNG")
    args = p.parse_args()

    if not args.no_prepare:
        sh(PY, "prepare_ct_scan.py")
    else:
        print("skipping prepare_ct_scan.py -- using committed data/scans.npy")

    sh(PY, "-m", "cobra.runner", "config.yml")

    conv = [PY, "cobra_to_puma_csv.py"]
    if args.domain is not None:
        conv += ["--domain", args.domain]
    sh(*conv)

    if not args.no_plot:
        plot_sample(HERE / "output" / "beta" / "sample_0.e", HERE / "porosity_field.png")

    print("\nDone. initial_condition.csv is ready to feed a PUMA input (see README.md).")


if __name__ == "__main__":
    main()
