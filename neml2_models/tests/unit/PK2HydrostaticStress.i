[Tensors]
    [F]
        type = Python
        expr = "R2(torch.tensor([[2.0, 1.0, 0.0], [0.0, 3.0, 1.0], [0.0, 0.0, 4.0]], dtype=torch.float64))"
    []
    [Spc]
        type = Python
        expr = "R2(torch.tensor([[-33.5416666666667, 7.0833333333333, -1.25], [7.0833333333333, -14.1666666666667, 2.5], [-1.25, 2.5, -7.5]], dtype=torch.float64))"
    []
[]

[Drivers]
    [unit]
        type = ModelUnitTest
        model = 'model'
        input_Scalar_names = 'state/sigma_h'
        input_Scalar_values = '5.0'
        input_R2_names = 'forces/F'
        input_R2_values = 'F'
        output_R2_names = 'state/Spc'
        output_R2_values = 'Spc'
    []
[]

[Models]
    [model]
        type = PK2HydrostaticStress
        hydrostatic_stress = 'state/sigma_h'
        deformation_gradient = 'forces/F'
        pk2_stress = 'state/Spc'
    []
[]