from __future__ import annotations

import torch

from neml2.factory import register_neml2_object
from neml2.models.chain_rule import ChainRuleDict
from neml2.models.model import Model
from neml2.schema import HitSchema, derived_input, input, output, parameter
from neml2.types import Scalar, clamp


@register_neml2_object("HermiteSolidificationRate")
class HermiteSolidificationRate(Model):
    r"""Discrete lever-rule liquid solidification rate.

    $$ \dot\phi^{f} = \phi_\mathrm{avail}\,\frac{g(T^{n}) - g(T^{n-1})}{t^{n}-t^{n-1}} $$

    where $g$ is the cubic Hermite smooth step (fraction still liquid, $g(T_s)=0$,
    $g(T_l)=1$) evaluated at the current and previous temperatures, and
    $\phi_\mathrm{avail}$ is the conserved total silicon in liquid-volume units.

    Using the *difference* of $g$ (not $g'\dot T$) makes the integral telescoping,
    so integrating $\dot\phi^{fs} = -(1+\Delta\Omega)\dot\phi^{f}$ reaches exactly
    $(1+\Delta\Omega)\phi_\mathrm{avail}$ across the freezing range (full
    completion, any $\Delta t$). Outside $[T_s,T_l]$ the difference is zero, so the
    rate vanishes and the integrated solid fraction is bounded (no re-freezing of
    transported/residual liquid below $T_s$).
    """

    hit = HitSchema(
        input("temperature", Scalar, "Current temperature", attr="_T"),
        derived_input("temperature", Scalar, attr="_Tn", suffix="~1"),
        input("time", Scalar, "Time", default="t", attr="_t"),
        derived_input("time", Scalar, attr="_tn", suffix="~1"),
        input("available", Scalar, "Total silicon in liquid-volume units", attr="_avail"),
        output("rate", Scalar, "Liquid solidification rate", attr="_rate"),
        parameter("lower_bound", Scalar, "Solidus temperature x0", attr="x0"),
        parameter("upper_bound", Scalar, "Liquidus temperature x1", attr="x1"),
    )

    _T: str
    _Tn: str
    _t: str
    _tn: str
    _avail: str
    _rate: str
    x0: Scalar
    x1: Scalar

    def forward(  # type: ignore[override]
        self,
        temperature: Scalar,
        temperature_n: Scalar,
        time: Scalar,
        time_n: Scalar,
        available: Scalar,
        *promoted_params: Scalar,
        v: ChainRuleDict | None = None,
    ):
        x0 = self._get_param("x0", promoted_params, Scalar)
        x1 = self._get_param("x1", promoted_params, Scalar)
        eps = torch.finfo(temperature.dtype).eps
        dx = x1 - x0

        u_n = clamp((temperature - x0) / dx, eps, 1.0 - eps)
        g_n = 3.0 * u_n * u_n - 2.0 * u_n * u_n * u_n
        u_o = clamp((temperature_n - x0) / dx, eps, 1.0 - eps)
        g_o = 3.0 * u_o * u_o - 2.0 * u_o * u_o * u_o

        dt = time - time_n
        dg = g_n - g_o
        rate = available * dg / dt
        if v is None:
            return rate

        # dg/dT at current/old T; clamp's flat tails make these vanish outside
        # [x0,x1] (u(1-u)->0 at the clamp bounds), matching HermiteSmoothStep.
        dgn_dT = 6.0 * u_n * (1.0 - u_n) / dx
        dgo_dTn = 6.0 * u_o * (1.0 - u_o) / dx

        d_rate_dT = available * dgn_dT / dt
        d_rate_dTn = available * (-dgo_dTn) / dt
        d_rate_davail = dg / dt
        rate_over_dt = rate / dt

        actions = {
            self._T: lambda V, c=d_rate_dT: c * V,
            self._Tn: lambda V, c=d_rate_dTn: c * V,
            self._avail: lambda V, c=d_rate_davail: c * V,
            self._t: lambda V, c=rate_over_dt: -(c * V),
            self._tn: lambda V, c=rate_over_dt: c * V,
        }
        return rate, self.apply_chain_rule(v, self._rate, actions, output=rate)


__all__ = ["HermiteSolidificationRate"]
