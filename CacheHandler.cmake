###############################################################################
# Artifacts Cache folder handler functionality
#
# Artifacts cache folder is location, where the artifacts are stored to be used 
# during build. This folder can be shared between different projects and 
# different builds.
###############################################################################

# Name of cmake file used for artifacts configuration
set(CACHE_HANDLER_CONFIG_FILE_NAME "ArtifactConfig.cmake")


#------------------------------------------------------------------------------#
# Checks, if Binary artifact with required version is cached or not.
#
# CACHED_ARTIFACTS_PATH_ARG  [in]: Path to the Artifacts Cache folder
# ARTIFACT_NAME_ARG          [in]: Name of artifact.
# ARTIFACT_BIN_VERSION_ARG   [in]: Required version of Binary artifact part
# CACHED_ARTIFACT_STATE_ARG [out]: State, if artifact exist
# CACHED_VERSION_ARG        [out]: Found version in format X.Y.Z
#------------------------------------------------------------------------------#
function(CacheHandler_Check_CachedArtifact_Bin CACHED_ARTIFACTS_PATH_ARG 
                                               ARTIFACT_NAME_ARG 
                                               ARTIFACT_BIN_VERSION_ARG 
                                               CACHED_ARTIFACT_STATE_ARG
                                               CACHED_VERSION_ARG)

    set(TARGET_VERSION "")
    set(ARTIFACT_PATH "${CACHED_ARTIFACTS_PATH_ARG}/${ARTIFACT_NAME_ARG}/Bin")

    if(NOT EXISTS "${ARTIFACT_PATH}" OR NOT IS_DIRECTORY "${ARTIFACT_PATH}")
        set(${CACHED_ARTIFACT_STATE_ARG} "FALSE" PARENT_SCOPE)
        message(DEBUG "Binary part of artifact ${ARTIFACT_NAME_ARG} is not cached.")
        return()
    endif()


    if(ARTIFACT_BIN_VERSION_ARG STREQUAL "latest")

        file(GLOB FOLDERS_LIST "${ARTIFACT_PATH}/*")
        
        if(NOT FOLDERS_LIST)
            set(${CACHED_ARTIFACT_STATE_ARG} "FALSE" PARENT_SCOPE)
            message(DEBUG "Artifact folder is empty.")
            return()
        endif()

        foreach(FOLDER_NAME IN LISTS FOLDERS_LIST)
            get_filename_component(ARTIFACT_VERSION "${FOLDER_NAME}" NAME)
            if(ARTIFACT_VERSION MATCHES "^[0-9]+\\.[0-9]+\\.[0-9]+$" AND IS_DIRECTORY "${FOLDER_NAME}")
                list(APPEND VERSION_LIST "${ARTIFACT_VERSION}")
            endif()
        endforeach()
        
        list(SORT VERSION_LIST COMPARE NATURAL ORDER DESCENDING)
        
        if(VERSION_LIST)
        
            list(GET VERSION_LIST 0 LATEST_VERSION)
        
            set(TARGET_VERSION ${LATEST_VERSION})
            
        else()
        
            set(TARGET_VERSION ${ARTIFACT_BIN_VERSION_ARG})
            
        endif()

    else()
    
        set(TARGET_VERSION ${ARTIFACT_BIN_VERSION_ARG})
        
    endif()
    
    set(${CACHED_VERSION_ARG} "${TARGET_VERSION}" PARENT_SCOPE)


    if(IS_DIRECTORY "${ARTIFACT_PATH}/${TARGET_VERSION}" AND NOT "${TARGET_VERSION}" STREQUAL "latest")

        set(${CACHED_ARTIFACT_STATE_ARG} "TRUE" PARENT_SCOPE)
        
        message(DEBUG "Artifacts Bin is already cached.")

    else()

        set(${CACHED_ARTIFACT_STATE_ARG} "FALSE" PARENT_SCOPE)
        
        message(DEBUG "Artifacts Bin is not cached.")

    endif()
    
endfunction(CacheHandler_Check_CachedArtifact_Bin)


#------------------------------------------------------------------------------#
# Checks, if Core artifact with required version is cached or not.
#
# CACHED_ARTIFACTS_PATH_ARG  [in]: Path to the Artifacts Cache folder
# ARTIFACT_NAME_ARG          [in]: Name of artifact.
# ARTIFACT_CORE_VERSION_ARG  [in]: Required version of Core artifact part
# CACHED_ARTIFACT_STATE_ARG [out]: State, if artifact exist
# CACHED_VERSION_ARG        [out]: Found version in format X.Y.Z
#------------------------------------------------------------------------------#
function(ArtifactsHandler_Check_CachedArtifact_Core CACHED_ARTIFACTS_PATH_ARG 
                                                    ARTIFACT_NAME_ARG 
                                                    ARTIFACT_CORE_VERSION_ARG 
                                                    CACHED_ARTIFACT_STATE_ARG
                                                    CACHED_VERSION_ARG)

    set(TARGET_VERSION "")
    set(ARTIFACT_PATH "${CACHED_ARTIFACTS_PATH_ARG}/${ARTIFACT_NAME_ARG}/Core")

    if(NOT EXISTS "${ARTIFACT_PATH}" OR NOT IS_DIRECTORY "${ARTIFACT_PATH}")
        set(${CACHED_ARTIFACT_STATE_ARG} "FALSE" PARENT_SCOPE)
        message(DEBUG "Artifact cached folder ${ARTIFACT_NAME_ARG} does not exist on ${ARTIFACT_PATH}.")
        return()
    endif()


    if(ARTIFACT_CORE_VERSION_ARG STREQUAL "latest")

        file(GLOB FOLDERS_LIST "${ARTIFACT_PATH}/*")
        
        if(NOT FOLDERS_LIST)
            set(${CACHED_ARTIFACT_STATE_ARG} "FALSE" PARENT_SCOPE)
            message(DEBUG "Artifact folder is empty.")
            return()
        endif()

        foreach(FOLDER_NAME IN LISTS FOLDERS_LIST)
            get_filename_component(ARTIFACT_VERSION "${FOLDER_NAME}" NAME)
            
            if(ARTIFACT_VERSION MATCHES "^[0-9]+\\.[0-9]+\\.[0-9]+$" AND IS_DIRECTORY "${FOLDER_NAME}")
                list(APPEND VERSION_LIST "${ARTIFACT_VERSION}")
            endif()
        endforeach()
        
        list(SORT VERSION_LIST COMPARE NATURAL ORDER DESCENDING)
        
        if(VERSION_LIST)
        
            list(GET VERSION_LIST 0 LATEST_VERSION)
        
            set(TARGET_VERSION ${LATEST_VERSION})
            
        else()
        
            set(TARGET_VERSION ${ARTIFACT_CORE_VERSION_ARG})
            
        endif()

    else()
    
        set(TARGET_VERSION ${ARTIFACT_CORE_VERSION_ARG})
        
    endif()
    
    set(${CACHED_VERSION_ARG} "${TARGET_VERSION}" PARENT_SCOPE)


    if(IS_DIRECTORY "${ARTIFACT_PATH}/${TARGET_VERSION}" AND NOT "${TARGET_VERSION}" STREQUAL "latest")

        set(${CACHED_ARTIFACT_STATE_ARG} "TRUE" PARENT_SCOPE)
        
        message(DEBUG "Artifacts Core is already cached.")

    else()

        set(${CACHED_ARTIFACT_STATE_ARG} "FALSE" PARENT_SCOPE)
        
        message(DEBUG "Artifacts Core is not cached.")

    endif()
    
endfunction(ArtifactsHandler_Check_CachedArtifact_Core)


#------------------------------------------------------------------------------#
# Initialize installed artifact.
#
# ARTIFACT_NAME_ARG [in]: Name of artifact to be processed (name of folder in 
#                     install directory)
# ARTIFACTS_CACHE_PATH_ARG   [in]: Path to the artifacts cache
# ARTIFACT_NAME_ARG          [in]: Name of artifacts to be installed
# ARTIFACT_CORE_VERSION_ARG  [in]: Required Core version to be used
# ARTIFACT_BIN_VERSION_ARG   [in]: Required Bin version to be used
#------------------------------------------------------------------------------#
function(CacheHandler_InitArtifact ARTIFACTS_CACHE_PATH_ARG
                                   ARTIFACT_NAME_ARG 
                                   ARTIFACT_CORE_VERSION_ARG
                                   ARTIFACT_BIN_VERSION_ARG)

    # Check if the current path is a directory
    if((IS_DIRECTORY "${ARTIFACTS_CACHE_PATH_ARG}/${ARTIFACT_NAME_ARG}/Core/${ARTIFACT_CORE_VERSION_ARG}") AND
       (IS_DIRECTORY "${ARTIFACTS_CACHE_PATH_ARG}/${ARTIFACT_NAME_ARG}/Bin/${ARTIFACT_BIN_VERSION_ARG}"  )     )
    
        # Construct the full path to the config file
        set(ARTIFACT_CONFIG_FULL_PATH "${ARTIFACTS_CACHE_PATH_ARG}/${ARTIFACT_NAME_ARG}/Core/${ARTIFACT_CORE_VERSION_ARG}/${CACHE_HANDLER_CONFIG_FILE_NAME}")
        # Construct the full path to the binary
        set(ARTIFACT_BIN_FULL_PATH "${ARTIFACTS_CACHE_PATH_ARG}/${ARTIFACT_NAME_ARG}/Bin/${ARTIFACT_BIN_VERSION_ARG}")
    
        # Check if the config file exists in the current subdirectory
        if(EXISTS "${ARTIFACT_CONFIG_FULL_PATH}")
        
            # Include the config file
            include("${ARTIFACT_CONFIG_FULL_PATH}")
            
            set(FUNCTION_NAME "${ARTIFACT_NAME_ARG}_ArtifactInit")
            
            # Check if artifact support getter for version getting.
            if(COMMAND ${FUNCTION_NAME})
            
                # Call artifact version getter
                cmake_language(CALL "${FUNCTION_NAME}" "${ARTIFACT_BIN_FULL_PATH}")
                
            else()
                
                message(STATUS "Artifact: ${ARTIFACT_NAME_ARG} does not support function ${FUNCTION_NAME}!")
                
            endif()
            
        else()
        
            message(STATUS "Configuration file not found in: ${ARTIFACT_NAME_ARG}")
            
        endif()
        
    else()
    
        message(WARNING "Required artifact path is not correct ${ARTIFACT_NAME_ARG}.") 
        
    endif()

endfunction(ArtifactsHandler_InitArtifact)

#------------------------------------------------------------------------------#
# Returns version of artifact.
#
# ARTIFACT_NAME_ARG_ARG  [in]: Name of artifact to be processed (name of folder 
#                              in installation directory)
# ARTIFACT_VERSION_ARG  [out]: Version of required artifact (in format X.Y.Z)
#------------------------------------------------------------------------------#
function(CacheHandler_Get_ArtifactVersion ARTIFACT_NAME_ARG_ARG 
                                          ARTIFACT_VERSION_ARG)
            
    set(FUNCTION_NAME "${ARTIFACT_NAME_ARG_ARG}_GetArtifactVersion")
    
    # Check if artifact support getter for version getting.
    if(COMMAND ${FUNCTION_NAME})
    
        set(RET_VERSION "")
        
        # Call artifact version getter
        cmake_language(CALL "${FUNCTION_NAME}" RET_VERSION)
        
        # Set value for the parent scope
        set(${ARTIFACT_VERSION_ARG} "${RET_VERSION}" PARENT_SCOPE)
        
    else()
        
        set(${ARTIFACT_VERSION_ARG} "0.0.0" PARENT_SCOPE)
        
        message(STATUS "Artifact: ${ARTIFACT_NAME_ARG_ARG} does not support function ${FUNCTION_NAME}!")
        
    endif()

endfunction(ArtifactsHandler_Get_ArtifactVersion)

