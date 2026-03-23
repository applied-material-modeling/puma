############## Input ################
# Simulation parameters
dt = 3
nx = 10

# models
Ts = 1687
Tf = 1707

# Molar Mass # g mol-1
M_Si = 28.085

# solidfication information
H_latent = 1.2e8 # erg/g -- 1.2e8 for theoretical
solidification_rate = 0.005
Tmax = 1720 #K
T0 = 300 #K
phif_min = 0.002

# density
rho_Si = 2.57 # density at liquid state
rho_Si_s = 2.37 # density at solid state
rho_SiC = 3.210
rho_C = 2.260

# specific heat
cp_Si = 0.7e7 # erg/g-K
cp_Si_s = 0.5e7 # erg/g-K
cp_SiC = 550e4
cp_C = 1500e4

# thermal conductivity #[erg cm-1 s-1 K]
kappa_Si = 1.4e7
kappa_Si_s = 1.4e7
kappa_SiC = 3e7
kappa_C = 3e8

# Heating conditions
dTdt = -60 #Kmin-1 heating rate
t_ramp = '${fparse (T0-Tmax)/dTdt*60}' #s
t_hold = 1800 #s
total_time = '${fparse t_ramp + t_hold-1200}'

# boundary conditions
htc = 20000 #g / s3-K

# porous flow
brooks_corey_threshold = 1e4 #Pa
capillary_pressure_power = 10

# solid permeability
kk_Si = 1e-8
permeability_power = 8

# liquid viscosity
mu_Si = 0.01

# macroscopic property
D_macro = 0.001 #cm2 s-1

# initial condition
phi_C = 0.3
phi_SiC = 0.3
phi_Si0 = 0.38

flux_out = 0.1

xmax = 100.0

gravity = 0.0 # 980.665 # cm/s2

# solid mechanics
Tref = 1720 #K
therm_expansion = 1e-6
phase_strain_coef = 1.0 # strain coefficient for the phase eigenstrain
strain_Sactivate = 0.2 # strain at which the phase eigenstrain starts to activate
E = 400e9
E_Si = 160e9
E_C = 400e9 
nu_Si = 0.3
nu_C = 0.3

# Calculations
omega_Si_s = '${fparse M_Si/rho_Si_s}'
omega_Si_l = '${fparse M_Si/rho_Si}'
delta_Omega = '${fparse omega_Si_s/omega_Si_l-1}'

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
    input = 'neml2/neml2_material.i'
    cli_args = 'rho_f=${rho_Si} rhof_nu=${fparse rho_Si/mu_Si} rhof2_nu=${fparse rho_Si^2/mu_Si}
                brooks_corey_threshold=${brooks_corey_threshold}
                capillary_pressure_power=${capillary_pressure_power}
                permeability_power=${permeability_power} kk_L=${kk_Si}
                TlmTs=${fparse 1/(Tf-Ts)} mTs_o_TlmTs=${fparse -Ts/(Tf-Ts)} s_TlmTs=${fparse 6/(Tf-Ts)}
                Tl=${Tf} Ts=${Ts} m_solidification_rate=${fparse -solidification_rate}
                o_omegaf=${fparse 1/omega_Si_l} mOfs_Ofl=${fparse -omega_Si_s/omega_Si_l}
                cp_rhofl=${fparse cp_Si*rho_Si} cp_rhofs=${fparse cp_Si_s*rho_Si_s}
                cp_rhos=${fparse cp_C*rho_C} cp_rhop=${fparse cp_SiC*rho_SiC}
                kap_fl=${kappa_Si} kap_fs=${kappa_Si_s} kap_s=${kappa_C} kap_p=${kappa_SiC}
                hf_rhof_onu=${fparse H_latent*rho_Si/mu_Si} hf_rhof2_onu=${fparse H_latent*rho_Si^2/mu_Si}
                mhf_rhof=${fparse -H_latent*rho_Si} mphi_min=${fparse -phif_min}
                Tref=${Tref} therm_expansion=${therm_expansion} T0=${T0} Tmax=${Tmax}
                phase_strain_coef=${phase_strain_coef} strain_Sactivate=${strain_Sactivate}
                E=${E} E_fs=${E_Si} E_m=${E_C} nu_fs=${nu_Si} nu_m=${nu_C} delta_Omega=${delta_Omega}'

    [all]
        model = 'model'
        verbose = true
        device = 'cpu'

        moose_input_types = 'POSTPROCESSOR POSTPROCESSOR MATERIAL
                             VARIABLE      VARIABLE      MATERIAL'
        moose_inputs = '     time          time          deformation_gradient
                             phif          T             phif_s'
        neml2_inputs = '     forces/t      old_forces/t  forces/F
                             forces/phif   forces/T      old_state/phif_s'

        moose_output_types = 'MATERIAL      MATERIAL       MATERIAL    MATERIAL    MATERIAL
                              MATERIAL      MATERIAL       MATERIAL    MATERIAL    MATERIAL
                              MATERIAL      MATERIAL       MATERIAL    MATERIAL    MATERIAL
                              MATERIAL      MATERIAL       MATERIAL'
        moose_outputs = '     M1            M3             M4          M5          M6
                              M7            M8             M9          M10         M11
                              phif_s        phif_max       perm        pk1_stress  nonliquid
                              Jt_sp         Jt_fs           Jt'
        neml2_outputs = '     state/M1      state/M3       state/M4    state/M5    state/M6
                              state/M7      state/M8       state/M9    state/M10   state/M11
                              state/phif_s  state/phif_max state/perm  state/pk1   state/nonliquid
                              state/Jt_sp state/Jt_fs      state/Jt'

        moose_parameter_types = 'MATERIAL   MATERIAL   '
        moose_parameters = '     phis       phip       '
        neml2_parameters = '     phis_param phip_param '

        moose_derivative_types = '                                           MATERIAL
                                  MATERIAL
                                  MATERIAL
                                  MATERIAL
                                  MATERIAL            MATERIAL
                                  MATERIAL            MATERIAL               MATERIAL
                                  MATERIAL            MATERIAL
                                  MATERIAL
                                  MATERIAL
                                  MATERIAL            MATERIAL               MATERIAL
                                  MATERIAL            MATERIAL               MATERIAL'
        moose_derivatives = '                                                dM1dF
                                  dM3dT
                                  dM4dT
                                  dM5dT
                                  dM6dT               dM6dphif
                                  dM7dT               dM7dphif               dM7dF
                                  dM8dT               dM8dphif
                                  dM9dT
                                  dM10dT
                                  dM11dT              dM11dphif              dM11dF
                                  dpk1dT              dpk1dphif              pk1_jacobian'
        neml2_derivatives = '                                                state/M1 forces/F;
                                  state/M3  forces/T;
                                  state/M4  forces/T;
                                  state/M5  forces/T;
                                  state/M6  forces/T; state/M6  forces/phif;
                                  state/M7  forces/T; state/M7  forces/phif; state/M7 forces/F;
                                  state/M8  forces/T; state/M8  forces/phif;
                                  state/M9  forces/T;
                                  state/M10 forces/T;
                                  state/M11 forces/T; state/M11 forces/phif; state/M11 forces/F;
                                  state/pk1 forces/T; state/pk1 forces/phif; state/pk1 forces/F'

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
        prop_names = ' dM1dT    dM1dphif  dM2dT           dM2dphif dM3dphif dM4dphif dM5dphif
                       dM9dphif dM10dphif dnonliquiddphif'
        prop_values = '0.0      0.0       0.0             0.0      0.0      0.0      0.0
                       0.0      0.0       0.0'
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
        growth_factor = 2.0
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
