# Copyright (c) 2026 qumolangmo
# 
# License: MIT License with Commons Clause License Condition v1.0
# see LICENSE-MIT and LICENSE-COMMONS-CLAUSE in the project root for full license text.
# 
# For commercial use, please contact: qumolangmo@gmail.com

cmake_minimum_required(VERSION 3.10.2)

project("wecho")

set(CMAKE_CXX_STANDARD 20)
set(CMAKE_CXX_STANDARD_REQUIRED ON)
set(CMAKE_CXX_EXTENSIONS OFF)

set(CMAKE_CXX_FLAGS "${CMAKE_CXX_FLAGS} -O3 -DANDROID_ABI=arm64-v8a")

find_package(oboe REQUIRED CONFIG)

add_subdirectory(${CMAKE_SOURCE_DIR}/../../../../../native ${CMAKE_BINARY_DIR}/native)

set(FFTW_LIB_DIR ${CMAKE_SOURCE_DIR}/../jniLibs/arm64-v8a)
link_directories(${FFTW_LIB_DIR})

set(SOURCES
    native-lib.cpp
)

add_library(
    wecho
    SHARED
    ${SOURCES}
)

target_include_directories(wecho PRIVATE ${WECHO_DSP_INCLUDE_DIR})

target_link_libraries(
    wecho
    android
    log
    fftw3f
    oboe::oboe
    wecho_dsp
)
