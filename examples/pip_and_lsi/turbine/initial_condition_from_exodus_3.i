[UserObjects]
    [reader_object2]
        type = SolutionUserObject
        mesh = '${save_folder}/out_cycle${fparse load_cycle}_${load_type}.e'
        system_variables = 'T disp_x disp_y disp_z ws wp wgcp o_Vref V phiop'
        execute_on = 'INITIAL'
        timestep = 'LATEST'
    []
[]

[AuxVariables]
    [phiop0]
        order = CONSTANT
        family = MONOMIAL
    []
    [ws]
        order = CONSTANT
        family = MONOMIAL
    []
    [wp]
        order = CONSTANT
        family = MONOMIAL
    []
    [wgcp]
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
    [phiop0]
        type = SolutionIC
        from_variable = phiop
        solution_uo = reader_object2
        variable = phiop0
    []
    [ws]
        type = SolutionIC
        from_variable = ws
        solution_uo = reader_object2
        variable = ws
    []
    [wp]
        type = SolutionIC
        from_variable = wp
        solution_uo = reader_object2
        variable = wp
    []
    [wgcp]
        type = SolutionIC
        from_variable = wgcp
        solution_uo = reader_object2
        variable = wgcp
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
    [init_phifmax]
        type = ParsedMaterial
        property_name = void
        coupled_variables = 'phiop0'
        expression = 'phiop0/1.0'
    []
    [init_ws]
        type = ParsedMaterial
        property_name = ws
        coupled_variables = 'ws'
        expression = 'ws'
    []
    [init_wp]
        type = ParsedMaterial
        property_name = wp
        coupled_variables = 'wp'
        expression = 'wp'
    []
    [init_wgcp]
        type = ParsedMaterial
        property_name = wgcp
        coupled_variables = 'wgcp'
        expression = 'wgcp'
    []
    [init_o_Vref]
        type = ParsedMaterial
        property_name = o_Vref
        coupled_variables = 'o_Vref'
        expression = 'o_Vref'
    []
    [init_V]
        type = ParsedMaterial
        property_name = V
        coupled_variables = 'V'
        expression = 'V'
    []
    [phi_solid]
        type = ParsedMaterial
        property_name = phi_solid
        coupled_variables = 'phiop0'
        expression = '1.0 - phiop0'
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
    [zinit]
        type = SolutionIC
        from_variable = disp_z
        solution_uo = reader_object2
        variable = disp_z
    []
    [temp_IC]
        type = SolutionIC
        from_variable = T
        solution_uo = reader_object2
        variable = T
    []
    [phif]
        type = ConstantIC
        variable = phif
        value = 0.00001
    []
[]