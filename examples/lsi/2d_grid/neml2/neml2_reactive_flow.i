initial_product_dummy_thickness = 0.001
reactivity_lowbound = 0.001
reactivity_upbound = 0.05
D = 9.5e-05
oP_oL = 1.143421422617255
K_nucl_growth = 1.2e-16
omega_SiC = 1.2495327102803738e-05
mhcolc = -0.076
oSiCm1 = 80029.91772625281
oCm1 = 188160.85255182747
chem_ratio = 1.0
mchem_P = -1.0
omega_Si = 1.0928015564202335e-05
rho_f = 2570.0
rhof_nu = 25700.0
rhof2_nu = 66049000.0
Dmacro = 7e-08
delta_Dscale_front = 3.93e-06
delta_Dscale_back = 0.0
new_scale = -0.1
transition_saturation_front = 0.75
transition_saturation_back = 0.45
transition_saturation_back_start = 0.65
kk_L = 1e-07
permeability_power = 20.0
brooks_corey_threshold = 50000.0
capillary_pressure_power = 10
rhocp_Si = 1811850.0
rhocp_SiC = 2214900.0
rhocp_C = 3390000.0
kap_Si = 148.0
kap_SiC = 120.0
kap_C = 300.0
E = 400000000000.0
therm_expansion = 2.3e-06
Tref = 300.0

[Solvers]
    [newton]
        type = Newton
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
    ## Shared models among different sub-models
    [Jacobian]
        type = R2Determinant
        input = 'deformation_gradient'
        determinant = 'J'
    []

    ## matrix
    [phisp_premodel]
        type = ScalarLinearCombination
        from = 'phis phinoreact'
        to = 'phi_sp'
        weights = '1.0 1.0'
    []

    ## reaction_rate
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
    [reaction_rate_premodel]
        type = ScalarLinearCombination
        from = 'rate_diff rate_nucl'
        to = 'react'
    []
    [reaction_rate]
        type = ComposedModel
        models = 'reaction_rate_premodel
                  outer_radius fluid_reactivity solid_reactivity
                  diffusion_controlled nucleation_controlled
                  transition switchoff_diff switchoff_nucl 
                  diffusion_rate_switch nucleation_rate_switch'
    []

    ## phip and phis
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
        models = "reaction_rate substance_product substance_product_old
                  product_rate substance_solid substance_solid_old solid_rate
                  residual_phip residual_phis"
    []
    [model_update]
        type = ImplicitUpdate
        equation_system = 'eq_sys'
        solver = 'newton'
    []

    ## phif_max
    [phif_max_premodel]
        type = ScalarLinearCombination
        from = 'phip phis phinoreact'
        to = 'phif_max'
        weights = '-1.0 -1.0 -1.0'
        offset = 1.0
    []

    ## phiv
    [phiv_premodel]
        type = ScalarLinearCombination
        from = 'phip phis phinoreact phif'
        to = 'phiv'
        weights = '-1.0 -1.0 -1.0 -1.0'
        offset = 1.0
    []

    ## Seff
    [effective_saturation_premodel]
        type = EffectiveSaturationSecondOrder
        residual_saturation = 0.0
        fluid_fraction = 'phif'
        max_fraction = 'phif_max'
        effective_saturation = 'Seff'
    []

    ## phidot_f
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
        to = 'react_new'
    []
    [alpha_rate]
        type = ScalarLinearCombination
        from = 'react_new'
        to = 'alpha_dot'
        weights = '${mchem_P}'
    []
    [liquid_consumption_rate]
        type = ScalarLinearCombination
        from = 'alpha_dot'
        to = 'phidot_f'
        weights = '${omega_Si}'
    []

    ## phip_total
    [phip_total_premodel]
        type = ScalarLinearCombination
        from = 'phip phis phinoreact'
        to = 'phiptotal'
        weights = '1.0 0.0 1.0'
    []

    ## Dmacro Diffusion saturation dependence coefficients
    [Dmacro_functional_form_front]
        type = HermiteSmoothStep
        argument = 'Seff'
        value = 'Dmacro_form_front'
        lower_bound = '${transition_saturation_front}'
        upper_bound = 1.0
    []
    [Dmacro_front]
        type = ScalarLinearCombination
        from = 'Dmacro_form_front'
        to = 'Dmacro_front'
        weights = '${delta_Dscale_front}'
        offset = '${Dmacro}'
    []
    [Dmacro_functional_form_back]
        type = SymmetricHermiteInterpolation
        argument = 'Seff'
        output = 'Dmacro_form_back_flip'
        lower_bound = '${transition_saturation_back_start}'
        upper_bound = '${transition_saturation_back}'
    []
    [Dmacro_back_flip]
        type = ScalarLinearCombination
        from = 'Dmacro_form_back_flip'
        to = 'Dmacro_form_back'
        weights = '${new_scale}'
    []
    [Dmacro_back]
        type = ScalarLinearCombination
        from = 'Dmacro_form_back'
        to = 'Dmacro_back'
        weights = '${delta_Dscale_back}'
        offset = '${Dmacro}'
    []
    [Dmacro_premodel]
        type = ScalarLinearCombination
        from = 'Dmacro_front Dmacro_back'
        to = 'Dmacro'
    []

    ## phifmax_switch
    [phif_max_switch_premodel]
        type = HermiteSmoothStep
        argument = 'phif_max'
        value = 'phif_max_switch'
        lower_bound = 0.001
        upper_bound = 0.1
    []

    ## perm
    [permeability]
        type = PowerLawPermeability
        reference_permeability = '${kk_L}'
        reference_porosity = 0.9
        exponent = '${permeability_power}'
        porosity = 'phif_max'
        permeability = 'perm'
    []

    ## rhocp
    [rhocp_premodel]
        type = ScalarLinearCombination
        from = 'phis phip phif phinoreact'
        to = 'rhocp'
        weights = '${rhocp_C} ${rhocp_SiC} ${rhocp_Si} ${rhocp_SiC}'
    []

    ## kappa_eff
    [kappa_eff_premodel]
        type = ScalarLinearCombination
        from = 'phis phip phif phinoreact'
        to = 'kappa_eff'
        weights = '${kap_C} ${kap_SiC} ${kap_Si} ${kap_SiC}'
    []

    # Pc - capillary pressure
    [capillary_pressure]
        type = BrooksCoreyCapillaryPressure
        threshold_pressure = '${brooks_corey_threshold}'
        exponent = '${capillary_pressure_power}'
        effective_saturation = 'Seff'
        capillary_pressure = 'Pc'
        log_extension = false
    []

    #pore pressure
    [Ppore_premodel]
        type = ScalarLinearCombination
        from = 'Pc'
        to = 'Ppore'
        weights = '1.0'
    []

    ## Jtotal
    [scale_therm_p]
        type = ScalarMultiplication
        from = 'phi_sp'
        to = 'scale_therm_p'
        scaling = '${therm_expansion}'
    []
    [Jt]
        type = ThermalDeformationJacobian
        temperature = 'T'
        reference_temperature = '${Tref}'
        CTE = 'scale_therm_p'
        jacobian = 'Jt'
    []
    [Jtotal_premodel]
        type = ScalarMultiplication
        from = 'Jt'
        to = 'Jtotal'
    []

    ## stress-strain
    [totalF]
        type = VolumeAdjustDeformationGradient
        input = 'deformation_gradient'
        output = 'Fe'
        jacobian = 'Jtotal'
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
        coefficients = '${E} 0.3'
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

    ## Material outputs
    [M1]
        type = ScalarLinearCombination
        weights = '${rho_f}'
        from = 'J'
        to = 'M1'
    []
    [M2]
        type = ScalarLinearCombination
        weights = '${rho_f}'
        from = 'Dmacro'
        to = 'M2'
    []
    [M3]
        type = ScalarMultiplication
        scaling = '${rhof_nu}'
        from = 'perm phif_max_switch'
        to = 'M3'
    []
    [M4]
        type = ScalarMultiplication
        scaling = '${rhof2_nu}'
        from = 'perm  phif_max_switch'
        to = 'M4'
    []
    [M5]
        type = ScalarMultiplication
        from = 'phidot_f'
        to = 'M5'
        scaling = '${rho_f}'
    []
    [M6]
        type = ScalarMultiplication
        from = 'Ppore phif_max_switch'
        to = 'M6'
        scaling = '-1.0'
    []
    [M7]
        type = ScalarMultiplication
        from = 'J rhocp'
        to = 'M7'
    []
    [M8]
        type = ScalarLinearCombination
        from = 'kappa_eff'
        to = 'M8'
    []
    [model]
        type = ComposedModel
        models = 'Jacobian model_update phisp_premodel
                  phif_max_premodel phiv_premodel phip_total_premodel
                  effective_saturation_premodel
                  Dmacro_functional_form_front Dmacro_front Dmacro_functional_form_back
                  Dmacro_back_flip Dmacro_back Dmacro_premodel
                  phif_max_switch_premodel permeability
                  rhocp_premodel kappa_eff_premodel
                  capillary_pressure Ppore_premodel
                  outer_radius_new fluid_reactivity_new solid_reactivity_new
                  diffusion_controlled_new nucleation_controlled_new
                  transition_new switchoff_diff_new switchoff_nucl_new
                  diffusion_rate_switch_new nucleation_rate_switch_new reaction_rate_new
                  alpha_rate liquid_consumption_rate
                  scale_therm_p Jt Jtotal_premodel
                  totalF green_strain S_pk2 S_pk2_R2 S_pk1
                  M1 M2 M3 M4 M5 M6 M7 M8'
        additional_outputs = 'phip phis phif_max pk2_stress Pc react_new Jt Seff'
    []
[]
