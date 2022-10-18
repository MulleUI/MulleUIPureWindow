### If you want to edit this, copy it from cmake/share to cmake. It will be
### picked up in preference over the one in cmake/share. And it will not get
### clobbered with the next upgrade.

### Files
if( NOT __IDE_SUPPORT__CMAKE__)
   set( __IDE_SUPPORT__CMAKE__ ON)

if( MULLE_TRACE_INCLUDE)
   message( STATUS "# Include \"${CMAKE_CURRENT_LIST_FILE}\"" )
endif()

#
# If there is (likely) a sourcetree
#
if( IS_DIRECTORY "${PROJECT_SOURCE_DIR}/.mulle/etc/sourcetree" OR
    IS_DIRECTORY "${PROJECT_SOURCE_DIR}/.mulle/etc/sourcetree")

   set( TMP_NEED_DEPENDENCY_CRAFT ON)

   #
   # If we have a dependency folder, check for the state which needs
   # to be complete. Conceivably the IS_DIRECTORY is superflous here
   #
   if( IS_DIRECTORY "${PROJECT_SOURCE_DIR}/dependency")
      execute_process( COMMAND cat ".state"
                       WORKING_DIRECTORY "${PROJECT_SOURCE_DIR}/dependency"
                       OUTPUT_VARIABLE TMP_DEPENDENCY_STATE
                       OUTPUT_STRIP_TRAILING_WHITESPACE)
      if( "${TMP_DEPENDENCY_STATE}" STREQUAL "complete")
         set( TMP_NEED_DEPENDENCY_CRAFT OFF)
      endif()
      unset( TMP_DEPENDENCY_STATE)
   endif()

   #
   # Use mulle-sde to build the dependency folder (what else :))
   #
   if( TMP_NEED_DEPENDENCY_CRAFT)
      find_program( MULLE_SDE mulle-sde)
      if( NOT MULLE_SDE)
         message( WARNING "The folder \"dependency\" is not ready.\nInstall mulle-sde and run `mulle-sde craft craftorder`")
      else()
         execute_process( COMMAND ${MULLE_SDE} craft --build-type "${CMAKE_BUILD_TYPE}" craftorder
                          WORKING_DIRECTORY ${PROJECT_SOURCE_DIR}
                          COMMAND_ERROR_IS_FATAL ANY)
      endif()
   endif()
   unset( TMP_NEED_DEPENDENCY_CRAFT)
endif()

endif()


# extension : mulle-sde/cmake
# directory : project/all
# template  : .../IDESupport.cmake
# Suppress this comment with `export MULLE_SDE_GENERATE_FILE_COMMENTS=NO`
