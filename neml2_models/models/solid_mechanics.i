E = 1000
mu = 0.3

[Models]
    [Jacobian]
        type = R2Determinant
        input = 'deformation_gradient'
        determinant = 'J'
    []
    [Jtotal]
        type = ThermalDeformationJacobian
        temperature = 'T'
        reference_temperature = 300
        CTE = 1e-5
        jacobian = 'JFthermal'
    []
    [totalF]
        type = VolumeAdjustDeformationGradient
        input = 'deformation_gradient'
        output = 'Fe'
        jacobian = 'JFthermal'
    []
    [green_strain]
        type = GreenLagrangeStrain
        deformation_gradient = 'Fe'
        strain = 'Ee'
    []
    [S_pk2]
        type = LinearIsotropicElasticity
        strain = 'Ee'
        stress = 'pk2_SR2'
        coefficients = '${E} ${mu}'
        coefficient_types = 'YOUNGS_MODULUS POISSONS_RATIO'
    []
    [S_pk2_R2]
        type = SR2ToR2
        input = 'pk2_SR2'
        output = 'pk2'
    []
    [S_pk1]
        type = R2Multiplication
        A = 'deformation_gradient'
        B = 'pk2'
        to = 'neml2_pk1'
        invert_B = false
    []
    [model]
        type = ComposedModel
        models = 'Jacobian Jtotal totalF green_strain S_pk2 S_pk2_R2 S_pk1'
        additional_outputs = 'pk2'
    []
[]
