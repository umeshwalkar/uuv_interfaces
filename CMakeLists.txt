cmake_minimum_required(VERSION 3.20)
project(uuv_interfaces CXX)

set(CMAKE_CXX_STANDARD 17)
set(CMAKE_CXX_STANDARD_REQUIRED ON)

# Fast DDS package name differs by version line: the ENTIRE 2.x line's CMake
# project is literally named 'fastrtps' (umeshwalkar/xl300-dev-base:0.1.0 pins
# Fast-DDS 2.14.x LTS). Only resolve it here if a consumer hasn't already --
# add_subdirectory()'d consumers that already called find_package() themselves
# will have the target in scope, and calling find_package() twice is harmless
# either way.
if(NOT TARGET fastdds AND NOT TARGET fastrtps)
  find_package(fastdds QUIET CONFIG)
  if(NOT fastdds_FOUND)
    find_package(fastrtps REQUIRED CONFIG)
  endif()
endif()
if(TARGET fastdds)
  set(FASTDDS_TARGET fastdds)
else()
  set(FASTDDS_TARGET fastrtps)
endif()
if(NOT TARGET fastcdr)
  find_package(fastcdr REQUIRED)
endif()

# Generated type support: run gen.sh FIRST -> generated/*.cxx + headers.
set(DDS_GEN_DIR "${CMAKE_CURRENT_SOURCE_DIR}/generated")
if(NOT EXISTS "${DDS_GEN_DIR}")
  message(FATAL_ERROR
    "Generated DDS types not found at ${DDS_GEN_DIR}.\n"
    "Run:  ./gen.sh   (requires fastddsgen -- see README.md)")
endif()
file(GLOB GEN_SRCS "${DDS_GEN_DIR}/*.cxx")

add_library(xl300_dds_types STATIC ${GEN_SRCS})
target_include_directories(xl300_dds_types PUBLIC ${DDS_GEN_DIR})
target_link_libraries(xl300_dds_types PUBLIC ${FASTDDS_TARGET} fastcdr)
