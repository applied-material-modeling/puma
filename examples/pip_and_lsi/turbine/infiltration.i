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
    input = 'neml2/aoti_infiltration/model_aoti.i'
    [all]
        model = 'model'
        verbose = true
        device = 'cpu'

        derivatives = 'M5 phif dM5dphif; M1 deformation_gradient dM1dF;
                       pk1_stress deformation_gradient pk1_jacobian;
                       pk1_stress T dpk1dT;
                       M4 phif dM4dphif; M9 phif dM9dphif'
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
    # phif_max (maximum fluid fraction) is the pyrolysis open porosity carried in
    # as material 'void' (from initial_condition_from_exodus_3.i). NEML2 gathers it
    # by name as a bare input.
    [phif_max_mat]
        type = ParsedMaterial
        property_name = phif_max
        material_property_names = 'void'
        expression = 'void'
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
