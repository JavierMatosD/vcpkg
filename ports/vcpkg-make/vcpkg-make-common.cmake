include_guard(GLOBAL)

function(z_vcpkg_make_determine_arch out_var value)
    if(${value} MATCHES "(amd|AMD)64")
        set(${out_var} x86_64 PARENT_SCOPE)
    elseif(${value} MATCHES "(x|X)86")
        set(${out_var} i686 PARENT_SCOPE)
    elseif(${value} MATCHES "^(ARM|arm)64$")
        set(${out_var} aarch64 PARENT_SCOPE)
    elseif(${value} MATCHES "^(ARM|arm)$")
        set(${out_var} arm PARENT_SCOPE)
    elseif(${value} MATCHES "^(x86_64|i686|aarch64|arm)$" OR NOT VCPKG_TARGET_IS_WINDOWS)
        # Do nothing an assume valid architectures
        set("${out_var}" "${value}" PARENT_SCOPE)
    else()
        message(FATAL_ERROR "Unsupported architecture '${value}' in '${CMAKE_CURRENT_FUNCTION}'!" )
    endif()
endfunction()

function(z_vcpkg_make_determine_host_arch out_var)
    if(DEFINED ENV{PROCESSOR_ARCHITEW6432})
        set(arch $ENV{PROCESSOR_ARCHITEW6432})
    elseif(DEFINED ENV{PROCESSOR_ARCHITECTURE})
        set(arch $ENV{PROCESSOR_ARCHITECTURE})
    else()
        set(arch "${VCPKG_DETECTED_CMAKE_HOST_SYSTEM_PROCESSOR}")
    endif()
    z_vcpkg_make_determine_arch("${out_var}" "${arch}")
    set("${out_var}" "${${out_var}}" PARENT_SCOPE)
endfunction()

function(z_vcpkg_make_determine_target_arch out_var)
    list(LENGTH VCPKG_OSX_ARCHITECTURES osx_archs_num)
    if(osx_archs_num GREATER_EQUAL 2 AND VCPKG_TARGET_IS_OSX)
        set(${out_var} "universal")
    else()
        z_vcpkg_make_determine_arch(${out_var} "${VCPKG_TARGET_ARCHITECTURE}")
    endif()
    set("${out_var}" "${${out_var}}" PARENT_SCOPE)
endfunction()


function(z_vcpkg_make_prepare_compiler_flags)
    cmake_parse_arguments(PARSE_ARGV 0 arg
        "NO_CPP" 
        "LIBS_OUT"
        "LANGUAGES"
    )
    if(DEFINED arg_LANGUAGES)
        # What a nice trick to get more output from vcpkg_cmake_get_vars if required
        # But what will it return for ASM on windows? TODO: Needs actual testing
        list(APPEND VCPKG_CMAKE_CONFIGURE_OPTIONS "-DVCPKG_LANGUAGES=${arg_LANGUAGES}")
    endif()
    vcpkg_cmake_get_vars(cmake_vars_file)
    include("${cmake_vars_file}")

    #TODO: parent scope requiered vars

endfunction()

function(z_vcpkg_make_prepare_environment_common)
endfunction()

macro(z_vcpkg_unparsed_args warning_level)
    if(DEFINED arg_UNPARSED_ARGUMENTS)
        message("${warning_level}" "${CMAKE_CURRENT_FUNCTION} was passed extra arguments: ${arg_UNPARSED_ARGUMENTS}")
    endif()
endmacro()

macro(z_vcpkg_conflicting_args)
    set(conflicting_args_set "")
    foreach(z_vcpkg_conflicting_args_index RANGE 0 "${ARGC}")
        if(${ARGV${z_vcpkg_conflicting_args_index}})
            list(APPEND conflicting_args_set "${ARGV${z_vcpkg_conflicting_args_index}}")
        endif()
    endforeach()
    list(LENGTH conflicting_args_set conflicting_args_set_length)
    if(conflicting_args_set_length GREATER 1)
        message(FATAL_ERROR "${CMAKE_CURRENT_FUNCTION} was passed conflicting arguments:'${conflicting_args_set}'. Only one of those arguments can be passed")
    endif()
    unset(conflicting_args_set_length)
    unset(conflicting_args_set)
    unset(z_vcpkg_conflicting_args_index)
endmacro()

function(z_vcpkg_set_global_property property value)
    if(DEFINED ARGN AND NOT ARGN MATCHES "^APPEND(_STRING)?$")
        message(FATAL_ERROR "'${CMAKE_CURRENT_FUNCTION}' called with invalid arguments '${ARGN}'")
    endif()
    set_property(GLOBAL ${ARGN} PROPERTY "z_vcpkg_global_property_${property}" ${value})
endfunction()

function(z_vcpkg_get_global_property outvar property)
    if(DEFINED ARGN AND NOT ARGN STREQUAL "SET")
        message(FATAL_ERROR "'${CMAKE_CURRENT_FUNCTION}' called with invalid arguments '${ARGN}'")
    endif()
    get_property(outprop GLOBAL PROPERTY "z_vcpkg_global_property_${property}")
    set(${outvar} "${outprop}" PARENT_SCOPE)
endfunction()