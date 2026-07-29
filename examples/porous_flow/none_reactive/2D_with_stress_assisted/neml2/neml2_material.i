rho_f = 2.0
swelling_coefficient = 0.1
E = 500
nu = 0.3
kk_L = 2e-5
permeability_power = 3
rhof_nu = 0.2
rhof2_nu = 0.4
brooks_corey_threshold = 0.1
capillary_pressure_power = 3

[Models]
    ## solid mechanics ----------------------------------------------------------
    [Jacobian]
        type = R2Determinant
        input = 'deformation_gradient'
        determinant = 'J'
    []
    [M1]
        type = ScalarLinearCombination
        weights = '${rho_f}'
        from = 'J'
        to = 'M1'
    []
    [fluid_F]
        type = SwellingAndPhaseChangeDeformationJacobian
        phase_fraction = 1.0
        swelling_coefficient = '${swelling_coefficient}'
        reference_volume_difference = 0.0
        jacobian = 'Jf'
        fluid_fraction = 'phif'
    []
    [total_F]
        type = VolumeAdjustDeformationGradient
        input = 'deformation_gradient'
        output = 'Fe'
        jacobian = 'Jf'
    []
    [green_strain]
        type = GreenLagrangeStrain
        deformation_gradient = 'Fe'
        strain = 'Ee'
    []
    [S_pk2]
        type = LinearIsotropicElasticity
        strain = 'Ee'
        stress = 'pk2_SR2'
        coefficients = '${E} ${nu}'
        coefficient_types = 'YOUNGS_MODULUS POISSONS_RATIO'
    []
    [S_pk2_R2]
        type = SR2ToR2
        input = 'pk2_SR2'
        output = 'pk2'
    []
    [S_pk1]
        type = R2Multiplication
        A = 'deformation_gradient'
        B = 'pk2'
        to = 'pk1_stress'
        invert_B = false
    []
    [model_pk1]
        type = ComposedModel
        models = 'fluid_F total_F
         green_strain S_pk2 S_pk2_R2 S_pk1'
    []
    [model_sm]
        type = ComposedModel
        models = 'model_pk1'
    []
    ############################################################
    [stress_induce_pressure]
        type = AdvectiveStress
        coefficient = 10.0 #'${swelling_coefficient}'
        js = 'Jf'
        deformation_gradient = 'deformation_gradient'
        pk1_stress = 'pk1_stress'
        advective_stress = 'Ps'
    []
    [stress_scale]
        type = ScalarMultiplication
        from = 'Ps Seff'
        to = 'SPs'
    []
    [advective_stress]
        type = ComposedModel
        models = 'model_pk1 fluid_F stress_scale stress_induce_pressure'
    []
    #################################################################
    ## porous flow -----------------------------------------------------------------
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
        residual_saturation = 0.0001
        fluid_fraction = 'phif'
        max_fraction = 'void'
        effective_saturation = 'Seff'
    []
    [Seff_cap]
        type = HermiteSmoothStep
        argument = 'phif'
        value = 'Seff_cap'
        lower_bound = '0'
        upper_bound = '0.1'
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
        from = 'Pc SPs'
        to = 'M5'
        weights = '-1.0 1.0'
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
    [model_porousflow]
        type = ComposedModel
        models = 'Jacobian M1 Seff_cap solid_fraction empty_porosity permeability
                    effective_saturation capillary_pressure M3 M4 M5
                    advective_stress'
        additional_outputs = 'perm'
    []
    [model]
        type = ComposedModel
        models = 'model_sm model_porousflow'
    []
[]