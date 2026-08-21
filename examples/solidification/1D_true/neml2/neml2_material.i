cp_rhofl = 17990000.0  # cp_Si*rho_Si
cp_rhofs = 11850000.0  # cp_Si_s*rho_Si_s
cp_rhos = 33900000.0  # cp_C*rho_C
cp_rhop = 17655000.0  # cp_SiC*rho_SiC
kap_fl = 14000000.0  # kappa_Si
kap_fs = 14000000.0  # kappa_Si_s
kap_s = 300000000.0  # kappa_C
kap_p = 30000000.0  # kappa_SiC
Ts = 1687
Tl = 1707  # Tf
inv_1pdw = 0.9221789883268482  # 1/(1+delta_Omega) = rho_Si_s/rho_Si
mOfs_Ofl = -1.0843881856540083  # -(1+delta_Omega) = -rho_Si/rho_Si_s
brooks_corey_threshold = 10000.0
capillary_pressure_power = 10
kk_L = 1e-08  # kk_Si
permeability_power = 8
rho_f = 2.57  # rho_Si
rhof_nu = 257.0  # rho_Si/mu_Si
rhof2_nu = 660.4899999999999  # rho_Si^2/mu_Si
hf_rhof_onu = 30840000000.0  # H_latent*rho_Si/mu_Si (H_latent=1.79e10 erg/g, physical L_Si)
hf_rhof2_onu = 79258799999.99998  # H_latent*rho_Si^2/mu_Si
mhf_rhof = -308400000.0  # -H_latent*rho_Si

# 1D_true: explicit lever kinetics; phif_s integrated (ForwardEuler), phifl_dot =
# phif_avail*(g(T^n)-g(T^{n-1}))/dt with phif_avail = phif + phif_s~1/(1+dOmega).
# Bounded (g-difference is 0 outside [Ts,Tl]); ~O(dt) under-completion residual
# from the OLD-phif_s lag (refine dt: dtmax~100-200 -> ~98% completion).
# NOTE: the implicit variant that removes the lag (g_liquid as co-unknown, flat
# composition -- the reactive-infiltration pattern) COMPILES but the baked AOTI
# implicit-Jacobian raises a broadcast/infer_size error at runtime; that is a
# NEML2/AOTI framework limitation, not resolvable from the input file.

[Models]
    [Jacobian]
        type = ScalarParameterToVariable
        from = 1.0
        to = 'J'
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
    [phif_avail]
        type = ScalarLinearCombination
        from = 'phif phif_s~1'
        to = 'phif_avail'
        weights = '1.0 ${inv_1pdw}'
    []
    [phifl_dot_premodel]
        type = HermiteSolidificationRate
        temperature = 'T'
        time = 't'
        available = 'phif_avail'
        lower_bound = '${Ts}'
        upper_bound = '${Tl}'
        rate = 'phifl_dot'
    []
    [phifl_dot]
        type = ComposedModel
        models = 'phif_avail phifl_dot_premodel'
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
    [M1]
        type = ScalarLinearCombination
        weights = '${rho_f}'
        from = 'J'
        to = 'M1'
    []
    [M3]
        type = ScalarMultiplication
        scaling = '${rhof_nu}'
        from = 'perm'
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
                    nonliquid phifl_dot phif_max_switch
                  M1 M3 M4 M5 M6 M7 M8 M9 M10 M11'
        additional_outputs = 'phif_s perm'
    []
[]
