omega_Si_s = '${fparse M_Si/rho_Si_s}'
omega_Si_l = '${fparse M_Si/rho_Si}'
delta_Omega = '${fparse omega_Si_s/omega_Si_l-1}'

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
  input = 'neml2/solidification.i'
  cli_args = 'rho_f=${rho_Si} rhof_nu=${fparse rho_Si/mu_Si} rhof2_nu=${fparse rho_Si^2/mu_Si}
                brooks_corey_threshold=${brooks_corey_threshold}
                capillary_pressure_power=${capillary_pressure_power}
                permeability_power=${permeability_power} kk_L=${kk_Si}
                TlmTs=${fparse 1/(Tf-Ts)} mTs_o_TlmTs=${fparse -Ts/(Tf-Ts)} s_TlmTs=${fparse 6/(Tf-Ts)}
                Tl=${Tf} Ts=${Ts} m_solidification_rate=${fparse -solidification_rate}
                o_omegaf=${fparse 1/omega_Si_l} mOfs_Ofl=${fparse -omega_Si_s/omega_Si_l}
                cp_rhofl=${fparse cp_Si*rho_Si} cp_rhofs=${fparse cp_Si_s*rho_Si_s}
                cp_rhos=${fparse cp_C*rho_C} cp_rhop=${fparse cp_SiC*rho_SiC}
                kap_fl=${kappa_Si} kap_fs=${kappa_Si_s} kap_s=${kappa_C} kap_p=${kappa_SiC}
                hf_rhof_onu=${fparse H_latent*rho_Si/mu_Si} hf_rhof2_onu=${fparse H_latent*rho_Si^2/mu_Si}
                mhf_rhof=${fparse -H_latent*rho_Si} mphi_min=${fparse -phif_min}
                Tref=${Tref} therm_expansion=${therm_expansion}
                E=${E} E_fs=${E_Si} E_m=${E_C} nu_fs=${nu_Si} nu_m=${nu_C} delta_Omega=${delta_Omega}'

  [all]
    model = 'model'
    verbose = true
    device = 'cpu'

    moose_input_types = 'POSTPROCESSOR POSTPROCESSOR MATERIAL
                         VARIABLE      VARIABLE      MATERIAL'
    moose_inputs = '     time          time          deformation_gradient
                         phif          T             phif_s'
    neml2_inputs = '     forces/t      old_forces/t  forces/F
                         forces/phif   forces/T      old_state/phif_s'

    moose_output_types = 'MATERIAL      MATERIAL       MATERIAL    MATERIAL    MATERIAL
                          MATERIAL      MATERIAL       MATERIAL    MATERIAL    MATERIAL
                          MATERIAL      MATERIAL       MATERIAL    MATERIAL    MATERIAL
                          MATERIAL      MATERIAL'
    moose_outputs = '     M1            M3             M4          M5          M6
                          M7            M8             M9          M10         M11
                          phif_s        phif_max       perm        pk1_stress  nonliquid
                          Jt            pk2_stress'
    neml2_outputs = '     state/M1      state/M3       state/M4    state/M5    state/M6
                          state/M7      state/M8       state/M9    state/M10   state/M11
                          state/phif_s  state/phif_max state/perm  state/pk1   state/nonliquid
                          state/Jt      state/pk2'

    moose_parameter_types = 'MATERIAL   MATERIAL   MATERIAL MATERIAL'
    moose_parameters = '     phis       phip       V        o_Vref'
    neml2_parameters = '     phis_param phip_param V_param  Jv_c_0'

    moose_derivative_types = '                                               MATERIAL
                                  MATERIAL
                                  MATERIAL
                                  MATERIAL
                                  MATERIAL            MATERIAL
                                  MATERIAL            MATERIAL               MATERIAL
                                  MATERIAL            MATERIAL
                                  MATERIAL
                                  MATERIAL
                                  MATERIAL            MATERIAL               MATERIAL
                                  MATERIAL            MATERIAL               MATERIAL'
    moose_derivatives = '                                                    dM1dF
                                  dM3dT
                                  dM4dT
                                  dM5dT
                                  dM6dT               dM6dphif
                                  dM7dT               dM7dphif               dM7dF
                                  dM8dT               dM8dphif
                                  dM9dT
                                  dM10dT
                                  dM11dT              dM11dphif              dM11dF
                                  dpk1dT              dpk1dphif              pk1_jacobian'
    neml2_derivatives = '                                                    state/M1 forces/F;
                                  state/M3  forces/T;
                                  state/M4  forces/T;
                                  state/M5  forces/T;
                                  state/M6  forces/T; state/M6  forces/phif;
                                  state/M7  forces/T; state/M7  forces/phif; state/M7 forces/F;
                                  state/M8  forces/T; state/M8  forces/phif;
                                  state/M9  forces/T;
                                  state/M10 forces/T;
                                  state/M11 forces/T; state/M11 forces/phif; state/M11 forces/F;
                                  state/pk1 forces/T; state/pk1 forces/phif; state/pk1 forces/F'

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
    prop_values = '0.0            '
  []
  [init_mat]
    type = GenericConstantMaterial
    prop_names = 'M2'
    prop_values = '${fparse D_macro*rho_Si}'
  []
  [zero_mat_derivative]
    type = GenericConstantMaterial
    prop_names = ' dM1dT    dM1dphif  dM2dT           dM2dphif dM3dphif dM4dphif dM5dphif
                   dM9dphif dM10dphif dnonliquiddphif'
    prop_values = '0.0      0.0       0.0             0.0      0.0      0.0      0.0
                   0.0      0.0       0.0'
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
    boundary = 'left right top bottom'
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
    boundary = 'left right top bottom'
    variable = T
    value = -1
  []
  # [open_BC]
  #   type = InfiltrationWake
  #   boundary = 'left right top bottom'
  #   inlet_flux = 0.0
  #   outlet_flux = flux_out
  #   product_fraction = nonliquid
  #   product_fraction_derivative = dnonliquiddphif
  #   solid_fraction = 0
  #   solid_fraction_derivative = 0
  #   variable = phif
  #   sharpness = 100
  #   no_flux_fraction_transition = 0.001
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
  file_base = '${save_folder}/out_cycle${save_cycle}_${save_type}'
  [console]
    type = Console
    execute_postprocessors_on = 'NONE'
  []
  [csv]
    type = CSV
    file_base = '${save_folder}/out_cycle${save_cycle}_${save_type}'
  []
  print_linear_residuals = false
[]
