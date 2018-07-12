cmake_minimum_required(VERSION 3.8 FATAL_ERROR)

add_executable(ProgressivePathTracer "main.cpp") 

target_link_libraries(ProgressivePathTracer dwSampleFramework)

add_custom_command(TARGET ProgressivePathTracer POST_BUILD COMMAND ${CMAKE_COMMAND} -E copy_directory ${CMAKE_SOURCE_DIR}/src/shader $<TARGET_FILE_DIR:ProgressivePathTracer>/shader)
add_custom_command(TARGET ProgressivePathTracer POST_BUILD COMMAND ${CMAKE_COMMAND} -E copy_directory ${CMAKE_SOURCE_DIR}/src/shader ${CMAKE_SOURCE_DIR}/build/src/shader)
