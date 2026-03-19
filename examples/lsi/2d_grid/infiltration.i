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

##
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
      property = reaction_rate
      execute_on = 'INITIAL TIMESTEP_END'
    []
  []
[]

[NEML2]
  input = 'neml2/neml2_reactive_flow.i'
  cli_args = 'kk_L=${perm_ref} permeability_power=${permeability_power} rhof_nu=${fparse rho_Si/mu_Si}
              rhof2_nu=${fparse rho_Si^2/mu_Si} phif_residual=${phi_L_residual} rho_f=${rho_Si}
              brooks_corey_threshold=${brooks_corey_threshold} capillary_pressure_power=${capillary_pressure_power}
              nu=${nu} hf_rhof_nu=${fparse hf*rho_Si/mu_Si}
              oP_oL=${fparse omega_SiC/omega_Si}
              hf_rhof2_nu=${fparse hf*rho_Si^2/mu_Si} therm_expansion=${therm_expansion} Tref=${T0}
              omega_Si=${omega_Si} D=${D_bar} oSiCm1=${oSiCm1} oCm1=${oCm1}
              chem_ratio=${chem_ratio} mchem_P=${fparse -k_SiC}
              rhocp_Si=${fparse rho_Si*cp_Si} rhocp_SiC=${fparse rho_SiC*cp_SiC} rhocp_C=${fparse rho_C*cp_C}
              E=${E} Dmacro=${D_macro}
              K_nucl_growth=${fparse K_nucl_growth*l_c} mhcolc=${fparse -h_c/l_c} omega_SiC=${omega_SiC}
              kap_C=${kappa_C} kap_SiC=${kappa_SiC} kap_Si=${kappa_Si}
              new_scale=${new_scale} transition_saturation_back=${transition_saturation_back}
              transition_saturation_back_start=${transition_saturation_back_start}
              transition_saturation_front=${transition_saturation_front}
              reactivity_upbound=${reactivity_upbound} reactivity_lowbound=${reactivity_lowbound}
              delta_Dscale_front=${fparse D_macro_high-D_macro}
              delta_Dscale_back=${fparse D_macro_low-D_macro}
              '
  [all]
    model = 'model'
    verbose = true
    device = 'cpu'

    moose_input_types = 'POSTPROCESSOR POSTPROCESSOR  VARIABLE    VARIABLE       MATERIAL
                         MATERIAL      MATERIAL       MATERIAL    MATERIAL       '
    moose_inputs = '     time          time           phif        T              deformation_gradient
                         phip          phip           phis        phis           '
    neml2_inputs = '     forces/t      old_forces/t   forces/phif forces/T       forces/F
                         state/phip    old_state/phip state/phis  old_state/phis'

    moose_parameter_types = 'MATERIAL'
    moose_parameters = '     phi0SiC_noreact'
    neml2_parameters = '     phinoreact_param'

    moose_output_types = 'MATERIAL       MATERIAL    MATERIAL       MATERIAL        MATERIAL    MATERIAL
                          MATERIAL       MATERIAL    MATERIAL       MATERIAL        MATERIAL    MATERIAL
                          MATERIAL       MATERIAL    MATERIAL       MATERIAL        MATERIAL    MATERIAL
                          MATERIAL'
    moose_outputs = '     pk1_stress     M1          M7             M3              M4          M6
                          M2             phis        phip           pk2_stress      Pc          reaction_rate
                          M5             M8          phif_max       phiptotal       Jt          Seff
                          phiv'
    neml2_outputs = '     state/pk1      state/M1    state/M7       state/M3        state/M4    state/M6
                          state/M2       state/phis  state/phip     state/pk2       state/Pc    state/react_new
                          state/M5       state/M8    state/phif_max state/phiptotal state/Jt    state/Seff
                          state/phiv'

    moose_derivative_types = '                                                MATERIAL
                                                      MATERIAL
                                                      MATERIAL
                                                      MATERIAL
                                                      MATERIAL
                                                      MATERIAL
                                                      MATERIAL                MATERIAL
                                                      MATERIAL
                                  MATERIAL            MATERIAL                MATERIAL
                                                      MATERIAL                MATERIAL'
    moose_derivatives = '                                                     dM1dF
                                                      dM2dphif
                                                      dM3dphif
                                                      dM4dphif
                                                      dM5dphif
                                                      dM6dphif
                                                      dM7dphif                dM7dF
                                                      dM8dphif
                                  dpk1dT              dpk1dphif               pk1_jacobian
                                                      dphisdphif              dphiptotaldphif'
    neml2_derivatives = '                                                     state/M1 forces/F;
                                                      state/M2  forces/phif;
                                                      state/M3  forces/phif;
                                                      state/M4  forces/phif;
                                                      state/M5  forces/phif;
                                                      state/M6  forces/phif;
                                                      state/M7  forces/phif;  state/M7 forces/F;
                                                      state/M8  forces/phif;
                                  state/pk1 forces/T; state/pk1 forces/phif;  state/pk1 forces/F;
                                                      state/phis forces/phif; state/phiptotal forces/phif'

    initialize_outputs = '      phip     phis   '
    initialize_output_values = 'phi0_SiC phi0_C '
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
