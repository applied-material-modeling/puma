from __future__ import annotations

import torch

from neml2.factory import register_neml2_object
from neml2.models.chain_rule import ChainRuleDict
from neml2.models.model import Model
from neml2.schema import HitSchema, input, output, parameter
from neml2.types import Scalar, clamp, pow


@register_neml2_object("PhaseChangeRadialStress")
class PhaseChangeRadialStress(Model):
    r"""Closed-form axisymmetric two-shell (matrix + new phase) hydrostatic
    interface stress with volumetric misfit $\delta\Omega$.
    """

    hit = HitSchema(
        input("macroscopic_strain", Scalar, "Macroscopic volumetric strain measure tr(eps)/3"),
        input("pore_pressure", Scalar, "Pore pressure"),
        input("matrix_volume_fraction", Scalar, "Matrix volume fraction"),
        input("new_phase_volume_fraction", Scalar, "New phase volume fraction"),
        output("hydrostatic_stress", Scalar, "Hydrostatic stress at the phase-solid interface"),
        parameter("E_s", Scalar, "New Phase Young's modulus", attr="Es"),
        parameter("nu_s", Scalar, "New Phase Poisson's ratio", attr="nus"),
        parameter("E_m", Scalar, "Matrix Young's modulus", attr="Em"),
        parameter("nu_m", Scalar, "Matrix Poisson's ratio", attr="num"),
        parameter("delta_Omega", Scalar, "Volumetric misfit", attr="dw"),
    )

    Es: Scalar
    nus: Scalar
    Em: Scalar
    num: Scalar
    dw: Scalar

    def forward(  # type: ignore[override]
        self,
        macroscopic_strain: Scalar,
        pore_pressure: Scalar,
        matrix_volume_fraction: Scalar,
        new_phase_volume_fraction: Scalar,
        *promoted_params: Scalar,
        v: ChainRuleDict | None = None,
    ):
        eps_t = macroscopic_strain
        p = pore_pressure
        phi_m = matrix_volume_fraction
        phi_fs = new_phase_volume_fraction
        Es = self._get_param("Es", promoted_params, Scalar)
        nus = self._get_param("nus", promoted_params, Scalar)
        Em = self._get_param("Em", promoted_params, Scalar)
        num = self._get_param("num", promoted_params, Scalar)
        d = self._get_param("dw", promoted_params, Scalar)

        eps = torch.finfo(phi_m.dtype).eps

        a2 = clamp(1.0 - phi_m - phi_fs, eps, 1.0)
        b2 = clamp(1.0 - phi_m, eps, 1.0)
        a = pow(a2, 0.5)
        b = pow(b2, 0.5)
        b3 = b2 * b
        b4 = b2 * b2
        a2b2 = a2 * b2

        Mm = Em * (1.0 - num) / ((1.0 + num) * clamp(1.0 - 2.0 * num, eps, 1.0))
        Ms = Es * (1.0 - nus) / ((1.0 + nus) * clamp(1.0 - 2.0 * nus, eps, 1.0))
        mum = Em / (2.0 * (1.0 + num))
        mus = Es / (2.0 * (1.0 + nus))

        C_a2b2 = Mm * Ms - Mm * mus - Ms * mum + Ms * mus + mum * mus - mus * mus
        C_a2 = Ms * mum - Ms * mus - mum * mus + mus * mus
        C_b4 = Mm * mus - Ms * mus - mum * mus + mus * mus
        C_b2 = Ms * mus + mum * mus - mus * mus

        D_num = C_a2b2 * a2b2 + C_a2 * a2 + C_b4 * b4 + C_b2 * b2
        denom_D = a2 * b3 + eps
        D = -4.0 * D_num / denom_D

        A_a2b2 = (
            -3.0 * Mm * Ms * d + 4.0 * Mm * d * mus + 3.0 * Mm * p
            + 3.0 * Ms * d * mum - 3.0 * Ms * d * mus
            - 4.0 * d * mum * mus + 4.0 * d * mus * mus
            - 3.0 * mum * p + 3.0 * mus * p
        )
        A_a2 = (
            -3.0 * Ms * d * mum + 3.0 * Ms * d * mus
            + 4.0 * d * mum * mus - 4.0 * d * mus * mus
            + 3.0 * mum * p - 3.0 * mus * p
        )
        A_b4 = 3.0 * Ms * d * mus - 4.0 * d * mus * mus
        A_b2 = -6.0 * Mm * eps_t * mus - 3.0 * Ms * d * mus + 4.0 * d * mus * mus

        N_As_num = A_a2b2 * a2b2 + A_a2 * a2 + A_b4 * b4 + A_b2 * b2

        cA = 2.0 / 3.0
        Q_As = denom_D * D
        As = cA * N_As_num / Q_As

        Ks = Es / (3.0 * ((1.0 - 2.0 * nus) + eps))
        sh = Ks * (2.0 * As - d)
        if v is None:
            return sh

        dA_a2b2_dp = 3.0 * Mm - 3.0 * mum + 3.0 * mus
        dA_a2_dp = 3.0 * mum - 3.0 * mus
        dN_As_dp = dA_a2b2_dp * a2b2 + dA_a2_dp * a2
        dA_b2_deps = -6.0 * Mm * mus
        dN_As_deps = dA_b2_deps * b2

        d_sh_dp = 2.0 * Ks * cA * dN_As_dp / Q_As
        d_sh_deps = 2.0 * Ks * cA * dN_As_deps / Q_As

        def dsigma_dphi(da2: float, db2: float) -> Scalar:
            da = 0.5 * da2 / (a + eps)
            db = 0.5 * db2 / (b + eps)
            da2b2 = da2 * b2 + a2 * db2
            db3 = db2 * b + b2 * db
            db4 = 2.0 * b2 * db2

            dD_num = C_a2b2 * da2b2 + C_a2 * da2 + C_b4 * db4 + C_b2 * db2
            ddenom_D = da2 * b3 + a2 * db3
            dD = -4.0 * (dD_num * denom_D - D_num * ddenom_D) / (denom_D * denom_D)

            dN_As = A_a2b2 * da2b2 + A_a2 * da2 + A_b4 * db4 + A_b2 * db2
            dQ_As = ddenom_D * D + denom_D * dD
            dAs = cA * (dN_As * Q_As - N_As_num * dQ_As) / (Q_As * Q_As)
            return 2.0 * Ks * dAs

        actions = {
            "pore_pressure": lambda V, c=d_sh_dp: c * V,
            "macroscopic_strain": lambda V, c=d_sh_deps: c * V,
            "matrix_volume_fraction": lambda V, c=dsigma_dphi(-1.0, -1.0): c * V,
            "new_phase_volume_fraction": lambda V, c=dsigma_dphi(-1.0, 0.0): c * V,
        }
        return sh, self.apply_chain_rule(v, "hydrostatic_stress", actions, output=sh)
