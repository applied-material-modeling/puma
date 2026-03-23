############### Input ################

# Simulation parameters
dt = 5 #s
total_time = 3600 #s

flux_in = 0.1 # volume fraction
flux_out = 0.1
t_ramp = 1500
t_displace = 200

dTdt = 1 # deg per s

# denisty # g cm-3
rho_PR = 2.00 # density at liquid state

brooks_corey_threshold = 1e4 #Pa
capillary_pressure_power = 3
phi_L_residual = 0.0

permeability_power = 3

# liquid viscosity
mu_PR = 10

# solid permeability
kk_PR = 2e-5

# heat enthalpy [g-cm2/s2]
hf = 1e7

# thermal conductivity
kappa_PR = 2e3 #[gcm/s3/K]

# heat capacity
cp_PR = 1e1 #g-cm2/s2/K

# macroscopic property
D_macro = 0.001 #cm2 s-1

#boundary conditions
htc = 2e1 #g / s3-K

porosity_feature = 0.5
porosity_background = 0.5

E = 1000
nu = 0.3
therm_expansion = 1e-4
T0 = 300

E_feature = '${fparse E*porosity_feature}'
E_background = '${fparse E*porosity_background}'

advs_coefficient = 10.0

gravity = 0 #980.665

# --------------- Mesh BCs
xroll = 10
yroll = 0
zroll = 0
xfix = 0
yfix = 0
zfix = 0
xdisplace_low = 8
xdisplace_high = 10
ydisplace = 10
zdisplace = 0
displace_value_x = 0.5
displace_value_y = 1

[GlobalParams]
  displacements = 'disp_x disp_y'
  pressure = P
  fluid_fraction = phif
  temperature = T
[]

[Mesh]
  [mesh0]
    type = FileMeshGenerator
    file = 'gold/core.msh'
  []
  [rollingnode]
    type = BoundingBoxNodeSetGenerator
    bottom_left = '${fparse xroll-0.00000001} ${fparse yroll-0.00000001} ${fparse zroll-0.00000001}'
    input = mesh0
    new_boundary = 'roll'
    top_right = '${fparse xroll+0.00000001} ${fparse yroll+0.00000001} ${fparse zroll+0.00000001}'
  []
  [fixnode]
    type = BoundingBoxNodeSetGenerator
    bottom_left = '${fparse xfix-0.00000001} ${fparse yfix-0.00000001} ${fparse zfix-0.00000001}'
    input = rollingnode
    new_boundary = 'fix'
    top_right = '${fparse xfix+0.00000001} ${fparse yfix+0.00000001} ${fparse zfix+0.00000001}'
  []
  [displacenode]
    type = BoundingBoxNodeSetGenerator
    bottom_left = '${fparse xdisplace_low-0.00000001} ${fparse ydisplace-0.00000001} ${fparse zdisplace-0.00000001}'
    input = fixnode
    new_boundary = 'displace'
    top_right = '${fparse xdisplace_high+0.00000001} ${fparse ydisplace+0.00000001} ${fparse zdisplace+0.00000001}'
  []
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
    material_deformation_gradient_derivative = dM5dF
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
    material_fluid_fraction_derivative = dpk1dphif
    material_pressure_derivative = zeroR2
    material_temperature_derivative = dpk1dT
  []
  [offDiagStressDiv_y]
    type = MomentumBalanceCoupledJacobian
    component = 1
    variable = disp_y
    material_fluid_fraction_derivative = dpk1dphif
    material_pressure_derivative = zeroR2
    material_temperature_derivative = dpk1dT
  []
[]

[AuxVariables]
  [init_void]
    order = CONSTANT
    family = MONOMIAL
    [AuxKernel]
      type = MaterialRealAux
      property = void
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
                            vonmises_pk1_stress max_principal_pk1_stress"
      []
    []
  []
[]

[NEML2]
  input = 'neml2/neml2_material.i'
  cli_args = 'kk_L=${kk_PR} permeability_power=${permeability_power} rhof_nu=${fparse rho_PR/mu_PR}
              rhof2_nu=${fparse rho_PR^2/mu_PR} phif_residual=${phi_L_residual} rho_f=${fparse rho_PR}
              brooks_corey_threshold=${brooks_corey_threshold} capillary_pressure_power=${capillary_pressure_power}
              nu=${nu} advs_coefficient=${advs_coefficient} hf_rhof_nu=${fparse hf*rho_PR/mu_PR}
              hf_rhof2_nu=${fparse hf*rho_PR^2/mu_PR} therm_expansion=${therm_expansion} Tref=${T0}'
  [all]
    model = 'model'
    verbose = true
    device = 'cpu'

    moose_input_types = 'VARIABLE    VARIABLE MATERIAL'
    moose_inputs = '     phif        T        deformation_gradient'
    neml2_inputs = '     forces/phif forces/T forces/F'

    moose_parameter_types = 'MATERIAL       MATERIAL'
    moose_parameters = '     void           E       '
    neml2_parameters = '     phif_max_param S_pk2_E '

    moose_output_types = 'MATERIAL   MATERIAL MATERIAL MATERIAL MATERIAL
                          MATERIAL MATERIAL MATERIAL   MATERIAL    MATERIAL'
    moose_outputs = '     pk1_stress M1       M3       M4       M5
                          M8       M9       poro       phis        perm'
    neml2_outputs = '     state/pk1  state/M1 state/M3 state/M4 state/M5
                          state/M8 state/M9 state/poro state/solid state/perm'

    moose_derivative_types = 'MATERIAL               MATERIAL             MATERIAL
                              MATERIAL               MATERIAL             MATERIAL
                              MATERIAL               MATERIAL'
    moose_derivatives = '     dM5dphif               dM1dF                pk1_jacobian
                              dpk1dphif              dM5dF                dpk1dT
                              dM4dphif               dM9dphif'
    neml2_derivatives = '     state/M5  forces/phif; state/M1 forces/F;   state/pk1 forces/F;
                              state/pk1 forces/phif; state/M5 forces/F;   state/pk1 forces/T;
                              state/M4  forces/phif; state/M9 forces/phif'
  []
[]

[Materials]
  [constant]
    type = GenericConstantMaterial
    prop_names = 'M2                        M6                     M7'
    prop_values = '${fparse rho_PR*D_macro} ${fparse rho_PR*cp_PR} ${fparse kappa_PR}'
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
  [void_feature]
    type = GenericConstantMaterial
    prop_names = 'void E'
    prop_values = '${porosity_feature} ${E_feature}'
    block = circle
  []
  [void_background]
    type = GenericConstantMaterial
    prop_names = 'void E'
    prop_values = '${porosity_background} ${E_background}'
    block = non_circle
  []
  [zeroR2]
    type = GenericConstantRankTwoTensor
    tensor_name = 'zeroR2'
    tensor_values = '0 0 0 0 0 0 0 0 0'
  []
  [convection]
    type = ADParsedMaterial
    property_name = q_boundary
    expression = 'htc*(T - if(time<t_displace, T0, if (time<t_ramp, T0 + dTdt*(time-t_displace), T0 + dTdt*(t_ramp-t_displace))))'
    coupled_variables = T
    constant_names = 'htc t_ramp dTdt t_displace T0'
    constant_expressions = '${htc} ${t_ramp} ${dTdt} ${t_displace} ${T0}'
    postprocessor_names = 'time'
    boundary = 'core_bottom core_top core_sides'
  []
[]

[Functions]
  [flux_in]
    type = PiecewiseLinear
    x = '0 ${t_displace} ${t_ramp}'
    y = '0 0 ${flux_in}'
  []
  [flux_out]
    type = PiecewiseLinear
    x = '0 ${t_displace} ${t_ramp}'
    y = '0 0 ${flux_out}'
  []
  [move_x]
    type = PiecewiseLinear
    x = '0 ${t_displace} ${t_ramp}'
    y = '0 ${displace_value_x} ${displace_value_x}'
  []
  [move_y]
    type = PiecewiseLinear
    x = '0 ${t_displace} ${t_ramp}'
    y = '0 ${displace_value_y} ${displace_value_y}'
  []
[]

[Postprocessors]
  [time]
    type = TimePostprocessor
    execute_on = 'INITIAL TIMESTEP_BEGIN'
  []
[]

[ICs]
  [temp]
    type = ConstantIC
    value = ${T0}
    variable = T
  []
  [phif]
    type = ConstantIC
    value = 0.001
    variable = phif
  []
[]

[BCs]
  [bottom_inlet]
    type = InfiltrationWake
    boundary = core_bottom
    inlet_flux = flux_in
    outlet_flux = flux_out
    product_fraction = 0.0
    product_fraction_derivative = 0.0
    solid_fraction = phis
    solid_fraction_derivative = 0.0
    variable = phif
  []
  [boundary]
    type = ADMatNeumannBC
    boundary_material = q_boundary
    boundary = 'core_bottom core_top core_sides'
    variable = T
    value = -1
  []
  [roller_bot]
    type = DirichletBC
    boundary = core_bottom
    value = 0.0
    variable = disp_y
  []
  [move_point_x]
    type = FunctionDirichletBC
    boundary = 'circle_interface'
    function = move_x
    variable = disp_x
  []
  [move_point_y]
    type = FunctionDirichletBC
    boundary = 'circle_interface'
    function = move_y
    variable = disp_y
  []
[]

[Executioner]
  type = Transient
  solve_type = 'newton'
  petsc_options_iname = '-pc_type -pc_factor_shift_type' #-snes_type'
  petsc_options_value = 'lu NONZERO' # vinewtonrsls'
  automatic_scaling = true

  line_search = none

  nl_abs_tol = 1e-06
  nl_rel_tol = 1e-08
  nl_max_its = 12

  end_time = ${total_time}
  dtmax = '${fparse 200*dt}'

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
  file_base = 'example/core'
  [console]
    type = Console
    execute_postprocessors_on = 'NONE'
  []
  [csv]
    type = CSV
    file_base = 'example/out'
  []
  print_linear_residuals = true
[]
