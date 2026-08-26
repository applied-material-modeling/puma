//* This file is part of PUMA
//* https://github.com/applied-material-modeling/puma
//*
//* Licensed under the MIT license, please see LICENSE for details
//* https://opensource.org/license/MIT

#pragma once

#include "Material.h"
#include "RankFourTensor.h"

/**
 * Declares a constant material property of type RankFourTensor.
 *
 * Mirrors the framework's GenericConstantRankTwoTensor for rank-four tensors.
 * `tensor_values` is optional: when omitted the property is the zero tensor,
 * which is exactly what a custom Cauchy stress needs to publish for
 * `dcauchy_stress_d_eigenstrain` (a prescribed eigenstrain has no stress
 * coupling, so its derivative is identically zero).
 */
template <bool is_ad>
class GenericConstantRankFourTensorTempl : public Material
{
public:
  static InputParameters validParams();

  GenericConstantRankFourTensorTempl(const InputParameters & parameters);

protected:
  virtual void initQpStatefulProperties() override;
  virtual void computeQpProperties() override;

  RankFourTensor _tensor;
  GenericMaterialProperty<RankFourTensor, is_ad> & _prop;
};

typedef GenericConstantRankFourTensorTempl<false> GenericConstantRankFourTensor;
typedef GenericConstantRankFourTensorTempl<true> ADGenericConstantRankFourTensor;
