//* This file is part of PUMA
//* https://github.com/applied-material-modeling/puma
//*
//* Licensed under the MIT license, please see LICENSE for details
//* https://opensource.org/license/MIT

#include "GenericConstantRankFourTensor.h"

registerMooseObject("PumaApp", GenericConstantRankFourTensor);
registerMooseObject("PumaApp", ADGenericConstantRankFourTensor);

template <bool is_ad>
InputParameters
GenericConstantRankFourTensorTempl<is_ad>::validParams()
{
  InputParameters params = Material::validParams();
  params.addClassDescription(
      "Object for declaring a constant rank four tensor as a material property.");
  params.addParam<std::vector<Real>>(
      "tensor_values",
      {},
      "Vector of values defining the constant rank four tensor. If omitted, the "
      "zero tensor is used.");
  params.addParam<MooseEnum>(
      "fill_method", RankFourTensor::fillMethodEnum() = "symmetric9", "The fill method");
  params.addRequiredParam<MaterialPropertyName>(
      "tensor_name", "Name of the tensor material property to be created");
  params.set<MooseEnum>("constant_on") = "SUBDOMAIN";
  return params;
}

template <bool is_ad>
GenericConstantRankFourTensorTempl<is_ad>::GenericConstantRankFourTensorTempl(
    const InputParameters & parameters)
  : Material(parameters),
    _prop(declareGenericProperty<RankFourTensor, is_ad>(
        getParam<MaterialPropertyName>("tensor_name")))
{
  const auto & values = getParam<std::vector<Real>>("tensor_values");
  if (values.empty())
    _tensor.zero();
  else
    _tensor.fillFromInputVector(
        values, (RankFourTensor::FillMethod)(int)getParam<MooseEnum>("fill_method"));
}

template <bool is_ad>
void
GenericConstantRankFourTensorTempl<is_ad>::initQpStatefulProperties()
{
  GenericConstantRankFourTensorTempl<is_ad>::computeQpProperties();
}

template <bool is_ad>
void
GenericConstantRankFourTensorTempl<is_ad>::computeQpProperties()
{
  _prop[_qp] = _tensor;
}

template class GenericConstantRankFourTensorTempl<false>;
template class GenericConstantRankFourTensorTempl<true>;
