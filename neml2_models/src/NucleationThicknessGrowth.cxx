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

#include "NucleationThicknessGrowth.h"
#include <neml2/base/Registry.h>

#include <neml2/tensors/Scalar.h>
#include <neml2/misc/assertions.h>
#include <neml2/tensors/functions/exp.h>
#include <neml2/tensors/functions/log.h>
#include <neml2/tensors/functions/pow.h>
#include <neml2/tensors/functions/clamp.h>

namespace neml2
{
register_NEML2_object(NucleationThicknessGrowth);

OptionSet
NucleationThicknessGrowth::expected_options()
{
  OptionSet options = Model::expected_options();
  options.doc() = "Calculate the product thickness rate of change, assuming a semi-"
                  "infinite liquid comes into contact with another semi-infinite solid"
                  "to form the product at the interface. The rate solution is controlled"
                  "via solid nucleation from inside the liquid, following Avrami and JMAK expression.";

  options.set_input("liquid_reactivity") = VariableName{"state", "R_l"};
  options.set("liquid_reactivity").doc() = "Reactivity of the liquid phase, between 0 and 1";
  
  options.set_input("solid_reactivity") = VariableName{"state", "R_s"};
  options.set("solid_reactivity").doc() = "Reactivity of the solid phase, between 0 and 1";

  options.set_parameter<TensorName<Scalar>>("growth_constant");
  options.set("growth_constant").doc() =
      "Growth constant of the solid nucleation in the liquid phase";

  options.set_parameter<TensorName<Scalar>>("closure_thickness");
  options.set("closure_thickness").doc() =
      "The thickness in which the product phase form a continuous layer between the solid and liquid phases";

  options.set_parameter<TensorName<Scalar>>("fraction_transform");
  options.set("fraction_transform").doc() =
      "The product phase fraction transformed at the closure time.";

  options.set_input("product_thickness") = VariableName{"state", "delta_P"};
  options.set("product_thickness").doc() = "Thickness of the product phase";

  EnumSelection order_type({"EXACT", "FIRST", "SECOND", "THIRD"}, "EXACT");
  options.set<EnumSelection>("order_type") = order_type;
  options.set("order_type").doc() = "Select the order of the rate equation. Options are " +
                                   order_type.join() + ". Default: EXACT";

  options.set_output("reaction_rate") = VariableName{"state", "alpha_rate"};
  options.set("reaction_rate").doc() = "Product phase thickness rate of change";

  return options;
}

NucleationThicknessGrowth::NucleationThicknessGrowth(const OptionSet & options)
  : Model(options),
    _R_l(options.get<VariableName>("liquid_reactivity").empty()
        ? nullptr
        : &declare_input_variable<Scalar>("liquid_reactivity")),
    _R_s(options.get<VariableName>("solid_reactivity").empty()
            ? nullptr
            : &declare_input_variable<Scalar>("solid_reactivity")),
    _K(declare_parameter<Scalar>("K", "growth_constant")),
    _hc(declare_parameter<Scalar>("hc", "closure_thickness", true)),
    _Q(declare_parameter<Scalar>("Q", "fraction_transform")),
    _delta_P(declare_input_variable<Scalar>("product_thickness")),
    _order_type(options.get<EnumSelection>("order_type")),
    _rate(declare_output_variable<Scalar>("reaction_rate"))
{
}

void
NucleationThicknessGrowth::set_value(bool out, bool dout_din, bool /*d2out_din2*/)
{

  const Scalar Rl = _R_l ? (*_R_l)() : Scalar::full(1.0, _delta_P.options());
  const Scalar Rs = _R_s ? (*_R_s)() : Scalar::full(1.0, _delta_P.options());

  const auto eps = machine_precision(_delta_P.scalar_type());

  // Shared quantities
  auto M = _hc / _Q;
  auto x = _delta_P / M;
  auto omhm_raw = 1.0 - x;
  auto omhm = omhm_raw;

  Scalar f = Scalar::full(0.0, _delta_P.options());
  Scalar dfdx = Scalar::full(0.0, _delta_P.options());

  if (_order_type == "FIRST") {
    f    = (x) / _K;
    dfdx = 1.0 / _K;
  }
  else if (_order_type == "SECOND") {
    f    = (x + 0.5 * x * x) / _K;
    dfdx = (1.0 + x) / _K;
  }
  else if (_order_type == "THIRD") {
    f    = (x + 0.5 * x * x + (1.0/3.0) * pow(x,3)) / _K;
    dfdx = (1.0 + x + x * x) / _K;
  }
  else if (_order_type == "EXACT") {
    omhm = clamp(omhm_raw, eps, 1.0 - eps);
    f    = -1.0 / (_K) * log(omhm);
    dfdx = 1.0 / (_K * omhm);
  }

  // Shared derivatives
  auto dfdP  = dfdx / M;                          
  auto dfdhc = dfdx * (-_delta_P / (M * _hc));    

  // Rate
  auto rate_val = 4.0 * _K * M * pow(f, 0.75) * omhm * Rl * Rs;

  if (out)
    _rate = rate_val;

  if (dout_din)
  {
    auto dRdP = 4.0 * _K * M * Rl * Rs *
      (0.75 * pow(f, -0.25) * dfdP * omhm - pow(f, 0.75) / M);

    _rate.d(_delta_P) = dRdP;

    if (_R_l && _R_l->is_dependent())
      _rate.d(*_R_l) = rate_val / Rl;

    if (_R_s && _R_s->is_dependent())
      _rate.d(*_R_s) = rate_val / Rs;

    if (const auto * const hc = nl_param("hc"))
    {
      auto dMdhc = M / _hc;
      auto dxdhc = -x / _hc;

      auto dgdx = 0.75 * pow(f, -0.25) * dfdx * omhm - pow(f, 0.75);

      auto dhc = 4.0 * _K * Rl * Rs * (
          dMdhc * pow(f, 0.75) * omhm   
        + M * dgdx * dxdhc              
      );

      _rate.d(*hc) = dhc;
    }
  }
}
} // namespace neml2