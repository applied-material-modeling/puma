[Drivers]
  [unit]
    type = ModelUnitTest
    model = 'model'
    input_Scalar_names = 'state/phi_fs state/phi_m state/p state/eps_t'
    input_Scalar_values = '0.2 0.3 10.0 0.002'
    output_Scalar_names = 'state/sh'
    output_Scalar_values = '-113.600218'
  []
[]

[Models]
  [model]
    type = PhaseChangeRadialStress
    E_s = 1000
    nu_s = 0.3
    E_m = 2000
    nu_m = 0.25
    delta_Omega = 0.3
    macroscopic_strain = 'state/eps_t'
    pore_pressure = 'state/p'
    matrix_volume_fraction = 'state/phi_m'
    new_phase_volume_fraction = 'state/phi_fs'
    hydrostatic_stress = 'state/sh'
  []
[]