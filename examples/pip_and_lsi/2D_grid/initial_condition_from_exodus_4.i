[UserObjects]
    [reader_object2]
        type = SolutionUserObject
        mesh = '${save_folder}/out_cycle${fparse load_cycle}_${load_type}.e'
        system_variables = 'T disp_x disp_y phis phip phigcp o_Vref V'
        execute_on = 'INITIAL'
        timestep = 'LATEST'
    []
[]

[AuxVariables]
    # Named *_pyro so they collide with neither the NEML2 reactive_flow output
    # materials (phis/phip) nor infiltration_lsi.i's display aux (phi_C/phi_SiC).
    [phis_pyro]
        order = CONSTANT
        family = MONOMIAL
    []
    [phip_pyro]
        order = CONSTANT
        family = MONOMIAL
    []
    [phigcp_pyro]
        order = CONSTANT
        family = MONOMIAL
    []
    [o_Vref]
        order = CONSTANT
        family = MONOMIAL
    []
    [V]
        order = CONSTANT
        family = MONOMIAL
    []
[]

[ICs]
    [phis_pyro]
        type = SolutionIC
        from_variable = phis
        solution_uo = reader_object2
        variable = phis_pyro
    []
    [phip_pyro]
        type = SolutionIC
        from_variable = phip
        solution_uo = reader_object2
        variable = phip_pyro
    []
    [phigcp_pyro]
        type = SolutionIC
        from_variable = phigcp
        solution_uo = reader_object2
        variable = phigcp_pyro
    []
    [o_Vref]
        type = SolutionIC
        from_variable = o_Vref
        solution_uo = reader_object2
        variable = o_Vref
    []
    [V]
        type = SolutionIC
        from_variable = V
        solution_uo = reader_object2
        variable = V
    []
[]

[Materials]
    [init_phiC0]
        type = ParsedMaterial
        property_name = phi0_C
        expression = 'phis_pyro'
        coupled_variables = 'phis_pyro'
    []
    [init_phiSiC0_noreact]
        type = ParsedMaterial
        property_name = phi0SiC_noreact
        expression = 'phip_pyro + phigcp_pyro'
        coupled_variables = 'phigcp_pyro phip_pyro'
    []
    [init_o_Vref]
        type = ParsedMaterial
        property_name = o_Vref
        expression = 'o_Vref'
        coupled_variables = 'o_Vref'
    []
    [init_V]
        type = ParsedMaterial
        property_name = V
        expression = 'V'
        coupled_variables = 'V'
    []
[]

[ICs]
    [xinit]
        type = SolutionIC
        from_variable = disp_x
        solution_uo = reader_object2
        variable = disp_x
    []
    [yinit]
        type = SolutionIC
        from_variable = disp_y
        solution_uo = reader_object2
        variable = disp_y
    []
    [temp_IC]
        type = SolutionIC
        from_variable = T
        solution_uo = reader_object2
        variable = T
    []
    [phif]
        type = ConstantIC
        value = 0.0005
        variable = phif
    []
[]