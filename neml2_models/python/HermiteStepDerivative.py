from __future__ import annotations

from neml2.factory import register_neml2_object
from neml2.models.chain_rule import ChainRuleDict
from neml2.models.model import Model
from neml2.schema import HitSchema, input, output, parameter
from neml2.types import Scalar, heaviside, macaulay


@register_neml2_object("HermiteStepDerivative")
class HermiteStepDerivative(Model):
    r"""Temperature derivative of the cubic Hermite smooth step.

    With $u = (x - x_0)/(x_1 - x_0)$ and $g(u) = 3u^2 - 2u^3$ (the
    ``HermiteSmoothStep`` value), this returns

    $$ g'(x) = \frac{6\,u\,(1-u)}{x_1 - x_0}, $$

    clamped to zero outside $[x_0, x_1]$ via a Macaulay bracket (the raw
    parabola is negative outside the interval). It is the normalized
    lever-rule solidification kernel: $\int_{x_0}^{x_1} g'\,dx = 1$, so a rate
    $\dot\phi = \phi_\mathrm{avail}\,g'(T)\,\dot T$ integrates to exactly
    $\phi_\mathrm{avail}$ across the interval (full completion, no rate knob).
    """

    hit = HitSchema(
        input("argument", Scalar, "Argument (e.g. temperature)"),
        output("value", Scalar, "g'(argument): the normalized Hermite bump"),
        parameter("lower_bound", Scalar, "Lower bound x0", attr="x0"),
        parameter("upper_bound", Scalar, "Upper bound x1", attr="x1"),
    )

    x0: Scalar
    x1: Scalar

    def forward(  # type: ignore[override]
        self,
        argument: Scalar,
        *promoted_params: Scalar,
        v: ChainRuleDict | None = None,
    ) -> Scalar | tuple[Scalar, ChainRuleDict]:
        x0 = self._get_param("x0", promoted_params, Scalar)
        x1 = self._get_param("x1", promoted_params, Scalar)
        dx = x1 - x0
        u = (argument - x0) / dx
        gp_raw = 6.0 * u * (1.0 - u) / dx  # < 0 outside [x0, x1]
        value = macaulay(gp_raw)  # max(gp_raw, 0): parabolic bump, 0 outside
        if v is None:
            return value

        # d(value)/dx = H(gp_raw) * d(gp_raw)/dx, with d(gp_raw)/dx = 6(1-2u)/dx^2.
        # The Heaviside mask kills the tangent outside the interval, matching the
        # Macaulay clamp on the value.
        dvalue_dx = heaviside(gp_raw) * (6.0 * (1.0 - 2.0 * u) / (dx * dx))
        return value, self.apply_chain_rule(
            v,
            "value",
            {"argument": lambda V, c=dvalue_dx: c * V},
            output=value,
        )


__all__ = ["HermiteStepDerivative"]
