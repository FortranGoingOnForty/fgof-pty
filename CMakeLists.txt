cmake_minimum_required(VERSION 3.25)

project(fgof_pty VERSION 0.1.0 LANGUAGES Fortran C)

add_library(fgof_pty
  src/fgof_pty_types.f90
  src/fgof_pty_posix.f90
  src/fgof_pty.f90
  src/fgof_pty_posix.c
)
add_library(fgof::pty ALIAS fgof_pty)

set_target_properties(fgof_pty PROPERTIES
  Fortran_MODULE_DIRECTORY "${CMAKE_CURRENT_BINARY_DIR}/mod"
)

target_include_directories(fgof_pty PUBLIC
  $<BUILD_INTERFACE:${CMAKE_CURRENT_BINARY_DIR}/mod>
)

target_compile_options(fgof_pty PRIVATE
  $<$<COMPILE_LANG_AND_ID:Fortran,GNU>:-std=f2018 -Wall -Wextra -Wpedantic -Werror>
  $<$<COMPILE_LANG_AND_ID:C,GNU,Clang,AppleClang>:-Wall -Wextra -Wpedantic -Werror>
)
