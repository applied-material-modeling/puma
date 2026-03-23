[Mesh]
    type = GeneratedMesh
    dim = 2
    nx = ${num_el_x}
    ny = ${num_el_y}
    xmax = ${L}
    ymax = ${L}
[]

# convection and Solid mechanics BCs
[BCs]
    [bottom]
        type = DirichletBC
        boundary = bottom
        value = 0.0
        variable = disp_y
    []
    [left]
        type = DirichletBC
        boundary = left
        value = 0.0
        variable = disp_x
    []
[]

[Physics]
    [SolidMechanics]
        [QuasiStatic]
            [sample]
                new_system = true
                add_variables = true
                strain = FINITE
                formulation = TOTAL
                volumetric_locking_correction = true
                generate_output = "max_principal_pk2_stress vonmises_pk2_stress"
            []
        []
    []
[]