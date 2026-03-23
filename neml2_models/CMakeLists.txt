cmake_minimum_required(VERSION 3.26)
project(MyProject LANGUAGES CXX)

# get everything in the src directory and make a library from it
file(GLOB_RECURSE SRC_FILES CONFIGURE_DEPENDS
  ${CMAKE_CURRENT_SOURCE_DIR}/src/*.cxx
)
add_library(puma_matlib SHARED ${SRC_FILES})

target_include_directories(puma_matlib PUBLIC
  $<BUILD_INTERFACE:${CMAKE_CURRENT_SOURCE_DIR}/include>
  $<INSTALL_INTERFACE:include>
)

# Find the neml2 package (which should have been installed)
#
# See CMake "Config Mode Search Procedure" for how you can control the search procedure
# https://cmake.org/cmake/help/latest/command/find_package.html#config-mode-search-procedure
#
# This will define imported targets like `neml2::neml2` that you can link against.
find_package(neml2 CONFIG)
target_link_libraries(puma_matlib PRIVATE neml2::neml2)

option(PUMA_MATLIB_TESTS "Build tests" ON)
if(PUMA_MATLIB_TESTS)
  add_subdirectory(tests)
endif()