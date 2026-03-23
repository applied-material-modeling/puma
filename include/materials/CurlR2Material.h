//* This file is part of PUMA
//* https://github.com/applied-material-modeling/puma
//*
//* Licensed under the MIT license, please see LICENSE for details
//* https://opensource.org/license/MIT

#pragma once

#include "Material.h"
#include "RankTwoTensor.h"

// This material computes the row-wise curl of a rank-2 tensor A
// aka (Curl A)_ij = epsilon_jkl dA_il/dx_k

class CurlR2Material : public Material
{
public:
  static InputParameters validParams();
  CurlR2Material(const InputParameters & parameters);

protected:
  virtual void computeQpProperties() override;

private:
  // Tensor components
  const VariableValue & _a11;
  const VariableValue & _a12;
  const VariableValue & _a13;
  const VariableValue & _a21;
  const VariableValue & _a22;
  const VariableValue & _a23;
  const VariableValue & _a31;
  const VariableValue & _a32;
  const VariableValue & _a33;

  // Gradients
  const VariableGradient & _ga11;
  const VariableGradient & _ga12;
  const VariableGradient & _ga13;
  const VariableGradient & _ga21;
  const VariableGradient & _ga22;
  const VariableGradient & _ga23;
  const VariableGradient & _ga31;
  const VariableGradient & _ga32;
  const VariableGradient & _ga33;

  // Output
  MaterialProperty<RankTwoTensor> & _curl;

  const Real _scale;

  static int PermutationOrder(unsigned i, unsigned j, unsigned k);
};