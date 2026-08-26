[Drivers]
  [unit]
    type = ModelUnitTest
    model = 'model'
    input_Scalar_names = 'state/delta_P state/R_l state/R_s'
    input_Scalar_values = '0.8 0.2 0.3'
    output_Scalar_names = 'state/delta_rate'
    output_Scalar_values = '0.00014814814'
  []
[]

[Models]
  [model]
    type = DiffusionThicknessGrowth
    rate_constant = 2e-3
    liquid_reactivity = 'state/R_l'
    solid_reactivity = 'state/R_s'
    product_thickness = 'state/delta_P'
    reaction_rate = 'state/delta_rate'
  []
[]
