A = 127270000000000.0
Ea = 209015.7262
R = 8.31446261815324
order = 7.3528
mY = -0.5534
mu = 0.001
mzeta = -0.8
Mref = 1.0
rho_s = 2260.0
rho_b = 1250.0
rho_p = 3210.0
rho_g = 13.0
rho_sm1M = 0.0004424778761061947
rho_bm1M = 0.0008
rho_pm1M = 0.00031152647975077883
rho_gm1M = 0.07692307692307693
cp_s = 1592.0
cp_b = 1200.0
cp_p = 750.0
k_s = 150.0
k_b = 279.0
k_p = 380.0
source_coeff = -3570800000.0
E = 400000000000.0
g = 4e-06
Tref = 300.0

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
        models = 'reaction_coef reaction_rate reaction_ode'
    []
    [solve_reaction]
        type = ImplicitUpdate
        equation_system = 'eq_sys'
        solver = 'newton'
    []
    [binder_rate]
        type = ScalarMultiplication
        from = 'mwb0 alpha_rate'
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
        models = 'reaction_rate_new phi_out rho cp rhocp K heat_generation'
        additional_outputs = 'phib phip phis'
    []
    [Jthermal]
        type = ThermalDeformationJacobian
        temperature = 'T'
        reference_temperature = '${Tref}'
        CTE = '${g}'
        jacobian = 'Jt'
    []
    [Jvolume]
        type = ScalarMultiplication
        from = 'o_Vref V'
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
        to = 'pk1_stress'
        invert_B = false
    []
    [model_sm]
        type = ComposedModel
        models = 'Jtotal Jvolume Jthermal totalF green_strain S_pk2 S_pk2_R2 S_pk1'
        additional_outputs = 'Jv Jt'
    []
    [model]
        type = ComposedModel
        models = 'model_solver elout model_sm'
        additional_outputs = 'phiop alpha wb ws wgcp phib phip phis phigcp Jt Jv V'
    []
[]
