cp_rhofl = 1811850.0
cp_rhofs = 1185000.0
cp_rhos = 3390000.0
cp_rhop = 2214900.0
kap_fl = 148.0
kap_fs = 140.0
kap_s = 300.0
kap_p = 120.0
Ts = 1667.0
Tl = 1707.0
mphi_min = -0.0001
m_solidification_rate = -0.002
mOfs_Ofl = -1.0843881856540085
brooks_corey_threshold = 50000.0
capillary_pressure_power = 10
kk_L = 1e-07
permeability_power = 20.0
rho_f = 2570.0
rhof_nu = 25700.0
rhof2_nu = 66049000.0
hf_rhof_onu = 45925900000.0
hf_rhof2_onu = 118029563000000.0
mhf_rhof = -4592590000.0
therm_expansion = 2.3e-06
Tref = 300.0
Tref_l = 1720.0
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
    	
    ## matrix
    [phisp_premodel]
        type = ScalarLinearCombination
        from = 'phis phinoreact'
        to = 'phi_sp'
        weights = '1.0 1.0'
    []

    ## Seff
    [effective_saturation_premodel]
        type = EffectiveSaturationSecondOrder
        residual_saturation = 0.0
        fluid_fraction = 'phif'
        max_fraction = 'phif_max'
        effective_saturation = 'Seff'
    []

    ## rhocp
    [rhocp_premodel]
        type = ScalarLinearCombination
        from = 'phif phif_s phis phip phinoreact'
        to = 'rhocp'
        weights = '${cp_rhofl} ${cp_rhofs} ${cp_rhos} ${cp_rhop} ${cp_rhop}'
    []

    ## kappa_eff
    [kappa_eff_premodel]
        type = ScalarLinearCombination
        from = 'phif phif_s phis phip phinoreact'
        to = 'kappa_eff'
        weights = '${kap_fl} ${kap_fs} ${kap_s} ${kap_p} ${kap_p}'
    []

    ## phif_max
    [phif_max_premodel]
        type = ScalarLinearCombination
        from = 'phis phip phinoreact phif_s'
        to = 'phif_max'
        weights = '-1.0 -1.0 -1.0 -1.0'
        offset = 1.0
    []

    ## phiv
    [phiv_premodel]
        type = ScalarLinearCombination
        from = 'phis phip phinoreact phif_s phif'
        to = 'phiv'
        weights = '-1.0 -1.0 -1.0 -1.0 -1.0'
        offset = 1.0
    []

    ## phifmax_switch
    [phif_max_switch_premodel]
        type = HermiteSmoothStep
        argument = 'phif_max'
        value = 'phif_max_switch'
        lower_bound = 0.001
        upper_bound = 0.1
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

    ## nonliquid
    [nonliquid_premodel]
        type = ScalarLinearCombination
        from = 'phif_max'
        to = 'nonliquid'
        weights = '-1.0'
        offset = 1.0
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

    #pore pressure
    [Ppore_premodel]
        type = ScalarLinearCombination
        from = 'Pc'
        to = 'Ppore'
        weights = '1.0'
    []

    ## Jtotal
    # Jt
    [scale_therm_p]
        type = ScalarMultiplication
        from = 'phi_sp'
        to = 'scale_therm_p'
        scaling = '${therm_expansion}'
    []
    [Jt_p]
        type = ThermalDeformationJacobian
        temperature = 'T'
        reference_temperature = '${Tref}'
        CTE = 'scale_therm_p'
        jacobian = 'Jt_p'
    []
    [phi_fsf]
        type = ScalarLinearCombination
        from = 'phip phif_s'
        to = 'phif_sfs'
        weights = '1.0 1.0'
    []
    [scale_therm_sfs]
        type = ScalarMultiplication
        from = 'phif_sfs'
        to = 'scale_therm_sfs'
        scaling = '${therm_expansion}'
    []
    [Jt_sfs]
        type = ThermalDeformationJacobian
        temperature = 'T'
        reference_temperature = '${Tref_l}'
        CTE = 'scale_therm_sfs'
        jacobian = 'Jt_sfs'
    []
    [Jt]
        type = ScalarMultiplication
        from = 'Jt_sfs Jt_p'
        to = 'Jt'
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
        to = 'pk1_stress'
        invert_B = false
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
        models = 'Jacobian
                  shift_phif activation phifl_dot_premodel phifs_dot phif_sout
                  phisp_premodel phif_max_premodel phiv_premodel nonliquid_premodel
                  effective_saturation_premodel rhocp_premodel kappa_eff_premodel
                  phif_max_switch_premodel permeability capillary_pressure Ppore_premodel
                  scale_therm_p Jt_p phi_fsf scale_therm_sfs Jt_sfs Jt Jtotal_premodel
                  totalF green_strain S_pk2_e S_pk2_e_R2
                  ee_vol zero_parameter rve_sh S_pk2_h S_pk2 S_pk1
                  M1 M3 M4 M5 M6 M7 M8 M9 M10 M11'
        additional_outputs = 'phif_s phif_max perm Seff Jt Jt_sfs Jt_p pk2_stress Pc rve_sh'
    []
[]
