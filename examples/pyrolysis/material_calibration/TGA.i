# reaction mechanism
Y = 0.5835777126099713 # yield
n = 1.0 # reaction order
k0 = 0.04210147513030456 # reaction rate coefficient
Q = 21191.61425138572 # J/mol
R = 8.31446261815324 # J/K/mol
 
[Models]
  [reaction_coef]
    type = ArrheniusParameter
    reference_value = '${k0}'
    activation_energy = '${Q}'
    ideal_gas_constant = '${R}'
    temperature = 'forces/T'
    parameter = 'state/k'
  []
  [reaction_rate]
    type = ContractingGeometry
    reaction_coef = 'reaction_coef'
    reaction_order = '${n}'
    conversion_degree = 'state/alpha'
    reaction_rate = 'state/alpha_rate'
  []
  [reaction_ode]
    type = ScalarBackwardEulerTimeIntegration
    variable = 'state/alpha'
  []
  [reaction]
    type = ComposedModel
    models = 'reaction_rate reaction_ode'
  []
  [solve_reaction]
    type = ImplicitUpdate
    implicit_model = 'reaction'
    solver = 'newton'
  []
  [binder_rate]
    type = ScalarLinearCombination
    from_var = 'state/alpha_rate'
    coefficients = '-1'
    to_var = 'state/wb_rate'
  []
  [char_rate]
    type = ScalarLinearCombination
    from_var = 'state/alpha_rate'
    coefficients = '${Y}'
    coefficient_as_parameter = 'true'
    to_var = 'state/wc_rate'
  []
  [binder]
    type = ScalarBackwardEulerTimeIntegration
    variable = 'state/wb'
  []
  [char]
    type = ScalarBackwardEulerTimeIntegration
    variable = 'state/wc'
  []
  [model]
    type = ComposedModel
    models = "reaction_rate reaction char_rate binder_rate
    binder char"
  []
[]