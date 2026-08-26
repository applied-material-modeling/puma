# Bare-name constants (driver overwrites at runtime; values only need to be
# valid floats for compilation). Seeded from lsi/2d_grid references where the
# name matches; swelling_coefficient has no reference match -> plausible float.
rho_f = 1250.0
Tref = 300.0
therm_expansion = 1e-06
swelling_coefficient = 0.0
kk_L = 2e-05
permeability_power = 8
rhof_nu = 125.0
hf_rhof_nu = 0.0
rhof2_nu = 156250.0
hf_rhof2_nu = 0.0
brooks_corey_threshold = 1000.0
capillary_pressure_power = 8

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
        type = ScalarParameterToVariable
        from = 1.0
        to = 'Jf'
    []
    # thermal add-on ###########
    [Fthermal]
        type = ThermalDeformationJacobian
        temperature = 'T'
        reference_temperature = ${Tref}
        CTE = ${therm_expansion}
        jacobian = 'Jtherm'
    []
    # Jv = V * o_Vref (current composite volume / reference volume).
    [Jvolume]
        type = ScalarMultiplication
        from = 'V o_Vref'
        to = 'Jv'
    []
    [Jt]
        type = ScalarMultiplication
        from = 'Jtherm Jv'
        to = 'Jt'
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
        coefficients = '1000 0.3'
        coefficient_types = 'YOUNGS_MODULUS POISSONS_RATIO'
    []
    [S_pk2_R2]
        type = SR2ToR2
        input = 'pk2_SR2'
        output = 'pk2_stress'
    []
    [S_pk1]
        type = R2Multiplication
        A = 'deformation_gradient'
        B = 'pk2_stress'
        to = 'neml2_pk1'
        invert_B = false
    []
    [model_pk1]
        type = ComposedModel
        models = 'fluid_JF Jtotal Jt Jvolume
                  Fthermal totalF green_strain S_pk2 S_pk2_R2 S_pk1'
        additional_outputs = 'Jf Jt pk2_stress'
    []
    [model_sm]
        type = ComposedModel
        models = 'Jacobian M1 model_pk1'
        additional_outputs = 'pk2_stress'
    []
    ############################################################
    [stress_induce_pressure]
        type = AdvectiveStress
        coefficient = '${swelling_coefficient}'
        js = 'Jf'
        jt = 'Jt'
        deformation_gradient = 'deformation_gradient'
        pk1_stress = 'neml2_pk1'
        advective_stress = 'Ps'
    []
    [stress_scale]
        type = ScalarMultiplication
        from = 'Ps Seff'
        to = 'SPs'
    []
    [advective_stress]
        type = ComposedModel
        models = 'stress_scale stress_induce_pressure'
    []
    #################################################################
    ## porous flow -----------------------------------------------------------------
    # phif_max is a bare gathered input (spatial void from MOOSE), not a constant.
    [permeability]
        type = PowerLawPermeability
        reference_permeability = ${kk_L}
        reference_porosity = 0.9
        exponent = ${permeability_power}
        porosity = 'phif_max'
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
        from = 'perm Seff'
        to = 'M9'
    []
    [effective_saturation]
        type = EffectiveSaturationSecondOrder
        residual_saturation = 0.0
        fluid_fraction = 'phif'
        max_fraction = 'phif_max'
        effective_saturation = 'Seff'
    []
    [capillary_pressure]
        type = BrooksCoreyCapillaryPressure
        threshold_pressure = '${brooks_corey_threshold}'
        exponent = '${capillary_pressure_power}'
        effective_saturation = 'Seff'
        capillary_pressure = 'Pc'
        log_extension = true
        transition_saturation = 0.001
    []
    [M5]
        type = ScalarLinearCombination
        from = 'Pc SPs'
        to = 'M5'
        weights = '-1.0 1.0'
    []
    [empty_porosity]
        type = ScalarLinearCombination
        from = 'phif_max phif'
        to = 'poro'
        weights = '1.0 -1.0'
    []
    [solid_fraction]
        type = ScalarLinearCombination
        from = 'phif_max'
        to = 'phis'
        offset = 1.0
        weights = '-1.0'
    []
    [model_porousflow]
        type = ComposedModel
        models = 'solid_fraction empty_porosity permeability
                    effective_saturation capillary_pressure M3 M4 M5 M8 M9
                    advective_stress'
        additional_outputs = 'perm'
    []
    [model]
        type = ComposedModel
        models = 'model_sm model_porousflow'
        additional_outputs = 'neml2_pk1 pk2_stress'
    []
[]
