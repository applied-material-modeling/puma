[Tensors]
  [A]
    type = Python
    expr = "SR2.fill(1.0, 2.0, 3.0, 4.0, 5.0, 6.0, dtype=torch.float64)"
  []
[]

[Drivers]
  [unit]
    type = ModelUnitTest
    model = 'model'
    input_SR2_names = 'state/A'
    input_SR2_values = 'A'
    output_Scalar_names = 'state/vol'
    output_Scalar_values = '2.0'
  []
[]

[Models]
  [model]
    type = SR2AverageVolumetric
    input = 'state/A'
    average_volumetric = 'state/vol'
  []
[]