rho_f = 2.0
E = 500
nu = 0.3
kk_L = 2e-05
permeability_power = 3
rhof_nu = 0.2
rhof2_nu = 0.4
hf_rhof_nu = 2000000.0
hf_rhof2_nu = 4000000.0
brooks_corey_threshold = 10000.0
capillary_pressure_power = 3
Tref = 300
therm_expansion = 0.0001

[Models]
    ## solid mechanics ----------------------------------------------------------
    [Jacobian]
        type = R2Determinant
        input = 'deformation_gradient'
        determinant = 'J'
    []
    [M1]
        type = ScalarLinearCombination
        weights = "${rho_f}"
        from = 'J'
        to = 'M1'
    []
    [fluid_JF]
        type = SwellingAndPhaseChangeDeformationJacobian
        phase_fraction = 1.0
        swelling_coefficient = 0.01 # '${swelling_coefficient}'
        reference_volume_difference = 0.0
        jacobian = 'Jf'
        fluid_fraction = 'phif'
    []
    # thermal add-on ###########
    [Fthermal]
        type = ThermalDeformationJacobian
        temperature = 'T'
        reference_temperature = ${Tref}
        CTE = ${therm_expansion}
        jacobian = 'Jt'
    []
    # -----------------------------
    [Jtotal]
        type = ScalarMultiplication
        from = 'Jt Jf'
        to = 'Jtotal'
    []
    [totalF]
        type = VolumeAdjustDeformationGradient
        input = 'deformation_gradient'
        output = 'Fe'
        jacobian = 'Jtotal'
    []
    ########
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
        to = 'neml2_pk1'
        invert_B = false
    []
    [model_pk1]
        type = ComposedModel
        models = 'fluid_JF Jtotal
                  Fthermal totalF green_strain S_pk2 S_pk2_R2 S_pk1'
        additional_outputs = 'Jf Jt pk2 neml2_pk1'
    []
    [model_sm]
        type = ComposedModel
        models = 'Jacobian M1 model_pk1'
        additional_outputs = 'pk2 neml2_pk1'
    []
    ############################################################
    [stress_induce_pressure]
        type = AdvectiveStress
        coefficient = 1.0 #'${swelling_coefficient}'
        js = 'Jf'
        jt = 'Jt'
        deformation_gradient = 'deformation_gradient'
        pk1_stress = 'neml2_pk1'
        advective_stress = 'Ps'
    []
    [stress_scale]
        type = ScalarMultiplication
        from = 'Ps Seff_cap'
        to = 'SPs'
    []
    [advective_stress]
        type = ComposedModel
        models = 'stress_scale stress_induce_pressure'
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
    [M3]
        type = ScalarLinearCombination
        weights = "${rhof_nu}"
        from = 'perm'
        to = 'M3'
    []
    [M8]
        type = ScalarLinearCombination
        weights = "${hf_rhof_nu}"
        from = 'perm'
        to = 'M8'
    []
    [M4]
        type = ScalarMultiplication
        scaling = "${rhof2_nu}"
        from = 'perm Seff'
        to = 'M4'
    []
    [M9]
        type = ScalarLinearCombination
        weights = "${hf_rhof2_nu}"
        from = 'perm Seff_cap'
        to = 'M9'
    []
    [effective_saturation]
        type = EffectiveSaturation
        residual_saturation = 0.0
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
        models = 'Seff_cap solid_fraction empty_porosity permeability
                    effective_saturation capillary_pressure M3 M4 M5 M8 M9
                    advective_stress'
        additional_outputs = 'perm'
    []
    [model]
        type = ComposedModel
        models = 'model_sm model_porousflow'
        additional_outputs = 'pk2 neml2_pk1'
    []
[]
