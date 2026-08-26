#!/usr/bin/env python
"""Prepare a CoBRA scan input (``data/scans.npy``) from a micro-CT TIFF stack.

CoBRA treats a ``(rows, cols, N)`` array as ``N`` samples of a single 2D field
(the last axis is the sample/image axis). We therefore take a *band of N
consecutive slices near the top surface of the bar* -- a region where the
porosity is statistically stationary, so the slices act as independent
realizations of the same 2D random field and the empirical covariance is
well defined ("good covariance / top slice").

For each slice we:
  1. crop an axis-aligned window fully inside the (rotated) bar cross-section,
  2. binarize into a pore map (grayscale < THRESHOLD  ->  pore = 1.0),
  3. block-mean downsample ("cut") by BLOCK to a continuous local porosity
     field in [0, 1] -- continuous values are what CoBRA's beta transform
     needs, and the smaller array is committable.

The result is a porosity field, i.e. exactly the quantity PUMA consumes as
``phi0_poro``. Output resolution = native voxel size * BLOCK.

Only PIL + numpy are required (both in the ``moose-src`` env); no imageio/skimage.
"""
import os
from pathlib import Path

import numpy as np
from PIL import Image

# --------------------------------------------------------------------------
# Parameters -- tune the slice band / window / threshold here.
# --------------------------------------------------------------------------
# Micro-CT TIFF stack (SiC bar, 12 um/voxel, 16-bit grayscale). Not committed;
# override with $CT_DIR. Low index = bottom of the bar, high index = top.
CT_DIR = Path(os.environ.get("CT_DIR", "/home/tranh/Work/work/00_Infiltration_RVE/CT_scan/SiC_12um"))
BASENAME = "image_"
FILEFMT = ".tif"

# Top-surface band: stationary porosity plateau (~0.75) => good covariance.
SLICE_START = 4100
SLICE_STOP = 4164          # exclusive
SLICE_STEP = 1

# Axis-aligned window fully inside the bar cross-section (image is [row=y, col=x]).
CENTER_XY = (949, 906)     # bar centroid (from the ROI corners of the CT analysis)
HALF = 250                 # half window size in px -> (2*HALF) square

THRESHOLD = 16218          # pore = grayscale intensity < THRESHOLD
BLOCK = 4                  # block-mean downsample factor ("cut")

NATIVE_RESOLUTION = 12e-6  # m / voxel
OUT = Path(__file__).resolve().parent / "data" / "scans.npy"

# Physical resolution of the produced field, for CoBRA's config.yml.
PHYSICAL_RESOLUTION = NATIVE_RESOLUTION * BLOCK


def block_mean(a: np.ndarray, k: int) -> np.ndarray:
    """Mean-pool a 2D array by an integer factor k (drops the ragged edge)."""
    r, c = (a.shape[0] // k) * k, (a.shape[1] // k) * k
    return a[:r, :c].reshape(r // k, k, c // k, k).mean(axis=(1, 3))


def main() -> None:
    cx, cy = CENTER_XY
    x0, x1 = cx - HALF, cx + HALF
    y0, y1 = cy - HALF, cy + HALF
    slices = range(SLICE_START, SLICE_STOP, SLICE_STEP)

    fields = []
    for s in slices:
        f = CT_DIR / f"{BASENAME}{s:04d}{FILEFMT}"
        im = np.asarray(Image.open(f))            # (row=y, col=x)
        window = im[y0:y1, x0:x1]
        pore = (window < THRESHOLD).astype(np.float32)   # 1 = pore
        porosity = block_mean(pore, BLOCK)               # continuous [0,1]
        fields.append(porosity)

    data = np.stack(fields, axis=-1).astype(np.float32)  # (rows, cols, N)
    data = np.clip(data, 1e-4, 1.0 - 1e-4)               # keep strictly in (0,1) for beta fit

    OUT.parent.mkdir(parents=True, exist_ok=True)
    np.save(OUT, data)

    print(f"saved {OUT}  shape={data.shape}  (rows, cols, N_slices)")
    print(f"  slices           : {SLICE_START}..{SLICE_STOP} step {SLICE_STEP}")
    print(f"  mean porosity     : {data.mean():.3f}  (min {data.min():.3f}, max {data.max():.3f})")
    print(f"  physical_resolution: {PHYSICAL_RESOLUTION:.3e} m/px  (put this in config.yml)")
    print(f"  field extent      : {data.shape[0]*PHYSICAL_RESOLUTION:.4e} x "
          f"{data.shape[1]*PHYSICAL_RESOLUTION:.4e} m")


if __name__ == "__main__":
    main()
