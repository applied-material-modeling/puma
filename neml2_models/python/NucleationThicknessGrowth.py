from __future__ import annotations

import torch

from neml2.factory import register_neml2_object
from neml2.models.chain_rule import ChainRuleDict
from neml2.models.model import Model
from neml2.schema import HitSchema, input, option, output, parameter
from neml2.types import Scalar, clamp, log, pow

from ._jmak import ORDER_TYPES, jmak_f


@register_neml2_object("NucleationThicknessGrowth")
class NucleationThicknessGrowth(Model):
    r"""Nucleation-limited (JMAK/Avrami) thickness-growth rate with a promotable
    closure thickness $h_c$ and $M = h_c / Q$, $x = \delta_P / M$.
    """

    hit = HitSchema(
        input("liquid_reactivity", Scalar, "Reactivity of the liquid phase, between 0 and 1"),
        input("solid_reactivity", Scalar, "Reactivity of the solid phase, between 0 and 1"),
        input("product_thickness", Scalar, "Thickness of the product phase"),
        output("reaction_rate", Scalar, "Product phase thickness rate of change"),
        parameter("growth_constant", Scalar,
                  "Growth constant of the solid nucleation in the liquid phase", attr="K"),
        parameter("closure_thickness", Scalar,
                  "Thickness at which the product forms a continuous layer",
                  attr="hc", allow_promotion=True),
        parameter("fraction_transform", Scalar,
                  "Product phase fraction transformed at the closure time", attr="Q"),
        option("order_type", str,
               "Order of the rate equation: EXACT, FIRST, SECOND, or THIRD",
               default="EXACT", attr="_order"),
    )

    K: Scalar
    hc: Scalar
    Q: Scalar
    _order: str

    def __post_init__(self) -> None:
        if self._order not in ORDER_TYPES:
            raise ValueError(f"order_type must be one of {ORDER_TYPES}")

    def forward(  # type: ignore[override]
        self,
        liquid_reactivity: Scalar,
        solid_reactivity: Scalar,
        product_thickness: Scalar,
        *promoted_params: Scalar,
        v: ChainRuleDict | None = None,
    ):
        Rl = liquid_reactivity
        Rs = solid_reactivity
        dP = product_thickness
        K = self._get_param("K", promoted_params, Scalar)
        hc = self._get_param("hc", promoted_params, Scalar)
        Q = self._get_param("Q", promoted_params, Scalar)

        eps = torch.finfo(dP.dtype).eps
        M = hc / Q
        x = dP / M
        omhm = 1.0 - x

        if self._order == "EXACT":
            omhm = clamp(1.0 - x, eps, 1.0 - eps)
            f = -1.0 / K * log(omhm)
            dfdx = 1.0 / (K * omhm)
        else:
            f, dfdx = jmak_f(x, K, self._order)

        dfdP = dfdx / M
        rate = 4.0 * K * M * pow(f, 0.75) * omhm * Rl * Rs
        if v is None:
            return rate

        dRdP = 4.0 * K * M * Rl * Rs * (
            0.75 * pow(f, -0.25) * dfdP * omhm - pow(f, 0.75) / M
        )
        actions = {
            "product_thickness": lambda V, c=dRdP: c * V,
            "liquid_reactivity": lambda V, c=rate / Rl: c * V,
            "solid_reactivity": lambda V, c=rate / Rs: c * V,
        }
        if "hc" in self._promoted_params:
            dMdhc = M / hc
            dxdhc = -x / hc
            dgdx = 0.75 * pow(f, -0.25) * dfdx * omhm - pow(f, 0.75)
            dRdhc = 4.0 * K * Rl * Rs * (dMdhc * pow(f, 0.75) * omhm + M * dgdx * dxdhc)
            actions[self._promoted_params["hc"].input_name] = lambda V, c=dRdhc: c * V
        return rate, self.apply_chain_rule(v, "reaction_rate", actions, output=rate)
