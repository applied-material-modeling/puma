[Models]
    ## solid mechanics ----------------------------------------------------------
    [Jacobian]
        type = R2Determinant
        input = 'forces/F'
        determinant = 'state/J'
    []
    [M1]
        type = ScalarLinearCombination
        coefficients = "${rho_f}"
        from_var = 'state/J'
        to_var = 'state/M1'
    []
    [fluid_JF]
        type = ScalarParameterToState
        from = 1.0
        to = 'state/Jf'
    []
    # thermal add-on ###########
    [Fthermal]
        type = ThermalDeformationJacobian
        temperature = 'forces/T'
        reference_temperature = ${Tref}
        CTE = ${therm_expansion}
        jacobian = 'state/Jt'
    []
    [V]
        type = ScalarParameterToState
        from = 1.0
        to = 'state/V'
    []
    [Jvolume]
        type = ScalarLinearCombination
        from_var = 'state/V'
        coefficients = '1.0'
        coefficient_as_parameter = true
        to_var = 'state/Jv'
    []
    # -----------------------------
    [Jtotal]
        type = ScalarMultiplication
        from_var = 'state/Jt state/Jf state/Jv'
        to_var = 'state/Jtotal'
    []
    [totalF]
        type = VolumeAdjustDeformationGradient
        input = 'forces/F'
        output = 'state/Fe'
        jacobian = 'state/Jtotal'
    []
    ########
    [green_strain]
        type = GreenLagrangeStrain
        deformation_gradient = 'state/Fe'
        strain = 'state/Ee'
    []
    [S_pk2]
        type = LinearIsotropicElasticity
        strain = 'state/Ee'
        stress = 'state/pk2_SR2'
        coefficients = '1000 0.3'
        coefficient_types = 'YOUNGS_MODULUS POISSONS_RATIO'
    []
    [S_pk2_R2]
        type = SR2toR2
        input = 'state/pk2_SR2'
        output = 'state/pk2'
    []
    [S_pk1]
        type = R2Multiplication
        A = 'forces/F'
        B = 'state/pk2'
        to = 'state/pk1'
        invert_B = false
    []
    [model_pk1]
        type = ComposedModel
        models = 'V fluid_JF Jtotal Jvolume
                  Fthermal totalF green_strain S_pk2 S_pk2_R2 S_pk1'
        additional_outputs = 'state/Jf state/Jt state/Jv state/pk2'
    []
    [model_sm]
        type = ComposedModel
        models = 'Jacobian M1 model_pk1'
    []
    #################################################################
    ## porous flow -----------------------------------------------------------------
    [phif_max]
        type = ScalarParameterToState
        from = 1.0
        to = 'state/phif_max'
    []
    [permeability]
        type = PowerLawPermeability
        reference_permeability = ${kk_L}
        reference_porosity = 0.9
        exponent = ${permeability_power}
        porosity = 'state/phif_max'
        permeability = 'state/perm'
    []
    [M3]
        type = ScalarLinearCombination
        coefficients = "${rhof_nu}"
        from_var = 'state/perm'
        to_var = 'state/M3'
    []
    [M8]
        type = ScalarLinearCombination
        coefficients = "${hf_rhof_nu}"
        from_var = 'state/perm'
        to_var = 'state/M8'
    []
    [M4]
        type = ScalarMultiplication
        coefficient = "${rhof2_nu}"
        from_var = 'state/perm state/Seff'
        to_var = 'state/M4'
    []
    [M9]
        type = ScalarLinearCombination
        coefficients = "${hf_rhof2_nu}"
        from_var = 'state/perm state/Seff'
        to_var = 'state/M9'
    []
    [effective_saturation]
        type = EffectiveSaturationSecondOrder
        residual_saturation = 0.0
        fluid_fraction = 'forces/phif'
        max_fraction = 'state/phif_max'
        effective_saturation = 'state/Seff'
    []
    [capillary_pressure]
        type = BrooksCoreyCapillaryPressure
        threshold_pressure = '${brooks_corey_threshold}'
        exponent = '${capillary_pressure_power}'
        effective_saturation = 'state/Seff'
        capillary_pressure = 'state/Pc'
        log_extension = true
        transition_saturation = 0.001
    []
    [M5]
        type = ScalarLinearCombination
        from_var = 'state/Pc'
        to_var = 'state/M5'
        coefficients = '-1.0'
    []
    [empty_porosity]
        type = ScalarLinearCombination
        from_var = 'state/phif_max forces/phif'
        to_var = 'state/poro'
        coefficients = '1.0 -1.0'
    []
    [solid_fraction]
        type = ScalarLinearCombination
        from_var = 'state/phif_max'
        to_var = 'state/solid'
        constant_coefficient = 1.0
        coefficients = '-1.0'
    []
    [model_porousflow]
        type = ComposedModel
        models = 'solid_fraction empty_porosity phif_max permeability
                    effective_saturation capillary_pressure M3 M4 M5 M8 M9'
        additional_outputs = 'state/perm'
    []
    [model]
        type = ComposedModel
        models = 'model_sm model_porousflow'
    []
[]