from __future__ import annotations

from neml2.factory import register_neml2_object
from neml2.models.chain_rule import ChainRuleDict
from neml2.models.model import Model
from neml2.schema import HitSchema, input, output
from neml2.types import R2, Scalar, det, inv, sym, tr


@register_neml2_object("PK2HydrostaticStress")
class PK2HydrostaticStress(Model):
    r"""Phase-change PK2 stress contribution
    $\mathbf{S}^{pc} = -J\,\sigma_h\,\mathbf{F}^{-1}\mathbf{F}^{-T}$, $J = \det\mathbf{F}$.
    """

    hit = HitSchema(
        input("hydrostatic_stress", Scalar, "Hydrostatic Cauchy stress offset"),
        input("deformation_gradient", R2, "Deformation gradient"),
        output("pk2_stress", R2, "Phase-change PK2 stress contribution"),
    )

    def forward(  # type: ignore[override]
        self,
        hydrostatic_stress: Scalar,
        deformation_gradient: R2,
        *promoted_params,
        v: ChainRuleDict | None = None,
    ):
        sh = hydrostatic_stress
        F = deformation_gradient
        Finv = inv(F)
        Cinv = Finv @ Finv.base.transpose(-2, -1)
        J = det(F)
        a = J * sh
        Spc = Cinv * (-a)
        if v is None:
            return Spc

        def sh_action(V: Scalar) -> R2:
            return Cinv * (-J * V)

        # dS/dF contracted with a tangent V, with G = Finv @ V:
        #   dS(V) = a (G Cinv + Cinv G^T - tr(G) Cinv)
        def F_action(V: R2) -> R2:
            G = Finv @ V
            return (G @ Cinv + Cinv @ G.base.transpose(-2, -1) - Cinv * tr(sym(G))) * a

        return Spc, self.apply_chain_rule(
            v,
            "pk2_stress",
            {"hydrostatic_stress": sh_action, "deformation_gradient": F_action},
            output=Spc,
        )
