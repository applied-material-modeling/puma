from __future__ import annotations

from neml2.factory import register_neml2_object
from neml2.models.chain_rule import ChainRuleDict
from neml2.models.model import Model
from neml2.schema import HitSchema, input, option, output, parameter
from neml2.types import Scalar


@register_neml2_object("DiffusionThicknessGrowth")
class DiffusionThicknessGrowth(Model):
    r"""Steady-state diffusion thickness-growth rate
    $\dot\alpha = \dfrac{K}{\delta_P + \delta}\,R_l R_s$.
    """

    hit = HitSchema(
        input("liquid_reactivity", Scalar, "Reactivity of the liquid phase, between 0 and 1"),
        input("solid_reactivity", Scalar, "Reactivity of the solid phase, between 0 and 1"),
        input("product_thickness", Scalar, "Thickness of the product phase"),
        output("reaction_rate", Scalar, "Product phase thickness rate of change"),
        parameter("rate_constant", Scalar,
                  "Rate constant of the rate-limiting species in the product phase", attr="K"),
        option("product_dummy_thickness", float,
               "Minimum product thickness to avoid division by 0",
               default=0.01, attr="_delta"),
    )

    K: Scalar
    _delta: float

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

        gap = dP + self._delta
        rate = K / gap * Rl * Rs
        if v is None:
            return rate

        actions = {
            "product_thickness": lambda V, c=-K / (gap * gap) * Rl * Rs: c * V,
            "liquid_reactivity": lambda V, c=K / gap * Rs: c * V,
            "solid_reactivity": lambda V, c=K / gap * Rl: c * V,
        }
        return rate, self.apply_chain_rule(v, "reaction_rate", actions, output=rate)
