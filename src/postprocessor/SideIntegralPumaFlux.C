// Copyright 2023, UChicago Argonne, LLC All Rights Reserved
// License: L-GPL 3.0

#include "SideIntegralPumaFlux.h"
#include "MathFVUtils.h"

#include "metaphysicl/raw_type.h"

registerMooseObject("MooseApp", SideIntegralPumaFlux);

InputParameters
SideIntegralPumaFlux::validParams()
{
  InputParameters params = SideIntegralPostprocessor::validParams();
  params.addRequiredParam<MaterialPropertyName>("material_property",
                                                "The scalar material property M");
  params.addRequiredCoupledVar("variable", "The variable whose gradient is used");
  params.addClassDescription("Computes the surface integral of M * (grad u · n)");
  return params;
}

SideIntegralPumaFlux::SideIntegralPumaFlux(const InputParameters & parameters)
  : SideIntegralPostprocessor(parameters),
    MooseVariableInterface<Real>(this,
                                 false,
                                 "variable",
                                 Moose::VarKindType::VAR_ANY,
                                 Moose::VarFieldType::VAR_FIELD_STANDARD),
    _u(coupledValue("variable")),
    _grad_u(coupledGradient("variable")),
    _M(getMaterialProperty<Real>("material_property"))
{
}

// do we need this?
// Real
// SideIntegralPumaFlux::computeFaceInfoIntegral(const FaceInfo * const fi)
// {
//   return _M[_qp] * (_grad_u[_qp] * _normals[_qp]);
// }

bool
SideIntegralPumaFlux::hasFaceSide(const FaceInfo & fi, const bool fi_elem_side) const
{
  return _field_variable->hasFaceSide(fi, fi_elem_side);
}

Real
SideIntegralPumaFlux::computeQpIntegral()
{

  return -_M[_qp] * (_grad_u[_qp] * _normals[_qp]);
}
