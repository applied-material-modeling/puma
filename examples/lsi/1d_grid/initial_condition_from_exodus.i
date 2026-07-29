# Transfer the infiltration end-state (phif liquid, phi_C=C, phi_SiC=SiC)
# onto the solidification mesh as initial conditions. Merged with solidification.i
# via a second -i argument.  T is NOT transferred (infiltration is isothermal) — it
# is imposed uniformly (fully liquid) by solidification.i's T_IC.
[UserObjects]
    [reader]
        type = SolutionUserObject
        mesh = 'infiltration_out.e'
        system_variables = 'phif phi_C phi_SiC'
        execute_on = 'INITIAL'
        timestep = 'LATEST'
    []
[]

[AuxVariables]
    [phi_C]
        order = CONSTANT
        family = MONOMIAL
    []
    [phi_SiC]
        order = CONSTANT
        family = MONOMIAL
    []
[]

[ICs]
    [phif_from_infil]
        type = SolutionIC
        variable = phif
        from_variable = phif
        solution_uo = reader
    []
    [phiC_from_infil]
        type = SolutionIC
        variable = phi_C
        from_variable = phi_C
        solution_uo = reader
    []
    [phiSiC_from_infil]
        type = SolutionIC
        variable = phi_SiC
        from_variable = phi_SiC
        solution_uo = reader
    []
[]

# phis (=C) and phip (=SiC) become spatially-varying materials from the transferred
# fields (replacing the constant parameters in solidification.i).
[Materials]
    [phis_from_infil]
        type = ParsedMaterial
        property_name = phis
        coupled_variables = 'phi_C'
        expression = 'phi_C'
    []
    [phip_from_infil]
        type = ParsedMaterial
        property_name = phip
        coupled_variables = 'phi_SiC'
        expression = 'phi_SiC'
    []
[]
