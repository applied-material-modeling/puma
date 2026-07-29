from __future__ import annotations

import torch

from neml2.factory import register_neml2_object
from neml2.models.chain_rule import ChainRuleDict
from neml2.models.model import Model
from neml2.schema import HitSchema, input, option, output, parameter
from neml2.types import Scalar, clamp, log, pow

from ._jmak import ORDER_TYPES, jmak_f


@register_neml2_object("NucleationLimitedReaction")
class NucleationLimitedReaction(Model):
    r"""Nucleation-limited (JMAK/Avrami) reaction rate as a function of product
    volume fraction: $\dot\alpha = 4 \dfrac{K}{\omega_P} f^{3/4}(1-x)\,R_l R_s$.
    """

    hit = HitSchema(
        input("liquid_reactivity", Scalar, "Reactivity of the liquid phase, between 0 and 1"),
        input("solid_reactivity", Scalar, "Reactivity of the solid phase, between 0 and 1"),
        input("product_volume_fraction", Scalar, "Volume fraction of the product phase"),
        output("reaction_rate", Scalar, "Product phase thickness rate of change"),
        parameter("growth_constant", Scalar,
                  "Growth constant of the solid nucleation in the liquid phase", attr="K"),
        parameter("product_molar_volume", Scalar, "Molar volume of the product phase",
                  attr="omega_P"),
        option("order_type", str,
               "Order of the rate equation: EXACT, FIRST, SECOND, or THIRD",
               default="EXACT", attr="_order"),
    )

    K: Scalar
    omega_P: Scalar
    _order: str

    def __post_init__(self) -> None:
        if self._order not in ORDER_TYPES:
            raise ValueError(f"order_type must be one of {ORDER_TYPES}")

    def forward(  # type: ignore[override]
        self,
        liquid_reactivity: Scalar,
        solid_reactivity: Scalar,
        product_volume_fraction: Scalar,
        *promoted_params: Scalar,
        v: ChainRuleDict | None = None,
    ):
        Rl = liquid_reactivity
        Rs = solid_reactivity
        phi_P = product_volume_fraction
        K = self._get_param("K", promoted_params, Scalar)
        omega_P = self._get_param("omega_P", promoted_params, Scalar)

        eps = torch.finfo(phi_P.dtype).eps
        x = clamp(phi_P, eps, 1.0 - eps)
        omx = 1.0 - x

        if self._order == "EXACT":
            f = -1.0 / K * log(omx)
            dfdx = 1.0 / (K * omx)
        else:
            f, dfdx = jmak_f(x, K, self._order)

        rate = 4.0 * K / omega_P * pow(f, 0.75) * omx * Rl * Rs
        if v is None:
            return rate

        dRdx = 4.0 * K / omega_P * Rl * Rs * (
            0.75 * pow(f, -0.25) * dfdx * omx - pow(f, 0.75)
        )
        actions = {
            "product_volume_fraction": lambda V, c=dRdx: c * V,
            "liquid_reactivity": lambda V, c=rate / Rl: c * V,
            "solid_reactivity": lambda V, c=rate / Rs: c * V,
        }
        return rate, self.apply_chain_rule(v, "reaction_rate", actions, output=rate)
