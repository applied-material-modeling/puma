############### Input ################
# Simulation parameters
dt = 20
nx = 10

# denisty kgm-3

# heat capacity Jkg-1K-1

# thermal conductivity W/m-1K-1

# reaction type



# models

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
    input = '../../../../neml2_models/aoti/pyrolysis_1d/model_aoti.i'
    [all]
        model = 'model'
        device = 'cpu'

        derivatives = 'M3 T dM3dT; M1 T dM1dT; M2 T dM2dT'

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
    print_linear_residuals = false
[]