[UserObjects]
    [reader_object1]
        type = PropertyReadFile
        prop_file_name = 'initial_condition.csv'
        read_type = 'voronoi'
        nprop = 4 # number of columns in CSV
        nvoronoi = '${num_file_data}' # number of rows that are considered\
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
    [init_phiC0]
        type = ParsedMaterial
        property_name = phi0_C
        expression = '(1-phi0_poro)*${C_ratio}'
        coupled_variables = phi0_poro
    []
    [init_phiSiC0_noreact]
        type = ParsedMaterial
        property_name = phi0SiC_noreact
        expression = '(1-phi0_poro)*${fparse 1-C_ratio}'
        coupled_variables = phi0_poro
    []
[]

[ICs]
    [temp]
        type = ConstantIC
        value = ${T0}
        variable = T
    []
    [phif]
        type = ConstantIC
        value = 0.0005
        variable = phif
    []
[]