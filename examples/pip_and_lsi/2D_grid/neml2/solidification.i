cp_rhofl = 1811850.0
cp_rhofs = 1185000.0
cp_rhos = 3597920.0
cp_rhop = 2407500.0
kap_fl = 148.0
kap_fs = 140.0
kap_s = 150.0
kap_p = 380.0
Ts = 1667.0
Tl = 1707.0
mphi_min = -0.0001
m_solidification_rate = -0.002
mOfs_Ofl = -1.0843881856540085
brooks_corey_threshold = 1000.0
capillary_pressure_power = 8
kk_L = 1e-07
permeability_power = 8
rho_f = 2570.0
rhof_nu = 25700.0
rhof2_nu = 66049000.0
hf_rhof_onu = 45925900000.0
hf_rhof2_onu = 118029563000000.0
mhf_rhof = -4592590000.0
therm_expansion = 1e-06
Tref = 300.0
E = 400000000000.0
E_fs = 160000000000.0
E_m = 400000000000.0
nu_fs = 0.3
nu_m = 0.3
delta_Omega = 0.08438818565400852

[Models]
    ## Shared models among different sub-models
    [Jacobian]
        type = R2Determinant
        input = 'deformation_gradient'
        determinant = 'J'
    []

    ## Seff
    [effective_saturation_premodel]
        type = EffectiveSaturationSecondOrder
        residual_saturation = 0.0
        fluid_fraction = 'phif'
        max_fraction = 'phif_max'
        effective_saturation = 'Seff'
    []
    [effective_saturation]
        type = ComposedModel
        models = 'phif_max effective_saturation_premodel'
    []

    ## rhocp
    [rhocp_premodel]
        type = ScalarLinearCombination
        from = 'phif phif_s phis phip'
        to = 'rhocp'
        weights = '${cp_rhofl} ${cp_rhofs} ${cp_rhos} ${cp_rhop}'
    []
    [rhocp]
        type = ComposedModel
        models = 'rhocp_premodel phif_s'
    []

    ## kappa_eff
    [kappa_eff_premodel]
        type = ScalarLinearCombination
        from = 'phif phif_s phis phip'
        to = 'kappa_eff'
        weights = '${kap_fl} ${kap_fs} ${kap_s} ${kap_p}'
    []
    [kappa_eff]
        type = ComposedModel
        models = 'kappa_eff_premodel phif_s'
    []

    ## phif_max
    [phif_max_premodel]
        type = ScalarLinearCombination
        from = 'phis phip phif_s'
        to = 'phif_max'
        weights = '-1.0 -1.0 -1.0'
        offset = 1.0
    []
    [phif_max]
        type = ComposedModel
        models = 'phif_s phif_max_premodel'
    []

    ## phifmax_switch
    [phif_max_switch_premodel]
        type = HermiteSmoothStep
        argument = 'phif_max'
        value = 'phif_max_switch'
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
        argument = 'T'
        value = 'H'
        lower_bound = '${Ts}'
        upper_bound = '${Tl}'
        complement = true
    []
    [shift_phif]
        type = ScalarLinearCombination
        from = 'phif'
        to = 'shift_phif'
        offset = '${mphi_min}'
    []
    [phifl_dot_premodel]
        type = ScalarMultiplication
        from = 'shift_phif H'
        to = 'phifl_dot'
        scaling = '${m_solidification_rate}'
    []
    [phifl_dot]
        type = ComposedModel
        models = 'shift_phif activation phifl_dot_premodel'
    []

    ## phif_s
    [phifs_dot]
        type = ScalarLinearCombination
        from = 'phifl_dot'
        to = 'phifs_rate'
        weights = '${mOfs_Ofl}'
    []
    [phif_sout]
        type = ScalarForwardEulerTimeIntegration
        variable = 'phif_s'
        rate = 'phifs_rate'
        time = 't'
    []
    [phif_s]
        type = ComposedModel
        models = 'phifl_dot phifs_dot phif_sout'
    []

    ## nonliquid
    [nonliquid_premodel]
        type = ScalarLinearCombination
        from = 'phif_max'
        to = 'nonliquid'
        weights = '-1.0'
        offset = 1.0
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
        effective_saturation = 'Seff'
        capillary_pressure = 'Pc'
        log_extension = true
        transition_saturation = 0.05
    []
    [permeability]
        type = PowerLawPermeability
        reference_permeability = '${kk_L}'
        reference_porosity = 0.9
        exponent = '${permeability_power}'
        porosity = 'phif_max'
        permeability = 'perm'
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
        variable = 'phif_s'
        time = 't'
    []
    [Jt]
        type = ThermalDeformationJacobian
        temperature = 'T'
        reference_temperature = '${Tref}'
        CTE = '${therm_expansion}'
        jacobian = 'Jt'
    []
    # Jv = V * o_Vref (current composite volume / reference volume).
    # o_Vref (=1/Vref) is a spatial gathered input from MOOSE.
    [Jv]
        type = ScalarMultiplication
        from = 'V o_Vref'
        to = 'Jv'
    []
    [Jtotal_premodel]
        type = ScalarMultiplication
        from = 'Jt Jv'
        to = 'Jtotal'
    []
    [Jtotal]
        type = ComposedModel
        models = 'Jtotal_premodel Jt Jv'
        additional_outputs = 'Jt'
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

    ## elastic stress
    [S_pk2_e]
        type = LinearIsotropicElasticity
        strain = 'Ee'
        stress = 'pk2_e_SR2'
        coefficients = '${E} 0.3'
        coefficient_types = 'YOUNGS_MODULUS POISSONS_RATIO'
    []
    [S_pk2_e_R2]
        type = SR2ToR2
        input = 'pk2_e_SR2'
        output = 'pk2_e'
    []
    ## hydrostatic RVE stress
    [ee_vol]
        type = SR2AverageVolumetric
        input = 'Ee'
        average_volumetric = 'Ee_ave_vol'
    []
    [zero_parameter]
        type = ScalarParameterToVariable
        from = 0.0
        to = 'zero'
    []
    [phisp]
        type = ScalarLinearCombination
        from = 'phis phip'
        to = 'phi_sp'
        weights = '1.0 1.0'
    []
    [rve_sh]
        type = PhaseChangeRadialStress
        E_s = '${E_fs}'
        nu_s = '${nu_fs}'
        E_m = '${E_m}'
        nu_m = '${nu_m}'
        delta_Omega = '${delta_Omega}'
        macroscopic_strain = 'Ee_ave_vol'
        pore_pressure = 'zero'
        matrix_volume_fraction = 'phi_sp'
        new_phase_volume_fraction = 'phif_s'
        hydrostatic_stress = 'rve_sh'
    []
    [S_pk2_h]
        type = PK2HydrostaticStress
        hydrostatic_stress = 'rve_sh'
        deformation_gradient = 'deformation_gradient'
        pk2_stress = 'pk2_sh'
    []
    [S_pk2]
        type = R2LinearCombination
        from = 'pk2_e pk2_sh'
        to = 'pk2_stress'
    []
    ##
    [S_pk1]
        type = R2Multiplication
        A = 'deformation_gradient'
        B = 'pk2_stress'
        to = 'neml2_pk1'
        invert_B = false
    []
    [model_sm]
        type = ComposedModel
        models = 'Jtotal totalF green_strain phisp S_pk2_e S_pk2_e_R2
                    ee_vol zero_parameter rve_sh S_pk2_h
                    S_pk2 S_pk1'
        additional_outputs = 'pk2_stress'
    []

    ## MATERIAL OUTPUTS
    [M1]
        type = ScalarLinearCombination
        weights = '${rho_f}'
        from = 'J'
        to = 'M1'
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
        from = 'perm phif_max_switch'
        to = 'M4'
    []
    [M5]
        type = ScalarMultiplication
        from = 'phifl_dot'
        to = 'M5'
        scaling = '${rho_f}'
    []
    [M6]
        type = ScalarMultiplication
        from = 'Pc phif_max_switch'
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
    [M9]
        type = ScalarMultiplication
        scaling = '${hf_rhof_onu}'
        from = 'perm phif_max_switch'
        to = 'M9'
    []
    [M10]
        type = ScalarMultiplication
        scaling = '${hf_rhof2_onu}'
        from = 'perm phif_max_switch'
        to = 'M10'
    []
    [M11]
        type = ScalarMultiplication
        from = 'J phifl_dot'
        to = 'M11'
        scaling = '${mhf_rhof}'
    []
    [model]
        type = ComposedModel
        models = 'Jacobian phif_s perm cap rhocp kappa_eff phif_max
                    nonliquid phifl_dot phif_max_switch model_sm
                  M1 M3 M4 M5 M6 M7 M8 M9 M10 M11'
        additional_outputs = 'phif_s perm pk2_stress'
    []
[]
