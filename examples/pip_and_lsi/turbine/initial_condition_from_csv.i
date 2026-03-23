
[UserObjects]
    [reader_object1]
        type = PropertyReadFile
        prop_file_name = 'initial_condition.csv'
        read_type = 'voronoi'
        nprop = 4 # number of columns in CSV
        nvoronoi = '${num_file_data}' # number of rows that are considered
    []
[]

[Functions]
    [phi0_poro]
        type = PiecewiseConstantFromCSV
        read_prop_user_object = reader_object1
        read_type = 'voronoi'
        column_number = 3
    []
[]

[AuxVariables]
    [phi0_poro]
        order = CONSTANT
        family = MONOMIAL
    []
[]

[ICs]
    [phi0_poro]
        type = FunctionIC
        function = phi0_poro
        variable = phi0_poro
    []
[]

[Materials]
    [init_wb]
        type = ParsedMaterial
        property_name = 'wb0'
        expression = '((phi0_poro) * ${rho_b}) / ((1 - (phi0_poro)) * ${rho_p})/ (1+((phi0_poro) * ${rho_b}) / ((1 - (phi0_poro)) * ${rho_p}))'
        coupled_variables = phi0_poro
    []
    [init_wp]
        type = ParsedMaterial
        property_name = 'wp'
        expression = '1-wb0'
        material_property_names = wb0
    []
    [init_V]
        type = ParsedMaterial
        property_name = 'o_Vref'
        expression = '1.0 / (${Mref} * (wb0/${rho_b} + wp/${rho_p}))'
        material_property_names = 'wb0 wp'
    []
    [init_mwb0]
        type = ParsedMaterial
        property_name = 'mwb0'
        expression = '-wb0'
        material_property_names = wb0
    []
    [init_ws]
        type = GenericConstantMaterial
        prop_names = 'ws0'
        prop_values = 0.0
    []
    [init_phiop]
        type = GenericConstantMaterial
        prop_names = 'phiop0'
        prop_values = '0.0'
    []
    [init_mat]
        type = GenericConstantMaterial
        prop_names = 'wgcp0'
        prop_values = '0.0'
    []
[]

[ICs]
    [temp_IC]
        type = ConstantIC
        variable = T
        value = ${T0}
    []
[]