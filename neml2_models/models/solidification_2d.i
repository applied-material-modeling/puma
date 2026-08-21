cp_rhofl = 17990000.0          # cp_Si*rho_Si
cp_rhofs = 11850000.0          # cp_Si_s*rho_Si_s
cp_rhos = 33900000.0           # cp_C*rho_C
cp_rhop = 17655000.0           # cp_SiC*rho_SiC
kap_fl = 14000000.0            # kappa_Si
kap_fs = 14000000.0            # kappa_Si_s
kap_s = 300000000.0            # kappa_C
kap_p = 30000000.0             # kappa_SiC
Ts = 1687
Tl = 1707                      # Tf
mphi_min = -0.002              # -phif_min
m_solidification_rate = -0.005 # -solidification_rate
mOfs_Ofl = -1.0843881856540084 # -omega_Si_s/omega_Si_l = -(rho_Si/rho_Si_s)
brooks_corey_threshold = 10000.0
capillary_pressure_power = 10
kk_L = 1e-8                    # kk_Si
permeability_power = 8
rho_f = 2.57                   # rho_Si
rhof_nu = 257.0               # rho_Si/mu_Si
rhof2_nu = 660.49             # rho_Si^2/mu_Si
hf_rhof_onu = 30840000000.0    # H_latent*rho_Si/mu_Si
hf_rhof2_onu = 79258800000.0   # H_latent*rho_Si^2/mu_Si
mhf_rhof = -308400000.0        # -H_latent*rho_Si
therm_expansion = 1e-6
T0 = 300
Tmax = 1720
E = 400e9
E_fs = 160e9                   # E_Si
E_m = 400e9                    # E_C
nu_fs = 0.3                    # nu_Si
nu_m = 0.3                     # nu_C
delta_Omega = 0.08438818565400843  # omega_Si_s/omega_Si_l - 1

[Models]
    [Jacobian]
        type = R2Determinant
        input = 'deformation_gradient'
        determinant = 'J'
    []
    [phisp_premodel]
        type = ScalarLinearCombination
        from = 'phis phip'
        to = 'phi_sp'
        weights = '1.0 1.0'
    []
    [phisp]
        type = ComposedModel
        models = 'phisp_premodel'
    []
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
        weights = '1.0'
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
    [scale_therm_sp]
        type = ScalarMultiplication
        from = 'phi_sp'
        to = 'scale_therm_sp'
        scaling = '${therm_expansion}'
    []
    [Jt_sp]
        type = ThermalDeformationJacobian
        temperature = 'T'
        reference_temperature = '${T0}'
        CTE = 'scale_therm_sp'
        jacobian = 'Jt_sp'
    []
    [scale_therm_fs]
        type = ScalarMultiplication
        from = 'phif_s'
        to = 'scale_therm_fs'
        scaling = '${therm_expansion}'
    []
    [Jt_fs]
        type = ThermalDeformationJacobian
        temperature = 'T'
        reference_temperature = '${Tmax}'
        CTE = 'scale_therm_fs'
        jacobian = 'Jt_fs'
    []
    [Jt]
        type = ScalarMultiplication
        from = 'Jt_fs Jt_sp'
        to = 'Jt'
    []
    [Jtotal_premodel]
        type = ScalarMultiplication
        from = 'Jt'
        to = 'Jtotal'
    []
    [Jtotal]
        type = ComposedModel
        models = 'phisp scale_therm_sp Jt_sp scale_therm_fs Jt_fs
         Jtotal_premodel Jt phif_s'
        additional_outputs = 'Jt_sp Jt_fs Jt'
    []
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
    # Macroscopic volumetric strain imposed at the RVE outer boundary r=r_o,
    # identified with the Jacobian-based macroscale dilation eps_v = J - 1
    # (J = det F, total macroscale deformation gradient; from [Jacobian]).
    [eps_v]
        type = ScalarLinearCombination
        from = 'J'
        to = 'eps_v'
        weights = '1.0'
        offset = -1.0
    []
    [rve_sh]
        type = PhaseChangeRadialStress
        E_s = '${E_fs}'
        nu_s = '${nu_fs}'
        E_m = '${E_m}'
        nu_m = '${nu_m}'
        delta_Omega = '${delta_Omega}'
        macroscopic_strain = 'eps_v'
        pore_pressure = 'Pc'
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
        to = 'pk2'
    []
    [S_pk1]
        type = R2Multiplication
        A = 'deformation_gradient'
        B = 'pk2'
        to = 'neml2_pk1'
        invert_B = false
    []
    [model_sm]
        type = ComposedModel
        models = 'Jacobian cap Jtotal totalF green_strain phisp S_pk2_e S_pk2_e_R2
                    eps_v rve_sh S_pk2_h
                    S_pk2 S_pk1 phif_s'
        additional_outputs = 'pk2'
    []
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
        additional_outputs = 'phif_s perm pk2'
    []
[]
