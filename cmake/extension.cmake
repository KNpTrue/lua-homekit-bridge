# Generate lua binray from lua script.
#
# out: absolute path of the output file
# in: input file path relative to ${dir}
# dir: the path in the debug information generated by luac will be relative to this directory
#
# gen_lua_binary(out in dir LUAC [DEBUG])
function(gen_lua_binary out in dir luac)
    set(options DEBUG)
    cmake_parse_arguments(arg "${options}" "" "" "${ARGN}")
    if(NOT arg_DEBUG)
        set(LUAC_FLAGS ${LUAC_FLAGS} -s)
    endif()
    add_custom_command(OUTPUT ${out}
        COMMAND cd ${dir}
        COMMAND ${luac} ${LUAC_FLAGS} -o ${out} ${in}
        COMMAND echo "Generated ${out}"
        DEPENDS ${luac} ${dir}/${in}
        COMMENT "Generating ${out}"
    )
endfunction(gen_lua_binary)

# Genrate lua binraies in a directory.
#
# gen_lua_binary_from_dir(TARGET DEST_DIR LUAC [DEBUG]
#                         [SRC_DIRS dir1 [dir2...]])
function(gen_lua_binary_from_dir target dest_dir luac)
    set(options DEBUG)
    set(multi SRC_DIRS)
    cmake_parse_arguments(arg "${options}" "" "${multi}" "${ARGN}")
    if(arg_DEBUG)
        set(GEN_LUA_LIBRARY_OPTIONS DEBUG)
    endif()
    foreach(src_dir ${arg_SRC_DIRS})
        # get all lua scripts
        file(GLOB_RECURSE scripts RELATIVE ${src_dir} ${src_dir}/*.lua)
        foreach(script ${scripts})
            set(bin ${dest_dir}/${script}c)
            set(bins ${bins} ${bin})
            get_filename_component(dir ${bin} DIRECTORY)
            make_directory(${dir})
            gen_lua_binary(${bin} ${script} ${src_dir} ${luac}
                ${GEN_LUA_LIBRARY_OPTIONS}
            )
        endforeach()
    endforeach()
    add_custom_target(${target}
        ALL
        DEPENDS ${bins}
    )
endfunction(gen_lua_binary_from_dir)

# Compile luac.
#
# compile_luac(BIN SRC_DIR BUILD_DIR
#              [DEPENDS depend depend depend ... ])
function(compile_luac bin src_dir build_dir)
    set(multi DEPENDS)
    cmake_parse_arguments(arg "" "" "${multi}" "${ARGN}")
    add_custom_command(OUTPUT ${bin}
        COMMAND ${CMAKE_COMMAND}
            -S${src_dir}
            -B${build_dir}
            -G Ninja
        COMMAND cmake --build ${build_dir} -j10
        DEPENDS ${src_dir}/CMakeLists.txt ${arg_DEPENDS}
        COMMENT "Compiling luac"
    )
    add_custom_target(luac ALL DEPENDS ${bin})
endfunction(compile_luac)

# Get host platform.
#
# get_host_platform(OUTPUT)
macro(get_host_platform output)
    execute_process(
        COMMAND uname
        OUTPUT_VARIABLE ${output}
    )
    string(REPLACE "\n" "" ${output} ${${output}})
    string(TOLOWER ${${output}} ${output})
endmacro(get_host_platform)

# Check code style.
#
# check_style(TARGET TOP_DIR [SRCS src1 [src2...]])
function(check_style target top_dir)
    find_program(CPPLINT NAMES "cpplint")
    if(NOT CPPLINT)
        message(FATAL_ERROR "Please install cpplint via \"pip3 install cpplint\".")    
    endif()

    set(multi SRCS)
    cmake_parse_arguments(arg "" "" "${multi}" "${ARGN}")

    set(cstyle_dir ${CMAKE_BINARY_DIR}/cstyle)
    foreach(src ${arg_SRCS})
        # get the relative path of the script
        file(RELATIVE_PATH rel_path ${top_dir} ${src})
        set(output ${cstyle_dir}/${rel_path}.cs)
        set(outputs ${outputs} ${output})
        get_filename_component(dir ${output} DIRECTORY)
        make_directory(${dir})
        add_custom_command(OUTPUT ${output}
            COMMENT "Check ${rel_path}"
            COMMAND ${CPPLINT}
                --linelength=120
                --filter=-readability/casting,-build/include,-runtime/arrays
                ${rel_path}
            COMMAND touch ${output}
            WORKING_DIRECTORY ${top_dir}
            DEPENDS ${src}
        )
    endforeach()
    add_custom_target(${target}
        ALL
        DEPENDS ${outputs}
    )
endfunction(check_style)

#
# Add embedfs to a target.
#
# target_add_embedfs(TARGET DIR ROOT_NAME)
function (target_add_embedfs target dir root_name)
    find_program(XXD NAMES "xxd")
    if(NOT XXD)
        message(FATAL_ERROR "Please install xxd via \"sudo apt install xxd\".")
    endif()

    set(dest_dir ${CMAKE_BINARY_DIR}/${target}_${root_name})
    set(output ${dest_dir}/${target}_${root_name}.c)

    file(GLOB_RECURSE files RELATIVE ${dir} ${dir}/*)
    foreach(file ${files})
        set(header ${dest_dir}/${file}.h)
        set(headers ${headers} ${header})
        add_custom_command(OUTPUT ${header}
            COMMAND cd ${dir}
            COMMAND ${XXD}
                -c 12 -i ${file} |
                sed "s/unsigned char/static const char/" |
                sed "/unsigned int/s/[=\;]//g\;s/unsigned int/#define/"
                > ${header}
            COMMAND echo "Generated ${header}"
            DEPENDS ${dir}/${file}
            COMMENT "Generating ${header}"
        )
    endforeach()

    add_custom_command(OUTPUT ${output}
        COMMAND ${CMAKE_COMMAND}
            -D OUTPUT=${output}
            -D ROOT_DIR=${dir}
            -D DEST_DIR=${dest_dir}
            -D EMBEDFS_ROOT_NAME=${root_name}
            -P ${TOP_DIR}/cmake/gen_embedfs.cmake
        DEPENDS ${headers} ${TOP_DIR}/cmake/gen_embedfs.cmake
    )
    target_sources(${target}
        PRIVATE ${output}
    )
    target_include_directories(${target}
        PRIVATE ${dest_dir}
    )
endfunction(target_add_embedfs)

#
# Add lua binary embedfs to a target.
#
# target_add_lua_binary_embedfs(TARGET ROOT_NAME LUAC [DEBUG]
#                               [SRC_DIRS dir1 [dir2...]])
function(target_add_lua_binary_embedfs target root_name luac)
    find_program(XXD NAMES "xxd")
    if(NOT XXD)
        message(FATAL_ERROR "Please install xxd via \"sudo apt install xxd\".")
    endif()

    set(options DEBUG)
    set(multi SRC_DIRS)
    cmake_parse_arguments(arg "${options}" "" "${multi}" "${ARGN}")
    if(arg_DEBUG)
        set(GEN_LUA_LIBRARY_OPTIONS DEBUG)
    endif()

    set(dest_dir ${CMAKE_BINARY_DIR}/${target}_${root_name})
    set(output ${dest_dir}/${target}_${root_name}.c)
    set(binary_dir ${CMAKE_BINARY_DIR}/${target}_${root_name}_bin)

    gen_lua_binary_from_dir(${target}_${root_name}_bin
        ${binary_dir}
        ${luac}
        ${GEN_LUA_LIBRARY_OPTIONS}
        SRC_DIRS ${arg_SRC_DIRS}
    )

    foreach(src_dir ${arg_SRC_DIRS})
        file(GLOB_RECURSE bins RELATIVE ${src_dir} ${src_dir}/*.lua)
        foreach(bin ${bins})
            set(bin ${bin}c)
            set(header ${dest_dir}/${bin}.h)
            set(headers ${headers} ${header})
            string(REGEX REPLACE "[/.]" "_" filename ${bin})
            add_custom_command(OUTPUT ${header}
                COMMAND cd ${binary_dir}
                COMMAND ${XXD}
                    -c 12 -i ${bin} |
                    sed "s/unsigned char/static const char/" |
                    sed "/unsigned int/s/[=\;]//g\;s/unsigned int/#define/"
                    > ${header}
                COMMAND echo "Generated ${header}"
                DEPENDS ${binary_dir}/${bin}
                COMMENT "Generating ${header}"
            )
        endforeach()
    endforeach()

    add_custom_command(OUTPUT ${output}
        COMMAND ${CMAKE_COMMAND}
            -D OUTPUT=${output}
            -D ROOT_DIR=${binary_dir}
            -D DEST_DIR=${dest_dir}
            -D EMBEDFS_ROOT_NAME=${root_name}
            -P ${TOP_DIR}/cmake/gen_embedfs.cmake
        DEPENDS ${headers} ${TOP_DIR}/cmake/gen_embedfs.cmake
    )
    target_sources(${target}
        PRIVATE ${output}
    )
endfunction(target_add_lua_binary_embedfs)
