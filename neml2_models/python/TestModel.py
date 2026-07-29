from __future__ import annotations

from neml2.factory import register_neml2_object
from neml2.models.chain_rule import ChainRuleDict
from neml2.models.model import Model
from neml2.schema import HitSchema, input, output
from neml2.types import Scalar


@register_neml2_object("TestModel")
class TestModel(Model):
    r"""$y = x_1 + x_2$."""

    hit = HitSchema(
        input("x1", Scalar, "First input"),
        input("x2", Scalar, "Second input"),
        output("y", Scalar, "Sum of the inputs"),
    )

    def forward(  # type: ignore[override]
        self,
        x1: Scalar,
        x2: Scalar,
        *promoted_params,
        v: ChainRuleDict | None = None,
    ):
        y = x1 + x2
        if v is None:
            return y
        return y, self.apply_chain_rule(
            v, "y", {"x1": lambda V: V, "x2": lambda V: V}, output=y
        )
