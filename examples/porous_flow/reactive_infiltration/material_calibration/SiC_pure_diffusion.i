[Models]
    [diffusion_rate]
        type = DiffusionThicknessGrowth
        rate_constant = 1.0
        product_thickness = 'state/delta_P'
        reaction_rate = 'state/delta_P_rate'
    []
    [residual]
        type = ScalarBackwardEulerTimeIntegration
        variable = 'state/delta_P'
    []
    [model]
        type = ComposedModel
        models = 'diffusion_rate residual'
    []
[]