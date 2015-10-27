# This file is part of CMake-codecov.
#
# CMake-codecov is free software: you can redistribute it and/or modify it under
# the terms of the GNU General Public License as published by the Free Software
# Foundation, either version 3 of the License, or (at your option) any later
# version.
#
# This program is distributed in the hope that it will be useful,but WITHOUT
# ANY WARRANTY; without even the implied warranty of MERCHANTABILITY or
# FITNESS FOR A PARTICULAR PURPOSE. See the GNU General Public License for
# more details.
#
# You should have received a copy of the GNU General Public License and GNU
# Lesser General Public License along with this program. If not, see
#
#  http://www.gnu.org/licenses/
#
#
# Copyright (c)
#   2015 RWTH Aachen University, Federal Republic of Germany
#
# Written by Alexander Haase, alexander.haase@rwth-aachen.de
#


# Header guard.
# This module must only be included once (via find_package or include). If it
# will be included more than once, there may be problems. The user should not be
# forced to include it in top directory, so this header guard will prevent them
# that this module is only loaded once, even if they include this module in
# every CMake file.
if (DEFINED COVERAGE_HEADER_GUARD)
    return()
endif ()
set(COVERAGE_HEADER_GUARD true)



#
# configuration
#
set(COVERAGE_CFLAGS "-g -O0 --coverage")
set(COVERAGE_LINKER_FLAGS "--coverage")



#
# options
#

# Add an option to choose, if coverage should be enabled or not. If enabled
# marked targets will be build with coverage support and appropriate targets
# will be added. If disabled coverage will be ignored for *ALL* targets.
option(ENABLE_COVERAGE "Enable coverage build." OFF)

# Add an option to choose, if coverage should be enabled for all targets, even
# those which are not explictly marked as coverage targets. If disabled, only
# targets added by add_coverage will be marked for coverage build. This option
# is only available, if coverage was enabled.
if (ENABLE_COVERAGE)
    option(ENABLE_COVERAGE_ALL "Enable coverage build for all targets." OFF)
endif ()



# Add coverage support for target ${TNAME} and register target for coverage
# evaluation. If coverage is disabled or not supported, this function will
# simply do nothing.
#
# Note: This function is only a wrapper to define this function always, even if
#   coverage is not supported by the compiler or disabled. This function must
#   stay here, because the module will be exited, if there is no coverage
#   support by the compiler or it is disabled by the user.
#
function (add_coverage TNAME)
    # only add coverage for target, if coverage is support and enabled.
    if (ENABLE_COVERAGE)
        add_coverage_target(${TNAME})
    endif ()
endfunction (add_coverage)



# Add global target to gather coverage information after all targets have been
# added. Other evaluation functions could be added here, after checks for the
# specific module have been passed.
#
# Note: This function must stay here, because the module will be exited, if
# there is no coverage support by the compiler or it is disabled by the user.
function (coverage_evaluate)
    # add lcov evaluation
    if (LCOV_FOUND)
        lcov_capture()
    endif (LCOV_FOUND)
endfunction ()


# Exit this module, if coverage is disabled. add_coverage is defined before this
# return, so this module can be exited now safely without breaking any build-
# scripts.
if (NOT ENABLE_COVERAGE)
    return()
endif ()



# Check for coverage compiler flags in C and CXX, if one of those languages is
# enabled. At least one language must pass this test to continue processing this
# module.
include(CheckCCompilerFlag)
include(CheckCXXCompilerFlag)

set(COVERAGE_FOUND false)
get_property(LANGUAGES GLOBAL PROPERTY ENABLED_LANGUAGES)
foreach (LANG ${LANGUAGES})
    # check compiler for coverage support.
    if (${LANG} STREQUAL C)
        set(CMAKE_REQUIRED_FLAGS "${COVERAGE_LINKER_FLAGS}")
        check_c_compiler_flag("${COVERAGE_CFLAGS}" HAVE_COVERAGE_C)
        unset(CMAKE_REQUIRED_FLAGS)

    elseif (${LANG} STREQUAL CXX)
        set(CMAKE_REQUIRED_FLAGS "${COVERAGE_LINKER_FLAGS}")
        check_cxx_compiler_flag("${COVERAGE_CFLAGS}" HAVE_COVERAGE_CXX)
        unset(CMAKE_REQUIRED_FLAGS)
    endif()

    # If compiler supports coverage, announce that we have found a compiler with
    # coverage support.
    if (HAVE_COVERAGE_${LANG})
        set(COVERAGE_FOUND true)
    endif ()
endforeach()

# Abort, if no coverage support by compiler. Disable coverage for further
# processing, so add_coverage will ignore it.
if (NOT COVERAGE_FOUND)
    message(WARNING "No compiler supports coverage.")
    set(ENABLE_COVERAGE OFF)
    return()
endif()



# Add coverage support for target ${TNAME} and register target for coverage
# evaluation.
#
function(add_coverage_target TNAME)
    # If coverage is already enabled for this target, we can skip the execution
    # of this function.
    if (TARGET ${TNAME}-coverage)
        return()
    endif ()

    # create coverage target for this target
    add_custom_target(${TNAME}-coverage DEPENDS ${TNAME})

    # enable coverage for target
    set_property(TARGET ${TNAME}
        APPEND_STRING
        PROPERTY COMPILE_FLAGS " ${COVERAGE_CFLAGS}"
    )
    set_property(TARGET ${TNAME}
        APPEND_STRING
        PROPERTY LINK_FLAGS " ${COVERAGE_LINKER_FLAGS}"
    )


    # Add check-targets for .gcda files. These should help to allow global
    # evaluation targets, even if there are no .gcda files for all targets. If
    # the .gcda file is not available, an empty one will be created, so gcov and
    # lcov can continue execution.
    set(TDIR ${CMAKE_CURRENT_BINARY_DIR}/CMakeFiles/${TNAME}.dir)

    get_target_property(TSOURCES ${TNAME} SOURCES)
    set(BUFFER "")
    foreach(FILE ${TSOURCES})
        get_filename_component(FILE_PATH "${TDIR}/${FILE}" PATH)
    endforeach()


    # add gcov evaluation
    if (GCOV_FOUND)
        add_gcov_target(${TNAME})
    endif (GCOV_FOUND)

    # add lcov evaluation
    if (LCOV_FOUND)
        add_lcov_target(${TNAME})
    endif (LCOV_FOUND)
endfunction(add_coverage_target)


# If ENABLE_COVERAGE_ALL is enabled, overload add_executable and add_library
# functions, to add coverage support for *ALL* targets. The functions will call
# the overloaded functions first and then add_coverage.
if (ENABLE_COVERAGE_ALL)
    function(add_executable ARGV)
        # add executable
        _add_executable(${ARGV})

        # check if target is supported for code coverage
        get_target_property(TSOURCES ${ARGV0} SOURCES)
        foreach (FILE ${TSOURCES})
            get_source_file_property(SLANG ${FILE} LANGUAGE)
            if ((NOT ${SLANG} STREQUAL "C") AND (NOT ${SLANG} STREQUAL "CXX"))
                # Target has source files that are not supported for code
                # coverage. Do not add coverage for this target and print a
                # warning.
                message("-- Code coverage not supported for target ${ARGV0}")
                return()
            endif()
        endforeach ()

        # add coverage
        add_coverage(${ARGV0})
    endfunction(add_executable)

    function(add_library ARGV)
        # add library
        _add_library(${ARGV})

        # check if target is supported for code coverage
        get_target_property(TSOURCES ${ARGV0} SOURCES)
        foreach (FILE ${TSOURCES})
            get_source_file_property(SLANG ${FILE} LANGUAGE)
            if ((NOT ${SLANG} STREQUAL "C") AND (NOT ${SLANG} STREQUAL "CXX"))
                # Target has source files that are not supported for code
                # coverage. Do not add coverage for this target and print a
                # warning.
                message("-- Code coverage not supported for target ${ARGV0}")
                return()
            endif()
        endforeach ()

        # add coverage
        add_coverage(${ARGV0})
    endfunction(add_library)
endif ()





# Include modules for parsing the collected data and output it in a readable
# format (like gcov and lcov).
#
find_package(Gcov)
find_package(Lcov)

