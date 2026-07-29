[GlobalParams]
  temperature = 'T'
  pressure = 'P'
  fluid_fraction = 'phif'
  displacements = 'disp_x disp_y'
  stabilize_strain = true
[]

[Variables]
  [T]
  []
  [P]
  []
  [phif]
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
  ## Pressure ---------------------------------------------------------------
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
    material_temperature_derivative = dM8dT
    material_pressure_derivative = dM8dP
    material_fluid_fraction_derivative = dM8dphif
    material_deformation_gradient_derivative = zeroR2
  []
  [temp_darcy_nograv]
    type = PumaCoupledDarcyFlow
    coupled_variable = P
    material_prop = M9
    variable = T
    material_fluid_fraction_derivative = dM9dphif
    material_pressure_derivative = dM9dP
    material_temperature_derivative = dM9dT
    material_deformation_gradient_derivative = zeroR2
  []
  [temp_gravity]
    type = CoupledAdditiveFlux
    material_prop = M10
    value = '0.0 ${gravity} 0.0'
    variable = T
    material_fluid_fraction_derivative = dM10dphif
    material_pressure_derivative = dM10dP
    material_temperature_derivative = dM10dT
    material_deformation_gradient_derivative = zeroR2
  []
  [reaction_heat]
    type = CoupledMaterialSource
    material_prop = M11
    coefficient = -1
    variable = T
    material_temperature_derivative = dM11dT
    material_fluid_fraction_derivative = dM11dphif
    material_pressure_derivative = dM11dP
    material_deformation_gradient_derivative = dM11dF
  []
  ## solid mechanics ---------------------------------------------------------
  [offDiagStressDiv_x]
    type = MomentumBalanceCoupledJacobian
    component = 0
    variable = disp_x
    material_temperature_derivative = dpk1dT
    material_pressure_derivative = zeroR2
    material_fluid_fraction_derivative = dpk1dphif
  []
  [offDiagStressDiv_y]
    type = MomentumBalanceCoupledJacobian
    component = 1
    variable = disp_y
    material_temperature_derivative = dpk1dT
    material_pressure_derivative = zeroR2
    material_fluid_fraction_derivative = dpk1dphif
  []
[]

[AuxVariables]
  [phif_s]
    order = CONSTANT
    family = MONOMIAL
    [AuxKernel]
      type = MaterialRealAux
      property = phif_s
      execute_on = 'INITIAL TIMESTEP_END'
    []
  []
  [phis]
    order = CONSTANT
    family = MONOMIAL
    [AuxKernel]
      type = MaterialRealAux
      property = phis
      execute_on = 'INITIAL TIMESTEP_END'
    []
  []
  [phip]
    order = CONSTANT
    family = MONOMIAL
    [AuxKernel]
      type = MaterialRealAux
      property = phip
      execute_on = 'INITIAL TIMESTEP_END'
    []
  []
  [porosity]
    order = CONSTANT
    family = MONOMIAL
    [AuxKernel]
      type = MaterialRealAux
      property = phif_max
      execute_on = 'INITIAL TIMESTEP_END'
    []
  []
  [nonliquid]
    order = CONSTANT
    family = MONOMIAL
    [AuxKernel]
      type = MaterialRealAux
      property = nonliquid
      execute_on = 'INITIAL TIMESTEP_END'
    []
  []
  [dummy]
  []
  [Jt_p]
    order = CONSTANT
    family = MONOMIAL
    [AuxKernel]
      type = MaterialRealAux
      property = Jt_p
      execute_on = 'INITIAL TIMESTEP_END'
    []
  []
  [Jt_sfs]
    order = CONSTANT
    family = MONOMIAL
    [AuxKernel]
      type = MaterialRealAux
      property = Jt_sfs
      execute_on = 'INITIAL TIMESTEP_END'
    []
  []
  [Jt]
    order = CONSTANT
    family = MONOMIAL
    [AuxKernel]
      type = MaterialRealAux
      property = Jt
      execute_on = 'INITIAL TIMESTEP_END'
    []
  []
  [Pc]
    order = CONSTANT
    family = MONOMIAL
    [AuxKernel]
      type = MaterialRealAux
      property = Pc
      execute_on = 'INITIAL TIMESTEP_END'
    []
  []
  [rve_sh]
    order = CONSTANT
    family = MONOMIAL
    [AuxKernel]
      type = MaterialRealAux
      property = rve_sh
      execute_on = 'INITIAL TIMESTEP_END'
    []
  []
  [saturation]
    order = CONSTANT
    family = MONOMIAL
    [AuxKernel]
      type = MaterialRealAux
      property = Seff
      execute_on = 'INITIAL TIMESTEP_END'
    []
  []
  [phiv]
    order = CONSTANT
    family = MONOMIAL
    [AuxKernel]
      type = MaterialRealAux
      property = phiv
      execute_on = 'INITIAL TIMESTEP_END'
    []
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
  input = 'neml2/aoti_solidification/model_aoti.i'
  [all]
    model = 'model'
    verbose = true
    device = 'cpu'

    derivatives = 'M1 deformation_gradient dM1dF;
                   M3 T dM3dT; M4 T dM4dT; M5 T dM5dT;
                   M6 T dM6dT; M6 phif dM6dphif;
                   M7 T dM7dT; M7 phif dM7dphif; M7 deformation_gradient dM7dF;
                   M8 T dM8dT; M8 phif dM8dphif;
                   M9 T dM9dT; M10 T dM10dT;
                   M11 T dM11dT; M11 phif dM11dphif; M11 deformation_gradient dM11dF;
                   pk1_stress T dpk1dT; pk1_stress phif dpk1dphif;
                   pk1_stress deformation_gradient pk1_jacobian;
                   M3 phif dM3dphif; M4 phif dM4dphif; M5 phif dM5dphif;
                   M9 phif dM9dphif; M10 phif dM10dphif;
                   nonliquid phif dnonliquiddphif'

    initialize_outputs = '      phif_s'
    initialize_output_values = 'solidified_fluid'
  []
[]

[Materials]
  [zeroR2]
    type = GenericConstantRankTwoTensor
    tensor_name = 'zeroR2'
    tensor_values = '0 0 0 0 0 0 0 0 0'
  []
  [parameters]
    type = GenericConstantMaterial
    prop_names = 'solidified_fluid'
    prop_values = '0.0'
  []
  [init_mat]
    type = GenericConstantMaterial
    prop_names = 'M2'
    prop_values = '${fparse D_macro*rho_Si}'
  []
  [zero_mat_derivative]
    type = GenericConstantMaterial
    prop_names = ' dM1dT dM1dphif dM2dT dM2dphif'
    prop_values = '0.0   0.0      0.0   0.0'
  []
  [pressure_nodependence_mat_prop]
    type = GenericConstantMaterial
    prop_names = ' dM1dP dM2dP dM3dP dM4dP dM5dP dM6dP dM7dP dM8dP dM9dP dM10dP dM11dP'
    prop_values = '0.0   0.0   0.0   0.0   0.0   0.0   0.0   0.0   0.0   0.0    0.0'
  []
  [convection]
    type = ADParsedMaterial
    property_name = q_boundary
    expression = 'htc*(T - if(time<t_ramp, T0 + dTdt*time, T0 + dTdt*t_ramp))'
    coupled_variables = T
    constant_names = 'htc t_ramp dTdt  T0'
    constant_expressions = '${htc} ${t_ramp} ${dTdt} ${T0}'
    postprocessor_names = 'time'
    boundary = 'top' # 'left right top bottom'
  []
[]

[Postprocessors]
  [time]
    type = TimePostprocessor
    execute_on = 'INITIAL TIMESTEP_BEGIN'
  []
[]

[Functions]
  [flux_out]
    type = PiecewiseLinear
    x = '0 ${t_ramp}'
    y = '0 ${flux_out}'
  []
[]

[BCs]
  [boundary]
    type = ADMatNeumannBC
    boundary_material = q_boundary
    boundary = 'top' # 'left right top bottom'
    variable = T
    value = -1
  []
  # [open_BC]
  #  type = InfiltrationWake
  #  boundary = 'left right top bottom'
  #  inlet_flux = 0.0
  #  outlet_flux = flux_out
  #  product_fraction = nonliquid
  #  product_fraction_derivative = dnonliquiddphif
  #  solid_fraction = 0
  #  solid_fraction_derivative = 0
  #  variable = phif
  #  sharpness = 100
  #  no_flux_fraction_transition = 0.001
  # []
[]

[Executioner]
  type = Transient
  solve_type = NEWTON

  petsc_options = '-ksp_converged_reason'
  petsc_options_iname = '-pc_type -snes_type' # -pc_factor_shift_type' #-snes_type'
  petsc_options_value = 'lu vinewtonrsls' # NONZERO' # vinewtonrsls'

  automatic_scaling = true
  # residual_and_jacobian_together = 'true'

  line_search = none

  nl_abs_tol = 1e-05
  nl_rel_tol = 1e-07
  nl_max_its = 10

  l_max_its = 100
  l_tol = 1e-06

  end_time = ${total_time}
  dtmax = '${fparse 100*dt}'

  [TimeStepper]
    type = IterationAdaptiveDT
    dt = ${dt} #s
    optimal_iterations = 7
    iteration_window = 2
    cutback_factor = 0.2
    cutback_factor_at_failure = 0.5
    growth_factor = 1.2
    linear_iteration_ratio = 1000
  []

  [Predictor]
    type = SimplePredictor
    scale = 1.0
    skip_after_failed_timestep = true
  []
[]

[Outputs]
  exodus = true
  file_base = 'solidification'
  [console]
    type = Console
    execute_postprocessors_on = 'NONE'
  []
  [csv]
    type = CSV
    file_base = 'solidification'
  []
  print_linear_residuals = false
[]
