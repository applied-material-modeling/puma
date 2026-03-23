############### Input ################

# Simulation parameters
dt = 5 #s
total_time = 10000 #s

flux_in = 0.1 # volume fraction
flux_out = 0.1
t_ramp = 1000

# denisty # g cm-3
rho_PR = 2.00 # density at liquid state

brooks_corey_threshold = 3e4 #Pa
capillary_pressure_power = 3
phi_L_residual = 0.0

permeability_power = 3

# liquid viscosity
mu_PR = 10

# solid permeability
kk_PR = 2e-5

# macroscopic property
D_macro = 0.0 #cm2 s-1

porosity_feature = 0.2
porosity_background = 0.8

gravity = 980.665

[GlobalParams]
  pressure = P
  fluid_fraction = phif
[]

[Mesh]
  [mesh0]
    type = FileMeshGenerator
    file = 'gold/core.msh'
  []
[]

[Variables]
  [P]
  []
  [phif]
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
    value = '0.0 ${gravity} 0.0'
    variable = phif
    material_fluid_fraction_derivative = dM4dphif
    material_pressure_derivative = dM4dP
  []
  [L2]
    type = CoupledL2Projection
    material_prop = M5
    variable = P
    material_fluid_fraction_derivative = dM5dphif
    material_pressure_derivative = dM5dP
  []
[]

[AuxVariables]
  [init_void]
    order = CONSTANT
    family = MONOMIAL
    [AuxKernel]
      type = MaterialRealAux
      property = void
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
[]

[NEML2]
  input = 'neml2/neml2_material.i'
  cli_args = 'kk_L=${kk_PR} permeability_power=${permeability_power} rhof_nu=${fparse rho_PR/mu_PR}
              rhof2_nu=${fparse rho_PR^2/mu_PR} phif_residual=${phi_L_residual}
              brooks_corey_threshold=${brooks_corey_threshold} capillary_pressure_power=${capillary_pressure_power}'
  [all]
    model = 'model'
    verbose = true
    device = 'cpu'

    moose_input_types = 'VARIABLE'
    moose_inputs = '     phif'
    neml2_inputs = '     forces/phif'

    moose_parameter_types = 'MATERIAL'
    moose_parameters = '     void'
    neml2_parameters = '     phif_max_param'

    moose_output_types = 'MATERIAL MATERIAL MATERIAL MATERIAL   MATERIAL    MATERIAL'
    moose_outputs = '     M3       M4       M5       poro       phis        perm'
    neml2_outputs = '     state/M3 state/M4 state/M5 state/poro state/solid state/perm'

    moose_derivative_types = 'MATERIAL              MATERIAL'
    moose_derivatives = '     dM5dphif              dM4dphif'
    neml2_derivatives = '     state/M5 forces/phif; state/M4 forces/phif'
  []
[]

[Materials]
  [constant]
    type = GenericConstantMaterial
    prop_names = 'M1                M2'
    prop_values = '${fparse rho_PR} ${fparse rho_PR*D_macro}'
  []
  [constant_derivative]
    type = GenericConstantMaterial
    prop_names = 'dM1dphif dM1dP dM2dphif dM2dP dM3dphif dM3dP dM4dP dM5dP'
    prop_values = '0.0     0.0   0.0     0.0    0.0     0.0    0.0   0.0'
  []
  [void_feature]
    type = GenericConstantMaterial
    prop_names = void
    prop_values = ${porosity_feature}
    block = circle
  []
  [void_background]
    type = GenericConstantMaterial
    prop_names = void
    prop_values = ${porosity_background}
    block = non_circle
  []
[]

[Functions]
  [flux_in]
    type = PiecewiseLinear
    x = '0 ${t_ramp}'
    y = '0 ${flux_in}'
  []
  [flux_out]
    type = PiecewiseLinear
    x = '0 ${t_ramp}'
    y = '0 ${flux_out}'
  []
  [dirichlet_in]
    type = PiecewiseLinear
    x = '0 ${t_ramp}'
    y = '0 ${fparse 1-porosity_background}'
  []
[]

[Postprocessors]
  [time]
    type = TimePostprocessor
    execute_on = 'INITIAL TIMESTEP_BEGIN'
  []
[]

[BCs]
  [bottom_inlet]
    type = InfiltrationWake
    boundary = core_bottom
    inlet_flux = flux_in
    outlet_flux = flux_out
    product_fraction = 0.0001
    product_fraction_derivative = 0.0
    solid_fraction = phis
    solid_fraction_derivative = 0.0
    variable = phif
  []
[]

[Executioner]
  type = Transient
  solve_type = 'newton'
  petsc_options_iname = '-pc_type' #-snes_type'
  petsc_options_value = 'lu' # vinewtonrsls'
  automatic_scaling = true

  line_search = none

  nl_abs_tol = 1e-06
  nl_rel_tol = 1e-08
  nl_max_its = 12

  end_time = ${total_time}
  dtmax = '${fparse 200*dt}'

  [TimeStepper]
    type = IterationAdaptiveDT
    dt = ${dt} #s
    optimal_iterations = 6
    iteration_window = 2
    cutback_factor = 0.5
    cutback_factor_at_failure = 0.1
    growth_factor = 1.2
    linear_iteration_ratio = 10000
  []

  #fixed_point_max_its = 10
  #fixed_point_algorithm = picard
  #fixed_point_abs_tol = 1e-06
  #fixed_point_rel_tol = 1e-08
[]

[Outputs]
  exodus = true
  file_base = 'example/core'
  [console]
    type = Console
    execute_postprocessors_on = 'NONE'
  []
  [csv]
    type = CSV
    file_base = 'example/out'
  []
  print_linear_residuals = false
[]
