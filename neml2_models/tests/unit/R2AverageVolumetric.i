[Tensors]
  [A]
    type = Python
    expr = "R2(torch.tensor([[1.0, 3.0, 2.0], [6.0, 2.0, 9.0], [4.0, 5.0, 3.0]], dtype=torch.float64))"
  []
[]

[Drivers]
  [unit]
    type = ModelUnitTest
    model = 'model'
    input_R2_names = 'state/A'
    input_R2_values = 'A'
    output_Scalar_names = 'state/vol'
    output_Scalar_values = '2.0'
  []
[]

[Models]
  [model]
    type = R2AverageVolumetric
    input = 'state/A'
    average_volumetric = 'state/vol'
  []
[]