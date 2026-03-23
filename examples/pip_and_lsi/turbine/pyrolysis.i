############### Calculations ################
# Simulation parameters
dt = 5

t_ramp = '${fparse (Tmax-T0)/dTdt*60}' #s
theat = '${fparse t_ramp+t_hold*3600}'
dTdtcool = '${fparse (Tmax-T0)/(tcool*3600)}' #Ks-1
total_time = '${fparse theat + tcool*3600}'

[GlobalParams]
    displacements = 'disp_x disp_y disp_z'
    temperature = 'T'
    stabilize_strain = true
[]

[Variables]
    [T]
    []
[]

[Kernels]
    ## Temperature flow ---------------------------------------------------------
    [temp_time]
        type = PumaCoupledTimeDerivative
        material_prop = M1
        variable = T
        material_temperature_derivative = dM1dT
        material_deformation_gradient_derivative = zeroR2
    []
    [temp_diffusion]
        type = PumaCoupledDiffusion
        material_prop = M2
        variable = T
        material_temperature_derivative = dM2dT
        material_deformation_gradient_derivative = zeroR2
    []
    [reaction_heat]
        type = CoupledMaterialSource
        material_prop = M3
        variable = T
        material_temperature_derivative = dM3dT
        material_deformation_gradient_derivative = zeroR2
    []
    ## solid mechanics ---------------------------------------------------------
    [offDiagStressDiv_x]
        type = MomentumBalanceCoupledJacobian
        component = 0
        variable = disp_x
        material_temperature_derivative = dpk1dT
    []
    [offDiagStressDiv_y]
        type = MomentumBalanceCoupledJacobian
        component = 1
        variable = disp_y
        material_temperature_derivative = dpk1dT
    []
    [offDiagStressDiv_z]
        type = MomentumBalanceCoupledJacobian
        component = 2
        variable = disp_z
        material_temperature_derivative = dpk1dT
    []
[]

[NEML2]
    input = 'neml2/pyrolysis.i'
    cli_args = 'rho_s=${rho_s} rho_b=${rho_b} rho_g=${rho_g} rho_p=${rho_p} Mref=${Mref}
                rho_sm1M=${fparse Mref/rho_s} rho_bm1M=${fparse Mref/rho_b}
                rho_gm1M=${fparse Mref/rho_g} rho_pm1M=${fparse Mref/rho_p}
                cp_s=${cp_s} cp_b=${cp_b} cp_g=${cp_g} cp_p=${cp_p}
                k_s=${k_s} k_b=${k_b} k_g=${k_g} k_p=${k_p}
                Ea=${Ea} A=${A} R=${R} mY=${fparse -Y}
                order=${order} source_coeff=${fparse -rho_s*hrp}
                mu=${pyro_mu} mzeta=${fparse -zeta}
                E=${E} g=${g} E=${E} Tref=${Tref}'
    [all]
        model = 'model'
        verbose = true
        device = 'cpu'

        moose_input_types = 'VARIABLE     POSTPROCESSOR POSTPROCESSOR   MATERIAL        MATERIAL
                             MATERIAL     MATERIAL      MATERIAL        MATERIAL        MATERIAL'
        moose_inputs = '     T            time          time            alpha           alpha
                             wb           ws            wgcp            phiop           deformation_gradient'
        neml2_inputs = '     forces/T     forces/t      old_forces/t    old_state/alpha state/alpha
                             old_state/wb old_state/ws  old_state/wgcp  old_state/phiop forces/F'

        moose_parameter_types = 'MATERIAL        MATERIAL        MATERIAL'
        moose_parameters = '     wp              mwb0            o_Vref'
        neml2_parameters = '     wp_state_param  binder_rate_c_0 Jvolume_c_0'

        moose_output_types = 'MATERIAL        MATERIAL   MATERIAL   MATERIAL     MATERIAL
                              MATERIAL        MATERIAL   MATERIAL   MATERIAL     MATERIAL
                              MATERIAL        MATERIAL   MATERIAL   MATERIAL     MATERIAL
                              MATERIAL        MATERIAL'
        moose_outputs = '     phiop           wb         ws         wgcp         pk1_stress
                              phib            phip       phis       phigcp       alpha
                              M3              M2         M1         Jt           Jv
                              V               pk2_stress'
        neml2_outputs = '     state/phiop     state/wb   state/ws   state/wgcp   state/pk1
                              state/phib      state/phip state/phis state/phigcp state/alpha
                              state/M3        state/M2   state/M1   state/Jt     state/Jv
                              state/V         state/pk2'

        moose_derivative_types = 'MATERIAL            MATERIAL              MATERIAL
                                  MATERIAL            MATERIAL'
        moose_derivatives = '     dM3dT               dM1dT                 dM2dT
                                  dpk1dT              pk1_jacobian'
        neml2_derivatives = '     state/M3 forces/T;  state/M1 forces/T;    state/M2 forces/T;
                                  state/pk1 forces/T; state/pk1 forces/F'

        initialize_outputs = '      wb  wgcp  ws  alpha  phiop'
        initialize_output_values = 'wb0 wgcp0 ws0 alpha0 phiop0'
    []
[]

[Materials]
    [init_alpha]
        type = GenericConstantMaterial
        prop_names = 'alpha0'
        prop_values = '0.0'
    []
    [zeroR2]
        type = GenericConstantRankTwoTensor
        tensor_name = 'zeroR2'
        tensor_values = '0 0 0 0 0 0 0 0 0'
    []
    [convection]
        type = ADParsedMaterial
        property_name = q_boundary
        expression = 'htc*(T - if(time<t_ramp,T0+(dTdt/60)*t_ramp,(if(time<theat, Tmax, Tmax-dTdtcool*tcool*3600))))'
        coupled_variables = T
        constant_names = 'htc t_ramp dTdt theat Tmax dTdtcool tcool T0'
        constant_expressions = '${htc} ${t_ramp} ${dTdt} ${theat} ${Tmax} ${dTdtcool} ${tcool} ${T0}'
        postprocessor_names = 'time'
        boundary = 'interface'
    []
[]

[Postprocessors]
    [time]
        type = TimePostprocessor
        execute_on = 'INITIAL TIMESTEP_BEGIN'
    []
[]

[VectorPostprocessors]
    [composition_info]
        type = ElementMaterialSampler
        property = 'phiop phigcp phis phip phib ws wp wb wgcp max_principal_pk1_stress'
        execute_on = 'FINAL'
    []
[]

[AuxVariables]
    [phib]
        order = CONSTANT
        family = MONOMIAL
        [AuxKernel]
            type = MaterialRealAux
            property = phib
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
    [phis]
        order = CONSTANT
        family = MONOMIAL
        [AuxKernel]
            type = MaterialRealAux
            property = phis
            execute_on = 'INITIAL TIMESTEP_END'
        []
    []
    [phigcp]
        order = CONSTANT
        family = MONOMIAL
        [AuxKernel]
            type = MaterialRealAux
            property = phigcp
            execute_on = 'INITIAL TIMESTEP_END'
        []
    []
    [phiop]
        order = CONSTANT
        family = MONOMIAL
        [AuxKernel]
            type = MaterialRealAux
            property = phiop
            execute_on = 'INITIAL TIMESTEP_END'
        []
    []
    [wb]
        order = CONSTANT
        family = MONOMIAL
        [AuxKernel]
            type = MaterialRealAux
            property = wb
            execute_on = 'INITIAL TIMESTEP_END'
        []
    []
    [ws]
        order = CONSTANT
        family = MONOMIAL
        [AuxKernel]
            type = MaterialRealAux
            property = ws
            execute_on = 'INITIAL TIMESTEP_END'
        []
    []
    [wp]
        order = CONSTANT
        family = MONOMIAL
        [AuxKernel]
            type = MaterialRealAux
            property = wp
            execute_on = 'INITIAL TIMESTEP_END'
        []
    []
    [wgcp]
        order = CONSTANT
        family = MONOMIAL
        [AuxKernel]
            type = MaterialRealAux
            property = wgcp
            execute_on = 'INITIAL TIMESTEP_END'
        []
    []
    [o_Vref]
        order = CONSTANT
        family = MONOMIAL
        [AuxKernel]
            type = MaterialRealAux
            property = o_Vref
            execute_on = 'INITIAL TIMESTEP_END'
        []
    []
    [V]
        order = CONSTANT
        family = MONOMIAL
        [AuxKernel]
            type = MaterialRealAux
            property = V
            execute_on = 'INITIAL TIMESTEP_END'
        []
    []
    [heatsource]
        order = CONSTANT
        family = MONOMIAL
        [AuxKernel]
            type = MaterialRealAux
            property = M3
            execute_on = 'INITIAL TIMESTEP_END'
        []
    []
    [alpha]
        order = CONSTANT
        family = MONOMIAL
        [AuxKernel]
            type = MaterialRealAux
            property = alpha
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
    [Jv]
        order = CONSTANT
        family = MONOMIAL
        [AuxKernel]
            type = MaterialRealAux
            property = Jv
            execute_on = 'INITIAL TIMESTEP_END'
        []
    []
[]

[BCs]
    [boundary]
        type = ADMatNeumannBC
        boundary_material = q_boundary
        boundary = 'interface'
        variable = T
        value = -1
    []
[]

[Executioner]
    type = Transient
    solve_type = NEWTON

    petsc_options = '-ksp_converged_reason'
    petsc_options_iname = '-pc_type' # -pc_factor_shift_type' #-snes_type'
    petsc_options_value = 'lu' # NONZERO' # vinewtonrsls'

    reuse_preconditioner = true
    reuse_preconditioner_max_linear_its = 25
    automatic_scaling = true

    residual_and_jacobian_together = 'true'

    line_search = none

    nl_abs_tol = 1e-05
    nl_rel_tol = 1e-07
    nl_max_its = 12

    l_max_its = 100
    l_tol = 1e-06

    end_time = ${total_time}
    dtmax = '${fparse 10*dt}'

    [TimeStepper]
        type = IterationAdaptiveDT
        dt = ${dt} #s
        optimal_iterations = 7
        iteration_window = 2
        cutback_factor = 0.2
        cutback_factor_at_failure = 0.1
        growth_factor = 1.2
        linear_iteration_ratio = 10000
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
        # execute_on = 'NONE'
        # execute_input_on = 'NONE'
        # execute_reporters_on = 'NONE'
        # outlier_variable_norms = False
    []
    [csv]
        type = CSV
        file_base = '${save_folder}/out_cycle${save_cycle}_${save_type}'
        execute_on = 'INITIAL FINAL'
        create_final_symlink = true
    []
    print_linear_residuals = false
[]