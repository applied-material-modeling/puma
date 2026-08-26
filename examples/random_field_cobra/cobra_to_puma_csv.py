#!/usr/bin/env python
"""Convert a CoBRA sampled field (Exodus ``.e``) into a PUMA initial-condition CSV.

PUMA's image-based examples read porosity via ``PropertyReadFile``
(``read_type = 'voronoi'``) + ``PiecewiseConstantFromCSV``, expecting a
*headerless 4-column* file ``x, y, z, phi0_poro`` -- one Voronoi seed point per
row (see e.g. ``examples/pip_and_lsi/2D_grid/initial_condition_from_csv.i``).

CoBRA already stores the sample as points + values, so this is a thin bridge:
read the sample, (optionally) rescale the coordinates to the target FE domain,
clip porosity to [0, 1], and write the CSV. Because the MOOSE reader uses
nearest-neighbour (Voronoi) lookup, the CoBRA grid points need not coincide
with the FE mesh nodes -- only the coordinate frame must match, hence --domain.

Usage:
    python cobra_to_puma_csv.py [sample.e] [-o initial_condition.csv] [--domain L]
"""
import argparse
from pathlib import Path

import numpy as np
from cobra.utils.io import Sample

HERE = Path(__file__).resolve().parent


def main() -> None:
    p = argparse.ArgumentParser(description=__doc__)
    p.add_argument("sample", nargs="?", default=str(HERE / "output" / "beta" / "sample_0.e"),
                   help="CoBRA sample Exodus file (default: output/beta/sample_0.e)")
    p.add_argument("-o", "--output", default=str(HERE / "initial_condition.csv"),
                   help="output CSV path (default: initial_condition.csv)")
    p.add_argument("--domain", type=float, default=None,
                   help="rescale x and y to a square [0, DOMAIN] to match the FE mesh "
                        "extent (in the mesh's length units). Default: keep CoBRA metres.")
    args = p.parse_args()

    s = Sample.from_file(args.sample)
    xyz = np.array(s.points, dtype=float)          # (N, 3): x, y, z
    poro = np.asarray(s.values, dtype=float).reshape(-1)

    if args.domain is not None:
        for k in (0, 1):                            # rescale x, y independently to [0, domain]
            lo, hi = xyz[:, k].min(), xyz[:, k].max()
            span = hi - lo
            if span > 0:
                xyz[:, k] = (xyz[:, k] - lo) / span * args.domain

    poro = np.clip(poro, 0.0, 1.0)
    out = np.column_stack([xyz[:, 0], xyz[:, 1], xyz[:, 2], poro])

    Path(args.output).parent.mkdir(parents=True, exist_ok=True)
    np.savetxt(args.output, out, delimiter=",")     # headerless: x,y,z,phi0_poro

    print(f"wrote {args.output}")
    print(f"  rows (num_file_data / nvoronoi): {out.shape[0]}")
    print(f"  phi0_poro: min {poro.min():.4f}  mean {poro.mean():.4f}  max {poro.max():.4f}")
    if args.domain is not None:
        print(f"  coords rescaled to [0, {args.domain}] in x and y")


if __name__ == "__main__":
    main()
