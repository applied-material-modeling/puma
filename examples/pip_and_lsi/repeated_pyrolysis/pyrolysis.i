############### Calculations ################
# Simulation parameters
dt = 5

t_ramp = '${fparse (Tmax-T0)/dTdt*60}' #s
theat = '${fparse t_ramp+t_hold*3600}'
dTdtcool = '${fparse (Tmax-T0)/(tcool*3600)}' #Ks-1
total_time = '${fparse theat + tcool*3600}'

[GlobalParams]
    displacements = 'disp_x disp_y'
    temperature = 'T'
[]

[Mesh]
    [mesh0]
        type = FileMeshGenerator
        file = '${meshfile}'
    []
    [rollingnode]
        type = BoundingBoxNodeSetGenerator
        bottom_left = '${fparse xroll-0.00000001} ${fparse yroll-0.00000001} ${fparse zroll-0.00000001}'
        input = mesh0
        new_boundary = 'roll'
        top_right = '${fparse xroll+0.00000001} ${fparse yroll+0.00000001} ${fparse zroll+0.00000001}'
    []
    [fixnode]
        type = BoundingBoxNodeSetGenerator
        bottom_left = '${fparse xfix-0.00000001} ${fparse yfix-0.00000001} ${fparse zfix-0.00000001}'
        input = rollingnode
        new_boundary = 'fix'
        top_right = '${fparse xfix+0.00000001} ${fparse yfix+0.00000001} ${fparse zfix+0.00000001}'
    []
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
[]

[Physics]
    [SolidMechanics]
        [QuasiStatic]
            [sample]
                new_system = true
                add_variables = true
                strain = FINITE
                formulation = TOTAL
                volumetric_locking_correction = true
                generate_output = "pk1_stress_xx pk1_stress_yy pk1_stress_zz 
                                    pk1_stress_xy pk1_stress_xz pk1_stress_yz vonmises_pk1_stress
                                    max_principal_pk1_stress"
            []
        []
    []
[]

[NEML2]
    input = 'neml2/neml2_material.i'
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
                              MATERIAL'
        moose_outputs = '     phiop           wb         ws         wgcp         pk1_stress
                              phib            phip       phis       phigcp       alpha
                              M3              M2         M1         Jt           Jv
                              V'
        neml2_outputs = '     state/phiop     state/wb   state/ws   state/wgcp   state/pk1
                              state/phib      state/phip state/phis state/phigcp state/alpha
                              state/M3        state/M2   state/M1   state/Jt     state/Jv
                              state/V'

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
        prop_names = 'alpha0 phiop0'
        prop_values = '0.0 0.0'
    []
    [zeroR2]
        type = GenericConstantRankTwoTensor
        tensor_name = 'zeroR2'
        tensor_values = '0 0 0 0 0 0 0 0 0'
    []
    [convection]
        type = ADParsedMaterial
        property_name = q_boundary
        expression = 'htc*(T - if(time<t_ramp,(dTdt/60)*t_ramp,(if(time<theat, Tmax, Tmax-dTdtcool*tcool*3600))))'
        coupled_variables = T
        constant_names = 'htc t_ramp dTdt theat Tmax dTdtcool tcool'
        constant_expressions = '${htc} ${t_ramp} ${dTdt} ${theat} ${Tmax} ${dTdtcool} ${tcool}'
        postprocessor_names = 'time'
        boundary = 'open'
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

[Functions]
    [temp_profile]
        type = ParsedFunction
        expression = 'if(t<t_ramp,(dTdt/60)*t_ramp,(if(t<theat, Tmax, Tmax-dTdtcool*tcool*3600)))'
        symbol_names = 't_ramp dTdt theat Tmax dTdtcool tcool'
        symbol_values = '${t_ramp} ${dTdt} ${theat} ${Tmax} ${dTdtcool} ${tcool}'
    []
[]

[BCs]
    [boundary]
        type = ADMatNeumannBC
        boundary_material = q_boundary
        boundary = 'open'
        variable = T
        value = -1
    []
    [roller_bot]
        type = DirichletBC
        boundary = 'roll'
        value = 0.0
        variable = disp_y
    []
    [fix_point_x]
        type = DirichletBC
        boundary = 'fix'
        value = 0.0
        variable = disp_x
    []
    [fix_point_y]
        type = DirichletBC
        boundary = 'fix'
        value = 0.0
        variable = disp_y
    []
[]

[Executioner]
    type = Transient
    solve_type = 'newton'
    petsc_options_iname = '-pc_type -snes_type'
    petsc_options_value = 'lu vinewtonrsls'
    automatic_scaling = true

    nl_abs_tol = 1e-8

    end_time = ${total_time}
    dtmax = '${fparse 100*dt}'

    [TimeStepper]
        type = IterationAdaptiveDT
        dt = ${dt} #s
        optimal_iterations = 7
        iteration_window = 2
        cutback_factor = 0.5
        cutback_factor_at_failure = 0.1
        growth_factor = 1.2
        linear_iteration_ratio = 10000
    []
[]

[Outputs]
    exodus = true
    file_base = '${save_folder}/out_cycle${cycle}'
    # console = true
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
        file_base = '${save_folder}/out_cycle${cycle}'
        execute_on = 'FINAL'
        create_final_symlink = true
    []
    print_linear_residuals = false
[]