############## Input ################
# Simulation parameters
dt = 20
nx = 100
xmax = 100.0

# temperature / heating
Tmax = 1720 #K
T0 = 300 #K
dTdt = -60 #Kmin-1
t_ramp = '${fparse (T0-Tmax)/dTdt*60}' #s
t_hold = 7200 #s
total_time = '${fparse t_ramp + t_hold}'
htc = 20000 #g / s3-K

# density + macroscopic diffusion (M2 = D_macro*rho_Si)
rho_Si = 2.57
D_macro = 0.001 #cm2 s-1

# initial condition
phi_C = 0.3
phi_SiC = 0.3
phi_Si0 = 0.38
phif_min = 0.002

flux_out = 0.1
gravity = 0.0 # cm/s2

[GlobalParams]
    temperature = 'T'
    pressure = 'P'
    fluid_fraction = 'phif'
    displacements = 'disp_x disp_y'
    stabilize_strain = true
[]

[Mesh]
    type = GeneratedMesh
    dim = 2
    nx = '${nx}'
    ny = 6
    xmax = '${xmax}'
    ymax = 10
[]

[Variables]
    [T]
    []
    [P]
    []
    [phif]
    []
[]

[Physics]
    [SolidMechanics]
        [QuasiStatic]
            [sample]
                new_system = true
                add_variables = true
                strain = FINITE
                formulation = TOTAL
                volumetric_locking_correction = true
                generate_output = "pk1_stress_xx pk1_stress_yy pk1_stress_zz 
                                    pk1_stress_xy pk1_stress_xz pk1_stress_yz
                                    max_principal_pk1_stress vonmises_pk1_stress"
            []
        []
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
    []
    [diffusion]
        type = PumaCoupledDiffusion
        material_prop = M2
        variable = phif
        material_fluid_fraction_derivative = dM2dphif
        material_pressure_derivative = dM2dP
        material_temperature_derivative = dM2dT
        material_deformation_gradient_derivative = zeroR2
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
    []
    [source]
        type = CoupledMaterialSource
        material_prop = M5
        coefficient = -1
        variable = phif
        material_fluid_fraction_derivative = dM5dphif
        material_pressure_derivative = dM5dP
        material_temperature_derivative = dM5dT
        material_deformation_gradient_derivative = zeroR2
    []
    ## Pressure ---------------------------------------------------------------
    [L2]
        type = CoupledL2Projection
        material_prop = M6
        variable = P
        material_fluid_fraction_derivative = dM6dphif
        material_pressure_derivative = dM6dP
        material_temperature_derivative = dM6dT
        material_deformation_gradient_derivative = zeroR2
    []
    ## Temperature flow ---------------------------------------------------------
    [temp_time]
        type = PumaCoupledTimeDerivative
        material_prop = M7
        variable = T
        material_fluid_fraction_derivative = dM7dphif
        material_pressure_derivative = dM7dP
        material_temperature_derivative = dM7dT
        material_deformation_gradient_derivative = dM7dF
    []
    [temp_diffusion]
        type = PumaCoupledDiffusion
        material_prop = M8
        variable = T
        material_temperature_derivative = dM8dT
        material_pressure_derivative = dM8dP
        material_fluid_fraction_derivative = dM8dphif
        material_deformation_gradient_derivative = zeroR2
    []
    [temp_darcy_nograv]
        type = PumaCoupledDarcyFlow
        coupled_variable = P
        material_prop = M9
        variable = T
        material_fluid_fraction_derivative = dM9dphif
        material_pressure_derivative = dM9dP
        material_temperature_derivative = dM9dT
        material_deformation_gradient_derivative = zeroR2
    []
    [temp_gravity]
        type = CoupledAdditiveFlux
        material_prop = M10
        value = '0.0 ${gravity} 0.0'
        variable = T
        material_fluid_fraction_derivative = dM10dphif
        material_pressure_derivative = dM10dP
        material_temperature_derivative = dM10dT
        material_deformation_gradient_derivative = zeroR2
    []
    [reaction_heat]
        type = CoupledMaterialSource
        material_prop = M11
        coefficient = -1
        variable = T
        material_temperature_derivative = dM11dT
        material_fluid_fraction_derivative = dM11dphif
        material_pressure_derivative = dM11dP
        material_deformation_gradient_derivative = dM11dF
    []
    ## solid mechanics ---------------------------------------------------------
    [offDiagStressDiv_x]
        type = MomentumBalanceCoupledJacobian
        component = 0
        variable = disp_x
        material_temperature_derivative = dpk1dT
        material_pressure_derivative = zeroR2
        material_fluid_fraction_derivative = dpk1dphif
    []
    [offDiagStressDiv_y]
        type = MomentumBalanceCoupledJacobian
        component = 1
        variable = disp_y
        material_temperature_derivative = dpk1dT
        material_pressure_derivative = zeroR2
        material_fluid_fraction_derivative = dpk1dphif
    []
[]

[NEML2]
    input = 'neml2/aoti/model_aoti.i'
    [all]
        model = 'model'
        device = 'cpu'

        derivatives = 'M1 deformation_gradient dM1dF;
                       M3 T dM3dT; M4 T dM4dT; M5 T dM5dT;
                       M6 T dM6dT; M6 phif dM6dphif;
                       M7 T dM7dT; M7 phif dM7dphif; M7 deformation_gradient dM7dF;
                       M8 T dM8dT; M8 phif dM8dphif;
                       M9 T dM9dT; M10 T dM10dT;
                       M11 T dM11dT; M11 phif dM11dphif; M11 deformation_gradient dM11dF;
                       neml2_pk1 T dpk1dT; neml2_pk1 phif dpk1dphif;
                       pk2 deformation_gradient dpk2_dF;
                       M3 phif dM3dphif; M4 phif dM4dphif; M5 phif dM5dphif;
                       M9 phif dM9dphif; M10 phif dM10dphif;
                       nonliquid phif dnonliquiddphif'

        initialize_outputs = '      phif_s'
        initialize_output_values = 'solidified_fluid'
    []
[]

[Materials]
    [zeroR2]
        type = GenericConstantRankTwoTensor
        tensor_name = 'zeroR2'
        tensor_values = '0 0 0 0 0 0 0 0 0'
    []
    [stress]
        type = ComputeLagrangianStressCustomPK2
        custom_pk2_stress = 'pk2'
        custom_pk2_jacobian = 'dpk2_dF'
        large_kinematics = true
    []
    [parameters]
        type = GenericConstantMaterial
        prop_names = ' phis             phip
                       solidified_fluid'
        prop_values = '${phi_C}         ${phi_SiC}
                       0.0'
    []
    [init_mat]
        type = GenericConstantMaterial
        prop_names = 'M2'
        prop_values = '${fparse D_macro*rho_Si}'
    []
    [zero_mat_derivative]
        type = GenericConstantMaterial
        prop_names = ' dM1dT dM1dphif dM2dT dM2dphif'
        prop_values = '0.0   0.0      0.0   0.0'
    []
    [pressure_nodependence_mat_prop]
        type = GenericConstantMaterial
        prop_names = ' dM1dP dM2dP dM3dP dM4dP dM5dP dM6dP dM7dP dM8dP dM9dP dM10dP dM11dP'
        prop_values = '0.0   0.0   0.0   0.0   0.0   0.0   0.0   0.0   0.0   0.0    0.0'
    []
    [convection]
        type = ADParsedMaterial
        property_name = q_boundary
        expression = 'htc*(T - if(time<t_ramp, Tmax + dTdt/60*time, Tmax + dTdt/60*t_ramp))'
        coupled_variables = T
        constant_names = 'htc t_ramp dTdt  Tmax'
        constant_expressions = '${htc} ${t_ramp} ${dTdt} ${Tmax}'
        postprocessor_names = 'time'
        boundary = 'left'
    []
[]

[AuxVariables]
    [phif_s]
        order = CONSTANT
        family = MONOMIAL
        [AuxKernel]
            type = MaterialRealAux
            property = phif_s
            execute_on = 'INITIAL TIMESTEP_END'
        []
    []
    [phis]
        order = CONSTANT
        family = MONOMIAL
        [AuxKernel]
            type = MaterialRealAux
            property = phis
            execute_on = 'INITIAL TIMESTEP_END'
        []
    []
    [phip]
        order = CONSTANT
        family = MONOMIAL
        [AuxKernel]
            type = MaterialRealAux
            property = phip
            execute_on = 'INITIAL TIMESTEP_END'
        []
    []
    [porosity]
        order = CONSTANT
        family = MONOMIAL
        [AuxKernel]
            type = MaterialRealAux
            property = phif_max
            execute_on = 'INITIAL TIMESTEP_END'
        []
    []
    [phifl_rate]
        order = CONSTANT
        family = MONOMIAL
        [AuxKernel]
            type = MaterialRealAux
            property = M5
            execute_on = 'INITIAL TIMESTEP_END'
        []
    []
    [heat_generate]
        order = CONSTANT
        family = MONOMIAL
        [AuxKernel]
            type = MaterialRealAux
            property = M11
            execute_on = 'INITIAL TIMESTEP_END'
        []
    []
    [nonliquid]
        order = CONSTANT
        family = MONOMIAL
        [AuxKernel]
            type = MaterialRealAux
            property = nonliquid
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
    [Jt]
        order = CONSTANT
        family = MONOMIAL
        [AuxKernel]
            type = MaterialRealAux
            property = Jt
            execute_on = 'INITIAL TIMESTEP_END'
        []
    []
    [Jt_sp]
        order = CONSTANT
        family = MONOMIAL
        [AuxKernel]
            type = MaterialRealAux
            property = Jt_sp
            execute_on = 'INITIAL TIMESTEP_END'
        []
    []
    [Jt_fs]
        order = CONSTANT
        family = MONOMIAL
        [AuxKernel]
            type = MaterialRealAux
            property = Jt_fs
            execute_on = 'INITIAL TIMESTEP_END'
        []
    []
    [dummy]
    []
[]

[Postprocessors]
    [time]
        type = TimePostprocessor
        execute_on = 'INITIAL TIMESTEP_BEGIN'
    []
[]

[Bounds]
    [phif_bound]
        type = ConstantBounds
        bound_value = ${phif_min}
        bounded_variable = phif
        variable = dummy
        bound_type = lower
    []
[]

[ICs]
    [T_IC]
        type = ConstantIC
        variable = T
        value = ${Tmax}
    []
    [phif_IC]
        type = ConstantIC
        variable = phif
        value = ${phi_Si0}
    []
[]

[Functions]
    [tramp]
        type = PiecewiseLinear
        x = '0 ${t_ramp}'
        y = '${Tmax} ${T0}'
    []
    [flux_out]
        type = PiecewiseLinear
        x = '0 ${t_ramp}'
        y = '0 ${flux_out}'
    []
    # [source_middle]
    #     type = ParsedFunction
    #     expression = 'if(x>90, if(x<110, 1.0, 0.0), 0.0)*(-5e6)'
    # []
[]

[BCs]
    [boundary]
        type = ADMatNeumannBC
        boundary_material = q_boundary
        boundary = 'left'
        variable = T
        value = -1
    []
    [roll_y]
        type = DirichletBC
        boundary = 'bottom'
        value = 0.0
        variable = disp_y
    []
    [roll_x]
        type = DirichletBC
        boundary = 'left'
        value = 0.0
        variable = disp_x
    []
[]

[VectorPostprocessors]
    [value]
        type = LineValueSampler
        start_point = '0 0 0'
        end_point = '${xmax} 0 0'
        num_points = ${nx}
        variable = 'phif phif_s phis phip T porosity phifl_rate
                    nonliquid heat_generate permeability P'
        sort_by = 'x'
        execute_on = 'INITIAL TIMESTEP_END'
    []
[]

[Executioner]
    type = Transient
    solve_type = NEWTON

    # petsc_options = '-ksp_converged_reason'
    petsc_options_iname = '-pc_type -snes_type' # -pc_factor_shift_type' #-snes_type'
    petsc_options_value = 'lu vinewtonrsls' # NONZERO' # vinewtonrsls'

    # reuse_preconditioner = true
    # reuse_preconditioner_max_linear_its = 25
    automatic_scaling = true

    # residual_and_jacobian_together = 'true'

    line_search = none

    nl_abs_tol = 1e-05
    nl_rel_tol = 1e-07
    nl_max_its = 12

    l_max_its = 100
    l_tol = 1e-06

    end_time = ${total_time}
    dtmax = '${fparse 100*dt}'

    [TimeStepper]
        type = IterationAdaptiveDT
        dt = ${dt} #s
        optimal_iterations = 7
        iteration_window = 2
        cutback_factor = 0.2
        cutback_factor_at_failure = 0.5
        growth_factor = 1.2
        linear_iteration_ratio = 10000
    []

    [Predictor]
        type = SimplePredictor
        scale = 1.0
        skip_after_failed_timestep = true
    []

    #fixed_point_max_its = 10
    #fixed_point_algorithm = picard
    #fixed_point_abs_tol = 1e-06
    #fixed_point_rel_tol = 1e-08
[]

[Outputs]
    exodus = true
    [console]
        type = Console
        execute_postprocessors_on = 'NONE'
    []
    [csv]
        type = CSV
        file_base = 'example/out'
    []
    print_linear_residuals = false
[]
