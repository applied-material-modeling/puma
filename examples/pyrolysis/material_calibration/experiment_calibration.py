import torch
import torch.distributions as dist
import neml2
from pyzag import nonlinear, reparametrization, chunktime
import matplotlib.pyplot as plt
#import matplotlib.font_manager as fm
import pandas as pd
import tqdm
import os


## Set up plot ------------------------------------------------------------
# fe = fm.FontEntry(
#    fname="/usr/share/fonts/truetype/wsttcorefonts/Arial.ttf", name="Arial"
#)
#fm.fontManager.ttflist.insert(0, fe)

fsize = 13.5
lw = 1
figsize = (4, 4)

plt.rc("font", size=fsize)  # controls default text sizes
plt.rc("axes", titlesize=fsize)  # fontsize of the axes title
plt.rc("axes", labelsize=fsize)  # fontsize clearof the x and y labels
plt.rc("xtick", labelsize=fsize)  # fontsize of the tick labels
plt.rc("ytick", labelsize=fsize)  # fontsize of the tick labels
plt.rc("legend", fontsize=fsize)  # legend fontsize
plt.rc("figure", titlesize=fsize)  # fontsize of the figure title

colors = ["blue", "red", "black", "purple"]  # Extend as needed
linestyles = ["-", "--", "-.", ":", (0, (3, 1, 1, 1))]  # Custom dash patterns optional

## Input ------------------------------------------------------------

torch.manual_seed(0)
nchunk = 10

torch.set_default_dtype(torch.double)
if torch.cuda.is_available():
    dev = "cuda:0"
else:
    dev = "cpu"
device = torch.device(dev)

## INPUT
Tmax = 1400  # K
Tmin = 300  # K
nTemp = 1000
dTdt = torch.tensor([5.0, 10.0, 20.0], dtype=float, device=device)  # K/min

## Initial parameter for reaction mechanism
Y = 0.6  # yield
n = 9  # reaction order
k0 = 1.0e14  # reaction rate coefficient
Q = 250000  # J/mol

## initial condition
wb0 = 1.0
wc0 = 0.0

## experiment
exp_folder = "experiment_data"
exp_filename = [
    "5degpermin_run1.csv",
    "10degpermin_run1.csv",
    "20degpermin_run1.csv",
    "20degpermin_run3.csv",
]  # corresponding to the correct id order from dTdt
exp_rate_id = [0, 1, 2, 2]  # which rate to use for each experiment file

save_folder = "main_2"

# Optimization
niter = 1000
lr = 5.0e-4

## RELEVANT WRAPPERS AND FUNCTIONS ------------------------------------------------------------


## NEML2 - PyTORCH wrapper
class Pyrolysis(torch.nn.Module):
    """Just integrate the model through some strain history

    Args:
        discrete_equations: the pyzag wrapped model
        nchunk (int): number of vectorized time steps
        rtol (float): relative tolerance to use for Newton's method during time integration
        atol (float): absolute tolerance to use for Newton's method during time integration
    """

    def __init__(self, discrete_equations, nchunk=1, rtol=1.0e-6, atol=1.0e-4):
        super().__init__()
        self.discrete_equations = discrete_equations
        self.nchunk = nchunk
        self.cached_solution = None
        self.rtol = rtol
        self.atol = atol

    def forward(self, time, temperature, cache=False):
        """Integrate through some time/temperature and return
        Args:
            time (torch.tensor): batched times
            temperature (torch.tensor): batched temperatures

        Keyword Args:
            cache (bool): if true, cache the solution and use it as a predictor for the next call.
                This heuristic can speed things up during inference where the model is called repeatedly with similar parameter values.
        """
        if cache and self.cached_solution is not None:
            solver = nonlinear.RecursiveNonlinearEquationSolver(
                self.discrete_equations,
                step_generator=nonlinear.StepGenerator(self.nchunk),
                predictor=nonlinear.FullTrajectoryPredictor(self.cached_solution),
                nonlinear_solver=chunktime.ChunkNewtonRaphson(
                    rtol=self.rtol, atol=self.atol
                ),
            )
        else:
            solver = nonlinear.RecursiveNonlinearEquationSolver(
                self.discrete_equations,
                step_generator=nonlinear.StepGenerator(self.nchunk),
                predictor=nonlinear.PreviousStepsPredictor(),
                nonlinear_solver=chunktime.ChunkNewtonRaphson(
                    rtol=self.rtol, atol=self.atol
                ),
            )

        # Setup
        forces = self.discrete_equations.forces_asm.assemble_by_variable(
            {
                "forces/t": time,
                "forces/T": temperature,
            }
        ).torch()

        state0 = torch.zeros(
            forces.shape[1:-1] + (self.discrete_equations.nstate,), device=forces.device
        )

        state0[:, 1] = wb0

        result = nonlinear.solve_adjoint(solver, state0, len(forces), forces)

        if cache:
            self.cached_solution = result.detach().clone()

        return result[..., 0:3]


def linear_interp_1d(x, y, xnew):
    # Ensure all tensors are 1D
    x = x.flatten().contiguous()
    y = y.flatten().contiguous()
    xnew = xnew.flatten().contiguous()

    # Get indices of left neighbors
    idx = torch.searchsorted(x, xnew, right=True) - 1
    idx = idx.clamp(0, len(x) - 2)  # avoid out-of-bounds

    x0 = x[idx]
    x1 = x[idx + 1]
    y0 = y[idx]
    y1 = y[idx + 1]

    # Linear interpolation formula
    ynew = y0 + (y1 - y0) * (xnew - x0) / (x1 - x0)
    return ynew


def plot_prediction_experiment(model, ax, plot_experiment=True):
    ## Plot to see if the model is accurate / initial guess

    with torch.no_grad():
        data = model(time, temperature)

    wtotal = data[..., 1].cpu() + data[..., 2].cpu()

    # plot initial guess
    for i in range(wtotal.shape[1]):
        ax.plot(
            temperature[:, i].cpu(),
            wtotal[:, i],
            color=colors[i % len(colors)],
            label=f"{dTdt[i]} K/min",
        )

    ax.set_xlabel("Temperature (K)")
    ax.set_ylabel("Total weight fraction")
    ax.legend(loc="best", frameon=False)

    # load and plot experiment
    exp_wtotal_all = {}

    if plot_experiment:
        stride = 50  # keep every 5th point
        for i in range(len(exp_filename)):
            df = pd.read_csv(f"{exp_folder}/{exp_filename[i]}")
            exp_temp = torch.tensor(df["Temperature (degC)"].values, device=device)
            exp_temp = exp_temp + 273.15  # convert to Kelvin
            exp_w = torch.tensor(df["Weight (mg)"].values, device=device)

            exp_wtotal = exp_w / exp_w[0]  # normalize to initial weight

            # interpolate exp_wtotal to the model's temperature range with id corresponding to dTdt
            id_exp_temp = exp_rate_id[i]
            exp_wtotal_save = linear_interp_1d(
                exp_temp, exp_wtotal, temperature[:, id_exp_temp]
            )

            # store exp_wtotal with dictionary of id_exp_temp
            exp_wtotal_all[i] = exp_wtotal_save.cpu()

            ax.scatter(
                exp_temp[::stride].cpu().numpy(),
                exp_wtotal[::stride].cpu().numpy(),
                color=colors[exp_rate_id[i] % len(colors)],
                marker="x",
                s=10,
            )

    exp_wtotal_df = pd.DataFrame(exp_wtotal_all)

    return exp_wtotal_df, exp_wtotal_all


## MAIN ------------------------------------------------------------

## Load NEML2 model
nmodel = neml2.load_model("TGA.i", "model")
nmodel.to(device=device)

print(nmodel)

## Initial guess
nmodel.reaction_coef_Q = neml2.tensors.Scalar.full(Q)
nmodel.char_rate_c_0 = neml2.tensors.Scalar.full(Y)
nmodel.reaction_coef_p0 = neml2.tensors.Scalar.full(k0)
nmodel.reaction_rate_n = neml2.tensors.Scalar.full(n)

model = Pyrolysis(
    neml2.pyzag.NEML2PyzagModel(
        nmodel,
        exclude_parameters=[],
    ),
    nchunk=nchunk,
)

## initial guess
nrate = len(dTdt)

# Allocate with (steps, batch, features)
time = torch.zeros((nTemp, nrate, 1), device=device)
temperature = torch.zeros((nTemp, nrate, 1), device=device)

# Fill each batch (one per heating rate)
for i, rate in enumerate(dTdt):
    # Temperature profile for this rate
    temperature[:, i, 0] = torch.linspace(Tmin, Tmax, nTemp, device=device)
    # Corresponding time profile
    time[:, i, 0] = (temperature[:, i, 0] - Tmin) / (rate / 60.0)

# Reshape into (steps, batch, features) – this is what PyZag expects
time = time.reshape((nTemp, -1, 1))          # (steps, nrate, 1)
temperature = temperature.reshape((nTemp, -1, 1))  # (steps, nrate, 1)

fig1, ax1 = plt.subplots(figsize=figsize)
exp_wtotal_df, exp_wtotal_all = plot_prediction_experiment(
    model, ax1, plot_experiment=True
)

## Rescale to get similar gradients (~1)

Y_scaler = reparametrization.RangeRescale(
    torch.tensor(0.05, device=device), torch.tensor(20.0, device=device), clamp=False
)
Q_scaler = reparametrization.RangeRescale(
    torch.tensor(500000.0, device=device),
    torch.tensor(1000000.0, device=device),
    clamp=False,
)
k0_scaler = reparametrization.RangeRescale(
    torch.tensor(1.0e14, device=device),
    torch.tensor(5.0e14, device=device),
    clamp=False,
)
n_scaler = reparametrization.RangeRescale(
    torch.tensor(1.0, device=device), torch.tensor(220.0, device=device), clamp=False
)

model_reparameterizer = reparametrization.Reparameterizer(
    {
        "discrete_equations.char_rate_c_0": Y_scaler,
        "discrete_equations.reaction_coef_Q": Q_scaler,
        "discrete_equations.reaction_coef_p0": k0_scaler,
        "discrete_equations.reaction_rate_n": n_scaler,
    },
    error_not_provided=True,
)
model_reparameterizer(model)

## Optimizing ------------------------------------------------------------

optimizer = torch.optim.Adam(model.parameters(), lr=lr)
loss_fn = torch.nn.MSELoss()

titer = tqdm.tqdm(
    range(niter),
    bar_format="{desc}: {percentage:3.0f}%|{bar}|{n_fmt}/{total_fmt}{postfix}",
)
titer.set_description("Loss:")
loss_history = []

# Print final results
print("Initial Guess:")
for n, p in model.discrete_equations.named_parameters():
    nice_name = n.split(".")[-2]
    ref_name = "discrete_equations." + nice_name
    scaler = model_reparameterizer.map_dict[ref_name]
    print(nice_name + ": \t" + str(scaler(p.data).cpu()) + "\t")

for i in titer:
    optimizer.zero_grad()

    res = model(time, temperature, cache=True)

    # calculate loss for each experiment
    loss = 0.0
    for j in range(len(exp_filename)):
        id_exp_temp = exp_rate_id[j]
        prediction = res[:, id_exp_temp, 1] + res[:, id_exp_temp, 2]
        exp_wtotal = exp_wtotal_all[j].to(device)
        loss += loss_fn(prediction, exp_wtotal)

    loss.backward()

    # for name, param in model.named_parameters():
    #     if param.grad is not None:
    #         print(f"{name}: grad norm = {param.grad.norm():.3e}")
    #     else:
    #         print(f"{name}: grad is None")

    loss_history.append(loss.detach().clone().cpu())
    titer.set_description("Loss: %3.2e" % loss_history[-1])
    optimizer.step()

# Plot the loss history final results preidctions
figsize = (8, 4)
fig2, ax2 = plt.subplots(1, 2, figsize=figsize)

ax2[0].loglog(loss_history, label="Training")
ax2[0].set_xlabel("Iteration")
ax2[0].set_ylabel("MSE")
ax2[0].legend(loc="best")

exp_wtotal_df, exp_wtotal_all = plot_prediction_experiment(model, ax2[1])

# Print final results
print("Optimized results:")
for n, p in model.discrete_equations.named_parameters():
    nice_name = n.split(".")[-2]
    ref_name = "discrete_equations." + nice_name
    scaler = model_reparameterizer.map_dict[ref_name]
    print(nice_name + ": \t" + str(scaler(p.data).cpu()) + "\t")

fig1.tight_layout()
fig2.tight_layout()

# create save folder if it does not exist
if not os.path.exists(save_folder):
    os.makedirs(save_folder)

# Save figures and models
fig1.savefig(f"{save_folder}/pyrolysis_initial_guess.png", dpi=300)
fig2.savefig(f"{save_folder}/pyrolysis_optimization_results.png", dpi=300)

# plt.show()
# print(data)
