cmake_minimum_required(VERSION 3.10)

project(begzar_native C CXX)

find_library(log-lib log)

add_library(
    begzar_security
    SHARED
    begzar_security_jni.cpp
    security/integrity.cpp
    security/anti_instrumentation.cpp
)

target_include_directories(begzar_security PRIVATE security)
target_link_libraries(begzar_security ${log-lib})

# Strip symbols in release builds (Gradle passes CMAKE_BUILD_TYPE).
if(CMAKE_BUILD_TYPE STREQUAL "Release")
    target_compile_options(begzar_security PRIVATE -O3 -fvisibility=hidden -ffunction-sections -fdata-sections)
    target_link_options(begzar_security PRIVATE -Wl,--gc-sections -Wl,--exclude-libs,ALL)
endif()
