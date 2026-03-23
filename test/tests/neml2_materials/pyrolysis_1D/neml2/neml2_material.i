[Solvers]
    [newton]
        type = Newton
        verbose = false
        linear_solver = 'lu'
    []
    [lu]
        type = DenseLU
    []
[]

[EquationSystems]
    [eq_sys]
        type = NonlinearSystem
        model = 'reaction'
    []
[]

[Models]
    [reaction_coef]
        type = ArrheniusParameter
        reference_value = '${A}'
        activation_energy = '${Ea}'
        ideal_gas_constant = '${R}'
        temperature = 'forces/T'
        parameter = 'state/k'
    []
    [reaction_rate]
        type = ContractingGeometry
        reaction_coef = 'reaction_coef'
        reaction_order = '${order}'
        conversion_degree = 'state/alpha'
        reaction_rate = 'state/alpha_rate'
    []
    [reaction_ode]
        type = ScalarBackwardEulerTimeIntegration
        variable = 'state/alpha'
    []
    [reaction]
        type = ComposedModel
        models = 'reaction_rate reaction_ode'
    []
    [solve_reaction]
        type = ImplicitUpdate
        equation_system = 'eq_sys'
        solver = 'newton'
    []
    [binder_rate]
        type = ScalarLinearCombination
        from_var = 'state/alpha_rate'
        coefficients = 0.0
        coefficient_as_parameter = true
        to_var = 'state/wb_rate'
    []
    [char_rate]
        type = ScalarLinearCombination
        from_var = 'state/wb_rate'
        coefficients = '${mY}'
        to_var = 'state/ws_rate'
    []
    [gas_rate]
        type = ScalarLinearCombination
        from_var = 'state/wb_rate state/ws_rate'
        coefficients = '-${mu} -${mu}'
        to_var = 'state/wgcp_rate'
    []
    [open_pore_rate]
        type = ScalarLinearCombination
        from_var = 'state/wb_rate'
        coefficients = '${mzeta}'
        to_var = 'state/phiop_rate'
    []
    [binder]
        type = ScalarForwardEulerTimeIntegration
        variable = 'state/wb'
    []
    [char]
        type = ScalarForwardEulerTimeIntegration
        variable = 'state/ws'
    []
    [gas]
        type = ScalarForwardEulerTimeIntegration
        variable = 'state/wgcp'
    []
    [open_pore]
        type = ScalarForwardEulerTimeIntegration
        variable = 'state/phiop'
    []
    [model_solver]
        type = ComposedModel
        models = "solve_reaction reaction_rate
                binder_rate char_rate gas_rate open_pore_rate
                binder char gas open_pore"
        additional_outputs = 'state/alpha'
    []
    ################################### POST PROCESS #################################
    #########
    ############### volume fraction ######
    [wp_state]
        type = ScalarParameterToState
        from = 0.0
        to = 'state/wp'
    []
    [V_RVE_post]
        type = EffectiveVolume
        reference_mass = '${Mref}'
        mass_fractions = 'state/wb state/ws state/wp state/wgcp'
        densities = '${rho_b} ${rho_s} ${rho_p} ${rho_g}'
        open_volume_fraction = 'state/phiop'
        composite_volume = 'state/V'
    []
    [phi_b]
        type = ScalarMultiplication
        from_var = 'state/wb state/V'
        coefficient = '${rho_bm1M}'
        to_var = 'state/phib'
        reciprocal = 'false true'
    []
    [phi_s]
        type = ScalarMultiplication
        from_var = 'state/ws state/V'
        coefficient = '${rho_sm1M}'
        to_var = 'state/phis'
        reciprocal = 'false true'
    []
    [phi_p]
        type = ScalarMultiplication
        from_var = 'state/wp state/V'
        coefficient = '${rho_pm1M}'
        to_var = 'state/phip'
        reciprocal = 'false true'
    []
    [phi_gcp]
        type = ScalarMultiplication
        from_var = 'state/wgcp state/V'
        coefficient = '${rho_gm1M}'
        to_var = 'state/phigcp'
        reciprocal = 'false true'
    []
    [phi_out]
        type = ComposedModel
        models = 'V_RVE_post phi_b phi_s phi_p phi_gcp'
        additional_outputs = 'state/V'
    []
    #########
    ######### element properties
    [rho]
        type = ScalarLinearCombination
        coefficients = '${rho_p} ${rho_b} ${rho_s}'
        from_var = 'state/phip state/phib state/phis'
        to_var = 'state/rho'
    []
    [cp]
        type = ScalarLinearCombination
        coefficients = '${cp_p} ${cp_b} ${cp_s}'
        from_var = 'state/wp state/wb state/ws'
        to_var = 'state/cp'
    []
    [rhocp]
        type = ScalarMultiplication
        from_var = 'state/rho state/cp'
        to_var = 'state/M1'
    []
    [K]
        type = ScalarLinearCombination
        coefficients = '${k_p} ${k_b} ${k_s}'
        from_var = 'state/phip state/phib state/phis'
        to_var = 'state/M2'
    []
    [reaction_rate_new]
        type = ContractingGeometry
        reaction_coef = 'reaction_coef'
        reaction_order = '${order}'
        conversion_degree = 'state/alpha'
        reaction_rate = 'state/alpha_rate'
    []
    [heat_generation]
        type = ScalarLinearCombination
        from_var = 'state/alpha_rate'
        coefficients = '${source_coeff}'
        to_var = 'state/M3'
    []
    [elout]
        type = ComposedModel
        models = 'wp_state reaction_rate_new phi_out rho cp rhocp K heat_generation'
        additional_outputs = 'state/phib state/phip state/phis'
    []
    #######################################################################################
    [model]
        type = ComposedModel
        models = 'model_solver elout'
        additional_outputs = 'state/phiop state/alpha state/wb state/ws state/wgcp'
    []
    #######################################################################################
[]