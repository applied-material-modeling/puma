# neml2-custom-lib-template

This repository is a template CMake-based C++ project which extends NEML2 for defining custom models.

It creates a library named `mylib` which contains a custom model named "MyModel" extended from `neml2::Model`.

## Project structure

```
- README.md           <-- this file
- CMakeLists.txt      <-- tells CMake how to configure
                          and build our custom library
- include
  - MyModel.h         <-- header file of our custom model "MyModel"
- src
  - MyModel.cxx       <-- source file of our custom model "MyModel"
- test.i              <-- an example NEML2 input file using MyModel
```

## Installation

The majority of the [NEML2 installation guide](https://applied-material-modeling.github.io/neml2/install.html) still applies.

To make things easier, you can just follow these steps (assuming the development environment has been set up properly, e.g., CMake, PyTorch, etc.,):

### 1. Download and install NEML2

```
git clone git@github.com:applied-material-modeling/neml2.git
cd neml2
cmake --preset runner -B build
cmake --build build
cmake --install build --prefix /path/to/install/neml2
```

Note `/path/to/install/neml2` is the path where you want NEML2 to be installed.

### 2. Download and build our custom library

```
git clone git@github.com:applied-material-modeling/neml2-custom-lib-template.git
cd neml2-custom-lib-template
cmake -Dneml2_ROOT=/path/to/install/neml2 -B build -S .
cmake --build build
```

This will create a `build` directory and compile our custom library in it.

Our custom library will be named `libmylib.so` (on linux) or `libmylib.dylib` (on mac).

### 3. Use our custom model

Our custom library contains a custom model named "MyModel". It can be used together with other NEML2 models as usual.

`test.i` is an example input file:

```python
[Settings]
  additional_libraries = 'build/libmylib.so'
  # on mac this is probably 'build/libmylib.dylib'
[]

[Models]
  [a_model_from_neml2]
    type = ScalarLinearCombination
    from_var = 'state/A state/B'
    coefficients = '-1.1 2.3'
    to_var = 'state/C'
  []
  [another_model_from_neml2]
    type = ScalarLinearCombination
    from_var = 'state/B state/C'
    coefficients = '0.3 -1'
    to_var = 'state/D'
  []
  ######################################### our custom model
  [my_custom_model]
    type = MyModel
    y = 'state/E'
    x1 = 'state/C'
    x2 = 'state/D'
  []
  #########################################
  [model]
    type = ComposedModel
    models = 'a_model_from_neml2 another_model_from_neml2 my_custom_model'
  []
[]
```

Note how `Settings/additional_libraries` tells NEML2 to load our custom library.

To test it, try
```
/path/to/install/neml2/bin/runner inspect test.i model
```
which prints the summary of the composed model:
```
Name:       model
Input:      state/A [Scalar]
            state/B [Scalar]
Output:     state/E [Scalar]
Buffers:    a_model_from_neml2_c_0 [Scalar][Double][cpu]
            a_model_from_neml2_c_1 [Scalar][Double][cpu]
            another_model_from_neml2_c_0 [Scalar][Double][cpu]
            another_model_from_neml2_c_1 [Scalar][Double][cpu]
```

## Have fun developing!
