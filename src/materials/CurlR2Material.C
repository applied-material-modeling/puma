//* This file is part of PUMA
//* https://github.com/applied-material-modeling/puma
//*
//* Licensed under the MIT license, please see LICENSE for details
//* https://opensource.org/license/MIT

#include "CurlR2Material.h"

registerMooseObject("PumaApp", CurlR2Material);

InputParameters
CurlR2Material::validParams()
{
  InputParameters params = Material::validParams();

  params.addRequiredCoupledVar("a11", "A(1,1)");
  params.addRequiredCoupledVar("a12", "A(1,2)");
  params.addRequiredCoupledVar("a13", "A(1,3)");
  params.addRequiredCoupledVar("a21", "A(2,1)");
  params.addRequiredCoupledVar("a22", "A(2,2)");
  params.addRequiredCoupledVar("a23", "A(2,3)");
  params.addRequiredCoupledVar("a31", "A(3,1)");
  params.addRequiredCoupledVar("a32", "A(3,2)");
  params.addRequiredCoupledVar("a33", "A(3,3)");

  params.addParam<MaterialPropertyName>("curl_name",
                                       "curl",
                                       "Name of the output curl tensor");

  params.addParam<Real>("scale",
                        1.0,
                        "Scalar multiplier applied to Curl(A)");

  return params;
}

CurlR2Material::CurlR2Material(const InputParameters & parameters)
  : Material(parameters),

    _a11(coupledValue("a11")),
    _a12(coupledValue("a12")),
    _a13(coupledValue("a13")),
    _a21(coupledValue("a21")),
    _a22(coupledValue("a22")),
    _a23(coupledValue("a23")),
    _a31(coupledValue("a31")),
    _a32(coupledValue("a32")),
    _a33(coupledValue("a33")),

    _ga11(coupledGradient("a11")),
    _ga12(coupledGradient("a12")),
    _ga13(coupledGradient("a13")),
    _ga21(coupledGradient("a21")),
    _ga22(coupledGradient("a22")),
    _ga23(coupledGradient("a23")),
    _ga31(coupledGradient("a31")),
    _ga32(coupledGradient("a32")),
    _ga33(coupledGradient("a33")),

    _curl(declareProperty<RankTwoTensor>(
        getParam<MaterialPropertyName>("curl_name"))),

    _scale(getParam<Real>("scale"))
{
}

int
CurlR2Material::PermutationOrder(unsigned i, unsigned j, unsigned k)
{
  if (i == j || j == k || i == k)
    return 0;

  if ((i == 0 && j == 1 && k == 2) ||
      (i == 1 && j == 2 && k == 0) ||
      (i == 2 && j == 0 && k == 1))
    return 1;

  return -1;
}

void
CurlR2Material::computeQpProperties()
{
  _curl[_qp].zero();

  auto dA = [&](unsigned i, unsigned l, unsigned k) -> Real
  {
    const RealVectorValue * g = nullptr;

    if (i == 0 && l == 0) g = &_ga11[_qp];
    else if (i == 0 && l == 1) g = &_ga12[_qp];
    else if (i == 0 && l == 2) g = &_ga13[_qp];
    else if (i == 1 && l == 0) g = &_ga21[_qp];
    else if (i == 1 && l == 1) g = &_ga22[_qp];
    else if (i == 1 && l == 2) g = &_ga23[_qp];
    else if (i == 2 && l == 0) g = &_ga31[_qp];
    else if (i == 2 && l == 1) g = &_ga32[_qp];
    else if (i == 2 && l == 2) g = &_ga33[_qp];

    if (!g)
      mooseError("CurlR2Material::dA invalid indices i=", i, " l=", l);

    return (*g)(k);
  };

  for (unsigned i = 0; i < 3; ++i)
    for (unsigned j = 0; j < 3; ++j)
    {
      Real sum = 0.0;
      for (unsigned k = 0; k < 3; ++k)
        for (unsigned l = 0; l < 3; ++l)
        {
          const int eps = PermutationOrder(j, k, l);
          if (eps)
            sum += static_cast<Real>(eps) * dA(i, l, k);
        }

      _curl[_qp](i, j) = _scale * sum;
    }
}
