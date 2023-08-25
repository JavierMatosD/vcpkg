include_guard(GLOBAL)
include("${CMAKE_CURRENT_SOURCE_DIR}/vcpkg-make.cmake")

function(vcpkg_make_configure) #
# Replacement for vcpkg_configure_make
# z_vcpkg_is_autoconf
# z_vcpkg_is_automake
    # Old signature
    #cmake_parse_arguments(PARSE_ARGV 0 arg
    #"AUTOCONFIG;SKIP_CONFIGURE;COPY_SOURCE;DISABLE_VERBOSE_FLAGS;NO_ADDITIONAL_PATHS;ADD_BIN_TO_PATH;NO_DEBUG;USE_WRAPPERS;NO_WRAPPERS;DETERMINE_BUILD_TRIPLET"
    #"SOURCE_PATH;PROJECT_SUBPATH;PRERUN_SHELL;BUILD_TRIPLET"
    #"OPTIONS;OPTIONS_DEBUG;OPTIONS_RELEASE;CONFIGURE_ENVIRONMENT_VARIABLES;CONFIG_DEPENDENT_ENVIRONMENT;ADDITIONAL_MSYS_PACKAGES"
    #)


    cmake_parse_arguments(PARSE_ARGV 0 arg
        "AUTOCONFIG;COPY_SOURCE;NO_WRAPPERS;NO_CPP;NO_CONFIGURE_TRIPLET;ADD_BIN_TO_PATH"
        "SOURCE_PATH;CONFIGURE_SUBPATH;BUILD_TRIPLET"
        "OPTIONS;OPTIONS_DEBUG;OPTIONS_RELEASE;PRE_CONFIGURE_CMAKE_COMMANDS;POST_CONFIGURE_CMAKE_COMMANDS;ADDITIONAL_MSYS_PACKAGES;RUN_SCRIPTS"
    )

    z_vcpkg_unparsed_args(FATAL_ERROR)
    #z_vcpkg_conflicting_args(arg_USE_WRAPPERS arg_NO_WRAPPERS)
    z_vcpkg_conflicting_args(arg_BUILD_TRIPLET arg_NO_CONFIGURE_TRIPLET)

    # Can be set in the triplet to append options for configure
    if(DEFINED VCPKG_MAKE_CONFIGURE_OPTIONS)
        list(APPEND arg_OPTIONS ${VCPKG_MAKE_CONFIGURE_OPTIONS})
    endif()
    if(DEFINED VCPKG_MAKE_CONFIGURE_OPTIONS_RELEASE)
        list(APPEND arg_OPTIONS_RELEASE ${VCPKG_MAKE_CONFIGURE_OPTIONS_RELEASE})
    endif()
    if(DEFINED VCPKG_MAKE_CONFIGURE_OPTIONS_DEBUG)
        list(APPEND arg_OPTIONS_DEBUG ${VCPKG_MAKE_CONFIGURE_OPTIONS_DEBUG})
    endif()

    set(src_dir "${arg_SOURCE_PATH}/${arg_CONFIGURE_SUBPATH}")

    z_vcpkg_warn_path_with_spaces()

    set(prepare_flags_opts "")
    if(arg_NO_WRAPPERS)
        set(prepare_flags_opts "NO_WRAPPERS")
    endif()
    if(arg_NO_CPP)
        list(APPEND prepare_flags_opts "NO_CPP")
    endif()
    z_vcpkg_set_global_property(make_prepare_flags_opts "${prepare_flags_opts}")
    vcpkg_make_prepare_flags(${prepare_flags_opts} C_COMPILER_NAME ccname FRONTEND_VARIANT_OUT frontend)

    if(DEFINED VCPKG_MAKE_BUILD_TRIPLET)
        set(arg_BUILD_TRIPLET "${VCPKG_MAKE_BUILD_TRIPLET}")
    endif()
    if(NOT DEFINED arg_BUILD_TRIPLET AND NOT arg_NO_CONFIGURE_TRIPLET)
        z_vcpkg_make_get_configure_triplets(arg_BUILD_TRIPLET COMPILER_NAME ccname)
    endif()


    if(arg_USE_WRAPPERS AND NOT arg_NO_WRAPPERS AND "${frontend}" STREQUAL "MSVC" )
        # Lets assume that wrappers are only required for MSVC like frontends.
        vcpkg_add_to_path(PREPEND "${CURRENT_HOST_INSTALLED_DIR}/share/vcpkg-make/wrappers")
    endif()

    vcpkg_make_get_shell(shell_cmd)

    if(arg_AUTOCONFIG)
        vcpkg_run_autoreconf("${shell_cmd}" "${src_dir}")
    endif()

    if(arg_RUN_SCRIPTS)
        message(STATUS "Running scripts for ${TARGET_TRIPLET} ${arg_RUN_SCRIPT}")
        set(run_index 0)
        foreach(script IN LISTS arg_RUN_SCRIPTS)
            message(STATUS "Running script:'${script}'")
            vcpkg_run_bash(
                BASH "${shell_cmd}"
                COMMAND "${script}"
                WORKING_DIRECTORY "${src_dir}"
                LOGNAME "run-script-${run_index}-${TARGET_TRIPLET}"
            )
            math(EXPR run_index "${run_index}+1")
        endforeach()
        message(STATUS "Finished running scripts for ${TARGET_TRIPLET}")
    endif()

    # Backup environment variables
    # CCAS CC C CPP CXX FC FF GC LD LF LIBTOOL OBJC OBJCXX R UPC Y 
    set(cm_FLAGS AR AS CCAS CC C CPP CXX FC FF GC LD LF LIBTOOL OBJC OBJXX R UPC Y RC)
    list(TRANSFORM cm_FLAGS APPEND "FLAGS")
    vcpkg_backup_env_variables(VARS 
        ${cm_FLAGS}
    # General backup
        PATH
    # Used by gcc/linux
        C_INCLUDE_PATH CPLUS_INCLUDE_PATH LIBRARY_PATH LD_LIBRARY_PATH
    # Used by cl
        INCLUDE LIB LIBPATH _CL_ _LINK_
    )
    z_vcpkg_make_set_common_vars()

    foreach(config IN LISTS buildtypes)
        set(target_dir "${work_dir_${config_up}}")
        file(REMOVE_RECURSE "${target_dir}")
        file(MAKE_DIRECTORY "${target_dir}")
        file(RELATIVE_PATH relative_build_path "${target_dir}" "${src_dir}")
        if(arg_COPY_SOURCE)
            file(COPY "${src_dir}/" DESTINATION "${target_dir}")
            set(relative_build_path ".")
        endif()

        set(opts "")
        vcpkg_make_default_path_and_configure_options(opts AUTOMAKE CONFIG "${config}") # TODO: figure out outmake
        vcpkg_list(APPEND arg_OPTIONS ${opts})

        set(configure_path_from_wd "./${relative_build_path}/configure")
        if(arg_ADD_BIN_TO_PATH)
            set(extra_configure_opts ADD_BIN_TO_PATH)
        endif()
        foreach(cmd IN LISTS arg_PRE_CONFIGURE_CMAKE_COMMANDS)
            cmake_language(CALL ${cmd} ${config})
        endforeach()
        vcpkg_make_run_configure(CONFIG 
                                    "${config}" 
                                 CONFIGURE_PATH
                                    "${configure_path_from_wd}"
                                 OPTIONS 
                                    ${arg_BUILD_TRIPLET}
                                    ${arg_OPTIONS} 
                                    ${arg_OPTIONS_${config_up}}
                                 WORKING_DIRECTORY 
                                    "${target_dir}" 
                                 ${extra_configure_opts}
                                )
        foreach(cmd IN LISTS arg_POST_CONFIGURE_CMAKE_COMMANDS)
            cmake_language(CALL ${cmd} ${config})
        endforeach()
    endforeach()

    # Restore environment
    vcpkg_restore_env_variables(VARS 
        ${cm_FLAGS} 
        C_INCLUDE_PATH CPLUS_INCLUDE_PATH LIBRARY_PATH LD_LIBRARY_PATH
        INCLUDE LIB LIBPATH _CL_ _LINK_
    )

    # Export matching make program for vcpkg_build_make (cache variable) # TODO: Why is this required?
    #if(CMAKE_HOST_WIN32 AND MSYS_ROOT) # This is no longer required. the normal windows triplet clean the environment and paths 
    #    find_program(Z_VCPKG_MAKE make PATHS "${MSYS_ROOT}/usr/bin" NO_DEFAULT_PATH REQUIRED)
    #endif()
    find_program(Z_VCPKG_MAKE NAMES make gmake NAMES_PER_DIR REQUIRED)

endfunction()