Y = 0.5835777126099713
n = 1.0
k0 = 0.04210147513030456
Q = 21191.61425138572
R = 8.31446261815324

[Solvers]
  [newton]
    type = Newton
    verbose = false
    linear_solver = 'lu'
  []
  [lu]
    type = DenseLU
  []
[]

[EquationSystems]
  [eq_sys]
    type = NonlinearSystem
    model = 'residual'
    unknowns = 'alpha wb wc'
    residuals = 'alpha_residual wb_residual wc_residual'
  []
[]

[Models]
  [reaction_coef]
    type = ArrheniusParameter
    reference_value = '${k0}'
    activation_energy = '${Q}'
    ideal_gas_constant = '${R}'
    temperature = 'T'
    parameter = 'k'
  []
  [reaction_rate]
    type = ContractingGeometry
    coef = 'k'
    order = '${n}'
    conversion_degree = 'alpha'
    reaction_rate = 'alpha_rate'
  []
  [binder_rate]
    type = ScalarLinearCombination
    from = 'alpha_rate'
    weights = '-1'
    to = 'wb_rate'
  []
  [char_rate]
    type = ScalarLinearCombination
    from = 'alpha_rate'
    weights = '${Y}'
    to = 'wc_rate'
  []
  [reaction_ode]
    type = ScalarBackwardEulerTimeIntegration
    variable = 'alpha'
    time = 't'
  []
  [binder]
    type = ScalarBackwardEulerTimeIntegration
    variable = 'wb'
    time = 't'
  []
  [char]
    type = ScalarBackwardEulerTimeIntegration
    variable = 'wc'
    time = 't'
  []
  [residual]
    type = ComposedModel
    models = 'reaction_coef reaction_rate binder_rate char_rate
              reaction_ode binder char'
  []
[]
