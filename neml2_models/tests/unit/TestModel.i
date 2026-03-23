[Settings]
  additional_libraries = 'libpuma_matlib.so'
[]

[Drivers]
  [unit]
    type = ModelUnitTest
    model = 'model'
    input_Scalar_names = 'state/x1 state/x2'
    input_Scalar_values = '2.0 -1.0'
    output_Scalar_names = 'state/y'
    output_Scalar_values = '1.0'
    derivative_abs_tol = 1e-6
  []
[]

[Models]
  [model]
    type = TestModel
    x1 = 'state/x1'
    x2 = 'state/x2'
    y = 'state/y'
  []
[]
