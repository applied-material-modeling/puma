from __future__ import annotations

from neml2.factory import register_neml2_object
from neml2.models.chain_rule import ChainRuleDict
from neml2.models.model import Model
from neml2.schema import HitSchema, input, option, output, parameter
from neml2.types import Scalar


@register_neml2_object("DiffusionLimitedReactionUpdate")
class DiffusionLimitedReactionUpdate(Model):
    r"""Diffusion-limited reaction rate
    $\dot\alpha = \dfrac{2 D R_l R_s}{\omega}\dfrac{r_o}{r_o - r_i + \delta}$.
    """

    hit = HitSchema(
        input("product_inner_radius", Scalar, "Inner radius of the product phase"),
        input("solid_inner_radius", Scalar, "Inner radius of the solid phase"),
        input("liquid_reactivity", Scalar, "Reactivity of the liquid phase, between 0 and 1"),
        input("solid_reactivity", Scalar, "Reactivity of the solid phase, between 0 and 1"),
        output("reaction_rate", Scalar, "Product phase substance (mol/V) rate of change"),
        parameter("diffusion_coefficient", Scalar,
                  "Diffusion coefficient of the rate-limiting species in the product phase",
                  attr="D"),
        option("molar_volume", float, "Molar volume of the rate-limiting (liquid) species",
               attr="_omega"),
        option("product_dummy_thickness", float,
               "Minimum product thickness to avoid division by 0",
               default=0.01, attr="_delta"),
    )

    D: Scalar
    _omega: float
    _delta: float

    def forward(  # type: ignore[override]
        self,
        product_inner_radius: Scalar,
        solid_inner_radius: Scalar,
        liquid_reactivity: Scalar,
        solid_reactivity: Scalar,
        *promoted_params: Scalar,
        v: ChainRuleDict | None = None,
    ):
        ri = product_inner_radius
        ro = solid_inner_radius
        Rl = liquid_reactivity
        Rs = solid_reactivity
        D = self._get_param("D", promoted_params, Scalar)

        factor = 2.0 * D * Rl * Rs / self._omega
        gap = ro - ri + self._delta
        ratio = ro / gap
        rate = factor * ratio
        if v is None:
            return rate

        drate = factor / gap / gap
        actions = {
            "product_inner_radius": lambda V, c=drate * ro: c * V,
            "solid_inner_radius": lambda V, c=drate * (self._delta - ri): c * V,
            "liquid_reactivity": lambda V, c=2.0 * D * Rs / self._omega * ratio: c * V,
            "solid_reactivity": lambda V, c=2.0 * D * Rl / self._omega * ratio: c * V,
        }
        return rate, self.apply_chain_rule(v, "reaction_rate", actions, output=rate)
