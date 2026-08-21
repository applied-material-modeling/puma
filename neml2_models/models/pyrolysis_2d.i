# PUMA pyrolysis (1D) NEML2 model, migrated to NEML2 3.x (bare names).
# Baked constants (were MOOSE [NEML2] cli_args, a no-op in 3.x; fparse precomputed to literals).
A = 0.0421047
Ea = 21191.61425
R = 8.31446261815324
order = 1.0
mY = -0.575                       # -Y
mu = 0.015                        # pyro_mu (2D)
mzeta = -0.05                     # -zeta
Mref = 18                         # ms0+mb0+mp0+mg0 = 3+10+5+0
rho_s = 2100
rho_b = 1250
rho_p = 3210
rho_g = 13
rho_sm1M = 0.008571428571428571   # Mref/rho_s
rho_bm1M = 0.0144                 # Mref/rho_b
rho_pm1M = 0.005607476635514019   # Mref/rho_p
rho_gm1M = 1.3846153846153846     # Mref/rho_g
cp_s = 1592
cp_b = 1200
cp_p = 750
k_s = 150
k_b = 279
k_p = 380
source_coeff = -331800000.0       # -rho_s*hrp = -2100*1.58e5
wp0 = 0.2777777777777778          # mp0/Mref = 5/18 (was MOOSE param wp)
mwb0 = -0.5555555555555556        # -wb0 = -10/18 (was MOOSE param binder_rate_c_0)
E = 400e9
g = 4e-6
Tref = 300
o_Vref = 90.93222879364822            # 1/V0 (was MOOSE param Jvolume_c_0)

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
        model = 'reaction'
        unknowns = 'alpha'
    []
[]

[Models]
    [reaction_coef]
        type = ArrheniusParameter
        reference_value = '${A}'
        activation_energy = '${Ea}'
        ideal_gas_constant = '${R}'
        temperature = 'T'
        parameter = 'k'
    []
    [reaction_rate]
        type = ContractingGeometry
        coef = 'k'
        order = '${order}'
        conversion_degree = 'alpha'
        reaction_rate = 'alpha_rate'
    []
    [reaction_ode]
        type = ScalarBackwardEulerTimeIntegration
        variable = 'alpha'
        time = 't'
    []
    [reaction]
        type = ComposedModel
        models = 'reaction_rate reaction_ode'
    []
    [solve_reaction]
        type = ImplicitUpdate
        equation_system = 'eq_sys'
        solver = 'newton'
    []
    [binder_rate]
        type = ScalarLinearCombination
        from = 'alpha_rate'
        weights = '${mwb0}'
        to = 'wb_rate'
    []
    [char_rate]
        type = ScalarLinearCombination
        from = 'wb_rate'
        weights = '${mY}'
        to = 'ws_rate'
    []
    [gas_rate]
        type = ScalarLinearCombination
        from = 'wb_rate ws_rate'
        weights = '-${mu} -${mu}'
        to = 'wgcp_rate'
    []
    [open_pore_rate]
        type = ScalarLinearCombination
        from = 'wb_rate'
        weights = '${mzeta}'
        to = 'phiop_rate'
    []
    [binder]
        type = ScalarForwardEulerTimeIntegration
        variable = 'wb'
        time = 't'
    []
    [char]
        type = ScalarForwardEulerTimeIntegration
        variable = 'ws'
        time = 't'
    []
    [gas]
        type = ScalarForwardEulerTimeIntegration
        variable = 'wgcp'
        time = 't'
    []
    [open_pore]
        type = ScalarForwardEulerTimeIntegration
        variable = 'phiop'
        time = 't'
    []
    [model_solver]
        type = ComposedModel
        models = "solve_reaction reaction_coef reaction_rate
                binder_rate char_rate gas_rate open_pore_rate
                binder char gas open_pore"
        additional_outputs = 'alpha k'
    []
    ################################### POST PROCESS #################################
    [wp_state]
        type = ScalarParameterToVariable
        from = '${wp0}'
        to = 'wp'
    []
    [V_RVE_post]
        type = EffectiveVolume
        reference_mass = '${Mref}'
        mass_fractions = 'wb ws wp wgcp'
        densities = '${rho_b} ${rho_s} ${rho_p} ${rho_g}'
        open_volume_fraction = 'phiop'
        composite_volume = 'V'
    []
    [phi_b]
        type = ScalarMultiplication
        from = 'wb V'
        scaling = '${rho_bm1M}'
        to = 'phib'
        reciprocal = 'false true'
    []
    [phi_s]
        type = ScalarMultiplication
        from = 'ws V'
        scaling = '${rho_sm1M}'
        to = 'phis'
        reciprocal = 'false true'
    []
    [phi_p]
        type = ScalarMultiplication
        from = 'wp V'
        scaling = '${rho_pm1M}'
        to = 'phip'
        reciprocal = 'false true'
    []
    [phi_gcp]
        type = ScalarMultiplication
        from = 'wgcp V'
        scaling = '${rho_gm1M}'
        to = 'phigcp'
        reciprocal = 'false true'
    []
    [phi_out]
        type = ComposedModel
        models = 'V_RVE_post phi_b phi_s phi_p phi_gcp'
        additional_outputs = 'V'
    []
    [rho]
        type = ScalarLinearCombination
        weights = '${rho_p} ${rho_b} ${rho_s}'
        from = 'phip phib phis'
        to = 'rho'
    []
    [cp]
        type = ScalarLinearCombination
        weights = '${cp_p} ${cp_b} ${cp_s}'
        from = 'wp wb ws'
        to = 'cp'
    []
    [rhocp]
        type = ScalarMultiplication
        from = 'rho cp'
        to = 'M1'
    []
    [K]
        type = ScalarLinearCombination
        weights = '${k_p} ${k_b} ${k_s}'
        from = 'phip phib phis'
        to = 'M2'
    []
    [reaction_rate_new]
        type = ContractingGeometry
        coef = 'k'
        order = '${order}'
        conversion_degree = 'alpha'
        reaction_rate = 'alpha_rate_post'
    []
    [heat_generation]
        type = ScalarLinearCombination
        from = 'alpha_rate_post'
        weights = '${source_coeff}'
        to = 'M3'
    []
    [elout]
        type = ComposedModel
        models = 'reaction_rate_new phi_out wp_state rho cp rhocp K heat_generation'
        additional_outputs = 'phib phip phis'
    []
    ## solid mechanics ----------------------------------------------------------
    [Jthermal]
        type = ThermalDeformationJacobian
        temperature = 'T'
        reference_temperature = '${Tref}'
        CTE = '${g}'
        jacobian = 'Jt'
    []
    [Jvolume]
        type = ScalarLinearCombination
        from = 'V'
        weights = '${o_Vref}'
        to = 'Jv'
    []
    [Jtotal]
        type = ScalarMultiplication
        from = 'Jt Jv'
        to = 'Jtotal'
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
        output = 'pk2'
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
        models = 'Jtotal Jvolume Jthermal totalF green_strain S_pk2 S_pk2_R2 S_pk1'
        additional_outputs = 'Jv Jt pk2'
    []
    [model]
        type = ComposedModel
        models = 'model_solver elout model_sm'
        additional_outputs = 'phiop alpha wb ws wgcp pk2'
    []
[]
