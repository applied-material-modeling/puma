############### Input ################

##Simulation parameters
# dt = 0.04 #s
# total_time = 1800 #s
# 
# num_el_x = 51
# num_el_y = 101
# L = 0.1
# num_file_data = 5151
# C_ratio = 0.2
# 
# flux_in = 0.005 # volume fraction
# flux_out = 0.1
# t_ramp = 500
# t_heat = 200
# 
# dTdt = 1 # deg per s
# 
# # heat enthalpy [g-cm2/s2]
# hf = 1e1
# 
# #boundary conditions
# htc = 2000 #g / s3-K
# 
# E = 10000000
# nu = 0.3
# therm_expansion = 0.0 # 1e-6
# T0 = 300
# 
# # Molar Mass # g mol-1
# M_Si = 28.085
# M_SiC = 40.11
# M_C = 12.011
# 
# # denisty # g cm-3
# rho_Si = 2.57 # density at liquid state
# rho_SiC = 3.21
# rho_C = 2.26
# 
# # material property
# D_LP = 9.5e-6 # cm2 s-1
# l_c = 0.1 # cm
# h_c = 0.0076 # cm
# K_nucl_growth = 1.2e-15 # cm s-1
# reactivity_upbound = 0.1
# reactivity_lowbound = 0.005
# 
# brooks_corey_threshold = 0.5e5 # 0.5e5 #dyn/cm2
# capillary_pressure_power = 10
# phi_L_residual = 0.0
# 
# permeability_power = 20.0
# 
# # liquid viscosity
# # liquid silicon viscosity in egs -s
# mu_Si = 0.01 # g cm-1 s-1
# 
# # solid reference permeability
# perm_ref = 1e-8
# 
# # chemical reaction constant
# k_C = 1.0
# k_SiC = 1.0
# 
# cp_Si = 0.7e7 # erg/g-K
# cp_SiC = 0.5e7 # erg/g-K
# cp_C = 1500e4 # erg/g-K
# 
# kappa_C = 3e7 # erg cm-1 s-1 K
# kappa_SiC = 3e7 # erg cm-1 s-1 K
# kappa_Si = 1.4e7 # erg cm-1 s-1
# 
# # macroscopic property
# D_macro = 0.0007 #cm2 s-1
# D_macro_high = 0.04 # cm2 s-1
# D_macro_low = 0.0007 # cm2 s-1
# 
# transition_saturation_front = 0.75
# transition_saturation_back = 0.25
# transition_saturation_back_start = 0.65
# 
# gravity = 980.665

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
    material_fluid_fraction_derivative = dpk1dphif
    material_pressure_derivative = zeroR2
    material_temperature_derivative = dpk1dT
  []
  [offDiagStressDiv_y]
    type = MomentumBalanceCoupledJacobian
    component = 1
    variable = disp_y
    material_fluid_fraction_derivative = dpk1dphif
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
  [phif_max]
    order = CONSTANT
    family = MONOMIAL
    [AuxKernel]
      type = MaterialRealAux
      property = phif_max
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
  [Jt]
    order = CONSTANT
    family = MONOMIAL
    [AuxKernel]
      type = MaterialRealAux
      property = Jt
      execute_on = 'INITIAL TIMESTEP_END'
    []
  []
  [phi0SiC_noreact]
    order = CONSTANT
    family = MONOMIAL
    [AuxKernel]
      type = MaterialRealAux
      property = phi0SiC_noreact
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
  [reaction_rate]
    order = CONSTANT
    family = MONOMIAL
    [AuxKernel]
      type = MaterialRealAux
      property = react_new
      execute_on = 'INITIAL TIMESTEP_END'
    []
  []
[]

[NEML2]
  input = 'neml2/aoti_reactive/model_aoti.i'
  [all]
    model = 'model'
    device = 'cpu'

    derivatives = 'M1 deformation_gradient dM1dF;
                   M2 phif dM2dphif; M3 phif dM3dphif; M4 phif dM4dphif;
                   M5 phif dM5dphif; M6 phif dM6dphif;
                   M7 phif dM7dphif; M7 deformation_gradient dM7dF; M8 phif dM8dphif;
                   neml2_pk1 T dpk1dT; neml2_pk1 phif dpk1dphif;
                   pk2_stress deformation_gradient dpk2_dF;
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
    prop_values = '0.00001 '
  []
  [zeroR2]
    type = GenericConstantRankTwoTensor
    tensor_name = 'zeroR2'
    tensor_values = '0 0 0 0 0 0 0 0 0'
  []
  [stress]
    type = ComputeLagrangianStressCustomPK2
    custom_pk2_stress = 'pk2_stress'
    custom_pk2_jacobian = 'dpk2_dF'
    large_kinematics = true
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
    x = '0 ${t_heat} ${t_ramp}'
    y = '0 0 ${flux_in}'
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
  reuse_preconditioner = true
  reuse_preconditioner_max_linear_its = 25

  line_search = none
  l_max_its = 100

  nl_abs_tol = 1e-5
  nl_rel_tol = 1e-7
  nl_max_its = 10

  end_time = ${total_time}
  dtmax = '${fparse 10000*dt}'

  [TimeStepper]
    type = IterationAdaptiveDT
    dt = ${dt} #s
    optimal_iterations = 8
    iteration_window = 2
    cutback_factor = 0.5
    cutback_factor_at_failure = 0.2
    growth_factor = 2.0
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
  file_base = 'infiltration'
  [console]
    type = Console
    execute_postprocessors_on = 'NONE'
  []
  [csv]
    type = CSV
    file_base = 'infiltration'
  []
  print_linear_residuals = false
[]
