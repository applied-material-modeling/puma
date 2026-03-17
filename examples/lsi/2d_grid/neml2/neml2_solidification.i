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
    [phinoreact]
        type = ScalarParameterToState
        from = 1.0
        to = 'state/phinoreact'
    []
    	
    ## matrix
    [phisp_premodel]
        type = ScalarLinearCombination
        from_var = 'state/phis state/phinoreact'
        to_var = 'state/phi_sp'
        coefficients = '1.0 1.0'
    []
    [phisp]
        type = ComposedModel
        models = 'phisp_premodel phis phinoreact'
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
        models = 'effective_saturation_premodel'
    []

    ## rhocp
    [rhocp_premodel]
        type = ScalarLinearCombination
        from_var = 'forces/phif state/phif_s state/phis state/phip state/phinoreact'
        to_var = 'state/rhocp'
        coefficients = '${cp_rhofl} ${cp_rhofs} ${cp_rhos} ${cp_rhop} ${cp_rhop}'
    []
    [rhocp]
        type = ComposedModel
        models = 'rhocp_premodel phif_s phis phip phinoreact'
    []

    ## kappa_eff
    [kappa_eff_premodel]
        type = ScalarLinearCombination
        from_var = 'forces/phif state/phif_s state/phis state/phip state/phinoreact'
        to_var = 'state/kappa_eff'
        coefficients = '${kap_fl} ${kap_fs} ${kap_s} ${kap_p} ${kap_p}'
    []
    [kappa_eff]
        type = ComposedModel
        models = 'kappa_eff_premodel phif_s phis phip phinoreact'
    []

    ## phif_max
    [phif_max_premodel]
        type = ScalarLinearCombination
        from_var = 'state/phis state/phip state/phinoreact state/phif_s'
        to_var = 'state/phif_max'
        coefficients = '-1.0 -1.0 -1.0 -1.0'
        constant_coefficient = 1.0
    []
    [phif_max]
        type = ComposedModel
        models = 'phis phip phif_s phif_max_premodel phinoreact'
    []

    ## phiv
    [phiv_premodel]
        type = ScalarLinearCombination
        from_var = 'state/phis state/phip state/phinoreact state/phif_s forces/phif'
        to_var = 'state/phiv'
        coefficients = '-1.0 -1.0 -1.0 -1.0 -1.0'
        constant_coefficient = 1.0
    []
    [phiv]
        type = ComposedModel
        models = 'phiv_premodel phis phip phinoreact phif_s'
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
        complement_condition = true
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

    ## fluid overflow pressure
    [Pp_function_form]
        type = HermiteSmoothStep
        argument = 'state/phiv'
        value = 'state/Pp_form'
        lower_bound = ${overflow_Stransition_start}
        upper_bound = ${overflow_Stransition_end}
        complement_condition = true
    []
    [Pp_premodel]
        type = ScalarMultiplication
        from_var = 'state/Pp_form'
        to_var = 'state/Pp'
        coefficient = ${overflow_Stransition_magnitude}
    []
    [Pp]
        type = ComposedModel
        models = 'Pp_function_form Pp_premodel phiv'
    []

    #pore pressure
    [Ppore_premodel]
        type = ScalarLinearCombination
        from_var = 'state/Pc state/Pp'
        to_var = 'state/Ppore'
        coefficients = '1.0 -1.0'
    []
    [Ppore]
        type = ComposedModel
        models = 'Ppore_premodel Pp cap'
        additional_outputs = 'state/Pp state/Pc'
    []

    ## Jtotal
    # Jt
    [scale_therm_p]
        type = ScalarMultiplication
        from_var = 'state/phi_sp'
        to_var = 'state/scale_therm_p'
        coefficient = '${therm_expansion}'
    []
    [Jt_p]
        type = ThermalDeformationJacobian
        temperature = 'forces/T'
        reference_temperature = '${Tref}'
        CTE = 'state/scale_therm_p'
        jacobian = 'state/Jt_p'
    []
    [phi_fsf]
        type = ScalarLinearCombination
        from_var = 'state/phip state/phif_s'
        to_var = 'state/phif_sfs'
        coefficients = '1.0 1.0'
    []
    [scale_therm_sfs]
        type = ScalarMultiplication
        from_var = 'state/phif_sfs'
        to_var = 'state/scale_therm_sfs'
        coefficient = '${therm_expansion}'
    []
    [Jt_sfs]
        type = ThermalDeformationJacobian
        temperature = 'forces/T'
        reference_temperature = '${Tref_l}'
        CTE = 'state/scale_therm_sfs'
        jacobian = 'state/Jt_sfs'
    []
    [Jt]
        type = ScalarMultiplication
        from_var = 'state/Jt_sfs state/Jt_p'
        to_var = 'state/Jt'
    []
    [Jtotal_premodel]
        type = ScalarMultiplication
        from_var = 'state/Jt'
        to_var = 'state/Jtotal'
    []
    [Jtotal]
        type = ComposedModel
        models = 'Jtotal_premodel Jt Jt_p Jt_sfs scale_therm_p phisp phip
        phi_fsf scale_therm_sfs phif_s'
        additional_outputs = 'state/Jt state/Jt_sfs state/Jt_p'
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
        to = 'state/pk1_stress'
        invert_B = false
    []
    [pore_stress]
        type = BiotPorePressureStress
        pore_pressure = 'state/Pp'
        deformation_gradient = 'forces/F'
        pk1_stress = 'state/pk1_pore'
    []
    [S_pk1_total]
        type = R2LinearCombination
        from_var = 'state/pk1_stress state/pk1_pore'
        to_var = 'state/pk1'
        coefficients = '1.0 1.0'
    []
    [model_sm]
        type = ComposedModel
        models = 'Jtotal totalF green_strain S_pk2 S_pk2_R2 S_pk1
        pore_stress Pp S_pk1_total'
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
        from_var = 'state/Ppore state/phif_max_switch'
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
        models = 'Jacobian phif_s perm rhocp kappa_eff phif_max effective_saturation
                    nonliquid phifl_dot phif_max_switch model_sm Ppore phiv
                  M1 M3 M4 M5 M6 M7 M8 M9 M10 M11'
        additional_outputs = 'state/phif_s state/perm state/phif_max'
    []
[]