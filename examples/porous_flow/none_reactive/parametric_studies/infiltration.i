############### Input ################

output = 'example'

# Simulation parameters
dt = 0.5 #s
total_time = 120 #s
t_out = ${total_time}

flux_in = 0.2 # volume fraction
flux_out = 0.2
t_ramp = 100

# density # g cm-3
rho_Si = 2.57 # density at liquid state

# initial condition
phi0_SiC = 0.0
phi0_C = 0.0

gravity = 0

L = 1
n = 500

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
      property = phif_max
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
  input = 'neml2/aoti/model_aoti.i'
  [all]
    model = 'model'
    device = 'cpu'

    derivatives = 'M6 phif dM6dphif; M3 phif dM3dphif; M4 phif dM4dphif;
                   M5 phif dM5dphif; phip phif dphipdphif; phis phif dphisdphif;
                   M2 phif dM2dphif; new_solid phif dphi_new_soliddphif'

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
    x = '0 ${t_ramp} ${t_out} ${fparse total_time +5}'
    y = '0 ${flux_in} ${flux_in} 0'
  []
  [flux_out]
    type = PiecewiseLinear
    x = '0 ${t_ramp}'
    y = '0 ${flux_out}'
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
    variable = 'phif phi_SiC phi_C phi_nonliquid porosity permeability M2 Seff'
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
    file_base = '${output}/out'
  []
  print_linear_residuals = false
[]