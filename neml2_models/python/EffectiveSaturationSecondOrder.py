from __future__ import annotations

from neml2.factory import register_neml2_object
from neml2.models.chain_rule import ChainRuleDict
from neml2.models.model import Model
from neml2.schema import HitSchema, buffer, input, output, parameter
from neml2.types import Scalar


@register_neml2_object("EffectiveSaturationSecondOrder")
class EffectiveSaturationSecondOrder(Model):
    r"""Second-order effective saturation
    $S = \dfrac{\phi^2 / (\phi_\max^2 + b) - S_r}{1 - S_r}$.
    """

    hit = HitSchema(
        input("fluid_fraction", Scalar, "Volume fraction of the fluid"),
        output("effective_saturation", Scalar, "Effective saturation"),
        parameter("residual_saturation", Scalar, "Liquid's residual volume fraction",
                  attr="Sr", default="0"),
        parameter("max_fraction", Scalar, "Maximum allowable volume fraction of the fluid",
                  attr="phimax", default="1", allow_promotion=True),
        buffer("max_fraction_buffer", Scalar, "Buffer to prevent max_fraction from being zero.",
               attr="buf", default="0.0001"),
    )

    Sr: Scalar
    phimax: Scalar
    buf: Scalar

    def forward(  # type: ignore[override]
        self,
        fluid_fraction: Scalar,
        *promoted_params: Scalar,
        v: ChainRuleDict | None = None,
    ):
        phi = fluid_fraction
        Sr = self._get_param("Sr", promoted_params, Scalar)
        phimax = self._get_param("phimax", promoted_params, Scalar)
        buf = self.buf

        denom = phimax * phimax + buf
        S = ((phi * phi) / denom - Sr) / (1.0 - Sr)
        if v is None:
            return S

        dS_dphi = (2.0 * phi) / (denom * (1.0 - Sr))
        actions = {"fluid_fraction": lambda V, c=dS_dphi: c * V}
        if "phimax" in self._promoted_params:
            dS_dphimax = -(phi * phi) / (1.0 - Sr) * 2.0 * phimax / (denom * denom)
            actions[self._promoted_params["phimax"].input_name] = (
                lambda V, c=dS_dphimax: c * V
            )
        return S, self.apply_chain_rule(v, "effective_saturation", actions, output=S)
