[Drivers]
  [unit]
    type = ModelUnitTest
    model = 'model'
    input_Scalar_names = 'state/hc state/delta_P state/R_l state/R_s'
    input_Scalar_values = '1.5 0.8 0.2 0.3'
    output_Scalar_names = 'state/delta_rate'
    output_Scalar_values = '0.034540180257621'
    derivative_abs_tol = 1e-7
    parameter_derivative_rel_tol = 1e-3
  []
[]

[Models]
  [rate]
    type = NucleationThicknessGrowth
    growth_constant = 2e-3
    closure_thickness = 'state/hc'
    fraction_transform = 0.8
    liquid_reactivity = 'state/R_l'
    solid_reactivity = 'state/R_s'
    product_thickness = 'state/delta_P'
    reaction_rate = 'state/delta_rate'
    order_type = 'THIRD'
  []
  [model]
    type = ComposedModel
    models = 'rate'
  []
[]
