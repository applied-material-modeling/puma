############### Calculations ################
# Simulation parameters
dt = 5

t_ramp = '${fparse (Tmax-T0)/dTdt*60}' #s
theat = '${fparse t_ramp+t_hold*3600}'
dTdtcool = '${fparse (Tmax-T0)/(tcool*3600)}' #Ks-1
total_time = '${fparse theat + tcool*3600}'

[GlobalParams]
    displacements = 'disp_x disp_y disp_z'
    temperature = 'T'
    stabilize_strain = true
[]

[Mesh]
    type = GeneratedMesh
    dim = 3
    nx = ${num_el}
    ny = ${num_el}
    nz = ${num_el}
    zmin = 0.01
    xmax = ${L}
    ymax = ${L}
    zmax = ${fparse L+0.01}
[]

[Variables]
    [T]
    []
[]

[Kernels]
    ## Temperature flow ---------------------------------------------------------
    [temp_time]
        type = PumaCoupledTimeDerivative
        material_prop = M1
        variable = T
        material_temperature_derivative = dM1dT
        material_deformation_gradient_derivative = zeroR2
    []
    [temp_diffusion]
        type = PumaCoupledDiffusion
        material_prop = M2
        variable = T
        material_temperature_derivative = dM2dT
        material_deformation_gradient_derivative = zeroR2
    []
    [reaction_heat]
        type = CoupledMaterialSource
        material_prop = M3
        variable = T
        material_temperature_derivative = dM3dT
        material_deformation_gradient_derivative = zeroR2
    []
    ## solid mechanics ---------------------------------------------------------
    [offDiagStressDiv_x]
        type = MomentumBalanceCoupledJacobian
        component = 0
        variable = disp_x
        material_temperature_derivative = dpk1dT
    []
    [offDiagStressDiv_y]
        type = MomentumBalanceCoupledJacobian
        component = 1
        variable = disp_y
        material_temperature_derivative = dpk1dT
    []
    [offDiagStressDiv_z]
        type = MomentumBalanceCoupledJacobian
        component = 2
        variable = disp_z
        material_temperature_derivative = dpk1dT
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
                                    pk1_stress_xy pk1_stress_xz pk1_stress_yz vonmises_pk1_stress
                                    max_principal_pk1_stress"
            []
        []
    []
[]

[NEML2]
    input = 'neml2/aoti/model_aoti.i'
    [all]
        model = 'model'
        device = 'cpu'

        derivatives = 'M3 T dM3dT; M1 T dM1dT; M2 T dM2dT;
                       neml2_pk1 T dpk1dT; pk2 deformation_gradient dpk2_dF'

        initialize_outputs = '      wb  wgcp  ws  alpha  phiop'
        initialize_output_values = 'wb0 wgcp0 ws0 alpha0 phiop0'
    []
[]

[Materials]
    [init_alpha]
        type = GenericConstantMaterial
        prop_names = 'alpha0 phiop0'
        prop_values = '0.0 0.0'
    []
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
    [convection]
        type = ADParsedMaterial
        property_name = q_boundary
        expression = 'htc*(T - if(time<t_ramp,(dTdt/60)*t_ramp,(if(time<theat, Tmax, Tmax-dTdtcool*tcool*3600))))'
        coupled_variables = T
        constant_names = 'htc t_ramp dTdt theat Tmax dTdtcool tcool'
        constant_expressions = '${htc} ${t_ramp} ${dTdt} ${theat} ${Tmax} ${dTdtcool} ${tcool}'
        postprocessor_names = 'time'
        boundary = 'back front bottom top left right'
    []
[]

[Postprocessors]
    [time]
        type = TimePostprocessor
        execute_on = 'INITIAL TIMESTEP_BEGIN'
    []
[]

[AuxVariables]
    [phib]
        order = CONSTANT
        family = MONOMIAL
        [AuxKernel]
            type = MaterialRealAux
            property = phib
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
    [phis]
        order = CONSTANT
        family = MONOMIAL
        [AuxKernel]
            type = MaterialRealAux
            property = phis
            execute_on = 'INITIAL TIMESTEP_END'
        []
    []
    [phigcp]
        order = CONSTANT
        family = MONOMIAL
        [AuxKernel]
            type = MaterialRealAux
            property = phigcp
            execute_on = 'INITIAL TIMESTEP_END'
        []
    []
    [phiop]
        order = CONSTANT
        family = MONOMIAL
        [AuxKernel]
            type = MaterialRealAux
            property = phiop
            execute_on = 'INITIAL TIMESTEP_END'
        []
    []
    [wb]
        order = CONSTANT
        family = MONOMIAL
        [AuxKernel]
            type = MaterialRealAux
            property = wb
            execute_on = 'INITIAL TIMESTEP_END'
        []
    []
    [ws]
        order = CONSTANT
        family = MONOMIAL
        [AuxKernel]
            type = MaterialRealAux
            property = ws
            execute_on = 'INITIAL TIMESTEP_END'
        []
    []
    [wgcp]
        order = CONSTANT
        family = MONOMIAL
        [AuxKernel]
            type = MaterialRealAux
            property = wgcp
            execute_on = 'INITIAL TIMESTEP_END'
        []
    []
    [V]
        order = CONSTANT
        family = MONOMIAL
        [AuxKernel]
            type = MaterialRealAux
            property = V
            execute_on = 'INITIAL TIMESTEP_END'
        []
    []
    [heatsource]
        order = CONSTANT
        family = MONOMIAL
        [AuxKernel]
            type = MaterialRealAux
            property = M3
            execute_on = 'INITIAL TIMESTEP_END'
        []
    []
    [alpha]
        order = CONSTANT
        family = MONOMIAL
        [AuxKernel]
            type = MaterialRealAux
            property = alpha
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
    [Jv]
        order = CONSTANT
        family = MONOMIAL
        [AuxKernel]
            type = MaterialRealAux
            property = Jv
            execute_on = 'INITIAL TIMESTEP_END'
        []
    []
[]

[Functions]
    [temp_profile]
        type = ParsedFunction
        expression = 'if(t<t_ramp,(dTdt/60)*t_ramp,(if(t<theat, Tmax, Tmax-dTdtcool*tcool*3600)))'
        symbol_names = 't_ramp dTdt theat Tmax dTdtcool tcool'
        symbol_values = '${t_ramp} ${dTdt} ${theat} ${Tmax} ${dTdtcool} ${tcool}'
    []
[]

[BCs]
    [boundary]
        type = ADMatNeumannBC
        boundary_material = q_boundary
        boundary = 'back front bottom top left right'
        variable = T
        value = -1
    []
    [bottom]
        type = DirichletBC
        boundary = bottom
        value = 0.0
        variable = disp_y
    []
    [left]
        type = DirichletBC
        boundary = left
        value = 0.0
        variable = disp_x
    []
    [back]
        type = DirichletBC
        boundary = back
        value = 0.0
        variable = disp_z
    []
[]

[Executioner]
  type = Transient
  solve_type = 'newton'

  petsc_options = '-ksp_converged_reason'
  petsc_options_iname = '-pc_type' #-snes_type'
  petsc_options_value = 'lu' # vinewtonrsls'
  automatic_scaling = true
  reuse_preconditioner = true
  reuse_preconditioner_max_linear_its = 25

  residual_and_jacobian_together = 'true'

  line_search = none

  nl_abs_tol = 1e-6
  nl_rel_tol = 1e-8
  nl_max_its = 10

  end_time = ${total_time}
  dtmax = '${fparse 20*dt}'

  [TimeStepper]
    type = IterationAdaptiveDT
    dt = ${dt} #s
    optimal_iterations = 8
    iteration_window = 2
    cutback_factor = 0.5
    cutback_factor_at_failure = 0.2
    growth_factor = 2.0
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
    file_base = 'pyrolysis'
    [console]
        type = Console
        execute_postprocessors_on = 'NONE'
    []
    print_linear_residuals = false
[]