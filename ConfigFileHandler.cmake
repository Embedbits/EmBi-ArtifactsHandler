###############################################################################
# Artifacts Configuration file handler functionality
###############################################################################


#------------------------------------------------------------------------------#
# Returns Root repository URL from ArtifactsConfig.txt file.
#
# ARTIFACTS_CONFIG_FILE_PATH_ARG [in]: Path to the ArtifactsConfig.txt file
# ROOT_REPO_URL_ARG             [out]: URL of root repository.
#------------------------------------------------------------------------------#
function(ConfigFileHandler_Get_RootRepoURL ARTIFACTS_CONFIG_FILE_PATH_ARG
                                           ROOT_REPO_URL_ARG)

    if(NOT EXISTS "${ARTIFACTS_CONFIG_FILE_PATH_ARG}")
        message(WARNING "ArtifactsConfig.txt not found!")
        return()
    endif()
    
    file(STRINGS "${ARTIFACTS_CONFIG_FILE_PATH_ARG}" ARTIFACTS_CONFIG_LINES)
    
    set(PARSED_LIST "")

    foreach(LINE IN LISTS ARTIFACTS_CONFIG_LINES)

        # Skip empty lines
        if(LINE STREQUAL "")
            continue()
        endif()

        if(LINE MATCHES "^ARTIFACTS_HANDLER_ROOT_REPO_URL=(.*)$")
        
            set(ROOT_REPO_URL "${CMAKE_MATCH_1}")

            set(${ROOT_REPO_URL_ARG} "${ROOT_REPO_URL}" PARENT_SCOPE)
            
            message(STATUS "Artifacts Root repository URL: ${ROOT_REPO_URL}")

            break()

        endif()

    endforeach()

endfunction(ConfigFileHandler_Get_RootRepoURL)


#------------------------------------------------------------------------------#
# Returns Required Artifacts List from ArtifactsConfig.txt file.
#
# ARTIFACTS_CONFIG_FILE_PATH_ARG [in]: Path to the ArtifactsConfig.txt file
# ARTIFACTS_LIST_ARG            [out]: List of Required Artifacts.
#------------------------------------------------------------------------------#
function(ConfigFileHandler_Get_ArtifactsList ARTIFACTS_CONFIG_FILE_PATH_ARG 
                                             ARTIFACTS_LIST_ARG)

    if(NOT EXISTS "${ARTIFACTS_CONFIG_FILE_PATH_ARG}")
        message(WARNING "ArtifactsConfig.txt not found!")
        return()
    endif()
    
    file(STRINGS "${ARTIFACTS_CONFIG_FILE_PATH_ARG}" ARTIFACTS_CONFIG_LINES)
    
    set(PARSED_LIST "")

    foreach(LINE IN LISTS ARTIFACTS_CONFIG_LINES)
        
        # Skip empty lines
        if(LINE STREQUAL "")
            continue()
        endif()

        # Ignore lines starting with "ARTIFACTS_HANDLER"
        if(LINE MATCHES "^ARTIFACTS_HANDLER")
            continue()
        endif()
        
        # Ignore lines starting with "#"
        if(LINE MATCHES "^#")
            continue()
        endif()

        # Check format: NAME;BINARY_VERSION;HANDLER_VERSION
        if(NOT LINE MATCHES "^([^;]+);([^;]+);([^;]+)$")
            message(FATAL_ERROR "Incorrect line format: '${LINE}'\nRequired format: NAME;BINARY_VERSION;HANDLER_VERSION")
        endif()
        
        string(REPLACE ";" "\;" LINE "${LINE}")
        string(REPLACE "," "\n" LINE "${LINE}")
        string(REPLACE " " "" LINE "${LINE}")
        string(REPLACE "_" "-" LINE "${LINE}")

        list(APPEND PARSED_LIST "${LINE}")
    endforeach()

    set(${ARTIFACTS_LIST_ARG} "${PARSED_LIST}" PARENT_SCOPE)

endfunction(ConfigFileHandler_Get_ArtifactsList)


#------------------------------------------------------------------------------#
# Returns path to the ArtifactsCache folder from ArtifactsConfig.txt file.
#
# ArtifactsConfig.txt file can contain path, to the Artifacts Cache folder. The
# configuration line shall begin with "ARTIFACTS_HANDLER_CACHE_PATH=". This 
# folder will be used as permanent storage for downloaded artifacts.
#
# ARTIFACTS_CONFIG_FILE_PATH_ARG [in]: Path to the ArtifactsConfig.txt file
# ARTIFACTS_CACHE_PATH_ARG      [out]: Path to the Artifacts Cache folder. If
#                                      not found, symbol "-" is returned
#------------------------------------------------------------------------------#
function(ConfigFileHandler_Get_CachePath ARTIFACTS_CONFIG_FILE_PATH_ARG 
                                         ARTIFACTS_CACHE_PATH_ARG)

    if(NOT EXISTS "${ARTIFACTS_CONFIG_FILE_PATH_ARG}")
        message(WARNING "ArtifactsConfig.txt not found!")
        return()
    endif()
    
    file(STRINGS "${ARTIFACTS_CONFIG_FILE_PATH_ARG}" ARTIFACTS_CONFIG_LINES)
    
    set(PARSED_LIST "")

    foreach(LINE IN LISTS ARTIFACTS_CONFIG_LINES)

        # Skip empty lines
        if(LINE STREQUAL "")
            continue()
        endif()

        if(LINE MATCHES "^ARTIFACTS_HANDLER_CACHE_PATH=(.*)$")
        
            set(ARTIFACTS_CACHE_PATH "${CMAKE_MATCH_1}")

            set(${ARTIFACTS_CACHE_PATH_ARG} "${ARTIFACTS_CACHE_PATH}" PARENT_SCOPE)

            break()
            
        else()
        
            set(${ARTIFACTS_CACHE_PATH_ARG} "-" PARENT_SCOPE)

        endif()

    endforeach()

endfunction(ConfigFileHandler_Get_CachePath)
