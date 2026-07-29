D = 2.65e-6                       # D_LP/l_c^2
omega_Si = 10.928015564202334    # M_Si/rho_Si
oSiCm1 = 0.08002991773871852     # rho_SiC/M_SiC = 1/omega_SiC
oCm1 = 0.18816085255182          # rho_C/M_C = 1/omega_C
chem_ratio = 1.0                 # k_SiC/k_C
mchem_P = -1.0                   # -k_SiC
rhof = 2.57                      # rho_Si
rhof_nu = 0.257                  # rho_Si/mu_Si
rhof2_nu = 0.66049               # rho_Si^2/mu_Si
kk_L = 2e-5                      # kk_ref
permeability_power = 3
brooks_corey_threshold = 100000.0
capillary_pressure_power = 3

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
        unknowns = 'phip phis'
        residuals = 'phip_residual phis_residual'
    []
[]

[Models]
    [outer_radius]
        type = CylindricalChannelGeometry
        solid_fraction = 'phis'
        product_fraction = 'phip'
        inner_radius = 'ri'
        outer_radius = 'ro'
    []
    [fluid_reactivity]
        type = HermiteSmoothStep
        argument = 'phif'
        value = 'R_L'
        lower_bound = 0
        upper_bound = 0.1
    []
    [solid_reactivity]
        type = HermiteSmoothStep
        argument = 'phis'
        value = 'R_S'
        lower_bound = 0
        upper_bound = 0.1
    []
    [reaction_rate]
        type = DiffusionLimitedReactionUpdate
        diffusion_coefficient = '${D}'
        molar_volume = '${omega_Si}'
        product_inner_radius = 'ri'
        solid_inner_radius = 'ro'
        liquid_reactivity = 'R_L'
        solid_reactivity = 'R_S'
        reaction_rate = 'react'
    []
    [substance_product]
        type = ScalarLinearCombination
        from = 'phip'
        to = 'alpha_p'
        weights = '${oSiCm1}'
    []
    [substance_product_old]
        type = ScalarLinearCombination
        from = 'phip~1'
        to = 'alpha_p~1'
        weights = '${oSiCm1}'
    []
    [product_rate]
        type = ScalarVariableRate
        variable = 'alpha_p'
        time = 't'
    []
    [substance_solid]
        type = ScalarLinearCombination
        from = 'phis'
        to = 'alpha_s'
        weights = '${oCm1}'
    []
    [substance_solid_old]
        type = ScalarLinearCombination
        from = 'phis~1'
        to = 'alpha_s~1'
        weights = '${oCm1}'
    []
    [solid_rate]
        type = ScalarVariableRate
        variable = 'alpha_s'
        time = 't'
    []
    [residual_phip]
        type = ScalarLinearCombination
        from = 'alpha_p_rate react'
        to = 'phip_residual'
        weights = '1.0 -1.0'
    []
    [residual_phis]
        type = ScalarLinearCombination
        from = 'alpha_p_rate alpha_s_rate'
        to = 'phis_residual'
        weights = '1.0 ${chem_ratio}'
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
    [outer_radius_new]
        type = CylindricalChannelGeometry
        solid_fraction = 'phis'
        product_fraction = 'phip'
        inner_radius = 'ri'
        outer_radius = 'ro'
    []
    [fluid_reactivity_new]
        type = HermiteSmoothStep
        argument = 'phif'
        value = 'R_L'
        lower_bound = 0
        upper_bound = 0.1
    []
    [solid_reactivity_new]
        type = HermiteSmoothStep
        argument = 'phis'
        value = 'R_S'
        lower_bound = 0
        upper_bound = 0.1
    []
    [reaction_rate_new]
        type = DiffusionLimitedReactionUpdate
        diffusion_coefficient = '${D}'
        molar_volume = '${omega_Si}'
        product_inner_radius = 'ri'
        solid_inner_radius = 'ro'
        liquid_reactivity = 'R_L'
        solid_reactivity = 'R_S'
        reaction_rate = 'react'
    []
    [alpha_rate]
        type = ScalarLinearCombination
        from = 'react'
        to = 'alpha_dot'
        weights = '${mchem_P}'
    []
    [liquid_consumption_rate]
        type = ScalarLinearCombination
        from = 'alpha_dot'
        to = 'phidotf'
        weights = '${omega_Si}'
    []
    [M5]
        type = ScalarLinearCombination
        from = 'phidotf'
        to = 'M5'
        weights = '${rhof}'
    []
    [void]
        type = ScalarLinearCombination
        from = 'phip phis phif'
        to = 'poro'
        weights = '-1.0 -1.0 -1.0'
        offset = 1.0
    []
    [model_M5]
        type = ComposedModel
        models = 'M5 void alpha_rate liquid_consumption_rate
        outer_radius_new reaction_rate_new fluid_reactivity_new solid_reactivity_new'
    []
    [phif_max]
        type = ScalarLinearCombination
        from = 'phip phis'
        to = 'phif_max'
        weights = '-1.0 -1.0'
        offset = 1.0
    []
    [permeability]
        type = PowerLawPermeability
        reference_permeability = ${kk_L}
        reference_porosity = 0.9
        exponent = ${permeability_power}
        porosity = 'phif_max'
        permeability = 'perm'
    []
    [effective_saturation]
        type = EffectiveSaturationSecondOrder
        residual_saturation = 0.00001
        fluid_fraction = 'phif'
        max_fraction = 'phif_max'
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
    [M6]
        type = ScalarLinearCombination
        from = 'Pc'
        to = 'M6'
        weights = '-1.0'
    []
    [model_M346]
        type = ComposedModel
        models = 'phif_max
        permeability effective_saturation capillary_pressure M3 M4 M6'
        additional_outputs = 'perm phif_max'
    []
    [model]
        type = ComposedModel
        models = 'model_solver model_M5 model_M346'
        additional_outputs = 'phip phis'
    []
[]
