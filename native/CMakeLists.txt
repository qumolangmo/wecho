cmake_minimum_required(VERSION 3.10.2)

project(wecho_dsp VERSION 1.0.0 LANGUAGES CXX)

set(CMAKE_CXX_STANDARD 20)
set(CMAKE_CXX_STANDARD_REQUIRED ON)
set(CMAKE_CXX_EXTENSIONS OFF)

set(WECHO_DSP_INCLUDE_DIR ${CMAKE_CURRENT_SOURCE_DIR})

set(WECHO_DSP_SOURCES
    ${CMAKE_CURRENT_SOURCE_DIR}/effects/BassEffect.cpp
    ${CMAKE_CURRENT_SOURCE_DIR}/effects/ChannelBalanceEffect.cpp
    ${CMAKE_CURRENT_SOURCE_DIR}/effects/ConvolveEffect.cpp
    ${CMAKE_CURRENT_SOURCE_DIR}/effects/ClarityEffect.cpp
    ${CMAKE_CURRENT_SOURCE_DIR}/effects/GainEffect.cpp
    ${CMAKE_CURRENT_SOURCE_DIR}/effects/EvenHarmonicEffect.cpp
    ${CMAKE_CURRENT_SOURCE_DIR}/effects/LimiterEffect.cpp
    ${CMAKE_CURRENT_SOURCE_DIR}/effects/LookAheadSoftLimitEffect.cpp
    ${CMAKE_CURRENT_SOURCE_DIR}/effects/LowCatEffect.cpp
    ${CMAKE_CURRENT_SOURCE_DIR}/effects/IIREqualizerEffect.cpp
    ${CMAKE_CURRENT_SOURCE_DIR}/effects/VirtualBassEffect.cpp

)

add_library(wecho_dsp STATIC ${WECHO_DSP_SOURCES})

target_include_directories(wecho_dsp PUBLIC
    ${WECHO_DSP_INCLUDE_DIR}
)

set(WECHO_DSP_INCLUDE_DIR ${WECHO_DSP_INCLUDE_DIR} PARENT_SCOPE)
