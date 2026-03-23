############### Calculations ################
dt = 5
phi_L_residual = 0.0

t_ramp = '${fparse (Tmax-T0)/dTdt*60}' #s
theat = '${fparse t_ramp+t_hold*3600}'
dTdtcool = '${fparse (Tmax-T0)/(tcool*3600)}' #Ks-1
total_time = '${fparse theat + tcool*3600}'

[GlobalParams]
    displacements = 'disp_x disp_y disp_z'
    temperature = 'T'
    fluid_fraction = 'phif'
    pressure = 'P'
[]

[Variables]
    [P]
    []
    [phif]
    []
    [T]
    []
[]

[Kernels]
    ## Fluid flow ---------------------------------------------------------
    [time]
        type = PumaCoupledTimeDerivative
        material_prop = M1
        variable = phif
        material_fluid_fraction_derivative = dM1dphif
        material_pressure_derivative = dM1dP
        material_temperature_derivative = dM1dT
        material_deformation_gradient_derivative = dM1dF
        stabilize_strain = true
    []
    [diffusion]
        type = PumaCoupledDiffusion
        material_prop = M2
        variable = phif
        material_fluid_fraction_derivative = dM2dphif
        material_pressure_derivative = dM2dP
        material_temperature_derivative = dM2dT
        material_deformation_gradient_derivative = zeroR2
        stabilize_strain = true
    []
    [darcy_nograv]
        type = PumaCoupledDarcyFlow
        coupled_variable = P
        material_prop = M3
        variable = phif
        material_fluid_fraction_derivative = dM3dphif
        material_pressure_derivative = dM3dP
        material_temperature_derivative = dM3dT
        material_deformation_gradient_derivative = zeroR2
        stabilize_strain = true
    []
    [gravity]
        type = CoupledAdditiveFlux
        material_prop = M4
        value = '0.0 ${gravity} 0.0'
        variable = phif
        material_fluid_fraction_derivative = dM4dphif
        material_pressure_derivative = dM4dP
        material_temperature_derivative = dM4dT
        material_deformation_gradient_derivative = zeroR2
        stabilize_strain = true
    []
    [L2]
        type = CoupledL2Projection
        material_prop = M5
        variable = P
        material_fluid_fraction_derivative = dM5dphif
        material_pressure_derivative = dM5dP
        material_temperature_derivative = dM5dT
        material_deformation_gradient_derivative = zeroR2
        stabilize_strain = true
    []
    ## Temperature flow ---------------------------------------------------------
    [temp_time]
        type = PumaCoupledTimeDerivative
        material_prop = M6
        variable = T
        material_fluid_fraction_derivative = dM6dphif
        material_pressure_derivative = dM6dP
        material_temperature_derivative = dM6dT
        material_deformation_gradient_derivative = zeroR2
        stabilize_strain = true
    []
    [temp_diffusion]
        type = PumaCoupledDiffusion
        material_prop = M7
        variable = T
        material_fluid_fraction_derivative = dM7dphif
        material_pressure_derivative = dM7dP
        material_temperature_derivative = dM7dT
        material_deformation_gradient_derivative = zeroR2
        stabilize_strain = true
    []
    [temp_darcy_nograv]
        type = PumaCoupledDarcyFlow
        coupled_variable = P
        material_prop = M8
        variable = T
        material_fluid_fraction_derivative = dM8dphif
        material_pressure_derivative = dM8dP
        material_temperature_derivative = dM8dT
        material_deformation_gradient_derivative = zeroR2
        stabilize_strain = true
    []
    [temp_gravity]
        type = CoupledAdditiveFlux
        material_prop = M9
        value = '0.0 ${gravity} 0.0'
        variable = T
        material_fluid_fraction_derivative = dM9dphif
        material_pressure_derivative = dM9dP
        material_temperature_derivative = dM9dT
        material_deformation_gradient_derivative = zeroR2
        stabilize_strain = true
    []
    ##
    ## solid mechanics ---------------------------------------------------------
    [offDiagStressDiv_x]
        type = MomentumBalanceCoupledJacobian
        component = 0
        variable = disp_x
        material_fluid_fraction_derivative = zeroR2
        material_pressure_derivative = zeroR2
        material_temperature_derivative = dpk1dT
    []
    [offDiagStressDiv_y]
        type = MomentumBalanceCoupledJacobian
        component = 1
        variable = disp_y
        material_fluid_fraction_derivative = zeroR2
        material_pressure_derivative = zeroR2
        material_temperature_derivative = dpk1dT
    []
    [offDiagStressDiv_z]
        type = MomentumBalanceCoupledJacobian
        component = 2
        variable = disp_z
        material_fluid_fraction_derivative = zeroR2
        material_pressure_derivative = zeroR2
        material_temperature_derivative = dpk1dT
    []
[]

[NEML2]
    input = 'neml2/infiltration.i'
    cli_args = 'kk_L=${kk_b} permeability_power=${permeability_power} rhof_nu=${fparse rho_b/mu_b}
              rhof2_nu=${fparse rho_b^2/mu_b} phif_residual=${phi_L_residual} rho_f=${fparse rho_b}
              brooks_corey_threshold=${brooks_corey_threshold} capillary_pressure_power=${capillary_pressure_power}
              hf_rhof_nu=${fparse hf*rho_b/mu_b} swelling_coefficient=0.0
              hf_rhof2_nu=${fparse hf*rho_b^2/mu_b} therm_expansion=${g} Tref=${Tref}
              E=${E}'
    [all]
        model = 'model'
        verbose = true
        device = 'cpu'

        moose_input_types = 'VARIABLE    VARIABLE MATERIAL'
        moose_inputs = '     phif        T        deformation_gradient'
        neml2_inputs = '     forces/phif forces/T forces/F'

        moose_parameter_types = 'MATERIAL       MATERIAL    MATERIAL'
        moose_parameters = '     void           o_Vref      V'
        neml2_parameters = '     phif_max_param Jvolume_c_0 V_param'

        moose_output_types = 'MATERIAL   MATERIAL MATERIAL   MATERIAL    MATERIAL
                              MATERIAL   MATERIAL MATERIAL   MATERIAL    MATERIAL   MATERIAL'
        moose_outputs = '     pk1_stress M1       M3         M4          M5
                              M8         M9       poro       phis        perm       pk2_stress'
        neml2_outputs = '     state/pk1 state/M1  state/M3   state/M4    state/M5
                              state/M8  state/M9  state/poro state/solid state/perm state/pk2'

        moose_derivative_types = 'MATERIAL               MATERIAL             MATERIAL
                                  MATERIAL
                                  MATERIAL               MATERIAL'
        moose_derivatives = '     dM5dphif               dM1dF                pk1_jacobian
                                  dpk1dT
                                  dM4dphif               dM9dphif'
        neml2_derivatives = '     state/M5  forces/phif; state/M1 forces/F;   state/pk1 forces/F;
                                  state/pk1 forces/T;
                                  state/M4  forces/phif; state/M9 forces/phif'
    []
[]

[Materials]
    [constant]
        type = GenericConstantMaterial
        prop_names = 'M2                        M6                     M7'
        prop_values = '${fparse rho_b*D_macro} ${fparse rho_b*cp_b} ${fparse k_b}'
    []
    [constant_derivative]
        type = GenericConstantMaterial
        prop_names = ' dM1dP    dM1dphif dM1dT dM2dphif dM2dP dM2dT
                       dM3dphif dM3dP    dM3dT dM4dP    dM4dT dM5dP dM5dT
                       dM6dP    dM6dphif dM6dT dM7dphif dM7dP dM7dT
                       dM8dphif dM8dP    dM8dT dM9dP    dM9dT'
        prop_values = '0.0      0.0      0.0   0.0      0.0   0.0
                       0.0      0.0      0.0   0.0      0.0   0.0   0.0
                       0.0      0.0      0.0   0.0      0.0   0.0
                       0.0      0.0      0.0   0.0      0.0'
    []
    [zeroR2]
        type = GenericConstantRankTwoTensor
        tensor_name = 'zeroR2'
        tensor_values = '0 0 0 0 0 0 0 0 0'
    []
    [convection]
        type = ADParsedMaterial
        property_name = q_boundary
        expression = 'htc*(T - if(time<t_ramp,T0+(dTdt/60)*t_ramp,(if(time<theat, Tmax, Tmax-dTdtcool*tcool*3600))))'
        coupled_variables = T
        constant_names = 'htc t_ramp dTdt theat Tmax dTdtcool tcool T0'
        constant_expressions = '${htc} ${t_ramp} ${dTdt} ${theat} ${Tmax} ${dTdtcool} ${tcool} ${T0}'
        postprocessor_names = 'time'
        boundary = 'interface'
    []
[]

[Postprocessors]
    [time]
        type = TimePostprocessor
        execute_on = 'INITIAL TIMESTEP_BEGIN'
    []
[]

[VectorPostprocessors]
    [composition_info]
        type = ElementMaterialSampler
        property = 'phiop phigcp ws wp wgcp max_principal_pk1_stress'
        execute_on = 'FINAL'
    []
[]

[AuxVariables]
    [dummy]
    []
    [init_void]
        order = CONSTANT
        family = MONOMIAL
        [AuxKernel]
            type = MaterialRealAux
            property = void
            execute_on = 'INITIAL TIMESTEP_END'
        []
    []
    [void]
        order = CONSTANT
        family = MONOMIAL
        [AuxKernel]
            type = MaterialRealAux
            property = poro
            execute_on = 'INITIAL TIMESTEP_END'
        []
    []
    [permeability]
        order = CONSTANT
        family = MONOMIAL
        [AuxKernel]
            type = MaterialRealAux
            property = perm
            execute_on = 'INITIAL TIMESTEP_END'
        []
    []
[]

[Functions]
    [flux_in]
        type = PiecewiseLinear
        x = '0 ${t_ramp} ${theat}'
        y = '0 0         ${flux_in} '
    []
    [flux_out]
        type = PiecewiseLinear
        x = '0 ${t_ramp} ${theat}'
        y = '0 0         ${flux_out}'
    []
[]

[BCs]
    [boundary]
        type = ADMatNeumannBC
        boundary_material = q_boundary
        boundary = 'interface'
        variable = T
        value = -1
    []
    [inlet]
        type = InfiltrationWake
        boundary = 'interface'
        inlet_flux = flux_in
        outlet_flux = 0.0
        product_fraction = 0.0
        product_fraction_derivative = 0.0
        solid_fraction = phi_solid
        solid_fraction_derivative = 0.0
        variable = phif
    []
[]

[Executioner]
    type = Transient
    solve_type = NEWTON

    petsc_options = '-ksp_converged_reason'
    petsc_options_iname = '-pc_type' # -pc_factor_shift_type' #'
    petsc_options_value = 'lu' # NONZERO' # '

    reuse_preconditioner = true
    reuse_preconditioner_max_linear_its = 25
    automatic_scaling = true

    residual_and_jacobian_together = 'true'

    line_search = none

    nl_abs_tol = 1e-05
    nl_rel_tol = 1e-07
    nl_max_its = 12

    l_max_its = 100
    l_tol = 1e-06

    end_time = ${total_time}
    dtmax = '${fparse 10*dt}'

    [TimeStepper]
        type = IterationAdaptiveDT
        dt = ${dt} #s
        optimal_iterations = 7
        iteration_window = 2
        cutback_factor = 0.2
        cutback_factor_at_failure = 0.1
        growth_factor = 1.2
        linear_iteration_ratio = 10000
    []

    [Predictor]
        type = SimplePredictor
        scale = 1.0
        skip_after_failed_timestep = true
    []
[]

[Outputs]
    exodus = true
    file_base = '${save_folder}/out_cycle${save_cycle}_${save_type}'
    [console]
        type = Console
        execute_postprocessors_on = 'NONE'
    []
    [csv]
        type = CSV
        file_base = '${save_folder}/out_cycle${save_cycle}_${save_type}'
        execute_on = 'FINAL'
        create_final_symlink = true
    []
    print_linear_residuals = false
[]