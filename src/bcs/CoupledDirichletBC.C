#include "CoupledDirichletBC.h"
#include "Function.h"

registerMooseObject("PumaApp", CoupledDirichletBC);

InputParameters
CoupledDirichletBC::validParams()
{
  InputParameters params = DirichletBCBase::validParams();
  params.addRequiredCoupledVar("coupled_variable",
                               "The variable providing the coupled boundary value.");
  params.addParam<FunctionName>(
      "function",
      "",
      "Optional function added to the coupled variable value. "
      "Total BC value is u = coupled_variable + f(t, x).");
  params.addClassDescription(
      "Imposes a Dirichlet boundary condition u = coupled_variable + f(t, x), "
      "where coupled_variable is another variable and f is an optional MOOSE Function.");
  return params;
}

CoupledDirichletBC::CoupledDirichletBC(const InputParameters & parameters)
  : DirichletBCBase(parameters),
    _coupled_variable(coupledValue("coupled_variable")),
    _coupled_var_id(coupled("coupled_variable")),
    _func(isParamValid("function") ? &getFunction("function") : nullptr)
{
}

Real
CoupledDirichletBC::computeQpValue()
{
  Real val = _coupled_variable[_qp];
  if (_func)
    val += _func->value(_t, *_current_node);
  return val;
}

Real
CoupledDirichletBC::computeQpJacobian()
{
  return 1.0;
}

Real
CoupledDirichletBC::computeQpOffDiagJacobian(unsigned int jvar)
{
  if (jvar == _coupled_var_id)
    return -1.0;
  return 0.0;
}