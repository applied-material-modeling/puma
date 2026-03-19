############### Input ################

# Simulation parameters
dt = 5 #s
total_time = 1800 #s

flux_in = 0.1 # volume fraction
flux_out = 0.5
t_ramp = 500

# Molar Mass # g mol-1
M_Si = 28.085
M_SiC = 40.11
M_C = 12.011

# denisty # g cm-3
rho_Si = 2.57 # density at liquid state
rho_SiC = 3.21
rho_C = 2.26

# material property
D_LP = 9.5e-6 # cm2 s-1
l_c = 0.1 # cm
h_c = 0.0076 # cm
K_nucl_growth = 1.2e-15 # cm s-1

brooks_corey_threshold = 0.5e5 #Pa
capillary_pressure_power = 10
phi_L_residual = 0.0

permeability_power = 20.0

# liquid viscosity
mu_Si = 0.01

# solid reference permeability
kk_ref = 1e-8

# chemical reaction constant
k_C = 1.0
k_SiC = 1.0

# macroscopic property
D_macro = 0.0007 #cm2 s-1
D_macro_high = 0.04 # cm2 s-1
D_macro_low = 0.0007 #0.003 # cm2 s-1

transition_saturation_front = 0.75
transition_saturation_back = 0.25
transition_saturation_back_start = 0.45

# initial condition
phi0_SiC = 0.0
phi0_C = 0.85

gravity = 980.665

# pool information
h0_pool = 0.76
levelset_smooth_transistion = 0.1
apparent_density = 0.3225925301 # g cm-3

## Calculations
D_bar = '${fparse D_LP/(l_c)}'

omega_C = '${fparse M_C/rho_C}'
omega_Si = '${fparse M_Si/rho_Si}'
omega_SiC = '${fparse M_SiC/rho_SiC}'

oCm1 = '${fparse 1/omega_C}'
oSiCm1 = '${fparse 1/omega_SiC}'

chem_ratio = '${fparse k_SiC/k_C}'

scale_flux = '${fparse rho_Si/apparent_density}'
new_scale = '${fparse (transition_saturation_back-transition_saturation_back_start)/2}'


[GlobalParams]
    pressure = P
    fluid_fraction = phif
[]

[Mesh]
    [mesh0]
        type = FileMeshGenerator
        file = 'gold/core.msh'
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
            property = non_liquid
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
    [M2]
        order = CONSTANT
        family = MONOMIAL
        [AuxKernel]
        type = MaterialRealAux
        property = M2
        execute_on = 'INITIAL TIMESTEP_END'
        []
    []
    [Seff]
        order = CONSTANT
        family = MONOMIAL
        [AuxKernel]
        type = MaterialRealAux
        property = Seff
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
    input = 'neml2/neml2_material.i'
    cli_args = 'kk_L=${kk_ref} permeability_power=${permeability_power} rhof_nu=${fparse rho_Si/mu_Si}
              rhof2_nu=${fparse rho_Si^2/mu_Si} phif_residual=${phi_L_residual} rhof=${fparse rho_Si}
              omega_Si=${omega_Si} D=${D_bar} oSiCm1=${oSiCm1} oCm1=${oCm1} oP_oL=${fparse omega_SiC/omega_Si}
              chem_ratio=${chem_ratio} mchem_P=${fparse -k_SiC}
              brooks_corey_threshold=${brooks_corey_threshold}
              K_nucl_growth=${fparse K_nucl_growth/l_c} mhcolc=${fparse -h_c/l_c} omega_SiC=${omega_SiC}
              Dmacro=${D_macro} delta_Dscale_front=${fparse D_macro_high-D_macro}
              delta_Dscale_back=${fparse D_macro_low-D_macro}
              rhof = ${rho_Si} new_scale=${new_scale} transition_saturation_back=${transition_saturation_back}
              transition_saturation_back_start=${transition_saturation_back_start}
              transition_saturation_front=${transition_saturation_front}
              capillary_pressure_power=${capillary_pressure_power}
              scale_flux=${scale_flux}'
    [all]
        model = 'model'
        verbose = true
        device = 'cpu'

        moose_input_types = 'POSTPROCESSOR POSTPROCESSOR  VARIABLE
                             MATERIAL      MATERIAL       MATERIAL    MATERIAL'
        moose_inputs = '     time          time           phif
                             phip          phip           phis        phis'
        neml2_inputs = '     forces/t      old_forces/t   forces/phif
                             state/phip    old_state/phip state/phis  old_state/phis'

        moose_output_types = 'MATERIAL       MATERIAL   MATERIAL   MATERIAL   MATERIAL
                              MATERIAL       MATERIAL   MATERIAL   MATERIAL   MATERIAL     MATERIAL'
        moose_outputs = '     M3             M4         M5         M6         M2
                              non_liquid     poro       perm       phip       phis         Seff'
        neml2_outputs = '     state/M3       state/M4   state/M5   state/M6   state/M2
                              state/phif_max state/poro state/perm state/phip state/phis   state/Seff'

        moose_derivative_types = 'MATERIAL              MATERIAL                MATERIAL
                                  MATERIAL              MATERIAL                MATERIAL
                                  MATERIAL'
        moose_derivatives = '     dM6dphif              dM3dphif                dM4dphif
                                  dM5dphif              dphipdphif              dphisdphif
                                  dM2dphif'
        neml2_derivatives = '     state/M6 forces/phif; state/M3 forces/phif;   state/M4 forces/phif;
                                  state/M5 forces/phif; state/phip forces/phif; state/phis forces/phif;
                                  state/M2 forces/phif'

        initialize_outputs = '      phip     phis'
        initialize_output_values = 'phi0_SiC phi0_C'
    []
[]

[Materials]
    [constant]
        type = GenericConstantMaterial
        prop_names = 'M1'
        prop_values = '${fparse rho_Si}'
    []
    [constant_derivative]
        type = GenericConstantMaterial
        prop_names = ' dM1dphif dM1dP dM2dP dM3dP dM4dP dM5dP dM6dP'
        prop_values = '0.0      0.0   0.0   0.0   0.0   0.0   0.0'
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
    [volume_rate1]
        type = SideIntegralPumaFlux
        boundary = 'interface'
        material_property = M2
        variable = phif
        execute_on = 'TIMESTEP_END'
    []
    [volume_rate2]
        type = SideIntegralPumaFlux
        boundary = 'interface'
        material_property = M3
        variable = P
        execute_on = 'TIMESTEP_END'
    []
    [volume_rate]
        type = LinearCombinationPostprocessor
        pp_coefs = '${scale_flux} 0.0'
        pp_names = 'volume_rate1 volume_rate2'
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
        no_flux_fraction_transition = 0.001
        sharpness = 10
        multiplier = M
    []
[]

[Executioner]
    type = Transient
    solve_type = 'newton'
    petsc_options_iname = '-pc_type' #-snes_type'
    petsc_options_value = 'lu' # vinewtonrsls'
    #reuse_preconditioner = true
    #residual_and_jacobian_together = 'true'
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