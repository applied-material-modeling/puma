[UserObjects]
    [reader_object2]
        type = SolutionUserObject
        mesh = 'infiltration.e'
        system_variables = 'T phif disp_x disp_y phi_C phi_SiC phi0SiC_noreact'
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
    [phi0SiC_noreact]
        order = CONSTANT
        family = MONOMIAL
    []
[]

[ICs]
    [phi_C]
        type = SolutionIC
        from_variable = phi_C
        solution_uo = reader_object2
        variable = phi_C
    []
    [phi_SiC]
        type = SolutionIC
        from_variable = phi_SiC
        solution_uo = reader_object2
        variable = phi_SiC
    []
    [phi0SiC_noreact]
        type = SolutionIC
        from_variable = phi0SiC_noreact
        solution_uo = reader_object2
        variable = phi0SiC_noreact
    []
[]

[Materials]
    [phip]
        type = ParsedMaterial
        property_name = phip
        coupled_variables = 'phi_SiC'
        expression = 'phi_SiC'
    []
    [phis]
        type = ParsedMaterial
        property_name = phis
        coupled_variables = 'phi_C'
        expression = 'phi_C'
    []
    [phi0SiC_noreact]
        type = ParsedMaterial
        property_name = phi0SiC_noreact
        coupled_variables = 'phi0SiC_noreact'
        expression = 'phi0SiC_noreact'
    []
[]

#### Transfer of solid mechanics information ####
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
        type = SolutionIC
        from_variable = phif
        solution_uo = reader_object2
        variable = phif
    []
[]