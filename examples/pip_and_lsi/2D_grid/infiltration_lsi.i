
## Calculations
D_bar = '${fparse D_LP/(l_c)}'

omega_C = '${fparse M_C/rho_C}'
omega_Si = '${fparse M_Si/rho_Si}'
omega_SiC = '${fparse M_SiC/rho_SiC}'

oCm1 = '${fparse 1/omega_C}'
oSiCm1 = '${fparse 1/omega_SiC}'

chem_ratio = '${fparse k_SiC/k_C}'

new_scale = '${fparse (transition_saturation_back-transition_saturation_back_start)/2}'

[GlobalParams]
  displacements = 'disp_x disp_y'
  pressure = P
  fluid_fraction = phif
  temperature = T
  stabilize_strain = true
[]

[Variables]
  [P]
  []
  [phif]
  []
  [T]
  []
[]

[Kernels]
  ## Fluid flow ---------------------------------------------------------
  [time]
    type = PumaCoupledTimeDerivative
    material_prop = M1
    variable = phif
    material_fluid_fraction_derivative = dM1dphif
    material_pressure_derivative = dM1dP
    material_temperature_derivative = dM1dT
    material_deformation_gradient_derivative = dM1dF
  []
  [diffusion]
    type = PumaCoupledDiffusion
    material_prop = M2
    variable = phif
    material_fluid_fraction_derivative = dM2dphif
    material_pressure_derivative = dM2dP
    material_temperature_derivative = dM2dT
    material_deformation_gradient_derivative = zeroR2
  []
  [darcy_nograv]
    type = PumaCoupledDarcyFlow
    coupled_variable = P
    material_prop = M3
    variable = phif
    material_fluid_fraction_derivative = dM3dphif
    material_pressure_derivative = dM3dP
    material_temperature_derivative = dM3dT
    material_deformation_gradient_derivative = zeroR2
  []
  [gravity]
    type = CoupledAdditiveFlux
    material_prop = M4
    value = '0.0 ${gravity} 0.0'
    variable = phif
    material_fluid_fraction_derivative = dM4dphif
    material_pressure_derivative = dM4dP
    material_temperature_derivative = dM4dT
    material_deformation_gradient_derivative = zeroR2
  []
  [source]
    type = CoupledMaterialSource
    material_prop = M5
    coefficient = -1
    variable = phif
    material_fluid_fraction_derivative = dM5dphif
    material_pressure_derivative = dM5dP
    material_temperature_derivative = dM5dT
    material_deformation_gradient_derivative = zeroR2
  []
  [L2]
    type = CoupledL2Projection
    material_prop = M6
    variable = P
    material_fluid_fraction_derivative = dM6dphif
    material_pressure_derivative = dM6dP
    material_temperature_derivative = dM6dT
    material_deformation_gradient_derivative = zeroR2
  []
  ## Temperature flow ---------------------------------------------------------
  [temp_time]
    type = PumaCoupledTimeDerivative
    material_prop = M7
    variable = T
    material_fluid_fraction_derivative = dM7dphif
    material_pressure_derivative = dM7dP
    material_temperature_derivative = dM7dT
    material_deformation_gradient_derivative = dM7dF
  []
  [temp_diffusion]
    type = PumaCoupledDiffusion
    material_prop = M8
    variable = T
    material_fluid_fraction_derivative = dM8dphif
    material_pressure_derivative = dM8dP
    material_temperature_derivative = dM8dT
    material_deformation_gradient_derivative = zeroR2
  []
  ##
  ## solid mechanics ---------------------------------------------------------
  [offDiagStressDiv_x]
    type = MomentumBalanceCoupledJacobian
    component = 0
    variable = disp_x
    material_fluid_fraction_derivative = zeroR2
    material_pressure_derivative = zeroR2
    material_temperature_derivative = dpk1dT
  []
  [offDiagStressDiv_y]
    type = MomentumBalanceCoupledJacobian
    component = 1
    variable = disp_y
    material_fluid_fraction_derivative = zeroR2
    material_pressure_derivative = zeroR2
    material_temperature_derivative = dpk1dT
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
  [phiSiC_total]
    order = CONSTANT
    family = MONOMIAL
    [AuxKernel]
      type = MaterialRealAux
      property = phiptotal
      execute_on = 'INITIAL TIMESTEP_END'
    []
  []
  [dummy]
  []
[]

[Bounds]
  [phif_bound]
    type = ConstantBounds
    bound_value = ${phif_min}
    bounded_variable = phif
    variable = dummy
    bound_type = lower
  []
[]

[NEML2]
  input = 'neml2/aoti_reactive_flow/model_aoti.i'
  [all]
    model = 'model'
    verbose = true
    device = 'cpu'

    derivatives = 'M1 deformation_gradient dM1dF; M2 phif dM2dphif; M3 phif dM3dphif;
                   M4 phif dM4dphif; M5 phif dM5dphif; M6 phif dM6dphif;
                   M7 phif dM7dphif; M7 deformation_gradient dM7dF; M8 phif dM8dphif;
                   pk1_stress T dpk1dT; pk1_stress deformation_gradient pk1_jacobian;
                   phis phif dphisdphif; phiptotal phif dphiptotaldphif'

    initialize_outputs = '      phip     phis'
    initialize_output_values = 'phi0_SiC phi0_C'
  []
[]

[Materials]
  [constant_derivative]
    type = GenericConstantMaterial
    prop_names = ' dM1dP    dM1dphif dM1dT    dM2dP dM2dT
                   dM3dP    dM3dT    dM4dP    dM4dT dM6dP dM6dT
                   dM7dP    dM7dT    dM8dP dM8dT
                   dM5dT    dM5dP'
    prop_values = '0.0      0.0      0.0      0.0   0.0
                   0.0      0.0      0.0      0.0   0.0
                   0.0      0.0      0.0      0.0   0.0
                   0.0      0.0'
  []
  [constant_material]
    type = GenericConstantMaterial
    prop_names = 'phi0_SiC '
    prop_values = '0.00001'
  []
  # phinoreact (unreactive SiC+gas-closed-pore fraction) carried in from the
  # pyrolysis handoff (initial_condition_from_exodus_4.i) as phi0SiC_noreact.
  [phinoreact_mat]
    type = ParsedMaterial
    property_name = phinoreact
    material_property_names = 'phi0SiC_noreact'
    expression = 'phi0SiC_noreact'
  []
  [zeroR2]
    type = GenericConstantRankTwoTensor
    tensor_name = 'zeroR2'
    tensor_values = '0 0 0 0 0 0 0 0 0'
  []
  [convection]
    type = ADParsedMaterial
    property_name = q_boundary
    expression = 'htc*(T - if(time<t_heat, T0 + dTdt*time, T0 + dTdt*t_heat))'
    coupled_variables = T
    constant_names = 'htc t_ramp dTdt t_heat T0'
    constant_expressions = '${htc} ${t_ramp} ${dTdt} ${t_heat} ${T0}'
    postprocessor_names = 'time'
    boundary = 'bottom top left right'
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
[]

[Postprocessors]
  [time]
    type = TimePostprocessor
    execute_on = 'INITIAL TIMESTEP_BEGIN'
  []
[]

[BCs]
  [boundary]
    type = ADMatNeumannBC
    boundary_material = q_boundary
    boundary = 'bottom top left right'
    variable = T
    value = -1
  []
  [bottom_inlet]
    type = InfiltrationWake
    boundary = 'bottom top left right'
    inlet_flux = flux_in
    outlet_flux = flux_out
    product_fraction = phiptotal
    product_fraction_derivative = dphiptotaldphif
    solid_fraction = phis
    solid_fraction_derivative = dphisdphif
    variable = phif
    no_flux_fraction_transition = 0.0001
    sharpness = 10
  []
[]

[Executioner]
  type = Transient
  solve_type = 'newton'

  petsc_options = '-ksp_converged_reason'
  petsc_options_iname = '-pc_type -snes_type'
  petsc_options_value = 'lu vinewtonrsls'
  automatic_scaling = true

  residual_and_jacobian_together = 'true'

  line_search = none

  nl_abs_tol = 1e-5
  nl_rel_tol = 1e-7
  nl_max_its = 10

  l_max_its = 100

  end_time = ${total_time}
  dtmax = '${fparse 1000*dt}'

  [TimeStepper]
    type = IterationAdaptiveDT
    dt = ${dt} #s
    optimal_iterations = 8
    iteration_window = 2
    cutback_factor = 0.5
    cutback_factor_at_failure = 0.2
    growth_factor = 1.5
    linear_iteration_ratio = 100
  []

  [Predictor]
    type = SimplePredictor
    scale = 1.0
    skip_after_failed_timestep = true
  []
[]

[Outputs]
  exodus = true
  file_base = '${save_folder}/out_cycle${save_cycle}_${save_type}'
  [console]
    type = Console
    execute_postprocessors_on = 'NONE'
  []
  [csv]
    type = CSV
    file_base = '${save_folder}/out_cycle${save_cycle}_${save_type}'
    execute_on = 'INITIAL FINAL'
    create_final_symlink = true
  []
  print_linear_residuals = false
[]
