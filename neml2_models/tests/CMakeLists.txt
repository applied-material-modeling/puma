# Catch2 config after a built NEML2 can be found at
# /contrib/Catch2/lib/cmake/Catch2
# so set -DCatch2_DIR=/path/to/neml2/contrib/Catch2/lib/cmake/Catch2 

find_package(Catch2 CONFIG REQUIRED)

file(GLOB_RECURSE TEST_SRCS CONFIGURE_DEPENDS
  ${CMAKE_CURRENT_SOURCE_DIR}/src/*.cxx
)

add_executable(unit_tests ${TEST_SRCS})

target_include_directories(unit_tests PRIVATE
  ${CMAKE_CURRENT_SOURCE_DIR}/include
)

target_link_libraries(unit_tests PRIVATE
  puma_matlib
  neml2::neml2
  Catch2::Catch2WithMain
)

target_compile_definitions(unit_tests PRIVATE
  PUMA_TESTS_SOURCE_DIR="${CMAKE_CURRENT_SOURCE_DIR}"
)

include(Catch)
catch_discover_tests(unit_tests)

add_custom_command(TARGET unit_tests POST_BUILD
  COMMAND ${CMAKE_COMMAND} -E copy
  $<TARGET_FILE:puma_matlib>
  ${CMAKE_CURRENT_SOURCE_DIR}/unit/
)