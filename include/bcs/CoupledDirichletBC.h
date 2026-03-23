#pragma once

#include "DirichletBCBase.h"

/**
 * CoupledDirichletBC enforces u = coupled_variable + f(t, x)
 * where coupled_variable is another field variable and f is an optional MOOSE Function.
 */
class CoupledDirichletBC : public DirichletBCBase
{
public:
  static InputParameters validParams();
  CoupledDirichletBC(const InputParameters & parameters);

protected:
  virtual Real computeQpValue() override;
  virtual Real computeQpJacobian() override;
  virtual Real computeQpOffDiagJacobian(unsigned int jvar) override;

  /// Coupled variable value
  const VariableValue & _coupled_variable;
  /// Coupled variable ID
  const unsigned int _coupled_var_id;
  /// Optional function pointer (can be null)
  const Function * _func;
};