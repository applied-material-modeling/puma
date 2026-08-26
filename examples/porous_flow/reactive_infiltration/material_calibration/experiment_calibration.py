# Copyright 2025, UChicago Argonne, LLC
# All Rights Reserved
# Software Name: PUMA: Powder Utilization Modeling Application
# By: UChicago Argonne, LLC
# OPEN SOURCE LICENSE (MIT)

import importlib.util
import os
import shutil
import sys
from pathlib import Path

# TorchInductor (compile=True) needs a plain C++ compiler. Prefer conda's g++
# (the moose-src env), else fall back to the system g++ (the nemlv3_pyzag env).
# This overrides any mpicxx/mpicc leaked in by an activated build sourcefile,
# which breaks Inductor's PCH step.
_cxx = shutil.which("x86_64-conda-linux-gnu-g++") or shutil.which("g++")
_cc = shutil.which("x86_64-conda-linux-gnu-gcc") or shutil.which("gcc")
if _cxx:
    os.environ["CXX"] = _cxx
if _cc:
    os.environ["CC"] = _cc

import neml2
import pandas as pd
import torch
import tqdm
from matplotlib import pyplot as plt
from neml2.pyzag import NEML2PyzagModel
from pyzag import chunktime, nonlinear, reparametrization

_pkg = Path(__file__).resolve().parents[4] / "neml2_models" / "python"
_spec = importlib.util.spec_from_file_location(
    "puma_neml2_models", _pkg / "__init__.py", submodule_search_locations=[str(_pkg)]
)
_mod = importlib.util.module_from_spec(_spec)
sys.modules["puma_neml2_models"] = _mod
_spec.loader.exec_module(_mod)

torch.manual_seed(0)
torch.set_default_dtype(torch.double)
device = torch.device("cuda:0" if torch.cuda.is_available() else "cpu")

tmax = 400.0
dt = 1.0
nt = int(tmax * 60.0 / dt)
delta_P0 = 1.0e-4

exp_folder = "experiment_data"
exp_filename = "SiC_growth_full.csv"
fit_group = "Martinez"

save_folder = "results_2"
nchunk = 250
niter = 1000
lr = 1.0e-2
# early stop: quit if the loss hasn't improved by >plateau_tol (relative) for
# plateau_patience consecutive iterations (protects against wasting the tail).
plateau_patience = 120
plateau_tol = 1.0e-3

CALIBRATION_PARAMS = ["crit_delta_value", "nucleation_rate_K", "diffusion_rate_K"]
# Deliberately poor starting guess: both reaction-rate constants are set to 0.3x
# their calibrated values (MSE ~9.9 vs ~0.29 at the optimum) so the optimization
# has a clear descent to show. The calibrated values are ~1.1853e-12 / ~0.0095.
INITIAL = {
    "crit_delta_value": 7.5989,
    "nucleation_rate_K": 3.5559e-13,
    "diffusion_rate_K": 2.85e-3,
}
PARAM_RANGES = {
    "crit_delta_value": (0.0, 1.0),
    "nucleation_rate_K": (1.0e-13, 1.0e-12),
    "diffusion_rate_K": (1.0e-3, 1.0e-2),
}
colors = ["blue", "red", "black", "purple"]
markers = ["o", "s", "^", "p", "*", "d", "v", "h", "x", "+"]

fsize = 11
plt.rc("font", size=fsize)
plt.rc("axes", titlesize=fsize)
plt.rc("axes", labelsize=fsize)


class SiCGrowth(torch.nn.Module):
    def __init__(self, factory, ntime, forces, y0, nchunk=1, rtol=1.0e-8, atol=1.0e-8):
        super().__init__()
        self.factory = factory
        self.ntime = ntime
        self.forces = forces
        self.y0 = y0
        self.nchunk = nchunk
        self.rtol = rtol
        self.atol = atol
        self.cached_solution = None

    def forward(self, cache=False):
        if cache and self.cached_solution is not None:
            predictor = nonlinear.FullTrajectoryPredictor(self.cached_solution)
        else:
            predictor = nonlinear.PreviousStepsPredictor()
        solver = nonlinear.RecursiveNonlinearEquationSolver(
            self.factory,
            step_generator=nonlinear.StepGenerator(self.nchunk),
            predictor=predictor,
            nonlinear_solver=chunktime.ChunkNewtonRaphson(rtol=self.rtol, atol=self.atol),
        )
        result = nonlinear.solve_adjoint(solver, self.y0, self.ntime, self.forces)
        if cache:
            self.cached_solution = result.detach().clone()
        return result[..., 0, 0]


def linear_interp_1d(x, y, xnew):
    x = x.flatten().contiguous()
    y = y.flatten().contiguous()
    xnew = xnew.flatten().contiguous()
    idx = torch.searchsorted(x, xnew, right=True) - 1
    idx = idx.clamp(0, len(x) - 2)
    x0, x1, y0, y1 = x[idx], x[idx + 1], y[idx], y[idx + 1]
    return y0 + (y1 - y0) * (xnew - x0) / (x1 - x0)


def load_experiment():
    df = pd.read_csv("{}/{}".format(exp_folder, exp_filename))
    groups = []
    for name, subset in df.groupby("Literature"):
        groups.append(
            {
                "id": name,
                "time": torch.tensor(subset["Reaction Duration (min)"].values, device=device),
                "thickness": torch.tensor(subset["SiC thickness (mu-m)"].values, device=device),
            }
        )
    return groups


def plot_prediction(model, pred_time, groups, ax):
    with torch.no_grad():
        thickness = model().cpu()
    ax.plot(pred_time.cpu(), thickness, color="red", label="NEML2")
    for i, g in enumerate(groups):
        ax.scatter(g["time"].cpu(), g["thickness"].cpu(), marker=markers[i % len(markers)],
                   facecolors="none", edgecolors="k", label=g["id"])
    ax.set_xlabel("Reaction Duration (minutes)")
    ax.set_ylabel("SiC Thickness (micrometers)")
    ax.legend(loc="best", frameon=False)


def evaluate_loss(model, pred_time, groups, loss_fn):
    pred = model(cache=True)
    losses = []
    for g in groups:
        if g["id"] != fit_group:
            continue
        pred_interp = linear_interp_1d(pred_time, pred, g["time"])
        losses.append(loss_fn(pred_interp, g["thickness"]))
    return torch.stack(losses).mean()


def main():
    time = torch.linspace(0.0, tmax * 60.0, nt, device=device).reshape(nt, 1)
    pred_time = time[:, 0] / 60.0

    nsys = neml2.load_nonlinear_system("SiCgrowth.i", "eq_sys")
    factory = NEML2PyzagModel(nsys, include_parameters=CALIBRATION_PARAMS)
    neml2.compile(factory)
    factory.to(device=device)
    with torch.no_grad():
        for name, value in INITIAL.items():
            getattr(factory, name).fill_(value)

    y0 = factory.assemble_state({"delta_P": torch.full((1,), delta_P0, device=device)}, dynamic_dim=1)
    forces = factory.assemble_forces({"t": time}, dynamic_dim=2)

    model = SiCGrowth(factory, nt, forces, y0, nchunk=nchunk)
    groups = load_experiment()

    fig1, ax1 = plt.subplots(figsize=(6, 4))
    plot_prediction(model, pred_time, groups, ax1)

    # persist the initial-guess prediction curve (params still at INITIAL) so the
    # paper figure can show the "before calibration" line.
    if not os.path.exists(save_folder):
        os.makedirs(save_folder)
    with torch.no_grad():
        init_thickness = model().cpu().numpy()
    pd.DataFrame(
        {"time_min": pred_time.cpu().numpy(), "thickness_um": init_thickness}
    ).to_csv("{}/initial_curve.csv".format(save_folder), index=False)

    map_dict = {
        "factory.{}".format(name): reparametrization.RangeRescale(
            torch.tensor(lo, device=device), torch.tensor(hi, device=device), clamp=False
        )
        for name, (lo, hi) in PARAM_RANGES.items()
    }
    reparametrization.Reparameterizer(map_dict, error_not_provided=True)(model)

    if not os.path.exists(save_folder):
        os.makedirs(save_folder)

    # Checkpoint helpers -- write incrementally during the loop so all data
    # needed to replot survives an early kill (e.g. once the loss plateaus).
    def save_loss(hist):
        pd.DataFrame(
            {"iteration": range(1, len(hist) + 1), "mse": hist}
        ).to_csv("{}/loss_history.csv".format(save_folder), index=False)

    def save_fit():
        with torch.no_grad():
            thickness = model().cpu().numpy()
        pd.DataFrame(
            {"time_min": pred_time.cpu().numpy(), "thickness_um": thickness}
        ).to_csv("{}/fit_curve.csv".format(save_folder), index=False)

    def current_params():
        # getattr(factory, name) returns the physical (de-reparametrized) value
        with torch.no_grad():
            return {n: float(getattr(factory, n).detach().cpu()) for n in CALIBRATION_PARAMS}

    def save_params(it):
        vals = current_params()
        pd.DataFrame([{"iteration": it, **vals}]).to_csv(
            "{}/calibrated_params.csv".format(save_folder), index=False
        )

    optimizer = torch.optim.Adam(model.parameters(), lr=lr)
    loss_fn = torch.nn.MSELoss()
    loss_history = []
    best_loss = float("inf")
    best_iter = 0
    titer = tqdm.tqdm(range(niter))
    for i in titer:
        optimizer.zero_grad()
        loss = evaluate_loss(model, pred_time, groups, loss_fn)
        loss.backward()
        loss_history.append(float(loss.detach().cpu()))
        titer.set_description("Loss: %3.2e" % loss_history[-1])
        optimizer.step()
        # checkpoint (loss is cheap; fit needs a forward, so save it less often)
        if (i + 1) % 10 == 0:
            save_loss(loss_history)
        if (i + 1) % 50 == 0:
            save_fit()
        if (i + 1) % 10 == 0:
            save_params(i + 1)
        # early stop on plateau
        if loss_history[-1] < best_loss * (1.0 - plateau_tol):
            best_loss = loss_history[-1]
            best_iter = i
        if i - best_iter >= plateau_patience:
            print("\nplateau: no >%.1f%% improvement in %d iters; stopping at iter %d"
                  % (plateau_tol * 100, plateau_patience, i + 1))
            break

    save_loss(loss_history)
    save_fit()
    save_params(len(loss_history))
    print("\ncalibrated parameters (final MSE %.4e):" % loss_history[-1])
    for name, value in current_params().items():
        print("  %-20s = %.6g" % (name, value))

    fig2, ax2 = plt.subplots(1, 2, figsize=(11, 4))
    ax2[0].loglog(loss_history)
    ax2[0].set_xlabel("Iteration")
    ax2[0].set_ylabel("MSE")
    plot_prediction(model, pred_time, groups, ax2[1])

    fig1.tight_layout()
    fig2.tight_layout()
    fig1.savefig("{}/initial_guess.png".format(save_folder), dpi=300)
    fig2.savefig("{}/optimized_results.png".format(save_folder), dpi=300)


if __name__ == "__main__":
    main()
