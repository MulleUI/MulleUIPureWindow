cmake_minimum_required( VERSION 3.15)

project( demos C)

set( MULLE_TRACE_INCLUDE ON)
#
# Turn an "Executable" into a "Library"
# * mulle-sde test init
# * mv src/main.m test/10_test/test.m
# Then set MULLE_PROJECT_TYPE to "Library".
# * mulle-sde reflect
# * mulle-sde test
#
set( MULLE_PROJECT_TYPE "Executable")

### mulle-sde environment

# add cmake module paths to search path
list( INSERT CMAKE_MODULE_PATH 0 "${PROJECT_SOURCE_DIR}/cmake/share")
list( INSERT CMAKE_MODULE_PATH 0 "${PROJECT_SOURCE_DIR}/cmake/reflect")
list( INSERT CMAKE_MODULE_PATH 0 "${PROJECT_SOURCE_DIR}/cmake")

include( Environment)

include( Files)

include( Dependencies OPTIONAL)

foreach( MAIN_SOURCE ${SOURCES})
   # get rid off src/main- prefix and .m suffix
   #             offset 9  length -9 - 2
   string( LENGTH "${MAIN_SOURCE}" MAIN_SOURCE_LENGTH)
   math( EXPR MAIN_SOURCE_LENGTH "${MAIN_SOURCE_LENGTH} - 11")
   string( SUBSTRING "${MAIN_SOURCE}" 9 ${MAIN_SOURCE_LENGTH} EXECUTABLE_NAME)

   set( SOURCES ${MAIN_SOURCE})
#   set( OTHER_EXECUTABLE_OBJECT_FILES $<TARGET_OBJECTS:MulleUI>)

   include( Executable)
   include( InstallExecutable)
   include( FinalOutput OPTIONAL)

   message( STATUS "ALL_LOAD_OS_SPECIFIC_LIBRARIES=\"${ALL_LOAD_OS_SPECIFIC_LIBRARIES}\"")
   message( STATUS "FORCE_ALL_LOAD_OS_SPECIFIC_LIBRARIES=\"${FORCE_ALL_LOAD_OS_SPECIFIC_LIBRARIES}\"")

# only for Executable
   include( Motd OPTIONAL)
endforeach()

