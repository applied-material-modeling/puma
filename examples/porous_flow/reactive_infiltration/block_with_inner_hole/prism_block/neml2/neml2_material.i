initial_product_dummy_thickness = 1e-3
reactivity_lowbound = 0.005
reactivity_upbound = 0.05
D = 9.5e-5                        # D_LP/l_c
oP_oL = 1.143421422617255        # omega_SiC/omega_Si
K_nucl_growth = 1.2e-14          # K_nucl_growth/l_c
omega_SiC = 12.495327102803738   # M_SiC/rho_SiC
mhcolc = -0.076                  # -h_c/l_c
oSiCm1 = 0.0800299177262528      # 1/omega_SiC
oCm1 = 0.18816085255182746       # 1/omega_C
chem_ratio = 1.0                 # k_SiC/k_C
mchem_P = -1.0                   # -k_SiC
omega_Si = 10.928015564202335    # M_Si/rho_Si
rhof = 2.57                      # rho_Si
rhof_nu = 257.0                  # rho_Si/mu_Si
rhof2_nu = 660.4899999999999     # rho_Si^2/mu_Si
om_phinoreact = 1.0
Dmacro = 0.0007
delta_Dscale_front = 0.0393
delta_Dscale_back = 0.0          # D_macro_low - D_macro
new_scale = -0.1                 # (tsb - tsbs)/2
transition_saturation_front = 0.75
transition_saturation_back = 0.25
transition_saturation_back_start = 0.45
kk_L = 1e-8                      # kk_ref
permeability_power = 20.0
phif_residual = 0.0             # phi_L_residual
brooks_corey_threshold = 50000.0
capillary_pressure_power = 10

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
        lower_bound = ${reactivity_lowbound}
        upper_bound = ${reactivity_upbound}
    []
    [solid_reactivity]
        type = HermiteSmoothStep
        argument = 'phis'
        value = 'R_S'
        lower_bound = ${reactivity_lowbound}
        upper_bound = ${reactivity_upbound}
    []
    [diffusion_controlled]
        type = DiffusionLimitedReactionUpdate
        diffusion_coefficient = '${D}'
        molar_volume = '${oP_oL}'
        product_inner_radius = 'ri'
        solid_inner_radius = 'ro'
        liquid_reactivity = 'R_L'
        solid_reactivity = 'R_S'
        reaction_rate = 'react_diff'
        product_dummy_thickness = ${initial_product_dummy_thickness}
    []
    [nucleation_controlled]
        type = NucleationLimitedReaction
        growth_constant = ${K_nucl_growth}
        product_molar_volume = ${omega_SiC}
        product_volume_fraction = 'phip'
        reaction_rate = 'react_nucl'
        liquid_reactivity = 'R_L'
        solid_reactivity = 'R_S'
        order_type = 'FIRST'
    []
    [transition]
        type = ScalarLinearCombination
        from = 'ro ri'
        to = 'rate_transition'
        weights = '1 -1'
        offset = ${mhcolc}
    []
    [switchoff_diff]
        type = HermiteSmoothStep
        argument = 'rate_transition'
        value = 'Hdiff'
        lower_bound = 0.0
        upper_bound = 0.1
        complement = false
    []
    [switchoff_nucl]
        type = ScalarLinearCombination
        from = 'Hdiff'
        to = 'Hnucl'
        weights = -1.0
        offset = 1.0
    []
    [diffusion_rate_switch]
        type = ScalarMultiplication
        from = 'react_diff Hdiff'
        to = 'rate_diff'
    []
    [nucleation_rate_switch]
        type = ScalarMultiplication
        from = 'react_nucl Hnucl'
        to = 'rate_nucl'
    []
    [reaction_rate]
        type = ScalarLinearCombination
        from = 'rate_diff rate_nucl'
        to = 'react'
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
                  diffusion_controlled nucleation_controlled
                  transition switchoff_diff switchoff_nucl
                  diffusion_rate_switch nucleation_rate_switch
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
        lower_bound = ${reactivity_lowbound}
        upper_bound = ${reactivity_upbound}
    []
    [solid_reactivity_new]
        type = HermiteSmoothStep
        argument = 'phis'
        value = 'R_S'
        lower_bound = ${reactivity_lowbound}
        upper_bound = ${reactivity_upbound}
    []
    [diffusion_controlled_new]
        type = DiffusionLimitedReactionUpdate
        diffusion_coefficient = '${D}'
        molar_volume = '${oP_oL}'
        product_inner_radius = 'ri'
        solid_inner_radius = 'ro'
        liquid_reactivity = 'R_L'
        solid_reactivity = 'R_S'
        reaction_rate = 'react_diff'
        product_dummy_thickness = ${initial_product_dummy_thickness}
    []
    [nucleation_controlled_new]
        type = NucleationLimitedReaction
        growth_constant = ${K_nucl_growth}
        product_molar_volume = ${omega_SiC}
        product_volume_fraction = 'phip'
        reaction_rate = 'react_nucl'
        order_type = 'FIRST'
        liquid_reactivity = 'R_L'
        solid_reactivity = 'R_S'
    []
    [transition_new]
        type = ScalarLinearCombination
        from = 'ro ri'
        to = 'rate_transition'
        weights = '1 -1'
        offset = ${mhcolc}
    []
    [switchoff_diff_new]
        type = HermiteSmoothStep
        argument = 'rate_transition'
        value = 'Hdiff'
        lower_bound = 0.0
        upper_bound = 0.1
        complement = false
    []
    [switchoff_nucl_new]
        type = ScalarLinearCombination
        from = 'Hdiff'
        to = 'Hnucl'
        weights = -1.0
        offset = 1.0
    []
    [diffusion_rate_switch_new]
        type = ScalarMultiplication
        from = 'react_diff Hdiff'
        to = 'rate_diff'
    []
    [nucleation_rate_switch_new]
        type = ScalarMultiplication
        from = 'react_nucl Hnucl'
        to = 'rate_nucl'
    []
    [reaction_rate_new]
        type = ScalarLinearCombination
        from = 'rate_diff rate_nucl'
        to = 'react'
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
        offset = ${om_phinoreact}
    []
    [model_M5]
        type = ComposedModel
        models = 'M5 void alpha_rate liquid_consumption_rate
        diffusion_controlled_new nucleation_controlled_new
        outer_radius_new reaction_rate_new
        transition_new switchoff_diff_new switchoff_nucl_new
        diffusion_rate_switch_new nucleation_rate_switch_new
        fluid_reactivity_new solid_reactivity_new'
    []
    [phif_max]
        type = ScalarLinearCombination
        from = 'phip phis'
        to = 'phif_max'
        weights = '-1.0 -1.0'
        offset = ${om_phinoreact}
    []
    [skeleton]
        type = ScalarLinearCombination
        from = 'phif_max'
        to = 'new_solid'
        weights = '-1.0'
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
        residual_saturation = ${phif_residual}
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
    [M2_functional_form_front]
        type = HermiteSmoothStep
        argument = 'Seff'
        value = 'M2_form_front'
        lower_bound = '${transition_saturation_front}'
        upper_bound = 1.0
    []
    [M2_front]
        type = ScalarLinearCombination
        from = 'M2_form_front'
        to = 'M2_front'
        weights = '${delta_Dscale_front}'
        offset = '${Dmacro}'
    []
    [M2_functional_form_back]
        type = SymmetricHermiteInterpolation
        argument = 'Seff'
        output = 'M2_form_back_flip'
        lower_bound = '${transition_saturation_back_start}'
        upper_bound = '${transition_saturation_back}'
    []
    [M2_back_flip]
        type = ScalarLinearCombination
        from = 'M2_form_back_flip'
        to = 'M2_form_back'
        weights = '${new_scale}'
    []
    [M2_back]
        type = ScalarLinearCombination
        from = 'M2_form_back'
        to = 'M2_back'
        weights = '${delta_Dscale_back}'
        offset = '${Dmacro}'
    []
    [M2_model]
        type = ScalarLinearCombination
        from = 'M2_front M2_back'
        to = 'M2'
        weights = '${rhof} ${rhof}'
    []
    [M2]
        type = ComposedModel
        models = 'M2_functional_form_front M2_front M2_functional_form_back
        M2_back M2_model M2_back_flip'
    []
    [M6]
        type = ScalarLinearCombination
        from = 'Pc'
        to = 'M6'
        weights = '-1.0'
    []
    [model_M346]
        type = ComposedModel
        models = 'phif_max skeleton
        permeability effective_saturation capillary_pressure
        M2 M3 M4 M6'
        additional_outputs = 'perm phif_max Seff'
    []
    [model]
        type = ComposedModel
        models = 'model_solver model_M5 model_M346'
        additional_outputs = 'phip phis'
    []
[]
