kk_L = 2e-5
permeability_power = 3
rhof_nu = 0.257
rhof2_nu = 0.66049
brooks_corey_threshold = 100000.0
capillary_pressure_power = 3

[Models]
    [permeability]
        type = PowerLawPermeability
        reference_permeability = ${kk_L}
        reference_porosity = 0.9
        exponent = ${permeability_power}
        porosity = 'void'
        permeability = 'perm'
    []
    [effective_saturation]
        type = EffectiveSaturation
        residual_saturation = 0.00001
        fluid_fraction = 'phif'
        max_fraction = 'void'
        effective_saturation = 'Seff'
    []
    [M3]
        type = ScalarLinearCombination
        weights = "${rhof_nu}"
        from = 'perm'
        to = 'M3'
    []
    [M4]
        type = ScalarMultiplication
        scaling = "${rhof2_nu}"
        from = 'perm Seff'
        to = 'M4'
    []
       [capillary_pressure]
        type = BrooksCoreyCapillaryPressure
        threshold_pressure = '${brooks_corey_threshold}'
        exponent = '${capillary_pressure_power}'
        effective_saturation = 'Seff'
        capillary_pressure = 'Pc'
        log_extension = true
        transition_saturation = 0.1
    []
    [M5]
        type = ScalarLinearCombination
        from = 'Pc'
        to = 'M5'
        weights = '-1.0'
    []
    [empty_porosity]
        type = ScalarLinearCombination
        from = 'void phif'
        to = 'poro'
        weights = '1.0 -1.0'
    []
    [solid_fraction]
        type = ScalarLinearCombination
        from = 'void'
        to = 'solid'
        offset = 1.0
        weights = '-1.0'
    []
    [model]
        type = ComposedModel
        models = 'solid_fraction empty_porosity permeability effective_saturation capillary_pressure M3 M4 M5'
        additional_outputs = 'perm'
    []
[]