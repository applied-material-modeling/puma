############### Input ################

# Simulation parameters
dt = 5 #s
total_time = 3600 #s

flux_in = 0.1 # volume fraction
flux_out = 0.1
t_ramp = 1000

# density # g cm-3
rho_Si = 2.57 # density at liquid state

# macroscopic property
D_macro = 0.001 #cm2 s-1

# initial condition
phi0_SiC = 0.001
phi0_C = 0.1

gravity = 980.665

# pool information
h0_pool = 1.3
levelset_smooth_transistion = 0.1

[GlobalParams]
    pressure = P
    fluid_fraction = phif
[]

[Mesh]
    [mesh0]
        type = FileMeshGenerator
        file = 'gold/core_in_meltpool.msh'
    []
    [mesh]
        type = BlockDeletionGenerator
        input = mesh0
        block = 'melt_pool'
    []
[]

[MultiApps]
    [melt_pool]
        type = TransientMultiApp
        input_files = 'melt_pool.i'
        cli_args = 'h0=${h0_pool};L0=${levelset_smooth_transistion}' # ';base_folder=${base_folder}'
        catch_up = true
        execute_on = 'TIMESTEP_BEGIN'
    []
[]

[Transfers]
    [volume_rate]
        type = MultiAppPostprocessorTransfer
        to_multi_app = 'melt_pool'
        from_postprocessor = 'volume_rate'
        to_postprocessor = 'volume_rate'
    []
    [M]
        type = MultiAppGeneralFieldNearestLocationTransfer
        from_multi_app = 'melt_pool'
        source_type = 'centroids'
        source_variable = 'M'
        variable = 'M'
        to_boundaries = 'interface'
        error_on_miss = true
    []
[]

[Variables]
    [P]
    []
    [phif]
    []
[]

[AuxVariables]
    [M] # materialization function (from 0 to 1)
        order = CONSTANT
        family = MONOMIAL
        [InitialCondition]
            type = ConstantIC
            value = 1
        []
    []
    [phi_C]
        order = CONSTANT
        family = MONOMIAL
        [AuxKernel]
            type = MaterialRealAux
            property = phis
            execute_on = 'INITIAL TIMESTEP_END'
        []
    []
    [phi_SiC]
        order = CONSTANT
        family = MONOMIAL
        [AuxKernel]
            type = MaterialRealAux
            property = phip
            execute_on = 'INITIAL TIMESTEP_END'
        []
    []
    [phi_nonliquid]
        order = CONSTANT
        family = MONOMIAL
        [AuxKernel]
            type = MaterialRealAux
            property = phif_max
            execute_on = 'INITIAL TIMESTEP_END'
        []
    []
    [porosity]
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

[Kernels]
    [time]
        type = PumaCoupledTimeDerivative
        material_prop = M1
        variable = phif
        material_fluid_fraction_derivative = dM1dphif
        material_pressure_derivative = dM1dP
    []
    [diffusion]
        type = PumaCoupledDiffusion
        material_prop = M2
        variable = phif
        material_fluid_fraction_derivative = dM2dphif
        material_pressure_derivative = dM2dP
    []
    [darcy_nograv]
        type = PumaCoupledDarcyFlow
        coupled_variable = P
        material_prop = M3
        variable = phif
        material_fluid_fraction_derivative = dM3dphif
        material_pressure_derivative = dM3dP
    []
    [gravity]
        type = CoupledAdditiveFlux
        material_prop = M4
        value = '0.0 ${gravity} 0.0'
        variable = phif
        material_fluid_fraction_derivative = dM4dphif
        material_pressure_derivative = dM4dP
    []
    [L2]
        type = CoupledL2Projection
        material_prop = M6
        variable = P
        material_fluid_fraction_derivative = dM6dphif
        material_pressure_derivative = dM6dP
    []
    [source]
        type = CoupledMaterialSource
        material_prop = M5
        coefficient = -1
        variable = phif
        material_fluid_fraction_derivative = dM5dphif
        material_pressure_derivative = dM5dP
    []
[]

[NEML2]
    input = 'neml2/aoti/model_aoti.i'
    [all]
        model = 'model'
        verbose = true
        device = 'cpu'

        derivatives = 'M6 phif dM6dphif; M3 phif dM3dphif; M4 phif dM4dphif;
                       M5 phif dM5dphif; phip phif dphipdphif; phis phif dphisdphif'

        initialize_outputs = '      phip     phis'
        initialize_output_values = 'phi0_SiC phi0_C'
    []
[]

[Materials]
    [constant]
        type = GenericConstantMaterial
        prop_names = 'M1                M2'
        prop_values = '${fparse rho_Si} ${fparse rho_Si*D_macro}'
    []
    [constant_derivative]
        type = GenericConstantMaterial
        prop_names = ' dM1dphif dM1dP dM2dphif dM2dP dM3dP dM4dP dM5dP dM6dP'
        prop_values = '0.0      0.0   0.0      0.0   0.0   0.0   0.0   0.0'
    []
    [constant_material]
        type = GenericConstantMaterial
        prop_names = 'phi0_SiC'
        prop_values = '${phi0_SiC}'
    []
    [phi0_C_constant]
        type = GenericConstantMaterial
        prop_names = phi0_C
        prop_values = '${phi0_C}'
    []
[]

[Postprocessors]
    [time]
        type = TimePostprocessor
        execute_on = 'INITIAL TIMESTEP_BEGIN'
    []
    [volume_rate]
        type = SideDiffusiveFluxIntegral
        diffusivity = Dtotal
        variable = phif
        boundary = 'interface'
        execute_on = 'TIMESTEP_END'
    []
[]

# [VectorPostprocessors]
#     [data_center_line]
#         type = LineValueSampler
#         end_point = '0.001 -0.54 0'
#         num_points = 50
#         sort_by = 'y'
#         start_point = '0.001 0 0'
#         variable = 'phi_SiC void_fraction'
#         execute_on = 'TIMESTEP_END'
#     []
# []

[Functions]
    [flux_in]
        type = PiecewiseLinear
        x = '0 ${t_ramp}'
        y = '0 ${flux_in}'
    []
    [flux_out]
        type = PiecewiseLinear
        x = '0 ${t_ramp}'
        y = '0 ${flux_out}'
    []
[]

[BCs]
    [inlet]
        type = InfiltrationWake
        variable = phif
        boundary = 'interface'
        inlet_flux = 'flux_in'
        outlet_flux = 'flux_out'
        product_fraction = phip
        product_fraction_derivative = dphipdphif
        solid_fraction = phis
        solid_fraction_derivative = dphisdphif
        no_flux_fraction_transition = 0.1
        multiplier = M
    []
[]

[Executioner]
    type = Transient
    solve_type = 'newton'
    petsc_options_iname = '-pc_type' #-snes_type'
    petsc_options_value = 'lu' # vinewtonrsls'
    automatic_scaling = true

    line_search = none

    nl_abs_tol = 1e-06
    nl_rel_tol = 1e-08
    nl_max_its = 12

    end_time = ${total_time}
    dtmax = '${fparse 100*dt}'

    [TimeStepper]
        type = IterationAdaptiveDT
        dt = ${dt} #s
        optimal_iterations = 6
        iteration_window = 2
        cutback_factor = 0.5
        cutback_factor_at_failure = 0.1
        growth_factor = 1.2
        linear_iteration_ratio = 10000
    []

    #fixed_point_max_its = 10
    #fixed_point_algorithm = picard
    #fixed_point_abs_tol = 1e-06
    #fixed_point_rel_tol = 1e-08
[]

[Outputs]
    exodus = true
    ## file_base = '${base_folder}/core'
    [console]
        type = Console
        execute_postprocessors_on = 'NONE'
    []
    [csv]
        type = CSV
        ## file_base = '${base_folder}/out'
    []
    print_linear_residuals = false
[]