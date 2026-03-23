[UserObjects]
    [reader_object2]
        type = SolutionUserObject
        mesh = '${save_folder}/out_cycle${fparse load_cycle}_${load_type}.e'
        system_variables = 'T disp_x disp_y disp_z ws wp wgcp o_Vref phiop V wc'
        execute_on = 'INITIAL'
        timestep = 'LATEST'
    []
[]

[AuxVariables]
    [phiop0]
        order = CONSTANT
        family = MONOMIAL
    []
    [phis0]
        order = CONSTANT
        family = MONOMIAL
    []
    [wp0]
        order = CONSTANT
        family = MONOMIAL
    []
    [ws0]
        order = CONSTANT
        family = MONOMIAL
    []
    [wb0]
        order = CONSTANT
        family = MONOMIAL
    []
    [wgcp0]
        order = CONSTANT
        family = MONOMIAL
    []
    [o_Vref0]
        order = CONSTANT
        family = MONOMIAL
    []
    [V0]
        order = CONSTANT
        family = MONOMIAL
    []
[]

[ICs]
    [wp]
        type = SolutionIC
        from_variable = wp
        solution_uo = reader_object2
        variable = wp0
    []
    [phiop]
        type = SolutionIC
        from_variable = phiop
        solution_uo = reader_object2
        variable = phiop0
    []
    [ws]
        type = SolutionIC
        from_variable = wc
        solution_uo = reader_object2
        variable = ws0
    []
    [wb]
        type = SolutionIC
        from_variable = ws
        solution_uo = reader_object2
        variable = wb0
    []
    [wgcp]
        type = SolutionIC
        from_variable = wgcp
        solution_uo = reader_object2
        variable = wgcp0
    []
    [o_Vref]
        type = SolutionIC
        from_variable = o_Vref
        solution_uo = reader_object2
        variable = o_Vref0
    []
    [V]
        type = SolutionIC
        from_variable = V
        solution_uo = reader_object2
        variable = V0
    []
[]

[Materials]
    [init_wb]
        type = ParsedMaterial
        property_name = wb0
        coupled_variables = 'wb0'
        expression = 'wb0/1.0'
    []
    [init_mwb0]
        type = ParsedMaterial
        property_name = mwb0
        coupled_variables = 'wb0'
        expression = '-wb0'
    []
    [init_wp]
        type = ParsedMaterial
        property_name = wp
        coupled_variables = 'wp0'
        expression = 'wp0/1.0'
    []
    [init_ws]
        type = ParsedMaterial
        property_name = ws0
        coupled_variables = 'ws0'
        expression = 'ws0/1.0'
    []
    [init_wgcp]
        type = ParsedMaterial
        property_name = wgcp0
        coupled_variables = 'wgcp0'
        expression = 'wgcp0/1.0'
    []
    [init_Vref]
        type = ParsedMaterial
        property_name = o_Vref
        coupled_variables = 'o_Vref0'
        expression = 'o_Vref0/1.0'
    []
    [init_phiop]
        type = ParsedMaterial
        property_name = phiop0
        coupled_variables = 'phiop0'
        expression = 'phiop0/1.0'
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
[]