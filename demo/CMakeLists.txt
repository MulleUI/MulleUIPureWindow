cmake_minimum_required( VERSION 3.15...99.99)

project( demo C)

set( MULLE_PROJECT_TYPE "Executable")

### mulle-sde environment

# add cmake module paths to search path
list( INSERT CMAKE_MODULE_PATH 0 "${CMAKE_CURRENT_SOURCE_DIR}/cmake/share")
list( INSERT CMAKE_MODULE_PATH 0 "${CMAKE_CURRENT_SOURCE_DIR}/cmake/reflect")
list( INSERT CMAKE_MODULE_PATH 0 "${CMAKE_CURRENT_SOURCE_DIR}/cmake")


include( Environment)

include( Files)

include( IDESupport OPTIONAL)

include( Dependencies OPTIONAL)

find_package( PkgConfig QUIET)
if( PkgConfig_FOUND)
   pkg_check_modules( WAYLAND_CLIENT QUIET wayland-client)
endif()

foreach( SOURCE ${SOURCES})
   # get rid off src/main- prefix and .m suffix
   #             offset 9  length -9 - 2
   # ignore library "main.c" and "main.m" files, just in case
   #
   if( NOT (SOURCE MATCHES ".*/main\.[cm]$"))
      if( SOURCE MATCHES "^src/main-")
         list( APPEND DEMO_MAIN_SOURCES "${SOURCE}")
      else()
         list( APPEND DEMO_OTHER_SOURCES "${SOURCE}")
      endif()
   endif()
endforeach()

foreach( MAIN_SOURCE ${DEMO_MAIN_SOURCES})
   string( LENGTH "${MAIN_SOURCE}" MAIN_SOURCE_LENGTH)
   math( EXPR MAIN_SOURCE_LENGTH "${MAIN_SOURCE_LENGTH} - 11")
   string( SUBSTRING "${MAIN_SOURCE}" 9 ${MAIN_SOURCE_LENGTH} EXECUTABLE_NAME)

   set( SOURCES "${MAIN_SOURCE}" ${DEMO_OTHER_SOURCES})
   include( Executable)
   if( WAYLAND_CLIENT_FOUND)
      target_link_libraries( "${EXECUTABLE_LINK_TARGET}" ${WAYLAND_CLIENT_LIBRARIES})
      target_include_directories( "${EXECUTABLE_COMPILE_TARGET}" PRIVATE ${WAYLAND_CLIENT_INCLUDE_DIRS})
   endif()
   include( InstallExecutable)
   include( FinalOutput OPTIONAL)
   # only for Executable
   include( Motd OPTIONAL)
endforeach()
