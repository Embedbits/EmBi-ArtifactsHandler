###############################################################################
# Artifacts Handler parameters handler functionality
###############################################################################


#------------------------------------------------------------------------------#
# Returns list of Required Artifacts from entered parameters.
#
# List of Required Artifacts can be entered through CMake parameter 
# "ARTIFACTS_LIST".
#
# ARTIFACTS_LIST_ARG [out]: List of Required Artifacts.
#------------------------------------------------------------------------------#
function(ParamsHandler_Get_ArtifactsList ARTIFACTS_LIST_ARG)

    if(DEFINED ARTIFACTS_LIST AND NOT ARTIFACTS_LIST STREQUAL "")
    
        message(STATUS "Artifacts list entered through parameter.")
        message(STATUS "List of artifacts: ${ARTIFACTS_LIST}")
        
        # Parse parameter with Artifacts list to the variable
        set(ARTIFACTS_CONFIG ${ARTIFACTS_LIST})
        string(REPLACE ";" "\;" ARTIFACTS_CONFIG "${ARTIFACTS_CONFIG}")
        string(REPLACE "," "\n" ARTIFACTS_CONFIG "${ARTIFACTS_CONFIG}")
        string(REPLACE " " "" ARTIFACTS_CONFIG "${ARTIFACTS_CONFIG}")
        string(REPLACE "_" "-" ARTIFACTS_CONFIG "${ARTIFACTS_CONFIG}")

    else()

        message(FATAL_ERROR "List of Required Artifacts List is not found in CMake parameters.")

    endif()

endfunction(ParamsHandler_Get_ArtifactsList)