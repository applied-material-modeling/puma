# Bare-name constants header (driver overwrites at runtime; only valid floats needed to compile)
A = 1000000000000.0
Ea = 98000.0
R = 8.31446261815324
order = 1.0
mY = -0.25
mu = 0.0
mzeta = -0.95
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
source_coeff = -357080000.0
Tref = 300.0
g = 1e-06
E = 400000000000.0
cws = 0.25
cwgcp = 0.0
cphiop = 0.95

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
        models = 'reaction_coef reaction_rate reaction_ode'
    []
    [solve_reaction]
        type = ImplicitUpdate
        equation_system = 'eq_sys'
        solver = 'newton'
    []
    # Mass fractions as algebraic functions of the bounded conversion alpha
    # (see pyrolysis.i). wb0,ws0,wgcp0,phiop0 are spatial gathered inputs.
    #   wb    = wb0 * (1 - alpha)
    #   ws    = ws0    + cws    * wb0 * alpha   (cws    = -mY)
    #   wgcp  = wgcp0  + cwgcp  * wb0 * alpha   (cwgcp  = mu*(1+mY))
    #   phiop = phiop0 + cphiop * wb0 * alpha   (cphiop = -mzeta)
    [wb0_alpha]
        type = ScalarMultiplication
        from = 'wb0 alpha'
        to = 'wb0_alpha'
    []
    [binder]
        type = ScalarLinearCombination
        from = 'wb0 wb0_alpha'
        weights = '1.0 -1.0'
        to = 'wb'
    []
    [curebinder]
        type = ScalarLinearCombination
        from = 'ws0 wb0_alpha'
        weights = '1.0 ${cws}'
        to = 'ws'
    []
    [gas]
        type = ScalarLinearCombination
        from = 'wgcp0 wb0_alpha'
        weights = '1.0 ${cwgcp}'
        to = 'wgcp'
    []
    [open_pore]
        type = ScalarLinearCombination
        from = 'phiop0 wb0_alpha'
        weights = '1.0 ${cphiop}'
        to = 'phiop'
    []
    [model_solver]
        type = ComposedModel
        models = "solve_reaction reaction_coef reaction_rate
                wb0_alpha binder curebinder gas open_pore"
        additional_outputs = 'alpha k'
    []
    ################################### POST PROCESS #################################
    #########
    ############### volume fraction ######
    # wp (SiC) and wc (cured resin carried from prior cycle) are spatial gathered
    # inputs from MOOSE.
    [V_RVE_post]
        type = EffectiveVolume
        reference_mass = '${Mref}'
        mass_fractions = 'wb ws wp wgcp wc'
        densities = '${rho_b} ${rho_b} ${rho_p} ${rho_g} ${rho_s}'
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
        scaling = '${rho_bm1M}'
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
    [phi_c]
        type = ScalarMultiplication
        scaling = '${rho_sm1M}'
        from = 'wc V'
        to = 'phic'
        reciprocal = 'false true'
    []
    [phi_out]
        type = ComposedModel
        models = 'V_RVE_post phi_b phi_s phi_p phi_gcp phi_c'
        additional_outputs = 'V'
    []
    #########
    ######### element properties
    [rho]
        type = ScalarLinearCombination
        weights = '${rho_p} ${rho_b} ${rho_b} ${rho_s}'
        from = 'phip phib phis phic'
        to = 'rho'
    []
    [cp]
        type = ScalarLinearCombination
        weights = '${cp_p} ${cp_b} ${cp_b} ${cp_s}'
        from = 'wp wb ws wc'
        to = 'cp'
    []
    [rhocp]
        type = ScalarMultiplication
        from = 'rho cp'
        to = 'M1'
    []
    [K]
        type = ScalarLinearCombination
        weights = '${k_p} ${k_b} ${k_b} ${k_s}'
        from = 'phip phib phis phic'
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
        additional_outputs = 'phib phip phis phic'
    []
    ## solid mechanics ----------------------------------------------------------
    [Jthermal]
        type = ThermalDeformationJacobian
        temperature = 'T'
        reference_temperature = '${Tref}'
        CTE = '${g}'
        jacobian = 'Jt'
    []
    # Jv = V * o_Vref = current composite volume / reference volume.
    # o_Vref (=1/Vref) is a spatial gathered input from MOOSE.
    [Jvolume]
        type = ScalarMultiplication
        from = 'V o_Vref'
        to = 'Jv'
    []
    # -----------------------------
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
    ########
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
    [model_sm]
        type = ComposedModel
        models = ' Jtotal Jvolume
                  Jthermal totalF green_strain S_pk2 S_pk2_R2 S_pk1'
        additional_outputs = 'Jv Jt pk2_stress'
    []
    #######################################################################################
    [model]
        type = ComposedModel
        models = 'model_solver elout model_sm'
        additional_outputs = 'phiop alpha wb ws wgcp V'
    []
    #######################################################################################
[]
