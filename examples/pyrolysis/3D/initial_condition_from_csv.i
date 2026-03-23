
[UserObjects]
    [reader_object1]
        type = PropertyReadFile
        prop_file_name = 'initial_condition.csv'
        read_type = 'voronoi'
        nprop = 8 # number of columns in CSV
        nvoronoi = '${num_file_data}' # number of rows that are considered
    []
[]

[Functions]
    [wb0]
        type = PiecewiseConstantFromCSV
        read_prop_user_object = reader_object1
        read_type = 'voronoi'
        column_number = 3
    []
    [mwb0]
        type = PiecewiseConstantFromCSV
        read_prop_user_object = reader_object1
        read_type = 'voronoi'
        column_number = 7
    []
    [wp0]
        type = PiecewiseConstantFromCSV
        read_prop_user_object = reader_object1
        read_type = 'voronoi'
        column_number = 4
    []
    [o_Vref]
        type = PiecewiseConstantFromCSV
        read_prop_user_object = reader_object1
        read_type = 'voronoi'
        column_number = 5
    []
    [ws0]
        type = PiecewiseConstantFromCSV
        read_prop_user_object = reader_object1
        read_type = 'voronoi'
        column_number = 6
    []
[]

[Materials]
    [init_wb]
        type = GenericFunctionMaterial
        prop_names = 'wb0'
        prop_values = wb0
    []
    [init_wp]
        type = GenericFunctionMaterial
        prop_names = 'wp'
        prop_values = wp0
    []
    [init_V]
        type = GenericFunctionMaterial
        prop_names = 'o_Vref'
        prop_values = o_Vref
    []
    [init_mwb0]
        type = GenericFunctionMaterial
        prop_names = 'mwb0'
        prop_values = mwb0
    []
    [init_ws]
        type = GenericFunctionMaterial
        prop_names = 'ws0'
        prop_values = ws0
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