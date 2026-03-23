############### Input ################
# Simulation parameters
dt = 20
nx = 100

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
pyro_mu = 0.05 # wgcp vs wg
zeta = 0.05 # phiop vs alphadot
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

alpha0 = 0.0 # initial reaction progress

Tmax = 1100 #K
# Tref = 300 #K

dTdt = 10 #Kmin-1 heating rate
t_ramp = '${fparse (Tmax-T0)/dTdt*60}' #s
total_time = '${fparse t_ramp*2}' #'${fparse 3600*1.75}'

xmax = 2.0

[GlobalParams]
    temperature = 'T'
[]

[Mesh]
    type = GeneratedMesh
    dim = 1
    nx = '${nx}'
    xmax = '${xmax}'
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
    []
    [temp_diffusion]
        type = PumaCoupledDiffusion
        material_prop = M2
        variable = T
        material_temperature_derivative = dM2dT
    []
    [reaction_heat]
        type = CoupledMaterialSource
        material_prop = M3
        variable = T
        material_temperature_derivative = dM3dT
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
                ws0=${ws0} wb0=${wb0}'
    [all]
        model = 'model'
        verbose = true
        device = 'cpu'

        moose_input_types = 'VARIABLE     POSTPROCESSOR POSTPROCESSOR   MATERIAL        MATERIAL
                             MATERIAL     MATERIAL      MATERIAL        MATERIAL'
        moose_inputs = '     T            time          time            alpha           alpha
                             wb           ws            wgcp            phiop'
        neml2_inputs = '     forces/T     forces/t      old_forces/t    old_state/alpha  state/alpha
                             old_state/wb old_state/ws  old_state/wgcp  old_state/phiop'

        moose_parameter_types = 'MATERIAL        MATERIAL        '
        moose_parameters = '     wp              mwb0            '
        neml2_parameters = '     wp_state_param  binder_rate_c_0 '

        moose_output_types = 'MATERIAL        MATERIAL   MATERIAL   MATERIAL
                              MATERIAL        MATERIAL   MATERIAL   MATERIAL     MATERIAL
                              MATERIAL        MATERIAL   MATERIAL   MATERIAL'
        moose_outputs = '     phiop           wb         ws         wgcp
                              phib            phip       phis       phigcp       alpha
                              M3              M2         V          M1'
        neml2_outputs = '     state/phiop     state/wb   state/ws   state/wgcp
                              state/phib      state/phip state/phis state/phigcp state/alpha
                              state/M3        state/M2   state/V    state/M1'

        moose_derivative_types = 'MATERIAL           MATERIAL              MATERIAL'
        moose_derivatives = '     dM3dT              dM1dT                 dM2dT'
        neml2_derivatives = '     state/M3 forces/T; state/M1 forces/T;    state/M2 forces/T'

        initialize_outputs = '      wb  wgcp  ws  alpha  phiop'
        initialize_output_values = 'wb0 wgcp0 ws0 alpha0 phiop0'
    []
[]

[Materials]
    [init_mat]
        type = GenericConstantMaterial
        prop_names = 'wp wb0 wgcp0 ws0 alpha0 phiop0 mwb0'
        prop_values = '${wp0} ${wb0} ${wgcp0} ${ws0} ${alpha0} ${phiop0} ${fparse -wb0}'
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
    [V]
        order = CONSTANT
        family = MONOMIAL
        [AuxKernel]
            type = MaterialRealAux
            property = V
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
[]

[VectorPostprocessors]
    [line]
        type = LineValueSampler
        end_point = '${xmax} 0 0'
        num_points = ${nx}
        sort_by = 'x'
        start_point = '0 0 0'
        variable = 'T phib phip phis phiop phigcp heatsource V wb ws alpha'
    []
[]

[ICs]
    [alphaIC]
        type = ConstantIC
        variable = T
        value = ${T0}
    []
[]

[Functions]
    [tramp]
        type = PiecewiseLinear
        x = '0 ${t_ramp}'
        y = '${T0} ${Tmax}'
    []
[]

[BCs]
    [left]
        type = FunctionDirichletBC
        boundary = left
        variable = T
        function = tramp
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
    dtmax = '${fparse 10*dt}'

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