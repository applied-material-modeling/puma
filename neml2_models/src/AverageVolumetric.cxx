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

#include "AverageVolumetric.h"

#include <neml2/base/Registry.h>
#include <neml2/tensors/R2.h>
#include <neml2/tensors/SR2.h>
#include <neml2/tensors/Scalar.h>
#include <neml2/tensors/functions/tr.h>

namespace neml2
{
using R2AverageVolumetric = AverageVolumetric<R2>;
using SR2AverageVolumetric = AverageVolumetric<SR2>;
register_NEML2_object(R2AverageVolumetric);
register_NEML2_object(SR2AverageVolumetric);

template <typename T>
OptionSet
AverageVolumetric<T>::expected_options()
{
  auto options = Model::expected_options();
  options.doc() = "Compute one-third of the trace of a second order tensor.";

  options.set_input("input") = VariableName(STATE, "A");
  options.set("input").doc() = "The second order tensor input";

  options.set_output("average_volumetric") = VariableName(STATE, "vol");
  options.set("average_volumetric").doc() = "One-third of the tensor trace";

  return options;
}

template <typename T>
AverageVolumetric<T>::AverageVolumetric(const OptionSet & options)
  : Model(options),
    _A(declare_input_variable<T>("input")),
    _v(declare_output_variable<Scalar>("average_volumetric"))
{
}

template <typename T>
void
AverageVolumetric<T>::set_value(bool out, bool dout_din, bool /*d2out_din2*/)
{
  if (out)
    _v = neml2::tr(_A()) / 3.0;

  if (dout_din && _A.is_dependent())
      _v.d(_A) = T::identity(_A.options()) / 3.0;
}

template class AverageVolumetric<R2>;
template class AverageVolumetric<SR2>;
} // namespace neml2
