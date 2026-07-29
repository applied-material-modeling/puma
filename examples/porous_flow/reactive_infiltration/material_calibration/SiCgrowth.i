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
        model = 'model'
        unknowns = 'delta_P'
        residuals = 'delta_P_residual'
    []
[]

[Models]
    [crit_delta]
        type = ScalarConstantParameter
        value = 1.0
    []
    [R_l]
        type = ScalarConstantParameter
        value = 1.0
    []
    [R_s]
        type = ScalarConstantParameter
        value = 1.0
    []
    [nucleation_rate]
        type = NucleationThicknessGrowth
        growth_constant = 1.0
        closure_thickness = 'crit_delta'
        fraction_transform = 1.0
        liquid_reactivity = 'R_l'
        solid_reactivity = 'R_s'
        product_thickness = 'delta_P'
        reaction_rate = 'rate_nucleation'
        order_type = 'FIRST'
    []
    [diffusion_rate]
        type = DiffusionThicknessGrowth
        rate_constant = 1.0
        liquid_reactivity = 'R_l'
        solid_reactivity = 'R_s'
        product_thickness = 'delta_P'
        reaction_rate = 'rate_diffusion'
    []
    [o_dP]
        type = ScalarMultiplication
        from = 'delta_P'
        to = 'o_dP'
        reciprocal = true
    []
    [ratio]
        type = ScalarMultiplication
        from = 'o_dP crit_delta'
        to = 'dPc_dP'
    []
    [switch_off_diff]
        type = HermiteSmoothStep
        argument = 'dPc_dP'
        value = 'Hdiff'
        lower_bound = 1.0
        upper_bound = 1.1
        complement = true
    []
    [switch_off_nucl]
        type = ScalarLinearCombination
        from = 'Hdiff'
        to = 'Hnucl'
        weights = -1.0
        offset = 1.0
    []
    [diffusion_rate_switch]
        type = ScalarMultiplication
        from = 'rate_diffusion Hdiff'
        to = 'rate_diffusion_switch'
    []
    [nucleation_rate_switch]
        type = ScalarMultiplication
        from = 'rate_nucleation Hnucl'
        to = 'rate_nucleation_switch'
    []
    [total_rate]
        type = ScalarLinearCombination
        from = 'rate_nucleation_switch rate_diffusion_switch'
        to = 'delta_P_rate'
    []
    [residual]
        type = ScalarBackwardEulerTimeIntegration
        variable = 'delta_P'
        time = 't'
    []
    [model]
        type = ComposedModel
        models = 'crit_delta R_l R_s nucleation_rate diffusion_rate ratio o_dP
           switch_off_diff diffusion_rate_switch
           switch_off_nucl nucleation_rate_switch
           total_rate residual'
    []
[]
