#!/usr/bin/env python
"""Run every PUMA custom-model ModelUnitTest.

Each ``<Model>.i`` carries a ``[Drivers] type = ModelUnitTest`` block that checks
the model's output values and first derivatives (directional JVPs) against an
autograd oracle. Exits non-zero if any scenario fails.
"""

from __future__ import annotations

import sys
from pathlib import Path

from neml2.cli._extensions import load_user_extensions
from neml2.drivers.ModelUnitTest import ModelUnitTest

HERE = Path(__file__).resolve().parent
EXT = HERE.parent.parent / "python"


def main() -> int:
    load_user_extensions([str(EXT)])
    failures = 0
    for f in sorted(HERE.glob("*.i")):
        try:
            rep = ModelUnitTest.from_file(str(f)).run()
            print(f"PASS {f.name}  (values={rep.value_checks}, jvp={rep.jvp_checks})")
        except Exception as e:  # noqa: BLE001
            failures += 1
            print(f"FAIL {f.name}\n    {type(e).__name__}: {str(e)[:400]}")
    print(f"\n{'OK' if failures == 0 else 'FAILED'}: "
          f"{failures} failure(s) out of the unit suite")
    return 1 if failures else 0


if __name__ == "__main__":
    sys.exit(main())
