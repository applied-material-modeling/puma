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

#include "PK2HydrostaticStress.h"
#include <neml2/base/Registry.h>

#include <neml2/tensors/Scalar.h>
#include <neml2/tensors/R2.h>
#include <neml2/tensors/functions/einsum.h>
#include <neml2/tensors/functions/symmetrization.h>
#include <neml2/tensors/functions/inv.h>
#include <neml2/tensors/functions/det.h>

namespace neml2
{
register_NEML2_object(PK2HydrostaticStress);

OptionSet
PK2HydrostaticStress::expected_options()
{
  OptionSet options = Model::expected_options();
  options.doc() =
      "Phase-change PK2 stress contribution, "
      "\\f$ \\mathbf{S}^{pc} = -J \\, \\sigma_h \\, \\mathbf{F}^{-1}\\mathbf{F}^{-T} "
      "= -J \\, \\sigma_h \\, \\mathbf{C}^{-1} \\f$, "
      "with \\f$ J = \\det(\\mathbf{F}) \\f$.";

  options.set_input("hydrostatic_stress") = VariableName(STATE, "sigma_h");
  options.set("hydrostatic_stress").doc() = "Hydrostatic Cauchy stress offset";

  options.set_input("deformation_gradient") = VariableName(FORCES, "F");
  options.set("deformation_gradient").doc() = "Deformation gradient";

  options.set_output("pk2_stress") = VariableName(STATE, "Spc");
  options.set("pk2_stress").doc() = "Phase-change PK2 stress contribution";

  return options;
}

PK2HydrostaticStress::PK2HydrostaticStress(const OptionSet & options)
  : Model(options),
    _Spc(declare_output_variable<R2>("pk2_stress")),
    _sh(declare_input_variable<Scalar>("hydrostatic_stress")),
    _F(declare_input_variable<R2>("deformation_gradient"))
{
}

void
PK2HydrostaticStress::set_value(bool out, bool dout_din, bool /*d2out_din2*/)
{
  const auto F = _F();
  const auto Finv = neml2::inv(F);
  const auto Cinv = Finv * Finv.transpose();
  const auto J = neml2::det(F);
  const auto a = J * _sh;

  if (out)
    _Spc = -a * Cinv;

  if (dout_din)
  {
    _Spc.d(_sh) = -J * Cinv;

    const auto term1 = einsum("...im,...nj->...ijmn", {Finv, Cinv});
    const auto term2 = einsum("...in,...jm->...ijmn", {Cinv, Finv});
    const auto term3 = einsum("...nm,...ij->...ijmn", {Finv, Cinv});

    _Spc.d(_F) = a * (term1 + term2 - term3);
  }
}

} // namespace neml2