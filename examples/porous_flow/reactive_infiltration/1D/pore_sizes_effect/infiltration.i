############### Input ################

# Simulation parameters
dt = 0.5 #s
total_time = 1800 #s

flux_in = 0.01 # volume fraction
flux_out = 0.01
t_ramp = 10
t_out = ${fparse total_time/10}

# Molar Mass # g mol-1
M_Si = 28.085
M_SiC = 40.11
M_C = 12.011

# denisty # g cm-3
rho_Si = 2.57 # density at liquid state
rho_SiC = 3.21
rho_C = 2.26

# material property
D_LP = 9.5e-6 # cm2 s-1
l_c = 0.05 # cm
h_c = 0.0076 # cm
K_nucl_growth = 1.2e-15 # cm s-1
reactivity_upbound = 0.05
reactivity_lowbound = 0.005

brooks_corey_threshold = 0.5e5 #dyn/cm2
capillary_pressure_power = 10
phi_L_residual = 0.0

permeability_power = 10.0

# liquid viscosity
# liquid silicon viscosity in egs -s
mu_Si = 0.01 # g cm-1 s-1

# solid reference permeability
kk_ref = 1e-8 # 1e-8

# chemical reaction constant
k_C = 1.0
k_SiC = 1.0

# macroscopic property
D_macro = 0.00007 #cm2 s-1
D_macro_high = 0.0004 # cm2 s-1
D_macro_low = 0.00007 #0.003 # cm2 s-1

transition_saturation_front = 0.75
transition_saturation_back = 0.45
transition_saturation_back_start = 0.65

# initial condition
phi_noreact = 0.0
phi0_SiC = 0.00001
phi0_C = 0.83

gravity = 0.0 

## Calculations
D_bar = '${fparse D_LP/(l_c)}'

omega_C = '${fparse M_C/rho_C}'
omega_Si = '${fparse M_Si/rho_Si}'
omega_SiC = '${fparse M_SiC/rho_SiC}'

oCm1 = '${fparse 1/omega_C}'
oSiCm1 = '${fparse 1/omega_SiC}'

om_phinoreact = '${fparse 1-phi_noreact}'

chem_ratio = '${fparse k_SiC/k_C}'

new_scale = '${fparse (transition_saturation_back-transition_saturation_back_start)/2}'

L = 0.6
n = 1000

[GlobalParams]
  pressure = P
  fluid_fraction = phif
[]

[Mesh]
  type = GeneratedMesh
  dim = 1
  nx = ${n}
  xmax = ${L}
[]

[Variables]
  [P]
    scaling = 1e-4
  []
  [phif]
    scaling = 0.409
  []
[]

[AuxVariables]
  [phi_C]
    order = CONSTANT
    family = MONOMIAL
    [AuxKernel]
      type = MaterialRealAux
      property = phis
      execute_on = 'INITIAL TIMESTEP_END'
    []
  []
  [phi_SiC]
    order = CONSTANT
    family = MONOMIAL
    [AuxKernel]
      type = MaterialRealAux
      property = phip
      execute_on = 'INITIAL TIMESTEP_END'
    []
  []
  [phi_nonliquid]
    order = CONSTANT
    family = MONOMIAL
    [AuxKernel]
      type = MaterialRealAux
      property = non_liquid
      execute_on = 'INITIAL TIMESTEP_END'
    []
  []
  [porosity]
    order = CONSTANT
    family = MONOMIAL
    [AuxKernel]
      type = MaterialRealAux
      property = poro
      execute_on = 'INITIAL TIMESTEP_END'
    []
  []
  [permeability]
    order = CONSTANT
    family = MONOMIAL
    [AuxKernel]
      type = MaterialRealAux
      property = perm
      execute_on = 'INITIAL TIMESTEP_END'
    []
  []
  [M2]
    order = CONSTANT
    family = MONOMIAL
    [AuxKernel]
      type = MaterialRealAux
      property = M2
      execute_on = 'INITIAL TIMESTEP_END'
    []
  []
  [Seff]
    order = CONSTANT
    family = MONOMIAL
    [AuxKernel]
      type = MaterialRealAux
      property = Seff
      execute_on = 'INITIAL TIMESTEP_END'
    []
  []
[]

[Kernels]
  [time]
    type = PumaCoupledTimeDerivative
    material_prop = M1
    variable = phif
    material_fluid_fraction_derivative = dM1dphif
    material_pressure_derivative = dM1dP
  []
  [diffusion]
    type = PumaCoupledDiffusion
    material_prop = M2
    variable = phif
    material_fluid_fraction_derivative = dM2dphif
    material_pressure_derivative = dM2dP
  []
  [darcy_nograv]
    type = PumaCoupledDarcyFlow
    coupled_variable = P
    material_prop = M3
    variable = phif
    material_fluid_fraction_derivative = dM3dphif
    material_pressure_derivative = dM3dP
  []
  [gravity]
    type = CoupledAdditiveFlux
    material_prop = M4
    value = '${gravity} 0.0 0.0'
    variable = phif
    material_fluid_fraction_derivative = dM4dphif
    material_pressure_derivative = dM4dP
  []
  [L2]
    type = CoupledL2Projection
    material_prop = M6
    variable = P
    material_fluid_fraction_derivative = dM6dphif
    material_pressure_derivative = dM6dP
  []
  [source]
    type = CoupledMaterialSource
    material_prop = M5
    coefficient = -1
    variable = phif
    material_fluid_fraction_derivative = dM5dphif
    material_pressure_derivative = dM5dP
  []
[]

[NEML2]
  input = 'neml2/neml2_material.i'
  cli_args = 'kk_L=${kk_ref} permeability_power=${permeability_power} rhof_nu=${fparse rho_Si/mu_Si}
              rhof2_nu=${fparse rho_Si^2/mu_Si} phif_residual=${phi_L_residual} rhof=${fparse rho_Si}
              omega_Si=${omega_Si} D=${D_bar} oSiCm1=${oSiCm1} oCm1=${oCm1}
              chem_ratio=${chem_ratio} mchem_P=${fparse -k_SiC} oP_oL=${fparse omega_SiC/omega_Si}
              brooks_corey_threshold=${brooks_corey_threshold}
              K_nucl_growth=${fparse K_nucl_growth/l_c} mhcolc=${fparse -h_c/l_c} omega_SiC=${omega_SiC}
              Dmacro=${D_macro} delta_Dscale_front=${fparse D_macro_high-D_macro}
              delta_Dscale_back=${fparse D_macro_low-D_macro}
              rhof = ${rho_Si} new_scale=${new_scale} transition_saturation_back=${transition_saturation_back}
              transition_saturation_back_start=${transition_saturation_back_start}
              transition_saturation_front=${transition_saturation_front}
              reactivity_upbound=${reactivity_upbound} reactivity_lowbound=${reactivity_lowbound}
              capillary_pressure_power=${capillary_pressure_power} om_phinoreact=${om_phinoreact}'
  [all]
    model = 'model'
    verbose = true
    device = 'cpu'

    moose_input_types = 'POSTPROCESSOR POSTPROCESSOR  VARIABLE
                         MATERIAL      MATERIAL       MATERIAL    MATERIAL'
    moose_inputs = '     time          time           phif
                         phip          phip           phis        phis'
    neml2_inputs = '     forces/t      old_forces/t   forces/phif
                         state/phip    old_state/phip state/phis  old_state/phis'

    moose_output_types = 'MATERIAL       MATERIAL       MATERIAL   MATERIAL   MATERIAL   MATERIAL
                          MATERIAL       MATERIAL       MATERIAL   MATERIAL   MATERIAL   MATERIAL'
    moose_outputs = '     M2             M3             M4         M5         M6         new_solid
                          non_liquid     poro           perm       phip       phis       Seff'
    neml2_outputs = '     state/M2       state/M3       state/M4   state/M5   state/M6   state/phi_skeleton
                          state/phif_max state/poro     state/perm state/phip state/phis state/Seff'

    moose_derivative_types = 'MATERIAL              MATERIAL                MATERIAL
                              MATERIAL              MATERIAL                MATERIAL
                              MATERIAL              MATERIAL'
    moose_derivatives = '     dM6dphif              dM3dphif                dM4dphif
                              dM5dphif              dphipdphif              dphisdphif
                              dM2dphif              dphi_new_soliddphif'
    neml2_derivatives = '     state/M6 forces/phif; state/M3 forces/phif;   state/M4 forces/phif;
                              state/M5 forces/phif; state/phip forces/phif; state/phis forces/phif;
                              state/M2 forces/phif; state/phi_skeleton forces/phif'

    initialize_outputs = '      phip     phis'
    initialize_output_values = 'phi0_SiC phi0_C'
  []
[]

[Materials]
  [constant]
    type = GenericConstantMaterial
    prop_names = 'M1'
    prop_values = '${fparse rho_Si}'
  []
  [constant_derivative]
    type = GenericConstantMaterial
    prop_names = ' dM1dphif dM1dP dM2dP dM3dP dM4dP dM5dP dM6dP'
    prop_values = '0.0      0.0   0.0   0.0   0.0   0.0   0.0'
  []
  [constant_material]
    type = GenericConstantMaterial
    prop_names = 'phi0_SiC'
    prop_values = '${phi0_SiC}'
  []
  [phi0_C]
    type = GenericConstantMaterial
    prop_names = phi0_C
    prop_values = ${phi0_C}
  []
[]

[Postprocessors]
  [time]
    type = TimePostprocessor
    execute_on = 'INITIAL TIMESTEP_BEGIN'
  []
[]

[Functions]
  [flux_in]
    type = PiecewiseLinear
    x = '0 ${t_ramp} ${t_out} ${fparse total_time}'
    y = '0 ${flux_in} 0 0'
  []
  [flux_out]
    type = PiecewiseLinear
    x = '0 ${t_ramp} ${t_out} ${fparse total_time}'
    y = '0 ${flux_out} 0 0'
  []
[]

[BCs]
  [left]
    type = InfiltrationWake
    boundary = left
    inlet_flux = flux_in
    outlet_flux = flux_out
    product_fraction = new_solid
    product_fraction_derivative = dphi_new_soliddphif
    solid_fraction = 0
    solid_fraction_derivative = 0
    variable = phif
    sharpness = 10
    no_flux_fraction_transition = 0.001
  []
  [right]
    type = InfiltrationWake
    boundary = right
    inlet_flux = 0
    outlet_flux = flux_out
    product_fraction = new_solid
    product_fraction_derivative = dphi_new_soliddphif
    solid_fraction = 0
    solid_fraction_derivative = 0
    variable = phif
    no_flux_fraction_transition = 0.001
    sharpness = 10
  []
[]

[VectorPostprocessors]
  [value]
    type = LineValueSampler
    start_point = '0 0 0'
    end_point = '${L} 0 0'
    num_points = ${n}
    variable = 'phif phi_SiC phi_C phi_nonliquid porosity permeability M2 Seff Hnucl Hdiff'
    sort_by = 'x'
    execute_on = 'INITIAL TIMESTEP_END'
  []
[]

[Executioner]
  type = Transient
  solve_type = 'newton'
  petsc_options_iname = '-pc_type' #-snes_type'
  petsc_options_value = 'lu' # vinewtonrsls'
  automatic_scaling = true

  line_search = none

  nl_abs_tol = 1e-6
  nl_rel_tol = 1e-8
  nl_max_its = 12

  end_time = ${total_time}
  dtmax = '${fparse 10000*dt}'

  [TimeStepper]
    type = IterationAdaptiveDT
    dt = ${dt} #s
    optimal_iterations = 8
    iteration_window = 2
    cutback_factor = 0.5
    cutback_factor_at_failure = 0.5
    growth_factor = 1.2
    linear_iteration_ratio = 10000
  []

  [Predictor]
    type = SimplePredictor
    scale = 1.0
    skip_after_failed_timestep = true
  []

  #fixed_point_max_its = 10
  #fixed_point_algorithm = picard
  #fixed_point_abs_tol = 1e-06
  #fixed_point_rel_tol = 1e-08
[]

[Outputs]
  exodus = true
  [console]
    type = Console
    execute_postprocessors_on = NONE
  []
  [csv]
    type = CSV
    file_base = 'example/out'
  []
  print_linear_residuals = false
[]