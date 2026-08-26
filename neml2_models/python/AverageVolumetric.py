from __future__ import annotations

from neml2.factory import register_neml2_object
from neml2.models.chain_rule import ChainRuleDict
from neml2.models.model import Model
from neml2.schema import HitSchema, input, output
from neml2.types import R2, SR2, Scalar, sym, tr


@register_neml2_object("SR2AverageVolumetric")
class SR2AverageVolumetric(Model):
    r"""One-third of the trace of a symmetric second order tensor: $v = \tr(A)/3$."""

    hit = HitSchema(
        input("input", SR2, "The second order tensor input"),
        output("average_volumetric", Scalar, "One-third of the tensor trace"),
    )

    def forward(  # type: ignore[override]
        self,
        input: SR2,  # noqa: A002
        *promoted_params,
        v: ChainRuleDict | None = None,
    ):
        vol = tr(input) / 3.0
        if v is None:
            return vol
        return vol, self.apply_chain_rule(
            v, "average_volumetric", {"input": lambda V: tr(V) / 3.0}, output=vol
        )


@register_neml2_object("R2AverageVolumetric")
class R2AverageVolumetric(Model):
    r"""One-third of the trace of a second order tensor: $v = \tr(A)/3$.
    The trace ignores the skew part, so $\tr(A) = \tr(\mathrm{sym}(A))$.
    """

    hit = HitSchema(
        input("input", R2, "The second order tensor input"),
        output("average_volumetric", Scalar, "One-third of the tensor trace"),
    )

    def forward(  # type: ignore[override]
        self,
        input: R2,  # noqa: A002
        *promoted_params,
        v: ChainRuleDict | None = None,
    ):
        vol = tr(sym(input)) / 3.0
        if v is None:
            return vol
        return vol, self.apply_chain_rule(
            v, "average_volumetric", {"input": lambda V: tr(sym(V)) / 3.0}, output=vol
        )
