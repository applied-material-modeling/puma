[Settings]
  additional_libraries = 'neml2/puma_custom_neml2'
[]

[Solvers]
    [newton]
        type = Newton
        verbose = false
        linear_solver = 'lu'
    []
    [lu]
        type = DenseLU
    []
[]

[EquationSystems]
    [eq_sys]
        type = NonlinearSystem
        model = 'model_residual'
    []
[]

[Models]
    ################################################################
    ###                                                          ###
    ###                                                          ###
    ###                   CONSTITUTIVE MODEL                      ##
    ###                                                          ###
    ###                                                          ###
    ################################################################
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
        lower_bound = 0
        upper_bound = 0.1
    []
    [solid_reactivity]
        type = HermiteSmoothStep
        argument = 'state/phis'
        value = 'state/R_S'
        lower_bound = 0
        upper_bound = 0.1
    []
    [reaction_rate]
        type = DiffusionLimitedReactionUpdate
        diffusion_coefficient = '${D}'
        molar_volume = '${omega_Si}'
        product_inner_radius = 'state/ri'
        solid_inner_radius = 'state/ro'
        liquid_reactivity = 'state/R_L'
        solid_reactivity = 'state/R_S'
        reaction_rate = 'state/react'
    []
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
    ### ----------------------------
    ### IVP
    ### ----------------------------
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
        models = "residual_phip residual_phis
                outer_radius fluid_reactivity solid_reactivity
                  reaction_rate substance_product product_rate 
                  substance_solid solid_rate
                  substance_solid_old substance_product_old"
    []
    [model_update]
        type = ImplicitUpdate
        equation_system = 'eq_sys'
        solver = 'newton'
    []
    [model_solver]
        type = ComposedModel
        models = 'model_update'
    []
    ################################################################
    ###                                                          ###
    ###                                                          ###
    ###                   POST PROCESS VALUES                     ##
    ###                                                          ###
    ###                                                          ###
    ################################################################
    # get the source term
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
        lower_bound = 0
        upper_bound = 0.1
    []
    [solid_reactivity_new]
        type = HermiteSmoothStep
        argument = 'state/phis'
        value = 'state/R_S'
        lower_bound = 0
        upper_bound = 0.1
    []
    [reaction_rate_new]
        type = DiffusionLimitedReactionUpdate
        diffusion_coefficient = '${D}'
        molar_volume = '${omega_Si}'
        product_inner_radius = 'state/ri'
        solid_inner_radius = 'state/ro'
        liquid_reactivity = 'state/R_L'
        solid_reactivity = 'state/R_S'
        reaction_rate = 'state/react'
    []
    [alpha_rate]
        type = ScalarLinearCombination
        from_var = 'state/react'
        to_var = 'state/alpha_dot'
        coefficients = '${mchem_P}'
    []
    [liquid_consumption_rate]
        type = ScalarLinearCombination
        from_var = 'state/alpha_dot'
        to_var = 'state/phidotf'
        coefficients = '${omega_Si}'
    []
    [M5]
        type = ScalarLinearCombination
        from_var = 'state/phidotf'
        to_var = 'state/M5'
        coefficients = '${rhof}'
    []
    [void]
        type = ScalarLinearCombination
        from_var = 'state/phip state/phis forces/phif state/phinoreact '
        to_var = 'state/poro'
        coefficients = '-1.0 -1.0 -1.0 -1.0'
        constant_coefficient = 1.0
    []
    [model_M5]
        type = ComposedModel
        models = 'M5 void alpha_rate liquid_consumption_rate
        outer_radius_new reaction_rate_new fluid_reactivity_new solid_reactivity_new'
    []
    # get the other material term
    [phif_max]
        type = ScalarLinearCombination
        from_var = 'state/phip state/phis'
        to_var = 'state/phif_max'
        coefficients = '-1.0 -1.0'
        constant_coefficient = 1.0
    []
    [permeability]
        type = PowerLawPermeability
        reference_permeability = ${kk_L}
        reference_porosity = 0.9
        exponent = ${permeability_power}
        porosity = 'state/phif_max'
        permeability = 'state/perm'
    []
    [effective_saturation]
        type = EffectiveSaturationSecondOrder
        residual_saturation = 0.00001
        fluid_fraction = 'forces/phif'
        max_fraction = 'state/phif_max'
        effective_saturation = 'state/Seff'
    []
    [M3]
        type = ScalarLinearCombination
        coefficients = "${rhof_nu}"
        from_var = 'state/perm'
        to_var = 'state/M3'
    []
    [M4]
        type = ScalarMultiplication
        coefficient = "${rhof2_nu}"
        from_var = 'state/perm state/Seff'
        to_var = 'state/M4'
    []
    [capillary_pressure]
        type = BrooksCoreyCapillaryPressure
        threshold_pressure = '${brooks_corey_threshold}'
        exponent = '${capillary_pressure_power}'
        effective_saturation = 'state/Seff'
        capillary_pressure = 'state/Pc'
        log_extension = true
        transition_saturation = 0.1
    []
    [M6]
        type = ScalarLinearCombination
        from_var = 'state/Pc'
        to_var = 'state/M6'
        coefficients = '-1.0'
    []
    [model_M346]
        type = ComposedModel
        models = 'phif_max
        permeability effective_saturation capillary_pressure M3 M4 M6'
        additional_outputs = 'state/perm state/phif_max'
    []
    [model]
        type = ComposedModel
        models = 'model_solver model_M5 model_M346'
        additional_outputs = 'state/phip state/phis'
    []
[]