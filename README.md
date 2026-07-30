# PUMA: Powder Utilization Modeling Application

PUMA is a high performance modeling framework to simulate powder processing. It provides a scalable tool for manufacturers to simulate powder pre- and post-processing.

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

1. __Required python packages__

- check `environment.yml` for the full list of required Python packages. This environment is named `graintrace_env` and provides the NEML2 v3 runtime stack: `pyzag` 2.0.0, `torch` 2.12.1, and `numpy` 2.4.6. To create it with conda, run:

```bash
conda env create -f environment.yml
```

`neml2` itself is intentionally **not** pinned in `environment.yml`: the PyPI `neml2` wheel hard-pins `pyzag==1.1.4`, which conflicts with the `pyzag==2.0.0` this stack requires. NEML2 (v3, pyzag-v2 compatible) is instead built from the `neml2/` submodule and pip-installed `--no-deps` into this environment by the MOOSE build step below (`update_and_rebuild_neml2.sh`), which also provides the C++ library MOOSE links against — so the C++ and Python NEML2 stay in lockstep.

> **pyzag note.** The material-calibration examples drive NEML2 3.0.7 through pyzag's adjoint, which needs the pyzag **v2 operators abstraction** (`pyzag.operators`, `pyzag.chunktime.BidiagonalPCRFactorization`) matching the `neml2/` submodule. This lives on the `hdt5kt/pyzag` fork; make sure the environment's `pyzag` provides `pyzag.operators` (a plain PyPI `pyzag` may not). The exact fork branch used for development still needs to be pushed to `hdt5kt/pyzag` for a fully reproducible install.

2. __MOOSE with NEML2__

PUMA builds against __NEML2 v3 (with the pyzag v2 port)__. The exact versions are pinned as git submodules:

- MOOSE: `https://github.com/hugary1995/moose.git` @ `neml2-v3-migration` → submodule `moose/`
- NEML2: `https://github.com/hdt5kt/neml2.git` @ `pyzag_v3_port` → submodule `neml2/`

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

> **Two environments.** `environment.yml` (`graintrace_env`) is the *analysis/runtime* env (pyzag, plotting, calibration). It does **not** contain the toolchain needed to *build* MOOSE. Build MOOSE + NEML2 + PUMA in a separate **MOOSE build environment** that provides a self-consistent conda toolchain — MPI + compilers + build libs: `mpich`, `gcc_linux-64`, `gxx_linux-64`, `gfortran_linux-64`, `cmake`, `make`, `ninja`, `hdf5`, `netcdf4`, `zlib`, `libaec`, `bison`, `flex`, `m4`, `pkg-config` (this mirrors MOOSE's own dev env). Do not rely on system compilers/MPI — a machine may lack a matching `gfortran`, and mixing conda + system toolchains fails to link.

- With that build environment active and the submodules populated, build MOOSE's PETSc, libMesh, and WASP from the `moose/` submodule (the conda `mpicc`/`mpicxx`/`mpif90` wrappers use the conda compilers):

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

- Configure MOOSE and build NEML2 for MOOSE and the python package. Do **not** download a standalone libtorch and do **not** set `LIBTORCH_DIR`: `./configure --with-libtorch --with-neml2` auto-discovers the conda `torch` (via the installed `neml2` package), and `update_and_rebuild_neml2.sh` links NEML2 against that same conda torch. Setting `LIBTORCH_DIR` overrides this and pins a different libtorch version — an ABI mismatch. `NEML2_SRC_DIR` points MOOSE at the `neml2/` submodule (the `pyzag_v3_port` version), overriding MOOSE's own pinned NEML2 submodule; it is pip-installed `--no-deps` into the active environment (so the C++ library and Python `neml2` stay in lockstep).

```bash
export NEML2_SRC_DIR=${PWD}/neml2
cd moose
./configure --with-libtorch --with-neml2
NEML2_SRC_DIR=${NEML2_SRC_DIR} ./scripts/update_and_rebuild_neml2.sh --skip-submodule-update
cd ..
```

Once neml2 is compiled, some message like this will appear, run the `cd <messagaes>`.

```bash
****************************************************************************************************
NEML2 has been successfully installed.
To configure MOOSE with NEML2, run the following commands:
  cd <messages>
****************************************************************************************************
```

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