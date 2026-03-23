// Copyright 2023, UChicago Argonne, LLC All Rights Reserved
// License: L-GPL 3.0

#pragma once

#include "SideIntegralPostprocessor.h"
#include "MooseVariableInterface.h"
#include "FaceArgInterface.h"

class SideIntegralPumaFlux : public SideIntegralPostprocessor, public MooseVariableInterface<Real>
{
public:
  static InputParameters validParams();

  SideIntegralPumaFlux(const InputParameters & parameters);

  bool hasFaceSide(const FaceInfo & fi, const bool fi_elem_side) const override;

protected:
  virtual Real computeQpIntegral() override;
  // Real computeFaceInfoIntegral(const FaceInfo * fi) override;

  /// Holds the solution at current quadrature points
  const VariableValue & _u;
  /// Holds the solution gradient at the current quadrature points
  const VariableGradient & _grad_u;

  /// Material property M
  const MaterialProperty<Real> & _M;
};