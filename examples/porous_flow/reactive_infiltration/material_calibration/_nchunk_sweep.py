# Standalone nchunk timing/convergence sweep for the pyzag SiC-growth calibration.
# Run with: /home/tranh/miniconda3/envs/nemlv3_pyzag/bin/python _nchunk_sweep.py
import sys
import time
import warnings

import torch
import neml2
from neml2.pyzag import NEML2PyzagFactory

import experiment_calibration as ec

device = ec.device

# Calibrated / physically-realistic (likely-stiffest) regime.
CALIB = {
    "crit_delta_value": 7.5989,
    "nucleation_rate_K": 1.1853e-12,
    "diffusion_rate_K": 0.0095,
}

# time / pred_time / groups / loss_fn are constant across nchunk.
TIME = torch.linspace(0.0, ec.tmax * 60.0, ec.nt, device=device).reshape(ec.nt, 1)
PRED_TIME = TIME[:, 0] / 60.0
GROUPS = ec.load_experiment()
LOSS_FN = torch.nn.MSELoss()


def set_params(factory, params):
    with torch.no_grad():
        for name, value in params.items():
            getattr(factory, name).fill_(value)


def build_model(factory, nchunk):
    y0 = factory.assemble_state(
        {"delta_P": torch.full((1,), ec.delta_P0, device=device)}, dynamic_dim=1
    )
    forces = factory.assemble_forces({"t": TIME}, dynamic_dim=2)
    return ec.SiCGrowth(factory, ec.nt, forces, y0, nchunk=nchunk)


def one_iter(model, timed=False):
    """One forward+backward. Returns (loss_value, finite_output, converge_warning)."""
    warned = False
    finite = True
    if timed:
        torch.cuda.synchronize()
        t0 = time.perf_counter()
    # zero grads on factory params
    for p in model.parameters():
        if p.grad is not None:
            p.grad = None
    with warnings.catch_warnings(record=True) as wlist:
        warnings.simplefilter("always")
        out = model()  # raw forward to inspect finiteness
        finite = bool(torch.isfinite(out).all().item())
        loss = ec.evaluate_loss(model, PRED_TIME, GROUPS, LOSS_FN)
        loss.backward()
        for w in wlist:
            if "converge" in str(w.message).lower():
                warned = True
    lv = float(loss.detach().cpu())
    if timed:
        torch.cuda.synchronize()
        dt = time.perf_counter() - t0
        return lv, finite, warned, dt
    return lv, finite, warned


def run_nchunk(nchunk, baseline_loss=None):
    result = {
        "nchunk": nchunk,
        "compile_first_s": None,
        "per_iter_s": None,
        "loss": None,
        "finite": None,
        "warned": None,
        "converged": False,
        "error": None,
    }
    try:
        nsys = neml2.load_nonlinear_system("SiCgrowth.i", "eq_sys")
        factory = NEML2PyzagFactory(
            nsys, include_parameters=ec.CALIBRATION_PARAMS, compile=True
        )
        factory.to(device=device)
        set_params(factory, CALIB)
        model = build_model(factory, nchunk)

        # Warm-up (triggers torch.compile at these shapes).
        torch.cuda.synchronize()
        tc0 = time.perf_counter()
        lv, finite, warned = one_iter(model, timed=False)
        torch.cuda.synchronize()
        result["compile_first_s"] = time.perf_counter() - tc0

        # Timed steady-state iters.
        times = []
        last = (lv, finite, warned)
        for _ in range(2):
            lv, finite, warned, dt = one_iter(model, timed=True)
            times.append(dt)
            last = (lv, finite, warned)
        result["per_iter_s"] = sum(times) / len(times)
        result["loss"] = last[0]
        result["finite"] = last[1]
        result["warned"] = last[2]

        ok = last[1] and (not last[2]) and (lv == lv)  # finite, no warn, not NaN
        if baseline_loss is not None:
            rel = abs(lv - baseline_loss) / abs(baseline_loss)
            ok = ok and (rel <= 1e-5)
            result["rel_to_baseline"] = rel
        result["converged"] = bool(ok)
    except Exception as e:
        import traceback
        result["error"] = "{}: {}".format(type(e).__name__, e)
        result["traceback"] = traceback.format_exc()
    finally:
        # reset compile caches between nchunk to avoid cross-contamination
        try:
            torch._dynamo.reset()
        except Exception:
            pass
        torch.cuda.empty_cache()
    return result


def run_nchunk_with_params(nchunk, params):
    """Isolated convergence run at given nchunk with arbitrary params (no baseline cmp)."""
    result = {"nchunk": nchunk, "per_iter_s": None, "loss": None,
              "finite": None, "warned": None, "error": None}
    try:
        nsys = neml2.load_nonlinear_system("SiCgrowth.i", "eq_sys")
        factory = NEML2PyzagFactory(nsys, include_parameters=ec.CALIBRATION_PARAMS, compile=True)
        factory.to(device=device)
        set_params(factory, params)
        model = build_model(factory, nchunk)
        lv, finite, warned = one_iter(model, timed=False)  # warm-up/compile
        lv, finite, warned, dt = one_iter(model, timed=True)
        result.update(per_iter_s=dt, loss=lv, finite=finite, warned=warned)
    except Exception as e:
        result["error"] = "{}: {}".format(type(e).__name__, e)
    finally:
        try:
            torch._dynamo.reset()
        except Exception:
            pass
        torch.cuda.empty_cache()
    return result


def fmt(r):
    return (
        "nchunk={nchunk:>6} | compile+1st={c:>7} | per-iter={p:>8} | "
        "loss={l} | finite={f} | warn={w} | converged={cv}{err}".format(
            nchunk=r["nchunk"],
            c=("%.2f" % r["compile_first_s"]) if r["compile_first_s"] else "n/a",
            p=("%.4f" % r["per_iter_s"]) if r["per_iter_s"] else "n/a",
            l=("%.8e" % r["loss"]) if r["loss"] is not None else "n/a",
            f=r["finite"],
            w=r["warned"],
            cv=r["converged"],
            err=("  ERR=" + r["error"]) if r["error"] else "",
        )
    )


def main():
    print("nt =", ec.nt, "device =", device)
    results = {}

    # 1) baseline at 250
    print("\n=== baseline nchunk=250 ===", flush=True)
    base = run_nchunk(250, baseline_loss=None)
    base["converged"] = base["finite"] and not base["warned"]
    baseline_loss = base["loss"]
    results[250] = base
    print(fmt(base), flush=True)
    print("baseline loss =", baseline_loss, flush=True)

    # 2) sweep upward
    candidates = [500, 1000, 2000, 3000, 4000, 6000, 8000, 12000, 24000]
    last_good = 250
    first_bad = None
    for nc in candidates:
        print("\n=== nchunk=%d ===" % nc, flush=True)
        r = run_nchunk(nc, baseline_loss=baseline_loss)
        results[nc] = r
        print(fmt(r), flush=True)
        if r["converged"]:
            last_good = nc
        else:
            first_bad = nc
            break

    # 3) bisect between last_good and first_bad
    if first_bad is not None:
        lo, hi = last_good, first_bad
        print("\n=== bisecting between %d (good) and %d (bad) ===" % (lo, hi), flush=True)
        for _ in range(4):
            if hi - lo <= max(1, int(0.10 * lo)):
                break
            mid = (lo + hi) // 2
            if mid in results:
                break
            print("\n=== nchunk=%d (bisect) ===" % mid, flush=True)
            r = run_nchunk(mid, baseline_loss=baseline_loss)
            results[mid] = r
            print(fmt(r), flush=True)
            if r["converged"]:
                lo = mid
            else:
                hi = mid
        print("\nconvergence boundary: last-good=%d first-bad=%d" % (lo, hi), flush=True)

    # summary table
    print("\n\n==================== SUMMARY ====================", flush=True)
    print("%8s | %12s | %8s | %9s | %s" % ("nchunk", "per-iter(s)", "speedup", "converged", "final loss"))
    base_t = results[250]["per_iter_s"]
    for nc in sorted(results):
        r = results[nc]
        pit = r["per_iter_s"]
        sp = (base_t / pit) if (pit and base_t) else float("nan")
        print("%8d | %12s | %8s | %9s | %s" % (
            nc,
            ("%.4f" % pit) if pit else "n/a",
            ("%.2fx" % sp) if pit else "n/a",
            str(r["converged"]),
            ("%.8e" % r["loss"]) if r["loss"] is not None else ("ERR: " + str(r["error"])),
        ))

    # recommendation: largest converging nchunk, backed off ~25% for margin
    conv = [nc for nc in sorted(results) if results[nc]["converged"]]
    largest_ok = max(conv) if conv else 250
    rec = int(round(largest_ok * 0.75))
    print("\nlargest converging nchunk =", largest_ok,
          "| per-iter =", results[largest_ok]["per_iter_s"],
          "| speedup =", (base_t / results[largest_ok]["per_iter_s"]))
    print("recommended nchunk (0.75 * largest_ok) =", rec, flush=True)

    # verify recommended nchunk converges at the WORSE-GUESS ec.INITIAL params too
    print("\n=== INITIAL-params check at recommended nchunk=%d ===" % rec, flush=True)
    r_init = run_nchunk_with_params(rec, ec.INITIAL)
    print("INITIAL @ nchunk=%d : loss=%s finite=%s warn=%s per-iter=%s" % (
        rec,
        ("%.8e" % r_init["loss"]) if r_init["loss"] is not None else "n/a",
        r_init["finite"], r_init["warned"],
        ("%.4f" % r_init["per_iter_s"]) if r_init["per_iter_s"] else "n/a",
    ), flush=True)
    r_init["converged_isolated"] = (
        r_init["finite"] and not r_init["warned"] and r_init["loss"] is not None
        and r_init["loss"] == r_init["loss"]
    )
    print("INITIAL converged (finite, no warn):", r_init["converged_isolated"], flush=True)
    results["INITIAL_at_%d" % rec] = r_init

    # write raw dict for reference
    import json
    with open("_nchunk_sweep_results.json", "w") as f:
        clean = {}
        for k, v in results.items():
            vv = {kk: vvv for kk, vvv in v.items() if kk != "traceback"}
            clean[str(k)] = vv
        json.dump(clean, f, indent=2, default=str)
    print("\nwrote _nchunk_sweep_results.json", flush=True)


if __name__ == "__main__":
    main()
