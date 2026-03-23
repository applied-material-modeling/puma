[Settings]
  additional_libraries = 'libpuma_matlib.so'
[]

[Drivers]
  [unit]
    type = ModelUnitTest
    model = 'model'
    input_Scalar_names = 'state/phi_P state/R_l state/R_s'
    input_Scalar_values = '0.7 0.2 0.3'
    output_Scalar_names = 'state/rate'
    output_Scalar_values = '0.01533203963'
    derivative_abs_tol = 1e-7
    parameter_derivative_rel_tol = 1e-3
  []
[]

[Models]
  [rate]
    type = NucleationLimitedReaction
    growth_constant = 2e-3
    product_volume_fraction = 'state/phi_P'
    product_molar_volume = 0.76
    liquid_reactivity = 'state/R_l'
    solid_reactivity = 'state/R_s'
    reaction_rate = 'state/rate'
    order_type = 'FIRST'
  []
  [model]
    type = ComposedModel
    models = 'rate'
  []
[]
