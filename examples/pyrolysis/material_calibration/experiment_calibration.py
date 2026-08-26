# Copyright 2025, UChicago Argonne, LLC
# All Rights Reserved
# Software Name: PUMA: Powder Utilization Modeling Application
# By: UChicago Argonne, LLC
# OPEN SOURCE LICENSE (MIT)

import os

os.environ.setdefault("CC", "x86_64-conda-linux-gnu-gcc")
os.environ["CXX"] = "x86_64-conda-linux-gnu-g++"

import neml2
import pandas as pd
import torch
import tqdm
from matplotlib import pyplot as plt
from neml2.pyzag import NEML2PyzagModel
from pyzag import chunktime, nonlinear, reparametrization

torch.manual_seed(0)
torch.set_default_dtype(torch.double)
device = torch.device("cuda:0" if torch.cuda.is_available() else "cpu")

Tmin = 300.0
Tmax = 1400.0
nTemp = 1000
dTdt = torch.tensor([5.0, 10.0, 20.0], device=device)
wb0 = 1.0

exp_folder = "experiment_data"
exp_filename = [
    "5degpermin_run1.csv",
    "10degpermin_run1.csv",
    "20degpermin_run1.csv",
    "20degpermin_run3.csv",
]
exp_rate_id = [0, 1, 2, 2]

save_folder = "main_2"
nchunk = 250
niter = 1000
lr = 5.0e-4

CALIBRATION_PARAMS = [
    "char_rate_weight_0",
    "reaction_coef_Q",
    "reaction_coef_p0",
    "reaction_rate_n",
]
INITIAL = {
    "char_rate_weight_0": 0.6,
    "reaction_coef_Q": 250000.0,
    "reaction_coef_p0": 1.0e14,
    "reaction_rate_n": 9.0,
}
PARAM_RANGES = {
    "char_rate_weight_0": (0.05, 20.0),
    "reaction_coef_Q": (500000.0, 1000000.0),
    "reaction_coef_p0": (1.0e14, 5.0e14),
    "reaction_rate_n": (1.0, 220.0),
}
colors = ["blue", "red", "black", "purple"]

fsize = 13.5
plt.rc("font", size=fsize)
plt.rc("axes", titlesize=fsize)
plt.rc("axes", labelsize=fsize)


class Pyrolysis(torch.nn.Module):
    def __init__(self, factory, ntime, forces, y0, nchunk=1, rtol=1.0e-6, atol=1.0e-4):
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
        return result[..., 0:3]


def linear_interp_1d(x, y, xnew):
    x = x.flatten().contiguous()
    y = y.flatten().contiguous()
    xnew = xnew.flatten().contiguous()
    idx = torch.searchsorted(x, xnew, right=True) - 1
    idx = idx.clamp(0, len(x) - 2)
    x0, x1, y0, y1 = x[idx], x[idx + 1], y[idx], y[idx + 1]
    return y0 + (y1 - y0) * (xnew - x0) / (x1 - x0)


def load_experiment(temperature):
    exp_wtotal_all = {}
    for i in range(len(exp_filename)):
        df = pd.read_csv("{}/{}".format(exp_folder, exp_filename[i]))
        exp_temp = torch.tensor(df["Temperature (degC)"].values, device=device) + 273.15
        exp_w = torch.tensor(df["Weight (mg)"].values, device=device)
        exp_wtotal = exp_w / exp_w[0]
        exp_wtotal_all[i] = linear_interp_1d(
            exp_temp, exp_wtotal, temperature[:, exp_rate_id[i]]
        ).cpu()
    return exp_wtotal_all


def plot_prediction(model, temperature, exp_wtotal_all, ax):
    with torch.no_grad():
        data = model()
    wtotal = data[..., 1].cpu() + data[..., 2].cpu()
    for i in range(wtotal.shape[1]):
        ax.plot(temperature[:, i].cpu(), wtotal[:, i], color=colors[i % len(colors)],
                label="{} K/min".format(dTdt[i]))
    for i in range(len(exp_filename)):
        ax.scatter(temperature[:, exp_rate_id[i]].cpu(), exp_wtotal_all[i],
                   color=colors[exp_rate_id[i] % len(colors)], marker="x", s=6)
    ax.set_xlabel("Temperature (K)")
    ax.set_ylabel("Total weight fraction")
    ax.legend(loc="best", frameon=False)


def main():
    nrate = len(dTdt)
    temperature = torch.zeros((nTemp, nrate), device=device)
    time = torch.zeros((nTemp, nrate), device=device)
    for i, rate in enumerate(dTdt):
        temperature[:, i] = torch.linspace(Tmin, Tmax, nTemp, device=device)
        time[:, i] = (temperature[:, i] - Tmin) / (rate / 60.0)

    nsys = neml2.load_nonlinear_system("TGA.i", "eq_sys")
    factory = NEML2PyzagModel(nsys, include_parameters=CALIBRATION_PARAMS)
    neml2.compile(factory)
    factory.to(device=device)
    with torch.no_grad():
        for name, value in INITIAL.items():
            getattr(factory, name).fill_(value)

    y0 = factory.assemble_state(
        {
            "alpha": torch.zeros(nrate, device=device),
            "wb": torch.full((nrate,), wb0, device=device),
            "wc": torch.zeros(nrate, device=device),
        },
        dynamic_dim=1,
    )
    forces = factory.assemble_forces({"T": temperature, "t": time}, dynamic_dim=2)

    model = Pyrolysis(factory, nTemp, forces, y0, nchunk=nchunk)
    exp_wtotal_all = load_experiment(temperature)

    fig1, ax1 = plt.subplots(figsize=(4, 4))
    plot_prediction(model, temperature, exp_wtotal_all, ax1)

    map_dict = {
        "factory.{}".format(name): reparametrization.RangeRescale(
            torch.tensor(lo, device=device), torch.tensor(hi, device=device), clamp=False
        )
        for name, (lo, hi) in PARAM_RANGES.items()
    }
    reparametrization.Reparameterizer(map_dict, error_not_provided=True)(model)

    optimizer = torch.optim.Adam(model.parameters(), lr=lr)
    loss_fn = torch.nn.MSELoss()
    loss_history = []
    titer = tqdm.tqdm(range(niter))
    for _ in titer:
        optimizer.zero_grad()
        res = model(cache=True)
        loss = sum(
            loss_fn(res[:, exp_rate_id[j], 1] + res[:, exp_rate_id[j], 2],
                    exp_wtotal_all[j].to(device))
            for j in range(len(exp_filename))
        )
        loss.backward()
        loss_history.append(float(loss.detach().cpu()))
        titer.set_description("Loss: %3.2e" % loss_history[-1])
        optimizer.step()

    fig2, ax2 = plt.subplots(1, 2, figsize=(8, 4))
    ax2[0].loglog(loss_history)
    ax2[0].set_xlabel("Iteration")
    ax2[0].set_ylabel("MSE")
    plot_prediction(model, temperature, exp_wtotal_all, ax2[1])

    if not os.path.exists(save_folder):
        os.makedirs(save_folder)
    fig1.tight_layout()
    fig2.tight_layout()
    fig1.savefig("{}/pyrolysis_initial_guess.png".format(save_folder), dpi=300)
    fig2.savefig("{}/pyrolysis_optimization_results.png".format(save_folder), dpi=300)


if __name__ == "__main__":
    main()
