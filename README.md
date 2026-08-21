# PUMA: Powder Utilization Modeling Application

PUMA is a high performance modeling framework to simulate powder processing. It provides a scalable tool for manufacturers to simulate powder pre- and post-processing.

Reference: https://www.sciencedirect.com/science/article/pii/S0965997826001225 

The tool can predict distortion, residual stress, and (for reactive processes) reaction completion fraction of complex parts after curing/debinding, sintering, and infiltration processes. These predictions are key metrics industry uses to optimize these processes to produce dense, defect-free, stable components.


https://youtu.be/I8haQ0K7SB0


## Architecture
PUMA is structured into two major levels: the governing physics and the material constitutive descriptions with an initial condition generated via a random field.

![architecture](./images/puma_architecture.png)

The governing physics are represented by four primary partial differential equations: conservation of mass through Darcy flow in porous media with an $L^2$-projection for pore pressure, conservation of energy, and balance of linear momentum. These equations are implemented within the MOOSE framework , which provides finite element utilities for solving the governing equations in a fully coupled manner.

The material constitutive response is handled through the NEML2 constitutive modeling library, designed for complex material behavior and efficient scaling on hybrid computing architectures. The integration of MOOSE and NEML2 in PUMA supports simulation of various powder-based post-processing techniques, including sintering, curing, pyrolysis, infiltration, and solidification.

## Chaining of sub-modules
Each submodule solves a different set of equations, but the unknowns and state variables are kept consistent, e.g., displacements, temperature, volume fractions, and pore pressure, from which derived constitutive quantities (e.g., stress, composition, capillary pressure, permeability) are computed.

Displacement and temperature fields, along with their derived quantities, are transferred directly between submodules and serve as initial conditions for subsequent steps. Derived constitutive quantities are likewise transferred through the state variables. For example, in the transition from curing to pyrolysis, the cured phenolic resin becomes the binder phase in the pyrolysis model.

The transfer of fluid volume fraction depends on the process sequence. In the case of reactive infiltration followed by solidification, the infiltrating liquid phase (e.g., Si) is directly transferred as the fluid variable; subsequent reaction and solidification models convert this fluid into either product (e.g., SiC) or solidified liquid phases.

Refer to `examples` folder for usage demonstrations and sample input.

## Installation Instructions

For the random field generation from images:
https://github.com/skounouho/puma-cobra.git

1. __Python environment__

Use a single conda environment that carries both the MOOSE build toolchain and NEML2's Python dependencies. NEML2 supplies its own runtime/build stack (`torch`, `pyzag` 2.0.0, `nmhit`), so there is no separate pinned list to maintain:

```bash
conda create -n puma python=3.13 \
  mpich gcc_linux-64 gxx_linux-64 gfortran_linux-64 \
  cmake make ninja hdf5 netcdf4 zlib libaec bison flex m4 pkg-config
conda activate puma
pip install torch nmhit pyzag==2.0.0 scikit-build-core ninja
```

`torch` and `nmhit` are resolved by CMake at NEML2 configure time, so they must be installed first. `neml2` itself is built from the `neml2/` submodule and pip-installed `--no-deps` by the MOOSE build step below, keeping the C++ library and Python `neml2` in lockstep.

> **pyzag.** The material-calibration examples use pyzag's adjoint, which needs `pyzag` 2.0.0 (from `applied-material-modeling/pyzag`) for its `pyzag.operators` abstraction. The drivers use `neml2.pyzag.NEML2PyzagModel` — construct it, then call `neml2.compile(model)` for JIT.

2. __MOOSE with NEML2__

PUMA builds against __NEML2 v3 (upstream `main`)__. The exact versions are pinned as git submodules:

- MOOSE: `https://github.com/hugary1995/moose.git` @ `neml2-v3-migration` → submodule `moose/`
- NEML2: `https://github.com/applied-material-modeling/neml2.git` @ `main` → submodule `neml2/`

Clone PUMA and populate the two submodules at their pinned commits:

```bash
git clone https://github.com/applied-material-modeling/puma.git
cd puma
git checkout development              # the NEML2 v3 development line
git submodule update --init          # pulls moose/ and neml2/ (not moose's own submodules)
```

`git submodule update --init` is intentionally non-recursive: it fetches only `moose/` and `neml2/`. MOOSE's own submodules (PETSc, libMesh, WASP) are initialized by MOOSE's build scripts in the steps below, not by PUMA.

The `moose/` submodule is picked up automatically by PUMA's `Makefile`. To build against a MOOSE checkout elsewhere, set `MOOSE_DIR` to its path — the submodule is then optional. The `neml2/` submodule is linked into MOOSE via `NEML2_SRC_DIR` during the NEML2 build step below.

`scripts/get_dependencies.sh` wraps the submodule init and the NEML2 build (`scripts/get_dependencies.sh --help` for options). The steps below do the same manually and document the PETSc/libMesh/libtorch prerequisites.

Here are the resources to successfully compile MOOSE with NEML2

- Built MOOSE from source: `https://mooseframework.inl.gov/getting_started/installation/hpc_install_moose.html`

- Built NEML2 from source: `https://applied-material-modeling.github.io/neml2/install.html` and `https://applied-material-modeling.github.io/neml2/tutorials-getting-started.html`

- Linking MOOSE and NEML2: `https://mooseframework.inl.gov/getting_started/installation/install_neml2.html` and `https://mooseframework.inl.gov/getting_started/installation/install_libtorch.html`

__Instructions__: at least worked for `Ubuntu 20.04` with the appropriate `mpi` and compiler packages. Check the above websites for prerequisites and dependencies.

### General installation on Linux (CPU)

The steps below build the full CPU stack (PETSc → libMesh → WASP → NEML2 → PUMA) on a generic Linux workstation. For GPU acceleration on an NVIDIA HPC cluster, do this first, then read [Building on an NVIDIA HPC cluster (GPU)](#building-on-an-nvidia-hpc-cluster-gpu) for the deltas.

Activate the `puma` environment from step 1 — it carries the conda toolchain (MPI, compilers, build libs) and NEML2's dependencies, so the same environment builds and runs the stack. Using the conda `mpicc`/`mpicxx`/`mpif90` wrappers keeps the compilers self-consistent.

- With the environment active and the submodules populated, build MOOSE's PETSc, libMesh, and WASP from the `moose/` submodule:

```bash
export CC=mpicc CXX=mpicxx FC=mpif90 F90=mpif90 F77=mpif77
export MOOSE_DIR=${PWD}/moose
export MOOSE_JOBS=12 METHODS=opt
cd moose/scripts
./update_and_rebuild_petsc.sh
./update_and_rebuild_libmesh.sh
./update_and_rebuild_wasp.sh
cd ../../
```

- Build NEML2 for MOOSE and the Python package, then configure MOOSE against it. `NEML2_SRC_DIR` points at the `neml2/` submodule (upstream `applied-material-modeling/neml2` `main`) and overrides MOOSE's own pinned NEML2; it is pip-installed `--no-deps` into the active environment, keeping the C++ library and Python `neml2` in lockstep. The build links the `torch` already in your environment. Build NEML2 first — it prints the exact `./configure` line — then configure with explicit `--with-neml2` / `--with-libtorch` paths into the conda site-packages:

```bash
export NEML2_SRC_DIR=${PWD}/neml2
cd moose
NEML2_SRC_DIR=${NEML2_SRC_DIR} ./scripts/update_and_rebuild_neml2.sh --skip-submodule-update
SP=$(python -c 'import neml2, os; print(os.path.dirname(os.path.dirname(neml2.__file__)))')
./configure --with-neml2="${SP}/neml2" --with-libtorch="${SP}/torch"
cd ..
```

`update_and_rebuild_neml2.sh` prints the exact `./configure --with-neml2=… --with-libtorch=…` line on success; the command above reconstructs those site-packages paths so you can paste-and-run.

Look at the last line, if it said `config.status: framework/include/base/MooseConfig.h is unchanged`. Then the NEML2-LIBTORCH configurations point to the correct path.

- Compile PUMA with linked MOOSE-NEML2 (from the PUMA repo root; the `moose/` submodule is used automatically).

```bash
make -j 12
```

- Compile NEML2 custom materials in PUMA

PUMA's custom materials are Python models under `neml2_models/python/`, with model definitions in `neml2_models/models/*.i`. `neml2-compile` turns each definition into an AOTInductor artifact under an `aoti/` folder that the MOOSE input files load at runtime. The `aoti/` folders are git-ignored and generated locally. **The regression tests require all eight models to be compiled first** (the test inputs load `neml2_models/aoti/<model>/model_aoti.i`, whose baked absolute paths must match this checkout):

```bash
cd neml2_models
for m in infiltration_1d infiltration_2d pyrolysis_1d pyrolysis_2d \
         solidification_1d solidification_2d solid_mechanics solid_mechanics_pressure; do
  neml2-compile --model model models/$m.i \
    --dtype float64 --device cpu \
    --output-dir aoti/$m --load python -d ":"
done
cd ..
```

Each example under `examples/` carries a `*_scripts.py` that compiles the models it needs with the same `neml2-compile` invocation. Model unit tests run via `neml2_models/tests/unit/run_model_unit_tests.py`.

- With the models compiled, run the test suite:

```bash
./run_tests
```

If all tests pass, the build is complete.

### Building on an NVIDIA HPC cluster (GPU)

Do the full [General installation on Linux (CPU)](#general-installation-on-linux-cpu) build first, then apply the deltas below to add GPU support. The MOOSE/PETSc/libMesh/WASP/NEML2/PUMA build itself is unchanged — GPU support comes from (a) a CUDA-enabled `torch` and (b) compiling the NEML2 material models for the `cuda` device.

1. __Load the cluster toolchain (modules).__ Load a compiler + MPI stack and, importantly, a **CUDA toolkit** — the CUDA AOTI export in step 4 needs `nvcc` on `PATH` (or `CUDA_HOME` pointing at a full toolkit; a runtime-only CUDA install without `nvcc` is not enough). On Cray/HPE systems the Cray wrappers (`cc`/`CC`/`ftn`, which wrap the loaded GNU compilers + `cray-mpich`) work for the MOOSE build; otherwise the conda `mpicc`/`mpicxx`/`mpif90` wrappers used in the CPU steps are fine.

```bash
module load cuda            # provides nvcc (name varies by site: cuda, cudatoolkit, nvhpc, ...)
module load gcc cray-mpich  # or your site's compiler + MPI (skip if using the conda toolchain)
export CUDA_HOME=${CUDA_HOME:-$(dirname "$(dirname "$(command -v nvcc)")")}
```

2. __Install a CUDA-matched `torch`__ in the build/analysis environment. NEML2's Python package (and thus PUMA) links whatever `torch` is active, so this single choice makes the whole stack GPU-capable. Match the wheel's CUDA build to the cluster driver — CUDA minor-version compatibility applies, so a `cu126` wheel runs on a CUDA 12.x driver, but a wheel newer than the driver (e.g. `cu130` on a 12.x driver) will report `torch.cuda.is_available() == False`:

```bash
pip install torch==2.12.1+cu126 --index-url https://download.pytorch.org/whl/cu126
python -c "import torch; print(torch.__version__, torch.cuda.is_available())"   # expect True
```

   Then run the CPU build steps (PETSc → libMesh → WASP → NEML2 → configure → `make`) unchanged — they link this `torch`. On many clusters PETSc must be built on a **compute node**; submit the `update_and_rebuild_*.sh` steps through the scheduler if a login-node build fails.

3. __Verify GPU visibility on a compute node.__ Grab an interactive GPU node (e.g. `salloc --gres=gpu:1 ...` / `srun ...`) and re-check `torch.cuda.is_available()` there — login nodes usually have no GPU.

4. __Compile the NEML2 material models for the GPU__ (this is the step that differs from the CPU build). Pass `--device cpu cuda` so both artifacts are baked; the `cuda` export invokes `nvcc`. Use a **plain host `g++`/`gcc`** for the inductor/AOTI C++ step — not the MPI or Cray compiler wrapper, which torch-inductor mis-handles:

```bash
cd neml2_models
export CC=gcc CXX=g++                       # bare host compiler for AOTI (NOT mpicxx / CC)
for m in infiltration_1d infiltration_2d pyrolysis_1d pyrolysis_2d \
         solidification_1d solidification_2d solid_mechanics solid_mechanics_pressure; do
  neml2-compile --model model models/$m.i \
    --dtype float64 --device cpu cuda \
    --output-dir aoti/$m --load python -d ":"
done
cd ..
```

   If `nvcc` is not available on your cluster, omit `cuda` (use `--device cpu`) — the CPU artifacts are all that CPU runs need.

5. __Run on the GPU.__ Point the model at the `cuda` device: in a MOOSE input set `device = cuda` in the `[NEML2]` block, and in the `examples/**/*_scripts.py` drivers set `DEVICES = ["cpu", "cuda"]` (compile) and the run device accordingly. Launch on GPU nodes through the scheduler (e.g. SLURM `--gres=gpu:N`, one MPI rank per GPU).