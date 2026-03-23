############### Input ################
# Simulation parameters
dt = 5
nx = 20
ny = 20
xmax = 0.5

# denisty kgm-3
rho_s = 2100
rho_b = 1250 # 1.2 and 1.4
rho_p = 3210

# heat capacity Jkg-1K-1
cp_s = 1592
cp_b = 1200
cp_g = 1e-4
cp_p = 750

# thermal conductivity W/m-1K-1
k_s = 150
k_b = 279
k_g = 1e-4
k_p = 380 #120 and 490

# reaction type
Ea = 21191.61425 # 177820 # J mol-1
A = 0.0421047 # 5.24e12 # s-1
R = 8.31446261815324 # JK-1mol-1
hrp = 1.58e5 # J kg-1

Y = 0.575
order = 1.0

# models
pyro_mu = 0.015 # wgcp vs wg
zeta = 0.03 # phiop vs wbdot
rho_g = 13 #kgm-3

# initial condition
ms0 = 3.0
mb0 = 10
mp0 = 5.0
mg0 = 0.0
mgcp0 = '${fparse mg0}'
phiop0 = 0.001 #void fraction
T0 = 300 #K

# calculations
Mref = '${fparse ms0 + mb0 + mp0 + mg0}'
wb0 = '${fparse mb0/Mref}'
ws0 = '${fparse ms0/Mref}'
wp0 = '${fparse mp0/Mref}'
wgcp0 = '${fparse mgcp0/Mref}'
V0 = '${fparse (ms0/rho_s + mb0/rho_b + mp0/rho_p + mgcp0/rho_g)/(1 - phiop0)}'
alpha0 = 0.0 # initial reaction progress

Tmax = 1000 #K
dTdt = 20 #Kmin-1 heating rate
t_ramp = '${fparse (Tmax-T0)/dTdt*60}' #s
t_hold = 2 #hrs
theat = '${fparse t_ramp+t_hold*3600}'
tcool = 2 #hrs
dTdtcool = '${fparse (Tmax-T0)/(tcool*3600)}' #Ks-1

total_time = '${fparse theat + tcool*3600}'

#### stress-strain ####
E = 400e9

# thermal expansion coefficients (degree-1)
Tref = 300 #K
g = 4e-6

#boundary conditions
htc = 200 #Wm-2K assume air doesnt move much

[GlobalParams]
    temperature = 'T'
    stabilize_strain = true
    displacements = 'disp_x disp_y'
[]

[Mesh]
    type = GeneratedMesh
    dim = 2
    nx = '${nx}'
    ny = '${ny}'
    xmax = '${xmax}'
    ymax = '${xmax}'
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
                                    pk1_stress_xy pk1_stress_xz pk1_stress_yz vonmises_pk1_stress"
            []
        []
    []
[]

[NEML2]
    input = 'neml2/neml2_material.i'
    cli_args = 'rho_s=${rho_s} rho_b=${rho_b} rho_g=${rho_g} rho_p=${rho_p} Mref=${Mref}
                rho_sm1M=${fparse Mref/rho_s} rho_bm1M=${fparse Mref/rho_b}
                rho_gm1M=${fparse Mref/rho_g} rho_pm1M=${fparse Mref/rho_p}
                cp_s=${cp_s} cp_b=${cp_b} cp_g=${cp_g} cp_p=${cp_p}
                k_s=${k_s} k_b=${k_b} k_g=${k_g} k_p=${k_p}
                Ea=${Ea} A=${A} R=${R} mY=${fparse -Y}
                order=${order} source_coeff=${fparse -rho_s*hrp}
                mu=${pyro_mu} mzeta=${fparse -zeta}
                ws0=${ws0} wb0=${wb0} E=${E} g=${g} E=${E} Tref=${Tref}'
    [all]
        model = 'model'
        verbose = true
        device = 'cpu'

        moose_input_types = 'VARIABLE     POSTPROCESSOR POSTPROCESSOR   MATERIAL        MATERIAL
                             MATERIAL     MATERIAL      MATERIAL        MATERIAL        MATERIAL'
        moose_inputs = '     T            time          time            alpha           alpha
                             wb           ws            wgcp            phiop           deformation_gradient'
        neml2_inputs = '     forces/T     forces/t      old_forces/t    old_state/alpha state/alpha
                             old_state/wb old_state/ws  old_state/wgcp  old_state/phiop forces/F'

        moose_parameter_types = 'MATERIAL        MATERIAL        MATERIAL'
        moose_parameters = '     wp              mwb0            o_Vref'
        neml2_parameters = '     wp_state_param  binder_rate_c_0 Jvolume_c_0'

        moose_output_types = 'MATERIAL        MATERIAL   MATERIAL   MATERIAL     MATERIAL
                              MATERIAL        MATERIAL   MATERIAL   MATERIAL     MATERIAL
                              MATERIAL        MATERIAL   MATERIAL   MATERIAL     MATERIAL'
        moose_outputs = '     phiop           wb         ws         wgcp         pk1_stress
                              phib            phip       phis       phigcp       alpha
                              M3              M2         M1         Jt           Jv'
        neml2_outputs = '     state/phiop     state/wb   state/ws   state/wgcp   state/pk1
                              state/phib      state/phip state/phis state/phigcp state/alpha
                              state/M3        state/M2   state/M1   state/Jt     state/Jv'

        moose_derivative_types = 'MATERIAL            MATERIAL              MATERIAL
                                  MATERIAL            MATERIAL'
        moose_derivatives = '     dM3dT               dM1dT                 dM2dT
                                  dpk1dT              pk1_jacobian'
        neml2_derivatives = '     state/M3 forces/T;  state/M1 forces/T;    state/M2 forces/T;
                                  state/pk1 forces/T; state/pk1 forces/F'

        initialize_outputs = '      wb  wgcp  ws  alpha  phiop'
        initialize_output_values = 'wb0 wgcp0 ws0 alpha0 phiop0'
    []
[]

[Materials]
    [zeroR2]
        type = GenericConstantRankTwoTensor
        tensor_name = 'zeroR2'
        tensor_values = '0 0 0 0 0 0 0 0 0'
    []
    [init_mat]
        type = GenericConstantMaterial
        prop_names = 'wp wb0 wgcp0 ws0 alpha0 phiop0 mwb0 o_Vref'
        prop_values = '${wp0} ${wb0} ${wgcp0} ${ws0} ${alpha0} ${phiop0} ${fparse -wb0} ${fparse 1/V0}'
    []
    [convection]
        type = ADParsedMaterial
        property_name = q_boundary
        expression = 'htc*(T - if(time<t_ramp,(dTdt/60)*t_ramp,(if(time<theat, Tmax, Tmax-dTdtcool*tcool*3600))))'
        coupled_variables = T
        constant_names = 'htc t_ramp dTdt theat Tmax dTdtcool tcool'
        constant_expressions = '${htc} ${t_ramp} ${dTdt} ${theat} ${Tmax} ${dTdtcool} ${tcool}'
        postprocessor_names = 'time'
        boundary = 'top right'
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

[ICs]
    [TIC]
        type = ConstantIC
        variable = T
        value = ${T0}
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
        boundary = 'top right'
        variable = T
        value = -1
    []
    [roller_left]
        type = DirichletBC
        boundary = left
        value = 0.0
        variable = disp_x
    []
    [roller_bot]
        type = DirichletBC
        boundary = bottom
        value = 0.0
        variable = disp_y
    []
[]

[Executioner]
    type = Transient
    solve_type = 'newton'
    petsc_options_iname = '-pc_type -snes_type'
    petsc_options_value = 'lu vinewtonrsls'
    automatic_scaling = true

    nl_abs_tol = 1e-8

    end_time = ${total_time}
    dtmax = '${fparse 50*dt}'

    [TimeStepper]
        type = IterationAdaptiveDT
        dt = ${dt} #s
        optimal_iterations = 7
        iteration_window = 2
        cutback_factor = 0.5
        cutback_factor_at_failure = 0.1
        growth_factor = 1.2
        linear_iteration_ratio = 10000
    []
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