[Models]
    ## Shared models among different sub-models
    [Jacobian]
        type = R2Determinant
        input = 'forces/F'
        determinant = 'state/J'
    []
    [phip]
        type = ScalarParameterToState
        from = 1.0
        to = 'state/phip'
    []
    [phis]
        type = ScalarParameterToState
        from = 1.0
        to = 'state/phis'
    []

    ## Seff
    [effective_saturation_premodel]
        type = EffectiveSaturationSecondOrder
        residual_saturation = 0.0
        fluid_fraction = 'forces/phif'
        max_fraction = 'state/phif_max'
        effective_saturation = 'state/Seff'
    []
    [effective_saturation]
        type = ComposedModel
        models = 'phif_max effective_saturation_premodel'
    []

    ## rhocp
    [rhocp_premodel]
        type = ScalarLinearCombination
        from_var = 'forces/phif state/phif_s state/phis state/phip'
        to_var = 'state/rhocp'
        coefficients = '${cp_rhofl} ${cp_rhofs} ${cp_rhos} ${cp_rhop}'
    []
    [rhocp]
        type = ComposedModel
        models = 'rhocp_premodel phif_s phis phip'
    []

    ## kappa_eff
    [kappa_eff_premodel]
        type = ScalarLinearCombination
        from_var = 'forces/phif state/phif_s state/phis state/phip'
        to_var = 'state/kappa_eff'
        coefficients = '${kap_fl} ${kap_fs} ${kap_s} ${kap_p}'
    []
    [kappa_eff]
        type = ComposedModel
        models = 'kappa_eff_premodel phif_s phis phip'
    []

    ## phif_max
    [phif_max_premodel]
        type = ScalarLinearCombination
        from_var = 'state/phis state/phip state/phif_s'
        to_var = 'state/phif_max'
        coefficients = '-1.0 -1.0 -1.0'
        constant_coefficient = 1.0
    []
    [phif_max]
        type = ComposedModel
        models = 'phis phip phif_s phif_max_premodel'
    []

    ## phifmax_switch
    [phif_max_switch_premodel]
        type = HermiteSmoothStep
        argument = 'state/phif_max'
        value = 'state/phif_max_switch'
        lower_bound = 0.001
        upper_bound = 0.1
    []
    [phif_max_switch]
        type = ComposedModel
        models = 'phif_max_switch_premodel phif_max'
    []

    ## solidification model - phifl_dot
    [activation]
        type = HermiteSmoothStep
        argument = 'forces/T'
        value = 'state/H'
        lower_bound = '${Ts}'
        upper_bound = '${Tl}'
        complement = true
    []
    [shift_phif]
        type = ScalarLinearCombination
        from_var = 'forces/phif'
        to_var = 'state/shift_phif'
        constant_coefficient = '${mphi_min}'
    []
    [phifl_dot_premodel]
        type = ScalarMultiplication
        from_var = 'state/shift_phif state/H'
        to_var = 'state/phifl_dot'
        coefficient = '${m_solidification_rate}'
    []
    [phifl_dot]
        type = ComposedModel
        models = 'shift_phif activation phifl_dot_premodel'
    []

    ## phif_s
    [phifs_dot]
        type = ScalarLinearCombination
        from_var = 'state/phifl_dot'
        to_var = 'state/phifs_rate'
        coefficients = '${mOfs_Ofl}'
    []
    [phif_sout]
        type = ScalarForwardEulerTimeIntegration
        variable = 'state/phif_s'
        rate = 'state/phifs_rate'
    []
    [phif_s]
        type = ComposedModel
        models = 'phifl_dot phifs_dot phif_sout'
    []

    ## nonliquid
    [nonliquid_premodel]
        type = ScalarLinearCombination
        from_var = 'state/phif_max'
        to_var = 'state/nonliquid'
        coefficients = '-1.0'
        constant_coefficient = 1.0
    []
    [nonliquid]
        type = ComposedModel
        models = 'phif_max nonliquid_premodel'
    []

    ## Permeability and capillary pressure
    [capillary_pressure]
        type = BrooksCoreyCapillaryPressure
        threshold_pressure = '${brooks_corey_threshold}'
        exponent = '${capillary_pressure_power}'
        effective_saturation = 'state/Seff'
        capillary_pressure = 'state/Pc'
        log_extension = true
        transition_saturation = 0.05
    []
    [permeability]
        type = PowerLawPermeability
        reference_permeability = '${kk_L}'
        reference_porosity = 0.9
        exponent = '${permeability_power}'
        porosity = 'state/phif_max'
        permeability = 'state/perm'
    []
    [cap]
        type = ComposedModel
        models = 'effective_saturation capillary_pressure'
    []
    [perm]
        type = ComposedModel
        models = 'permeability phif_max'
    []

    ## Jtotal
    [phif_s_rate]
        type = ScalarVariableRate
        variable = 'state/phif_s'
        rate = 'state/phif_s_rate'
        time = 'forces/t'
    []
    [Jt]
        type = ThermalDeformationJacobian
        temperature = 'forces/T'
        reference_temperature = '${Tref}'
        CTE = '${therm_expansion}'
        jacobian = 'state/Jt'
    []
    [activation_strain]
        type = HermiteSmoothStep
        argument = 'forces/T'
        value = 'state/Hs'
        lower_bound = '${strain_Sactivate}'
        upper_bound = 1.0
    []
    [eps_vdot]
        type = ScalarMultiplication
        from_var = 'forces/phif state/Hs state/phif_s_rate'
        to_var = 'state/eps_vdot'
        coefficient = '${phase_strain_coef}'
    []
    [eps_f]
        type = ScalarForwardEulerTimeIntegration
        variable = 'state/eps_f'
        rate = 'state/eps_vdot'
    []
    [Jf]
        type = ScalarLinearCombination
        from_var = 'state/eps_f'
        to_var = 'state/Jf'
        coefficients = '1.0'
        constant_coefficient = 1.0
    []
    [V]
        type = ScalarParameterToState
        from = 1.0
        to = 'state/V'
    []
    [Jv]
        type = ScalarLinearCombination
        from_var = 'state/V'
        coefficients = '1.0'
        coefficient_as_parameter = true
        to_var = 'state/Jv'
    []
    [Jtotal_premodel]
        type = ScalarMultiplication
        from_var = 'state/Jt state/Jf state/Jv'
        to_var = 'state/Jtotal'
    []
    [Jtotal]
        type = ComposedModel
        models = 'Jtotal_premodel Jt Jf
        V Jv activation_strain eps_vdot eps_f phif_s_rate'
        additional_outputs = 'state/eps_f state/Jf state/Jt'
    []

    ## stress-strain
    [totalF]
        type = VolumeAdjustDeformationGradient
        input = 'forces/F'
        output = 'state/Fe'
        jacobian = 'state/Jtotal'
    []
    [green_strain]
        type = GreenLagrangeStrain
        deformation_gradient = 'state/Fe'
        strain = 'state/Ee'
    []
    [S_pk2]
        type = LinearIsotropicElasticity
        strain = 'state/Ee'
        stress = 'state/pk2_SR2'
        coefficients = '${E} 0.3'
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
    [model_sm]
        type = ComposedModel
        models = 'Jtotal totalF green_strain S_pk2 S_pk2_R2 S_pk1'
        additional_outputs = 'state/pk2'
    []

    ## MATERIAL OUTPUTS
    [M1]
        type = ScalarLinearCombination
        coefficients = '${rho_f}'
        from_var = 'state/J'
        to_var = 'state/M1'
    []
    [M3]
        type = ScalarMultiplication
        coefficient = '${rhof_nu}'
        from_var = 'state/perm state/phif_max_switch'
        to_var = 'state/M3'
    []
    [M4]
        type = ScalarMultiplication
        coefficient = '${rhof2_nu}'
        from_var = 'state/perm state/phif_max_switch'
        to_var = 'state/M4'
    []
    [M5]
        type = ScalarMultiplication
        from_var = 'state/phifl_dot'
        to_var = 'state/M5'
        coefficient = '${rho_f}'
    []
    [M6]
        type = ScalarMultiplication
        from_var = 'state/Pc state/phif_max_switch'
        to_var = 'state/M6'
        coefficient = '-1.0'
    []
    [M7]
        type = ScalarMultiplication
        from_var = 'state/J state/rhocp'
        to_var = 'state/M7'
    []
    [M8]
        type = ScalarLinearCombination
        from_var = 'state/kappa_eff'
        to_var = 'state/M8'
    []
    [M9]
        type = ScalarMultiplication
        coefficient = '${hf_rhof_onu}'
        from_var = 'state/perm state/phif_max_switch'
        to_var = 'state/M9'
    []
    [M10]
        type = ScalarMultiplication
        coefficient = '${hf_rhof2_onu}'
        from_var = 'state/perm state/phif_max_switch'
        to_var = 'state/M10'
    []
    [M11]
        type = ScalarMultiplication
        from_var = 'state/J state/phifl_dot'
        to_var = 'state/M11'
        coefficient = '${mhf_rhof}'
    []
    [model]
        type = ComposedModel
        models = 'Jacobian phif_s perm cap rhocp kappa_eff phif_max
                    nonliquid phifl_dot phif_max_switch model_sm
                  M1 M3 M4 M5 M6 M7 M8 M9 M10 M11'
        additional_outputs = 'state/phif_s state/perm'
    []
[]