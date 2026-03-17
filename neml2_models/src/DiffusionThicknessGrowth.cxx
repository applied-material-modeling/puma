// Copyright 2024, UChicago Argonne, LLC
// All Rights Reserved
// Software Name: NEML2 -- the New Engineering material Model Library, version 2
// By: Argonne National Laboratory
// OPEN SOURCE LICENSE (MIT)
//
// Permission is hereby granted, free of charge, to any person obtaining a copy
// of this software and associated documentation files (the "Software"), to deal
// in the Software without restriction, including without limitation the rights
// to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
// copies of the Software, and to permit persons to whom the Software is
// furnished to do so, subject to the following conditions:
//
// The above copyright notice and this permission notice shall be included in
// all copies or substantial portions of the Software.
//
// THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
// IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
// FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
// AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
// LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
// OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN
// THE SOFTWARE.

#include "DiffusionThicknessGrowth.h"
#include <neml2/base/Registry.h>

#include <neml2/tensors/Scalar.h>

namespace neml2
{
register_NEML2_object(DiffusionThicknessGrowth);

OptionSet
DiffusionThicknessGrowth::expected_options()
{
  OptionSet options = Model::expected_options();
  options.doc() = "Calculate the product thickness rate of change, assuming a semi-"
                  "infinite liquid comes into contact with another semi-infinite solid"
                  "to form the product at the interface. The rate solution is assumed"
                  "to be a steady-state diffusion of the fluid species through the product"
                  "thickness layer.";

  options.set<double>("product_dummy_thickness") = 0.01;
  options.set("product_dummy_thickness").doc() = "Minimum product thickness to avoid division by 0";

  options.set_input("liquid_reactivity") = VariableName{"state", "R_l"};
  options.set("liquid_reactivity").doc() = "Reactivity of the liquid phase, between 0 and 1";
  
  options.set_input("solid_reactivity") = VariableName{"state", "R_s"};
  options.set("solid_reactivity").doc() = "Reactivity of the solid phase, between 0 and 1";

  options.set_parameter<TensorName<Scalar>>("rate_constant");
  options.set("rate_constant").doc() =
      "Rate constant of the rate-limiting species in the product phase";

  options.set_input("product_thickness") = VariableName{"state", "delta_P"};
  options.set("product_thickness").doc() = "Thickness of the product phase";

  options.set_output("reaction_rate") = VariableName{"state", "alpha_rate"};
  options.set("reaction_rate").doc() = "Product phase thickness rate of change";

  return options;
}

DiffusionThicknessGrowth::DiffusionThicknessGrowth(const OptionSet & options)
  : Model(options),
    _delta(options.get<double>("product_dummy_thickness")),
    _R_l(options.get<VariableName>("liquid_reactivity").empty()
        ? nullptr
        : &declare_input_variable<Scalar>("liquid_reactivity")),
    _R_s(options.get<VariableName>("solid_reactivity").empty()
            ? nullptr
            : &declare_input_variable<Scalar>("solid_reactivity")),
    _K(declare_parameter<Scalar>("K", "rate_constant")),
    _delta_P(declare_input_variable<Scalar>("product_thickness")),
    _rate(declare_output_variable<Scalar>("reaction_rate"))
{
}

void
DiffusionThicknessGrowth::set_value(bool out, bool dout_din, bool /*d2out_din2*/)
{

  const Scalar Rl = _R_l ? (*_R_l)() : Scalar::full(1.0, _delta_P.options());
  const Scalar Rs = _R_s ? (*_R_s)() : Scalar::full(1.0, _delta_P.options());

  if (out)
  {
    _rate = _K / (_delta_P + _delta) * Rl * Rs;
  }

  if (dout_din)
  {
    _rate.d(_delta_P) = -_K / ((_delta_P + _delta) * (_delta_P + _delta)) * Rl * Rs;

    if (_R_l && _R_l->is_dependent())
      _rate.d(*_R_l) = _K / (_delta_P + _delta) * Rs;

    if (_R_s && _R_s->is_dependent())
    _rate.d(*_R_s) = _K / (_delta_P + _delta) * Rl;
  }
}
} // namespace neml2