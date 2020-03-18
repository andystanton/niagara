cmake_minimum_required(VERSION 3.14)
project(niagara CXX)

set(CMAKE_CXX_STANDARD 17)
set(CMAKE_EXPORT_COMPILE_COMMANDS ON)
set(CMAKE_MODULE_PATH ${CMAKE_MODULE_PATH} ${CMAKE_CURRENT_SOURCE_DIR}/cmake)

set(VULKAN_SDK "$ENV{VULKAN_SDK}" CACHE STRING "LunarG Vulkan SDK path")
if (VULKAN_SDK)
    set(ENV{VULKAN_SDK} ${VULKAN_SDK})
endif ()

find_package(vulkan REQUIRED)
find_program(GLSLC glslc HINTS ${VULKAN_SDK}/bin)

if (NOT Vulkan_FOUND)
    message(FATAL_ERROR "Vulkan not found")
endif ()

if (NOT GLSLC)
    message(FATAL_ERROR "GLSLC not found")
endif ()

add_subdirectory(extern/glm)

set(GLFW_INSTALL OFF CACHE BOOL "" FORCE)
set(GLFW_BUILD_DOCS OFF CACHE BOOL "" FORCE)
set(GLFW_BUILD_TESTS OFF CACHE BOOL "" FORCE)
set(GLFW_BUILD_EXAMPLES OFF CACHE BOOL "" FORCE)
if (APPLE)
    add_compile_definitions(GLFW_EXPOSE_NATIVE_COCOA)
endif()
add_subdirectory(extern/glfw)

add_subdirectory(extern/fast_obj)
add_subdirectory(extern/meshoptimizer)

if (WIN32)
    set(VOLK_STATIC_DEFINES VK_USE_PLATFORM_WIN32_KHR)
elseif(APPLE)
    set(VOLK_STATIC_DEFINES VK_USE_PLATFORM_MACOS_MVK)
endif()
add_subdirectory(extern/volk)

set(
    niagara_includes
    ${Vulkan_INCLUDE_DIRS}
    ${CMAKE_CURRENT_SOURCE_DIR}/extern/volk
    ${CMAKE_CURRENT_SOURCE_DIR}/extern/glm
    ${CMAKE_CURRENT_SOURCE_DIR}/extern/fast_obj
    ${CMAKE_CURRENT_SOURCE_DIR}/extern/meshoptimizer/src
)

add_executable(
    niagara
    src/niagara.cpp
    src/device.cpp
    src/fast_obj.cpp
    src/resources.cpp 
    src/shaders.cpp
    src/swapchain.cpp
)

set_property(TARGET niagara PROPERTY CXX_STANDARD 17)
target_include_directories(niagara PRIVATE ${niagara_includes})
target_link_libraries(
    niagara
    PRIVATE
    ${Vulkan_LIBRARIES}
    glfw
    volk
    meshoptimizer
)

set(SHADER_PATHS src/shaders/**.*.glsl)
file(GLOB_RECURSE SHADERS RELATIVE ${CMAKE_CURRENT_SOURCE_DIR} ${SHADER_PATHS})

foreach (SHADER ${SHADERS})
    string(REGEX MATCHALL "^(.*)\\/(.+)\\.(.+)\\.glsl$" SHADER_MATCH ${SHADER})
    set(SHADER_PATH ${CMAKE_MATCH_1})
    set(SHADER_NAME ${CMAKE_MATCH_2})
    set(SHADER_TYPE ${CMAKE_MATCH_3})
    set(SHADER_IN ${CMAKE_CURRENT_SOURCE_DIR}/${SHADER})
    set(SHADER_OUT ${CMAKE_CURRENT_BINARY_DIR}/shaders/${SHADER_NAME}.${SHADER_TYPE}.spv)
    add_custom_command(
        OUTPUT ${SHADER_OUT}
        COMMAND ${CMAKE_COMMAND} -E make_directory "${CMAKE_CURRENT_BINARY_DIR}/shaders"
        COMMAND ${GLSLC} --target-spv=spv1.3 -fshader-stage=${SHADER_TYPE} ${SHADER_IN} -o ${SHADER_OUT}
        COMMENT "Compiling ${SHADER_IN} to ${SHADER_OUT}"
        DEPENDS ${SHADER_IN}
        VERBATIM
    )
    set(SHADER_OUTPUTS ${SHADER_OUTPUTS} ${SHADER_OUT})
endforeach ()

add_custom_target(compile-shaders ALL DEPENDS ${SHADER_OUTPUTS})

set(RESOURCE_PATHS data/**.obj)
file(GLOB_RECURSE RESOURCE_FILES RELATIVE ${CMAKE_CURRENT_SOURCE_DIR} ${RESOURCE_PATHS})

foreach (RESOURCE ${RESOURCE_FILES})
    string(REGEX MATCHALL "(.*)\\/(.*)" RESOURCE_MATCH ${RESOURCE})
    set(RESOURCE_PATH ${CMAKE_MATCH_1})
    set(RESOURCE_IN ${CMAKE_CURRENT_SOURCE_DIR}/${RESOURCE})
    set(RESOURCE_OUT ${CMAKE_CURRENT_BINARY_DIR}/${RESOURCE})
    add_custom_command(
        OUTPUT ${RESOURCE_OUT}
        COMMAND ${CMAKE_COMMAND} -E make_directory "${CMAKE_CURRENT_BINARY_DIR}/${RESOURCE_PATH}"
        COMMAND ${CMAKE_COMMAND} -E copy_if_different "${RESOURCE_IN}" "${RESOURCE_OUT}"
        COMMENT "Copying ${RESOURCE_IN} to ${RESOURCE_OUT}"
        DEPENDS ${RESOURCE_IN}
        VERBATIM
    )
    set(RESOURCE_OUTPUTS ${RESOURCE_OUTPUTS} ${RESOURCE_OUT})
endforeach ()

add_custom_target(copy-resources ALL DEPENDS ${RESOURCE_OUTPUTS})

add_dependencies(
    niagara
    compile-shaders
    copy-resources
)
