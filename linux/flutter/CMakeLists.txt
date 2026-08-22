cmake_minimum_required(VERSION 3.10)

set(EPHEMERAL_DIR "${CMAKE_CURRENT_SOURCE_DIR}/ephemeral")

if(NOT EXISTS "${EPHEMERAL_DIR}/flutter_linux_gtk.cc")
  message(FATAL_ERROR "Flutter ephemeral directory is missing. Run 'flutter build linux' to generate it.")
endif()

add_library(flutter INTERFACE)
target_include_directories(flutter INTERFACE
  "${EPHEMERAL_DIR}"
  "${EPHEMERAL_DIR}/cpp_client_wrapper/include"
  "${EPHEMERAL_DIR}/flutter_linux"
)

find_package(PkgConfig REQUIRED)
pkg_check_modules(GTK REQUIRED IMPORTED_TARGET gtk+-3.0)
pkg_check_modules(FLUTTER_GTK REQUIRED IMPORTED_TARGET flutter_linux_gtk)

target_link_libraries(flutter INTERFACE PkgConfig::GTK PkgConfig::FLUTTER_GTK)

set(FLUTTER_LIBRARY "${EPHEMERAL_DIR}/libflutter_linux_gtk.so" PARENT_SCOPE)
set(FLUTTER_ICU_DATA_FILE "${EPHEMERAL_DIR}/icudtl.dat" PARENT_SCOPE)
set(PROJECT_BUILD_DIR "${EPHEMERAL_DIR}/.." PARENT_SCOPE)
set(AOT_LIBRARY "${EPHEMERAL_DIR}/libapp.so" PARENT_SCOPE)
set(FLUTTER_ASSET_DIR_NAME "flutter_assets" PARENT_SCOPE)

add_custom_target(flutter_assemble DEPENDS
  "${FLUTTER_LIBRARY}"
  "${FLUTTER_ICU_DATA_FILE}"
  "${AOT_LIBRARY}"
)

include("${EPHEMERAL_DIR}/generated_config.cmake" OPTIONAL)
include("generated_plugins.cmake" OPTIONAL)
