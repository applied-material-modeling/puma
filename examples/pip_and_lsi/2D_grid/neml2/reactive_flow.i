initial_product_dummy_thickness = 1e-3

[Solvers]
    [newton]
        type = Newton
        verbose = false
    []
[]

[Models]
    ## Shared models among different sub-models
    [Jacobian]
        type = R2Determinant
        input = 'forces/F'
        determinant = 'state/J'
    []
    [phinoreact]
        type = ScalarParameterToState
        from = 0.0
        to = 'state/phinoreact'
    []

    ## reaction_rate
    [outer_radius]
        type = CylindricalChannelGeometry
        solid_fraction = 'state/phis'
        product_fraction = 'state/phip'
        inner_radius = 'state/ri'
        outer_radius = 'state/ro'
    []
    [fluid_reactivity]
        type = HermiteSmoothStep
        argument = 'forces/phif'
        value = 'state/R_L'
        lower_bound = ${reactivity_lowbound}
        upper_bound = ${reactivity_upbound}
    []
    [solid_reactivity]
        type = HermiteSmoothStep
        argument = 'state/phis'
        value = 'state/R_S'
        lower_bound = ${reactivity_lowbound}
        upper_bound = ${reactivity_upbound}
    []
    [diffusion_controlled]
        type = DiffusionLimitedReactionUpdate
        diffusion_coefficient = '${D}'
        molar_volume = '${oP_oL}'
        product_inner_radius = 'state/ri'
        solid_inner_radius = 'state/ro'
        liquid_reactivity = 'state/R_L'
        solid_reactivity = 'state/R_S'
        reaction_rate = 'state/react_diff'
        product_dummy_thickness = ${initial_product_dummy_thickness}
    []
    [chemistry_controlled]
        type = ChemistryLimitedReaction
        exponent = '${chem_p}'
        scale = '${chem_scale}'
        product_inner_radius = 'state/ri'
        solid_inner_radius = 'state/ro'
        liquid_reactivity = 'state/R_L'
        solid_reactivity = 'state/R_S'
        reaction_rate = 'state/react_chem'
    []
    [reaction_rate_premodel]
        type = ScalarLinearCombination
        from_var = 'state/react_diff state/react_chem'
        to_var = 'state/react'
    []
    [reaction_rate]
        type = ComposedModel
        models = 'reaction_rate_premodel outer_radius fluid_reactivity solid_reactivity
                  diffusion_controlled chemistry_controlled'
    []

    ## phip and phis
    [substance_product]
        type = ScalarLinearCombination
        from_var = 'state/phip'
        to_var = 'state/alpha_p'
        coefficients = '${oSiCm1}'
    []
    [substance_product_old]
        type = ScalarLinearCombination
        from_var = 'old_state/phip'
        to_var = 'old_state/alpha_p'
        coefficients = '${oSiCm1}'
    []
    [product_rate]
        type = ScalarVariableRate
        variable = 'state/alpha_p'
        rate = 'state/adot_p'
        time = 'forces/t'
    []
    [substance_solid]
        type = ScalarLinearCombination
        from_var = 'state/phis'
        to_var = 'state/alpha_s'
        coefficients = '${oCm1}'
    []
    [substance_solid_old]
        type = ScalarLinearCombination
        from_var = 'old_state/phis'
        to_var = 'old_state/alpha_s'
        coefficients = '${oCm1}'
    []
    [solid_rate]
        type = ScalarVariableRate
        variable = 'state/alpha_s'
        rate = 'state/adot_s'
        time = 'forces/t'
    []
    [residual_phip]
        type = ScalarLinearCombination
        from_var = 'state/adot_p state/react'
        to_var = 'residual/phip'
        coefficients = '1.0 -1.0'
    []
    [residual_phis]
        type = ScalarLinearCombination
        from_var = 'state/adot_p state/adot_s'
        to_var = 'residual/phis'
        coefficients = '1.0 ${chem_ratio}'
    []
    [model_residual]
        type = ComposedModel
        models = "reaction_rate substance_product substance_product_old
                  product_rate substance_solid substance_solid_old solid_rate
                  residual_phip residual_phis"
    []
    [model_update]
        type = ImplicitUpdate
        implicit_model = 'model_residual'
        solver = 'newton'
    []
    [phip_phis]
        type = ComposedModel
        models = 'model_update'
        additional_outputs = 'state/phip state/phis'
    []

    ## phif_max
    [phif_max_premodel]
        type = ScalarLinearCombination
        from_var = 'state/phip state/phis state/phinoreact'
        to_var = 'state/phif_max'
        coefficients = '-1.0 -1.0 -1.0'
        constant_coefficient = 1.0
    []
    [phif_max]
        type = ComposedModel
        models = 'phif_max_premodel phinoreact phip_phis'
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

    ## phidot_f
    [outer_radius_new]
        type = CylindricalChannelGeometry
        solid_fraction = 'state/phis'
        product_fraction = 'state/phip'
        inner_radius = 'state/ri'
        outer_radius = 'state/ro'
    []
    [fluid_reactivity_new]
        type = HermiteSmoothStep
        argument = 'forces/phif'
        value = 'state/R_L'
        lower_bound = ${reactivity_lowbound}
        upper_bound = ${reactivity_upbound}
    []
    [solid_reactivity_new]
        type = HermiteSmoothStep
        argument = 'state/phis'
        value = 'state/R_S'
        lower_bound = ${reactivity_lowbound}
        upper_bound = ${reactivity_upbound}
    []
    [diffusion_controlled_new]
        type = DiffusionLimitedReactionUpdate
        diffusion_coefficient = '${D}'
        molar_volume = '${oP_oL}'
        product_inner_radius = 'state/ri'
        solid_inner_radius = 'state/ro'
        liquid_reactivity = 'state/R_L'
        solid_reactivity = 'state/R_S'
        reaction_rate = 'state/react_diff'
        product_dummy_thickness = ${initial_product_dummy_thickness}
    []
    [chemistry_controlled_new]
        type = ChemistryLimitedReaction
        exponent = '${chem_p}'
        scale = '${chem_scale}'
        product_inner_radius = 'state/ri'
        solid_inner_radius = 'state/ro'
        liquid_reactivity = 'state/R_L'
        solid_reactivity = 'state/R_S'
        reaction_rate = 'state/react_chem'
    []
    [reaction_rate_new]
        type = ScalarLinearCombination
        from_var = 'state/react_diff state/react_chem'
        to_var = 'state/react_new'
    []
    [alpha_rate]
        type = ScalarLinearCombination
        from_var = 'state/react_new'
        to_var = 'state/alpha_dot'
        coefficients = '${mchem_P}'
    []
    [liquid_consumption_rate]
        type = ScalarLinearCombination
        from_var = 'state/alpha_dot'
        to_var = 'state/phidot_f'
        coefficients = '${omega_Si}'
    []
    [phidot_f]
        type = ComposedModel
        models = 'outer_radius_new fluid_reactivity_new solid_reactivity_new
        diffusion_controlled_new chemistry_controlled_new reaction_rate_new
         alpha_rate liquid_consumption_rate'
    []

    ## phip_total
    [phip_total_premodel]
        type = ScalarLinearCombination
        from_var = 'state/phip state/phis state/phinoreact'
        to_var = 'state/phiptotal'
        coefficients = '1.0 0.0 1.0'
    []
    [phip_total]
        type = ComposedModel
        models = 'phip_phis phip_total_premodel phinoreact'
    []

    ## Dmacro Diffusion saturation dependence coefficients
    [Dmacro_functional_form_front]
        type = HermiteSmoothStep
        argument = 'state/Seff'
        value = 'state/Dmacro_form_front'
        lower_bound = '${transition_saturation_front}'
        upper_bound = 1.0
    []
    [Dmacro_front]
        type = ScalarLinearCombination
        from_var = 'state/Dmacro_form_front'
        to_var = 'state/Dmacro_front'
        coefficients = '${delta_Dscale_front}'
        constant_coefficient = '${Dmacro}'
    []
    [Dmacro_functional_form_back]
        type = SymmetricHermiteInterpolation
        argument = 'state/Seff'
        value = 'state/Dmacro_form_back_flip'
        lower_bound = '${transition_saturation_back_start}'
        upper_bound = '${transition_saturation_back}'
    []
    [Dmacro_back_flip]
        type = ScalarLinearCombination
        from_var = 'state/Dmacro_form_back_flip'
        to_var = 'state/Dmacro_form_back'
        coefficients = '${new_scale}'
    []
    [Dmacro_back]
        type = ScalarLinearCombination
        from_var = 'state/Dmacro_form_back'
        to_var = 'state/Dmacro_back'
        coefficients = '${delta_Dscale_back}'
        constant_coefficient = '${Dmacro}'
    []
    [Dmacro_premodel]
        type = ScalarLinearCombination
        from_var = 'state/Dmacro_front state/Dmacro_back'
        to_var = 'state/Dmacro'
    []
    [Dmacro]
        type = ComposedModel
        models = 'effective_saturation
                  Dmacro_functional_form_front Dmacro_front
                  Dmacro_functional_form_back Dmacro_back_flip
                  Dmacro_back Dmacro_premodel'
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

    ## perm
    [permeability]
        type = PowerLawPermeability
        reference_permeability = '${kk_L}'
        reference_porosity = 0.9
        exponent = '${permeability_power}'
        porosity = 'state/phif_max'
        permeability = 'state/perm'
    []
    [perm]
        type = ComposedModel
        models = 'permeability phif_max'
    []

    ## rhocp
    [rhocp_premodel]
        type = ScalarLinearCombination
        from_var = 'state/phis state/phip forces/phif state/phinoreact'
        to_var = 'state/rhocp'
        coefficients = '${rhocp_C} ${rhocp_SiC} ${rhocp_Si} ${rhocp_SiC}'
    []
    [rhocp]
        type = ComposedModel
        models = 'rhocp_premodel phinoreact phip_phis'
    []

    ## kappa_eff
    [kappa_eff_premodel]
        type = ScalarLinearCombination
        from_var = 'state/phis state/phip forces/phif state/phinoreact'
        to_var = 'state/kappa_eff'
        coefficients = '${kap_C} ${kap_SiC} ${kap_Si} ${kap_SiC}'
    []
    [kappa_eff]
        type = ComposedModel
        models = 'phip_phis kappa_eff_premodel phinoreact'
    []

    # Pc - capillary pressure
    [capillary_pressure]
        type = BrooksCoreyCapillaryPressure
        threshold_pressure = '${brooks_corey_threshold}'
        exponent = '${capillary_pressure_power}'
        effective_saturation = 'state/Seff'
        capillary_pressure = 'state/Pc'
        log_extension = false
    []
    [Pc]
        type = ComposedModel
        models = 'capillary_pressure effective_saturation'
    []

    ## Jtotal
    [phip_dot]
        type = ScalarVariableRate
        variable = 'state/phip'
        rate = 'state/phip_dot'
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
        from_var = 'forces/phif state/Hs state/phip_dot'
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
        V Jv activation_strain eps_vdot eps_f phip_dot'
        additional_outputs = 'state/eps_f'
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
    [model_pk1]
        type = ComposedModel
        models = 'Jtotal totalF green_strain S_pk2 S_pk2_R2 S_pk1'
        additional_outputs = 'state/pk2'
    []

    ## Material outputs
    [M1]
        type = ScalarLinearCombination
        coefficients = '${rho_f}'
        from_var = 'state/J'
        to_var = 'state/M1'
    []
    [M2]
        type = ScalarLinearCombination
        coefficients = '${rho_f}'
        from_var = 'state/Dmacro'
        to_var = 'state/M2'
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
        from_var = 'state/perm  state/phif_max_switch'
        to_var = 'state/M4'
    []
    [M5]
        type = ScalarMultiplication
        from_var = 'state/phidot_f'
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
    [model]
        type = ComposedModel
        models = 'Jacobian perm Pc phip_phis phif_max phip_total
                 phif_max_switch rhocp kappa_eff phidot_f Dmacro
                    model_pk1 M1 M2 M3 M4 M5 M6 M7 M8'
        additional_outputs = 'state/phip state/phis state/phif_max'
    []
[]