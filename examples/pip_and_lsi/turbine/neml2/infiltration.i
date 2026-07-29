# Bare-name constants (driver overwrites at runtime; values only need to be
# valid floats for compilation). This turbine PIP infiltration model is the
# simpler variant: no fluid swelling Jacobian (Jf), no advective/induced stress,
# Jt is the thermal Jacobian directly, and the L2 pressure term uses only the
# capillary pressure Pc.
rho_f = 1250.0
Tref = 300.0
therm_expansion = 1e-06
kk_L = 2e-05
permeability_power = 8
rhof_nu = 125.0
hf_rhof_nu = 0.0
rhof2_nu = 156250.0
hf_rhof2_nu = 0.0
brooks_corey_threshold = 30000.0
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
    # thermal add-on ###########
    # Jt is the thermal deformation Jacobian directly (no fluid Jacobian Jf).
    [Fthermal]
        type = ThermalDeformationJacobian
        temperature = 'T'
        reference_temperature = ${Tref}
        CTE = ${therm_expansion}
        jacobian = 'Jt'
    []
    # Jv = V * o_Vref (current composite volume / reference volume).
    [Jvolume]
        type = ScalarMultiplication
        from = 'V o_Vref'
        to = 'Jv'
    []
    # -----------------------------
    [Jtotal]
        type = ScalarMultiplication
        from = 'Jt Jv'
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
        to = 'pk1_stress'
        invert_B = false
    []
    [model_pk1]
        type = ComposedModel
        models = 'Jtotal Jvolume
                  Fthermal totalF green_strain S_pk2 S_pk2_R2 S_pk1'
        additional_outputs = 'Jt Jv pk2_stress'
    []
    [model_sm]
        type = ComposedModel
        models = 'Jacobian M1 model_pk1'
    []
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
        from = 'Pc'
        to = 'M5'
        weights = '-1.0'
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
                    effective_saturation capillary_pressure M3 M4 M5 M8 M9'
        additional_outputs = 'perm'
    []
    [model]
        type = ComposedModel
        models = 'model_sm model_porousflow'
        additional_outputs = 'pk1_stress'
    []
[]
