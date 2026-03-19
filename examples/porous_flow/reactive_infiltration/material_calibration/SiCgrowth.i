[Models]
    [crit_delta]
        type = ScalarConstantParameter
        value = 1.0
    []
    [nucleation_rate]
        type = NucleationThicknessGrowth
        growth_constant = 1.0
        closure_thickness = 'crit_delta'
        fraction_transform = 1.0
        product_thickness = 'state/delta_P'
        reaction_rate = 'state/rate_nucleation'
        order_type = 'FIRST'
    []
    [diffusion_rate]
        type = DiffusionThicknessGrowth
        rate_constant = 1.0
        product_thickness = 'state/delta_P'
        reaction_rate = 'state/rate_diffusion'
    []
    [o_dP]
        type = ScalarMultiplication
        from_var = 'state/delta_P'
        to_var = 'state/o_dP'
        reciprocal = true
    []
    [ratio]
        type = ScalarLinearCombination
        from_var = 'state/o_dP'
        to_var = 'state/dPc_dP'
        coefficients = 'crit_delta'
        coefficient_as_parameter = true
    []
    [switch_off_diff]
        type = HermiteSmoothStep
        argument = 'state/dPc_dP'
        value = 'state/Hdiff'
        lower_bound = 1.0
        upper_bound = 1.1
        complement = true
    []
    [switch_off_nucl]
        type = ScalarLinearCombination
        from_var = 'state/Hdiff'
        to_var = 'state/Hnucl'
        coefficients = -1.0
        constant_coefficient = 1.0
    []
    [diffusion_rate_switch]
        type = ScalarMultiplication
        from_var = 'state/rate_diffusion state/Hdiff'
        to_var = 'state/rate_diffusion_switch'
    []
    [nucleation_rate_switch]
        type = ScalarMultiplication
        from_var = 'state/rate_nucleation state/Hnucl'
        to_var = 'state/rate_nucleation_switch'
    []
    [total_rate]
        type = ScalarLinearCombination
        from_var = 'state/rate_nucleation_switch state/rate_diffusion_switch'
        to_var = 'state/delta_P_rate'
    []
    [residual]
        type = ScalarBackwardEulerTimeIntegration
        variable = 'state/delta_P'
    []
    [model]
        type = ComposedModel
        models = 'crit_delta nucleation_rate diffusion_rate ratio o_dP
           switch_off_diff diffusion_rate_switch
           switch_off_nucl nucleation_rate_switch
           total_rate residual'
        # models = 'crit_delta nucleation_rate diffusion_rate total_rate residual'
    []
[]