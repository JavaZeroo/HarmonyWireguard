cmake_minimum_required(VERSION 3.5.0)
project(HarmonyWireguard)

set(NATIVERENDER_ROOT_PATH ${CMAKE_CURRENT_SOURCE_DIR})

if(DEFINED PACKAGE_FIND_FILE)
    include(${PACKAGE_FIND_FILE})
endif()

# 头文件搜索路径
include_directories(${NATIVERENDER_ROOT_PATH})
include_directories(${NATIVERENDER_ROOT_PATH}/wireguard)
include_directories(${NATIVERENDER_ROOT_PATH}/wireguard/crypto/refc)
include_directories(${NATIVERENDER_ROOT_PATH}/tunnel)
include_directories(${NATIVERENDER_ROOT_PATH}/utils)

# 收集所有源文件
file(GLOB WG_SOURCES
    ${NATIVERENDER_ROOT_PATH}/tunnel/*.cpp
    ${NATIVERENDER_ROOT_PATH}/utils/*.cpp
    ${NATIVERENDER_ROOT_PATH}/*.cpp
)

# WireGuard 协议核心
file(GLOB WG_CRYPTO_SOURCES ${NATIVERENDER_ROOT_PATH}/wireguard/crypto/refc/*.c)
list(APPEND WG_SOURCES ${NATIVERENDER_ROOT_PATH}/wireguard/wireguard.c)
list(APPEND WG_SOURCES ${NATIVERENDER_ROOT_PATH}/wireguard/crypto.c)
list(APPEND WG_SOURCES ${NATIVERENDER_ROOT_PATH}/wireguard/wireguard_platform_harmony.cpp)
list(APPEND WG_SOURCES ${NATIVERENDER_ROOT_PATH}/wireguard/wireguardif_harmony.cpp)
list(APPEND WG_SOURCES ${WG_CRYPTO_SOURCES})

# 编译为动态库 libentry.so
add_library(entry SHARED ${WG_SOURCES})

# 链接鸿蒙 NAPI 库和系统库
target_link_libraries(entry PUBLIC
    libace_napi.z.so
    libhilog_ndk.z.so
)
