from __future__ import annotations

from neml2.types import Scalar, pow

ORDER_TYPES = ("EXACT", "FIRST", "SECOND", "THIRD")


def jmak_f(x: Scalar, K: Scalar, order: str) -> tuple[Scalar, Scalar]:
    """Return (f, df/dx) for the JMAK/Avrami rate integral, per non-EXACT order."""
    if order == "FIRST":
        return x / K, 1.0 / K
    if order == "SECOND":
        return (x + 0.5 * x * x) / K, (1.0 + x) / K
    if order == "THIRD":
        return (x + 0.5 * x * x + (1.0 / 3.0) * pow(x, 3)) / K, (1.0 + x + x * x) / K
    raise ValueError("EXACT is handled inline by the caller")
