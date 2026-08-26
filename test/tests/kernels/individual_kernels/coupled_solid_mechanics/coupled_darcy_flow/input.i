[GlobalParams]
  displacements = 'disp_x disp_y'
  temperature = T
  pressure = P
[]

[Mesh]
  type = GeneratedMesh
  dim = 2
  nx = 10
[]

[Variables]
  [T]
  []
  [P]
  []
[]

[Kernels]
  [offDiagStressDiv_x]
    type = MomentumBalanceCoupledJacobian
    component = 0
    variable = disp_x
    material_temperature_derivative = neml2_dpk1dT
    material_pressure_derivative = R20
  []
  [offDiagStressDiv_y]
    type = MomentumBalanceCoupledJacobian
    component = 1
    variable = disp_y
    material_temperature_derivative = neml2_dpk1dT
    material_pressure_derivative = R20
  []
  [Tsource]
    type = PumaCoupledDarcyFlow
    coupled_variable = P
    material_prop = J
    variable = T
    material_temperature_derivative = 0.0
    material_pressure_derivative = 0.0
    material_deformation_gradient_derivative = neml2_dJdF
    stabilize_strain = true
  []
  [PL2]
    type = CoupledL2Projection
    material_prop = J
    variable = P
    material_temperature_derivative = 0.0
    material_pressure_derivative = 0.0
    material_deformation_gradient_derivative = neml2_dJdF
    stabilize_strain = true
  []
  [Tdot]
    type = TimeDerivative
    variable = T
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
      []
    []
  []
[]

[NEML2]
  input = '../../../../../../neml2_models/aoti/solid_mechanics_pressure/model_aoti.i'
  [all]
    model = 'model'
    device = 'cpu'

    input_types = 'VARIABLE VARIABLE MATERIAL'
    inputs      = 'T        P        deformation_gradient'

    derivatives = 'J          deformation_gradient neml2_dJdF;
                   pk2 deformation_gradient dpk2_dF;
                   neml2_pk1 T                    neml2_dpk1dT;
                   pc         T                    neml2_dpcdT;
                   pc         P                    neml2_dpcdP'
  []
[]

# [ICs]
#   [ic_T]
#     type = ConstantIC
#     value = 3
#     variable = T
#   []
# []

[Materials]
  [stress]
    type = ComputeLagrangianStressCustomPK2
    custom_pk2_stress = 'pk2'
    custom_pk2_jacobian = 'dpk2_dF'
    large_kinematics = true
  []
  [zeroR2]
    type = GenericConstantRankTwoTensor
    tensor_name = R20
    tensor_values = '0 0 0 0 0 0 0 0 0'
  []
[]

[BCs]
  [left_heat]
    type = NeumannBC
    boundary = left
    value = 0.01
    variable = T
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
  # petsc_options_iname = '-pc_type' #-snes_type'
  # petsc_options_value = 'lu' # vinewtonrsls'
  automatic_scaling = true

  line_search = none

  nl_abs_tol = 1e-6
  nl_rel_tol = 1e-8
  nl_max_its = 20

  dt = 1
  end_time = 1
[]

[Outputs]
  exodus = true
  print_linear_residuals = false
[]
