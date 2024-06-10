include("${CMAKE_CURRENT_LIST_DIR}/../vcpkg-cmake-get-vars/vcpkg-port-config.cmake")

file(GLOB cmake_files "${CMAKE_CURRENT_LIST_DIR}/*.cmake")
list(REMOVE_ITEM cmake_files "${CMAKE_CURRENT_LIST_FILE}")
foreach(cmake_file IN LISTS cmake_files)
    include("${cmake_file}")
endforeach()
