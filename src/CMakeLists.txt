# The Flutter tooling requires that developers have CMake 3.10 or later
# installed. You should not increase this version, as doing so will cause
# the plugin to fail to compile for some customers of the plugin.
cmake_minimum_required(VERSION 3.10)

project(my_plugin_library VERSION 0.0.1 LANGUAGES C)

add_library(my_plugin SHARED
  "my_plugin.c"
)

set_target_properties(my_plugin PROPERTIES
  PUBLIC_HEADER my_plugin.h
  OUTPUT_NAME "my_plugin"
)

target_compile_definitions(my_plugin PUBLIC DART_SHARED_LIB)
