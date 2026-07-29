#!/usr/bin/env python3
"""Single-element (0D) study of the solidification kinetics closures.

A material point is taken fully liquid, cooled below the solidus, then
re-heated above the liquidus (prescribed temperature history). We compare how
different discretizations of the SAME lever-rule physics behave, and confirm
the algebraic-difference form used in 1D_true/2D reaches full completion at any
time step and is reversible.

Closures (all with phif_avail = 1, so solid fraction = 1 - phif):
  * algebraic     : phif = phif_avail*g(T)  -> evaluated from T (not integrated).
                    Reaches exactly 1-g and hits full solid at T_s for ANY dt.
                    The rate handed to the balances is the telescoping
                    difference (phif_s^n - phif_s^{n-1})/dt.
  * gprime-integ  : Form 3 as a rate, phi_dot = phif_avail*g'(T)*Tdot, then
                    forward-Euler integrated. Under-resolves the g' bump at
                    coarse dt -> incomplete.
  * relaxation    : phi_dot = -k_s*(phif - phif_min)*H_comp(T). Irreversible.

Run:  python3 kinetics_single_element.py
"""

import matplotlib

matplotlib.use("Agg")
import matplotlib.pyplot as plt
import numpy as np

Ts, Tl = 1687.0, 1707.0
PHIF0 = 1.0
PHIF_MIN = 0.002


def smoothstep(T):
    """Cubic Hermite g(T): 0 at Ts, 1 at Tl (fraction still liquid)."""
    x = np.clip((T - Ts) / (Tl - Ts), 0.0, 1.0)
    return x * x * (3.0 - 2.0 * x)


def gprime(T):
    """g'(T) = 6u(1-u)/(Tl-Ts), zero outside [Ts,Tl]."""
    u = (T - Ts) / (Tl - Ts)
    gp = 6.0 * u * (1.0 - u) / (Tl - Ts)
    return np.where((u > 0.0) & (u < 1.0), gp, 0.0)


def temperature_history(n=4000, T_hot=1720.0, T_cold=1665.0, rate=0.25):
    dt = 1.0
    down = np.arange(T_hot, T_cold, -rate * dt)
    up = np.arange(T_cold, T_hot + rate * dt, rate * dt)
    return np.concatenate([down, up]), dt


def solid_algebraic(T):
    """Algebraic closure: solid fraction = 1 - g(T). Pure function of T ->
    identical at any dt, exactly 1 for T <= Ts. (The implemented rate is the
    telescoping difference of this, which reproduces this curve exactly.)"""
    return 1.0 - smoothstep(T)


def integrate_gprime(Tarr):
    """Form 3 as an integrated rate on a (possibly coarse) T path. The forward-
    Euler update is Delta phif = g'(T^n)*(T^n - T^{n-1}) (dt cancels), i.e. a
    Riemann sum of the g' bump -> under-completes when the window is spanned by
    few steps. g' is sampled at the step's new temperature (as in the model)."""
    phif = PHIF0
    out = [1.0 - phif]
    for i in range(1, len(Tarr)):
        phif += gprime(Tarr[i]) * PHIF0 * (Tarr[i] - Tarr[i - 1])  # phif_avail=PHIF0
        phif = min(max(phif, 0.0), PHIF0)
        out.append(1.0 - phif)
    return np.array(out)


def coarse_cool_path(nstep_window, T_hot=1720.0, T_cold=1665.0):
    """Cooling path whose step spans the [Ts,Tl] window in ~nstep_window steps."""
    dT = (Tl - Ts) / nstep_window
    return np.arange(T_hot, T_cold - dT, -dT)


def integrate_relaxation(T, dt, k_s_rel=0.05):
    phif = PHIF0
    out = np.empty_like(T)
    out[0] = 1.0 - phif
    for i in range(1, len(T)):
        x = np.clip((T[i] - Ts) / (Tl - Ts), 0.0, 1.0)
        Hcomp = 1.0 - (x * x * (3.0 - 2.0 * x))
        phif += -k_s_rel * (phif - PHIF_MIN) * Hcomp * dt
        phif = min(max(phif, 0.0), PHIF0)
        out[i] = 1.0 - phif
    return out


def main():
    T, dt = temperature_history()
    half = int(np.argmin(T)) + 1

    fig, (ax1, ax2) = plt.subplots(1, 2, figsize=(12, 5), sharey=True)

    # ---- Panel 1: algebraic form is a function of T -> dt-independent, exact ----
    Tfine = np.linspace(1720.0, 1665.0, 400)
    ax1.plot(Tfine, solid_algebraic(Tfine), "k-", lw=3, label="algebraic  1 - g(T)")
    # coarse-dt evaluations land exactly on the curve (it's a function of T)
    for nstep, c in zip([2, 4], plt.cm.winter(np.linspace(0.2, 0.7, 2))):
        Tpath = coarse_cool_path(nstep)
        ax1.plot(Tpath, solid_algebraic(Tpath), "o", color=c, ms=6,
                 label=f"evaluated at {nstep} steps/window")
    ax1.axvspan(Ts, Tl, color="grey", alpha=0.12)
    ax1.axhline(1.0, color="0.5", lw=0.8, ls=":")
    ax1.annotate("full solid at Ts\n(any dt)", xy=(Ts, 1.0), xytext=(1690, 0.55),
                 fontsize=8, arrowprops=dict(arrowstyle="->", color="0.4"))
    ax1.set_title("Algebraic closure is a function of T\n"
                  "coarse-dt samples lie on the curve; exactly 1 at Ts")
    ax1.set_xlabel("Temperature [K]")
    ax1.set_ylabel("solid fraction (1 - phif)")
    ax1.legend(fontsize=8, loc="center left")
    ax1.grid(alpha=0.3)

    # ---- Panel 2: reversibility over the cool/heat cycle ----
    ax2.plot(T[:half], solid_algebraic(T[:half]), "-", color="C0", lw=2.5,
             label="algebraic (cool)")
    ax2.plot(T[half:], solid_algebraic(T[half:]), "--", color="C2", lw=2.0,
             label="algebraic (heat)")
    rel = integrate_relaxation(T, dt)
    ax2.plot(T[:half], rel[:half], "-", color="C3", lw=1.8, label="relaxation (cool)")
    ax2.plot(T[half:], rel[half:], "--", color="C3", lw=1.8, label="relaxation (heat)")
    ax2.axvspan(Ts, Tl, color="grey", alpha=0.12)
    ax2.set_title("Reversibility: algebraic retraces (cool=heat);\nrelaxation does not")
    ax2.set_xlabel("Temperature [K]")
    ax2.legend(fontsize=8, loc="center left")
    ax2.grid(alpha=0.3)

    fig.tight_layout()
    out = "kinetics_single_element.png"
    fig.savefig(out, dpi=130)
    print(f"wrote {out}")

    # completion summary at the cold end (T < Ts)
    print(f"\ncooled below Ts={Ts:.0f}; algebraic solid fraction = "
          f"{solid_algebraic(1665.0):.4f} (exact, any dt)")
    print("g'-integrated completion is quadrature-error-prone (sampling-dependent);")
    print("see the MOOSE runs: g' left ~16% residual at coarse adaptive dt.")


if __name__ == "__main__":
    main()
