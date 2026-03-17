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

#include "PhaseChangeRadialStress.h"
#include <neml2/base/Registry.h>

#include <neml2/tensors/Scalar.h>
#include <neml2/tensors/functions/pow.h>
#include <neml2/tensors/functions/clamp.h>

namespace neml2
{
register_NEML2_object(PhaseChangeRadialStress);

OptionSet
PhaseChangeRadialStress::expected_options()
{
  OptionSet options = Model::expected_options();
  options.doc() = "Closed-form radial interface stress for an axisymmetric "
                  "phase transformation with volumetric misfit.";

  // Parameters
  options.set_parameter<TensorName<Scalar>>("E_s");
  options.set("E_s").doc() = "New Phase Young's modulus";
  
  options.set_parameter<TensorName<Scalar>>("nu_s");
  options.set("nu_s").doc() = "New Phase Poisson's ratio";

  options.set_parameter<TensorName<Scalar>>("E_m");
  options.set("E_m").doc() = "Matrix Young's modulus";

  options.set_parameter<TensorName<Scalar>>("nu_m");
  options.set("nu_m").doc() = "Matrix Poisson's ratio";

  options.set_parameter<TensorName<Scalar>>("delta_Omega");
  options.set("delta_Omega").doc()  = "Volumetric misfit";

  // State inputs
  options.set_input("macroscopic_strain") = VariableName{"state", "eps_t"};
  options.set("macroscopic_strain").doc() = "Macroscopic radial strain";

  options.set_input("pore_pressure") = VariableName{"state", "p"};
  options.set("pore_pressure").doc() = "Pore pressure";

  options.set_input("matrix_volume_fraction") = VariableName{"state", "phi_m"};
  options.set("matrix_volume_fraction").doc() = "Matrix volume fraction";

  options.set_input("new_phase_volume_fraction") = VariableName{"state", "phi_fs"};
  options.set("new_phase_volume_fraction").doc() = "New phase volume fraction";

  // Output
  options.set_output("radial_stress") = VariableName{"state", "radial_stress"};
  options.set("radial_stress").doc() = "Radial stress at the phase-solid interface";

  return options;
}

PhaseChangeRadialStress::PhaseChangeRadialStress(const OptionSet & options)
  : Model(options),
    _Es(declare_parameter<Scalar>("E_s","E_s")),
    _nus(declare_parameter<Scalar>("nu_s","nu_s")),
    _Em(declare_parameter<Scalar>("E_m","E_m")),
    _num(declare_parameter<Scalar>("nu_m","nu_m")),
    _dw(declare_parameter<Scalar>("delta_Omega","delta_Omega")),
    _eps_t(declare_input_variable<Scalar>("macroscopic_strain")),
    _p(declare_input_variable<Scalar>("pore_pressure")),
    _phi_m(declare_input_variable<Scalar>("matrix_volume_fraction")),
    _phi_fs(declare_input_variable<Scalar>("new_phase_volume_fraction")),
    _srr(declare_output_variable<Scalar>("radial_stress"))
{
}

void
PhaseChangeRadialStress::set_value(bool out, bool dout_din, bool /*d2out_din2*/)
{

  const auto eps = machine_precision(_phi_m.scalar_type());

  auto a2_raw = 1.0 - _phi_m - _phi_fs;
  auto b2_raw = 1.0 - _phi_m;

  auto a2 = clamp(a2_raw, eps, 1.0);
  auto b2 = clamp(b2_raw, eps, 1.0);

  auto a  = pow(a2, 0.5);
  auto b  = pow(b2, 0.5);

  auto b3   = b2 * b;
  auto b4   = b2 * b2;
  auto a2b2 = a2 * b2;

  auto one_p_num  = (1.0 + _num);
  auto one_m2_num = clamp(1.0 - 2.0 * _num, eps, 1.0);

  auto one_p_nus  = (1.0 + _nus);
  auto one_m2_nus = clamp(1.0 - 2.0 * _nus, eps, 1.0);

  auto Mm  = _Em * (1.0 - _num) / (one_p_num * one_m2_num);
  auto Ms  = _Es * (1.0 - _nus) / (one_p_nus * one_m2_nus);
  auto mum = _Em / (2.0 * one_p_num);
  auto mus = _Es / (2.0 * one_p_nus);

  auto d = _dw;

  auto C_a2b2 = Mm * Ms - Mm * mus - Ms * mum + Ms * mus + mum * mus - mus * mus;
  auto C_a2   = Ms * mum - Ms * mus - mum * mus + mus * mus;
  auto C_b4   = Mm * mus - Ms * mus - mum * mus + mus * mus;
  auto C_b2   = Ms * mus + mum * mus - mus * mus;

  auto D_num =
        C_a2b2 * a2b2
      + C_a2   * a2
      + C_b4   * b4
      + C_b2   * b2;

  auto denom_D = a2 * b3 + eps;
  auto D       = -4.0 * D_num / denom_D;

  auto A_a2b2 =
      -3.0 * Mm * Ms * d + 4.0 * Mm * d * mus + 3.0 * Mm * _p
    + 3.0 * Ms * d * mum - 3.0 * Ms * d * mus
    - 4.0 * d * mum * mus + 4.0 * d * mus * mus
    - 3.0 * mum * _p + 3.0 * mus * _p;

  auto A_a2 =
      -3.0 * Ms * d * mum + 3.0 * Ms * d * mus
    + 4.0 * d * mum * mus - 4.0 * d * mus * mus
    + 3.0 * mum * _p - 3.0 * mus * _p;

  auto A_b4 =
      3.0 * Ms * d * mus - 4.0 * d * mus * mus;

  auto A_b2 =
      -6.0 * Mm * _eps_t * mus
    - 3.0 * Ms * d * mus
    + 4.0 * d * mus * mus;

  auto N_As_num =
        A_a2b2 * a2b2
      + A_a2   * a2
      + A_b4   * b4
      + A_b2   * b2;

  auto B_b2 =
      -3.0 * Mm * Ms * d + 4.0 * Mm * d * mus + 3.0 * Mm * _p
    + 3.0 * Ms * d * mum - 3.0 * Ms * _p
    - 4.0 * d * mum * mus - 3.0 * mum * _p + 3.0 * mus * _p;

  auto B_const =
        6.0 * Mm * Ms * _eps_t
      - 6.0 * Mm * _eps_t * mus
      - 3.0 * Ms * d * mum + 3.0 * Ms * _p
      + 4.0 * d * mum * mus + 3.0 * mum * _p - 3.0 * mus * _p;

  auto N_Bs_num = B_b2 * b2 + B_const;

  auto denom_As = denom_D;
  auto denom_Bs = b + eps;

  auto cA =  2.0 / 3.0;
  auto cB = -2.0 / 3.0;

  auto Q_As = denom_As * D;
  auto Q_Bs = denom_Bs * D;

  auto As = cA * N_As_num / Q_As;
  auto Bs = cB * N_Bs_num / Q_Bs;

  auto denom_s = (1.0 + _nus) * (1.0 - 2.0 * _nus) + eps;

  auto sigma_int =
        _Es * As / denom_s
      - (_Es / (1.0 + _nus)) * (Bs / (b2 + eps))
      - _Es * _dw / (3.0 * (1.0 - 2.0 * _nus) + eps);

  if (out)
    _srr = sigma_int;

  if (dout_din)
  {
    auto dA_a2b2_dp = 3.0 * Mm - 3.0 * mum + 3.0 * mus;
    auto dA_a2_dp   = 3.0 * mum - 3.0 * mus;
    auto dA_b4_dp   = Scalar::full(0.0, _phi_m.options());
    auto dA_b2_dp   = Scalar::full(0.0, _phi_m.options());
  
    auto dN_As_dp =
          dA_a2b2_dp * a2b2
        + dA_a2_dp   * a2
        + dA_b4_dp   * b4
        + dA_b2_dp   * b2;
  
    auto dA_a2b2_deps = Scalar::full(0.0, _phi_m.options());
    auto dA_a2_deps   = Scalar::full(0.0, _phi_m.options());
    auto dA_b4_deps   = Scalar::full(0.0, _phi_m.options());
    auto dA_b2_deps   = -6.0 * Mm * mus;
  
    auto dN_As_deps =
          dA_a2b2_deps * a2b2
        + dA_a2_deps   * a2
        + dA_b4_deps   * b4
        + dA_b2_deps   * b2;
  
    auto dB_b2_dp =
        3.0 * Mm - 3.0 * Ms - 3.0 * mum + 3.0 * mus;
    auto dB_const_dp =
        3.0 * Ms + 3.0 * mum - 3.0 * mus;
  
    auto dN_Bs_dp =
          dB_b2_dp * b2
        + dB_const_dp;
  
    auto dB_b2_deps   = Scalar::full(0.0, _phi_m.options());
    auto dB_const_deps = 6.0 * Mm * Ms - 6.0 * Mm * mus;
  
    auto dN_Bs_deps =
          dB_b2_deps   * b2
        + dB_const_deps;
  
    auto dQ_As_dp   = Scalar::full(0.0, _phi_m.options()); 
    auto dQ_Bs_dp   = Scalar::full(0.0, _phi_m.options());
    auto dQ_As_deps = Scalar::full(0.0, _phi_m.options());
    auto dQ_Bs_deps = Scalar::full(0.0, _phi_m.options());
  
    auto dAs_dp   = cA * (dN_As_dp   * Q_As - N_As_num * dQ_As_dp)   / (Q_As * Q_As);
    auto dAs_deps = cA * (dN_As_deps * Q_As - N_As_num * dQ_As_deps) / (Q_As * Q_As);
  
    auto dBs_dp   = cB * (dN_Bs_dp   * Q_Bs - N_Bs_num * dQ_Bs_dp)   / (Q_Bs * Q_Bs);
    auto dBs_deps = cB * (dN_Bs_deps * Q_Bs - N_Bs_num * dQ_Bs_deps) / (Q_Bs * Q_Bs);
  
    auto d_sigma_dp =
          _Es * dAs_dp / denom_s
        - (_Es / (1.0 + _nus)) * (dBs_dp / (b2 + eps));
  
    auto d_sigma_deps =
          _Es * dAs_deps / denom_s
        - (_Es / (1.0 + _nus)) * (dBs_deps / (b2 + eps));
  
    _srr.d(_p)     = d_sigma_dp;
    _srr.d(_eps_t) = d_sigma_deps;
  
    // for other two derivatives
    auto compute_dsigma_dphi =
      [&](const Scalar & da2, const Scalar & db2) -> Scalar
    {
      auto da = 0.5 * da2 / (a + eps);
      auto db = 0.5 * db2 / (b + eps);
  
      auto da2b2 = da2 * b2 + a2 * db2;
      auto db3   = db2 * b + b2 * db;
      auto db4   = 2.0 * b2 * db2; 
  
      auto dD_num =
            C_a2b2 * da2b2
          + C_a2   * da2
          + C_b4   * db4
          + C_b2   * db2;
  
      auto ddenom_D = da2 * b3 + a2 * db3;
  
      auto dD = -4.0 * (dD_num * denom_D - D_num * ddenom_D) / (denom_D * denom_D);
  
      auto dN_As =
            A_a2b2 * da2b2
          + A_a2   * da2
          + A_b4   * db4
          + A_b2   * db2;
  
      auto dN_Bs = B_b2 * db2;
  
      auto ddenom_As = ddenom_D;
      auto dQ_As     = ddenom_As * D + denom_As * dD;
  
      auto dAs =
        cA * (dN_As * Q_As - N_As_num * dQ_As) / (Q_As * Q_As);
  
      auto ddenom_Bs = db;
      auto dQ_Bs     = ddenom_Bs * D + denom_Bs * dD;
  
      auto dBs =
        cB * (dN_Bs * Q_Bs - N_Bs_num * dQ_Bs) / (Q_Bs * Q_Bs);
  
      auto db2_eps = b2 + eps;
  
      auto d_sigma_dphi =
            _Es * dAs / denom_s
          - (_Es / (1.0 + _nus)) *
            ( dBs / db2_eps
            - Bs * db2 / (db2_eps * db2_eps) );
  
      return d_sigma_dphi;
    };

    auto da2_phi_m = Scalar::full(-1.0, _phi_m.options());
    auto db2_phi_m = Scalar::full(-1.0, _phi_m.options());
    _srr.d(_phi_m) = compute_dsigma_dphi(da2_phi_m, db2_phi_m);
  
    auto da2_phi_fs = Scalar::full(-1.0, _phi_m.options());
    auto db2_phi_fs = Scalar::full( 0.0, _phi_m.options());
    _srr.d(_phi_fs) = compute_dsigma_dphi(da2_phi_fs, db2_phi_fs);
  }
}
} // namespace neml2
