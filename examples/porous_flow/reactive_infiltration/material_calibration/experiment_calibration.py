import torch
import torch.distributions as dist
import neml2
from pyzag import nonlinear, reparametrization, chunktime
import matplotlib.pyplot as plt
import matplotlib.font_manager as fm
from matplotlib.ticker import AutoMinorLocator
import pandas as pd
import tqdm
import os


## Set up plot ------------------------------------------------------------
fe = fm.FontEntry(
    fname="/home/tranh/Fonts/arial.ttf", name="Arial"
)
fm.fontManager.ttflist.insert(0, fe)

font = {"family": "Arial"}
fsize = 11
lw = 1.2

plt.rc("font", **font)
plt.rc("font", **font, size=fsize)  # controls default text sizes
plt.rc("axes", titlesize=fsize)  # fontsize of the axes title
plt.rc("axes", labelsize=fsize)  # fontsize clearof the x and y labels
plt.rc("xtick", labelsize=fsize)  # fontsize of the tick labels
plt.rc("ytick", labelsize=fsize)  # fontsize of the tick labels
plt.rc("legend", fontsize=fsize)  # legend fontsize
plt.rc("figure", titlesize=fsize)  # fontsize of the figure title

colors = ["blue", "red", "black", "purple"]  # Extend as needed
linestyles = ["-", "--", "-.", ":", (0, (3, 1, 1, 1))]  # Custom dash patterns optional
marker = ['o','s','^','p','*','d','v','h','x','+']  # Extend as needed
facecond = ['none', 'none', 'k', 'none', 'none', 'none', 'none', 'none', 'none', 'none']  # Extend as needed

## Input ------------------------------------------------------------
experiment_name = "SiC_growth_full.csv"

save_folder = "results_2"
torch.manual_seed(0)
nchunk = 100

torch.set_default_dtype(torch.double)
if torch.cuda.is_available():
    dev = "cuda:0"
else:
    dev = "cpu"
device = torch.device(dev)

## simulation condition
tmax = 400 # minutes
dt = 1 # seconds

## initial guess
hc = 7.5989 # micro-meter
Q = 1.0 # fraction transform -- 1 - exp(-K*tc) where tc is the closure time
K_nucl = 1.1853e-12 # kinetic constant for nucleation
K_diff = 0.0095 # kinetic constant for diffusion

# Optimization
niter = 100
lr = 1.0e-3
check_grad_norm = False

## NEML2 - PyTORCH wrapper
class SiCGrowth(torch.nn.Module):
    """Just integrate the model through some strain history

    Args:
        discrete_equations: the pyzag wrapped model
        nchunk (int): number of vectorized time steps
        rtol (float): relative tolerance to use for Newton's method during time integration
        atol (float): absolute tolerance to use for Newton's method during time integration
    """

    def __init__(self, discrete_equations, nchunk=1, rtol=1.0e-8, atol=1.0e-8):
        super().__init__()
        self.discrete_equations = discrete_equations
        self.nchunk = nchunk
        self.cached_solution = None
        self.rtol = rtol
        self.atol = atol

    def forward(self, time, cache=False):
        """Integrate through some time and return
        Args:
            time (torch.tensor): batched times

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
            }
        ).torch()

        state0 = torch.zeros(
            forces.shape[1:-1] + (self.discrete_equations.nstate,), device=forces.device
        )

        state0[..., -1] = 1e-4

        result = nonlinear.solve_adjoint(solver, state0, len(forces), forces)

        if cache:
            self.cached_solution = result.detach().clone()

        return result[..., 0]

def save_csv(time, thickness, folder, name):
    # assuming two columns: first column is time, second column is thickness
    df = pd.DataFrame({
        "time (s)": time,
        "thickness (microm)": thickness
    })
    df.to_csv(os.path.join(folder, name), index=False)

def plot_prediction_experiment(model, time, ax, 
                               plot_experiment=True,
                               experiment_name="SiC_growth.csv",
                               save_data=True, 
                               save_folder="results",
                               save_name="data.csv"):

    with torch.no_grad():
        out = model(time, cache=True)

    if save_data:
        if not os.path.exists(save_folder):
            os.makedirs(save_folder)
        save_csv((time[:,0]/60).cpu().reshape(-1), out[:,0].cpu().reshape(-1), save_folder, save_name
        )

    ax.plot(
        (time[:,0]/60).cpu(),
        out[:,0].cpu(),
        color="red",
        linestyle="-",
        linewidth=lw,
        label="NEML2",
    )

    # experiment data
    # Load CSV
    df = pd.read_csv(experiment_name)
    experiment = []
    
    # Scatter plot
    for i, (literature, subset) in enumerate(df.groupby("Literature")):
        if plot_experiment:
            ax.scatter(
                subset["Reaction Duration (min)"],
                subset["SiC thickness (mu-m)"],
                label=literature,
                marker=marker[i],
                facecolors=facecond[i],          
                edgecolors='k'          
            )
        # set experiment as "id", "time", "values" each literature data as id, time, thickness
        experiment.append({
            "id": literature,
            "time": torch.tensor(subset["Reaction Duration (min)"].values, device=device),
            "thickness": torch.tensor(subset["SiC thickness (mu-m)"].values, device=device)
        })

    ax.set_xlabel("Reaction Duration (minutes)")
    ax.set_ylabel("SiC Thickness (micrometers)")
    # ax.legend(frameon=False, bbox_to_anchor=(1.05, 1), loc='upper left')

    return experiment

def evaluate_loss(model, time, experiments, loss_fn, experiment_ids="all"):

    pred_time = (time[:,0] / 60)                 # minutes
    pred_values = model(time, cache=True)[:,0]   # (nt,)

    if experiment_ids != "all":
        if isinstance(experiment_ids, str):
            experiment_ids = [experiment_ids]
        experiments = [exp for exp in experiments if exp["id"] in experiment_ids]

    losses = []
    for exp in experiments:
        exp_time = exp["time"]
        exp_values = exp["thickness"]

        # interpolation prediction to experimental time
        pred_interp = torch_interp(exp_time, pred_time, pred_values)
        losses.append(loss_fn(pred_interp, exp_values))

    return torch.stack(losses).mean()

def torch_interp(x, xp, fp):

    xp = xp.squeeze()
    fp = fp.squeeze()

    idx = torch.searchsorted(xp, x, right=True) - 1
    idx = idx.clamp(0, len(xp) - 2)  # keep within bounds

    x0, x1 = xp[idx], xp[idx+1]
    y0, y1 = fp[idx], fp[idx+1]

    slope = (y1 - y0) / (x1 - x0)
    return y0 + slope * (x - x0)

## Main -------------------------------------------------------------

# create save folder if it does not exist
if not os.path.exists(save_folder):
    os.makedirs(save_folder)

# neml2 model
nmodel = neml2.load_model("SiCgrowth.i", "model")
nmodel.to(device=device)

print(nmodel)

# initial guess
nmodel.crit_delta_value = neml2.tensors.Scalar.full(hc)
nmodel.nucleation_rate_Q = neml2.tensors.Scalar.full(Q)
nmodel.nucleation_rate_K = neml2.tensors.Scalar.full(K_nucl)
nmodel.diffusion_rate_K = neml2.tensors.Scalar.full(K_diff)

model = SiCGrowth(
    neml2.pyzag.NEML2PyzagModel(
        nmodel,
        exclude_parameters=["diffusion_rate_switch_A", 
                            "nucleation_rate_switch_A",
                            "nucleation_rate_Q",
                            "o_dP_A"]  # exclude parameters from optimization,
    ),
    nchunk=nchunk,
)

nt = int(tmax*60/dt)

# Create time sequence: shape (steps, batch, features)
time = torch.linspace(0, tmax*60, nt, device=device)        # (nt,)
time = time[:, None, None]                                  # (nt, 1, 1)                                     

fig1, ax1 = plt.subplots(figsize=(4,2.9))
ax1.minorticks_on()
ax1.set_xlim(0, 400)
ax1.set_ylim(0, 25)
ax1.xaxis.set_minor_locator(AutoMinorLocator(2))
ax1.yaxis.set_minor_locator(AutoMinorLocator(2))
experiments = plot_prediction_experiment(model, time, ax1, plot_experiment=True,
                                         experiment_name=experiment_name,
                                         save_data=False, save_folder="check_order", 
                                         save_name="first.csv")

fig1.tight_layout()
fig1.savefig(f"{save_folder}/initial_guess.png", dpi=300)
plt.close()

## Rescaling
hc_scaler = reparametrization.RangeRescale(
    torch.tensor(0.0, device=device), torch.tensor(1.0, device=device), clamp=False
)
Q_scaler = reparametrization.RangeRescale(
    torch.tensor(0.0, device=device), torch.tensor(1.0, device=device), clamp=False
)
K_nucl_scaler = reparametrization.RangeRescale(
    torch.tensor(1.0e-13, device=device), torch.tensor(1.0e-12, device=device), clamp=False
)
K_diff_scaler = reparametrization.RangeRescale(
    torch.tensor(1.0e-3, device=device), torch.tensor(1.0e-2, device=device), clamp=False
)

model_reparameterizer = reparametrization.Reparameterizer(
    {
        "discrete_equations.crit_delta_value": hc_scaler,
        # "discrete_equations.nucleation_rate_Q": Q_scaler,
        "discrete_equations.nucleation_rate_K": K_nucl_scaler,
        "discrete_equations.diffusion_rate_K": K_diff_scaler,
    },
    error_not_provided=True,
)
model_reparameterizer(model)

## Optimizing
optimizer = torch.optim.Adam(model.parameters(), lr=lr)
loss_fn = torch.nn.MSELoss()

titer = tqdm.tqdm(
    range(niter),
    bar_format="{desc}: {percentage:3.0f}%|{bar}|{n_fmt}/{total_fmt}{postfix}",
)
titer.set_description("Loss:")
loss_history = []

print("Initial Guess:")
for n, p in model.discrete_equations.named_parameters():
    nice_name = n.split(".")[-2]
    ref_name = "discrete_equations." + nice_name
    scaler = model_reparameterizer.map_dict[ref_name]
    print(nice_name + ": \t" + str(scaler(p.data).cpu()) + "\t")

for i in titer:
    optimizer.zero_grad()
    loss = evaluate_loss(model, time, experiments, loss_fn, experiment_ids="Martinez")#"all")
    loss.backward()
    optimizer.step()

    loss_history.append(loss.detach().clone().cpu())
    titer.set_description("Loss: %3.2e" % loss_history[-1])
    optimizer.step()

    if check_grad_norm:
        print("Checking gradient norms after first iteration, optimization will only run for 1 iteration:")
        for name, param in model.named_parameters():
            if param.grad is not None:
                print(f"{name}: grad norm = {param.grad.norm():.3e}")
            else:
                print(f"{name}: grad is None")
        break

if not check_grad_norm:
    # Print final results
    print("Optimized results:")
    for n, p in model.discrete_equations.named_parameters():
        nice_name = n.split(".")[-2]
        ref_name = "discrete_equations." + nice_name
        scaler = model_reparameterizer.map_dict[ref_name]
        print(nice_name + ": \t" + str(scaler(p.data).cpu()) + "\t")

    fig2, ax2 = plt.subplots(figsize=(6,4))
    experiments = plot_prediction_experiment(model, time, ax2, plot_experiment=True,
                                             experiment_name=experiment_name,
                                             save_data=True, save_folder=save_folder, 
                                             save_name="fitted.csv")
    fig2.tight_layout()
    fig2.savefig(f"{save_folder}/optimized_results.png", dpi=300)

    plt.close(fig2)

# Plot the loss history final results preidctions
figsize = (8, 4)
fig3, ax3 = plt.subplots(figsize=(6,4))

ax3.loglog(loss_history)
ax3.set_xlabel("Iteration")
ax3.set_ylabel("MSE")

fig3.tight_layout()
fig3.savefig(f"{save_folder}/loss_history.png", dpi=300)

plt.close(fig3)

