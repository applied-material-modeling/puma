[UserObjects]
    [reader_object2]
        type = SolutionUserObject
        mesh = '${save_folder}/out_cycle${fparse load_cycle}_${load_type}.e'
        system_variables = 'T phif disp_x disp_y phi_C phiSiC_total o_Vref V'
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
    [phi_nonliquid]
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
    [phi_C]
        type = SolutionIC
        from_variable = phi_C
        solution_uo = reader_object2
        variable = phi_C
    []
    [phi_SiC]
        type = SolutionIC
        from_variable = phiSiC_total
        solution_uo = reader_object2
        variable = phi_SiC
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