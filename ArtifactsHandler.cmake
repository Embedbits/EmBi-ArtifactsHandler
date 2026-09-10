###############################################################################
# Artifacts handler
###############################################################################
# 
#------------------------------------------------------------------------------
# Artifacts cache folder example structure:
# ArtifactsCache/
# ├── gcc-arm-none-eabi/
# │   ├── 15.2.1/
# │   ├── 14.3.1/
# │   ├── 14.2.1/
# │   ...
# │   └── 11.3.1/
# │
# ├── ninja/
# │   ├── 1.13.2/
# │   ├── 1.13.1/
# │   ├── 1.13.0/
# │   ...
# │   └── 1.1.0/
# │
# ...
# └── doxygen/
#     ├── 1.16.1/
#     ├── 1.16.0/
#     ├── 1.15.0/
#     ...
#     └── 1.9.8/
#
#------------------------------------------------------------------------------
# Available artifacts has to be added as git submodule in artifacts root 
# repository. The URL can be passed through:
# - Enviromental variable : ARTIFACTS_HANDLER_ROOT_REPO
# - Attribute parameter: -DARTIFACTS_HANDLER_ROOT_REPO="YourURL"
#
# Artifacts root repository example structure:
#
# Artifacts
# ├── doxygen                   Doxygen artifact Git submodule
# ├── gcc                       GCC artifact Git submodule
# ├── gcc_arm_none_eabi         Gcc-Arm-None-Eabi artifact Git submodule
# ...
# ├── ninja                     Ninja artifact Git submodule
# ├── .gitmodules               List of Git submodules
# └── README.md                 Artifacts repository manual
#
# Each artifact shall contain three branches. 
#
# Bin branch shall contain all artifacts binaries. Each version shall have its 
# own Git TAG in format Bin/ArtifactVersion-OsVersion where ArtifactVersion 
# shall be in format X.Y.Z, OsVersion shall be one of the following:
# - Win         : For Windows based OS
# - Unix        : For Linux/Unix based OS
# - DarvinARM   : For rotten fruit ARM based OS
#
# Core branch shall contain artifact CMake handler. This can be versioned 
# separately and allow user to change functionality independently from binary
# artifact.
#
# Main/master branch shall contain README.md for keeping details about artifact,
# its versions and abilities.
# 
# Artifact repository default branch structure:
# 
# ArtifactRepo
# ├── Bin/                      Branch containing all binaries
# ├── Core/                     Branch containing artifact CMake handler
# └── main/master               Branch containing artifact details
#
#------------------------------------------------------------------------------
#
# Example usage 1:
# cmake -P ArtifactsHandler.cmake
#
# Attribute list:
#
# Optional attributes:
#
# OFFLINE MODE:
# Only local cache will be checked. No download will be triggered (default:false).
# -DOFFLINE_MODE=true/false
#
# ARTIFACT LIST:
# Required artifacts list (bypassing configuration file list) 
# -DARTIFACTS_LIST=ninja;1.12.0;latest,gcc-arm-none-eabi;latest;latest,doxygen;latest;latest
#
# CACHE PATH:
# Required cache folder path (default value is configuration file). If the parameter 
# is not specified the system enviromental variable can be set through "ARTIFACTS_HANDLER_CACHE_PATH"
# -DARTIFACTS_HANDLER_CACHE_PATH="D:/Artifacts"
#
# CONFIG FILE PATH:
# The configuration file path can be configured through parameter:
# -DCONFIG_FILE_PATH="PathToThe_ArtifactsConfig.txt"
#
################################################################################
cmake_minimum_required(VERSION 3.21)

include("${CMAKE_CURRENT_LIST_DIR}/CacheHandler.cmake")
include("${CMAKE_CURRENT_LIST_DIR}/ConfigFileHandler.cmake")
include("${CMAKE_CURRENT_LIST_DIR}/ParamsHandler.cmake")
include("${CMAKE_CURRENT_LIST_DIR}/RootRepoHandler.cmake")

#==============================================================================#
# Global variables
#==============================================================================#

# Path to the installed artifacts
set(ARTIFACTS_INSTAL_LOC "Cache/Artifacts")
# Artifacts configuration file name
set(ARTIFACTS_CONFIG_FILE_NAME "ArtifactsConfig.txt")
# Path to the artifacts configuration file.
set(CONFIG_FILE "${CMAKE_SOURCE_DIR}/${ARTIFACTS_CONFIG_FILE_NAME}")



# Path to the stored root repository.
set(ARTIFACTS_HANDLER_TEMP_PATH "${CMAKE_CURRENT_LIST_DIR}/Temp")
set(ARTIFACTS_HANDLER_ROOT_REPO_PATH "${ARTIFACTS_HANDLER_TEMP_PATH}/RootRepo")
set(ARTIFACTS_HANDLER_BIN_TEMP_PATH "${ARTIFACTS_HANDLER_TEMP_PATH}/BinTemp")
set(ARTIFACTS_HANDLER_DEFAULT_CACHE_PATH "${ARTIFACTS_HANDLER_TEMP_PATH}/Cache")

# List of OS versions names.
set(ARTIFACTS_HANDLER_OS_WIN  "Win")
set(ARTIFACTS_HANDLER_OS_UNIX "Unix")
set(ARTIFACTS_HANDLER_OS_MAC  "DarwinARM")

# List of Required Artifacts list source
set(ARTIFACTS_HANDLER_ARTIFACT_LIST_SRC_FILE  "SRC_FILE")
set(ARTIFACTS_HANDLER_ARTIFACT_LIST_SRC_PARAM "SRC_PARAM")
set(ARTIFACTS_HANDLER_ARTIFACT_LIST_SRC_ENV   "SRC_ENV")

#==============================================================================#
# Local functions
#==============================================================================#


#------------------------------------------------------------------------------#
# Returns path to the ArtifactsConfig.txt file.
#
# User can configure path to the ArtifactsConfig.txt through:
# 1: Enviromental variable "CONFIG_FILE_PATH"
# 2: CMake parameter "-DCONFIG_FILE_PATH="PathToThe_ArtifactsConfig.txt""
# 3: Root folder of CMake build (In case the script is called during build)
# 4: Actual folder of CMake script (In case the scipt is executed in script mode)
#
# ARTIFACTS_CONFIG_FILE_PATH_ARG [out]: Decoded path to the ArtifactsConfig.txt
#------------------------------------------------------------------------------#
function(ArtifactsHandler_Get_ArtifactsConfigFile_Path ARTIFACTS_CONFIG_FILE_PATH_ARG)

    set(CONFIG_FILE "")

    # --- Step 1: Check for ArtifactsConfig.txt path.
    if(DEFINED ENV{CONFIG_FILE_PATH} AND NOT "$ENV{CONFIG_FILE_PATH}" STREQUAL "")

        # Path to the ArtifactsConfig.txt is passed through enviromental variable.
        set(CONFIG_FILE "${CONFIG_FILE_PATH}/${ARTIFACTS_CONFIG_FILE_NAME}")
        
        message(DEBUG "Artifacts configuration list is provided by enviromental variable.")

    elseif(DEFINED CONFIG_FILE_PATH AND NOT CONFIG_FILE_PATH STREQUAL "")

        # Path to the ArtifactsConfig.txt is passed through argument.
        set(CONFIG_FILE "${CONFIG_FILE_PATH}/${ARTIFACTS_CONFIG_FILE_NAME}")
        
        message(DEBUG "Artifacts configuration list is provided by CMake parameters.")

    elseif(DEFINED CONFIG_FILE_PATH AND NOT CONFIG_FILE_PATH STREQUAL "")

        # Path to the ArtifactsConfig.txt is used from CMakeLists.txt path.
        set(CONFIG_FILE "${CONFIG_FILE_PATH}/${ARTIFACTS_CONFIG_FILE_NAME}")
        
        message(DEBUG "Artifacts configuration list is provided by configuration file.")

    else()

        # Path to the ArtifactsConfig.txt is used from current location.
        set(CONFIG_FILE "${CMAKE_CURRENT_LIST_DIR}/${ARTIFACTS_CONFIG_FILE_NAME}")
        
        message(DEBUG "Artifacts configuration list is provided by default configuration file.")

    endif()

    if(EXISTS "${CONFIG_FILE}" AND NOT IS_DIRECTORY "${CONFIG_FILE}")

        set(${ARTIFACTS_CONFIG_FILE_PATH_ARG} "${CONFIG_FILE}" PARENT_SCOPE)

    else()

        message(FATAL_ERROR "ArtifactsConfig.txt not found in ${CONFIG_FILE}")

        set(${ARTIFACTS_CONFIG_FILE_PATH_ARG} "" PARENT_SCOPE)

    endif()

endfunction(ArtifactsHandler_Get_ArtifactsConfigFile_Path)



#------------------------------------------------------------------------------#
# Returns path to the Root repository URL.
#
# User can configure Root repository URL through:
# 1: Enviromental variable "ROOT_REPO_URL"
# 2: CMake parameter "-ROOT_REPO_URL="RootRepositoryURL""
# 3: Artifacts configuration file by setting ARTIFACTS_HANDLER_ROOT_REPO_URL=RootRepoURL
#
# ARTIFACTS_CONFIG_FILE_PATH_ARG  [in]: Decoded path to the ArtifactsConfig.txt
# ROOT_REPO_URL_ARG              [out]: Root repository URL 
#------------------------------------------------------------------------------#
function(ArtifactsHandler_Get_RootRepoURL ARTIFACTS_CONFIG_FILE_PATH_ARG
                                          ROOT_REPO_URL_ARG)

    set(ROOT_REPO_URL "")

    # --- Step 1: Check for ArtifactsConfig.txt path.
    if(DEFINED ENV{ROOT_REPO_URL} AND NOT "$ENV{ROOT_REPO_URL}" STREQUAL "")

        # Root repository is passed through enviromental variable.
        set(ROOT_REPO_URL "${ROOT_REPO_URL}")
        
        message(DEBUG "Root repository URL is provided by enviromental variable.")

    elseif(DEFINED ROOT_REPO_URL AND NOT ROOT_REPO_URL STREQUAL "")

        # Root repository is passed through argument.
        set(ROOT_REPO_URL "${ROOT_REPO_URL}")
        
        message(DEBUG "Root repository URL is provided by CMake parameter.")

    else()
    
        # Root repository is read from the ArtifactsConfig.txt
        ConfigFileHandler_Get_RootRepoURL("${ARTIFACTS_CONFIG_FILE_PATH_ARG}" ROOT_REPO_URL)
        
        message(DEBUG "Root repository URL is provided configuration file.")

    endif()

    if("${ROOT_REPO_URL}" STREQUAL "")
    
        message(FATAL_ERROR "Root repository URL not configured.")
        
        set(${ARTIFACTS_CONFIG_FILE_PATH_ARG} "" PARENT_SCOPE)

    else()

        set(${ROOT_REPO_URL_ARG} "${ROOT_REPO_URL}" PARENT_SCOPE)

    endif()

endfunction(ArtifactsHandler_Get_RootRepoURL)


#------------------------------------------------------------------------------#
# Returns detected OS version
#
# OS_VERSION_ARG [out]: Version of actual OS. Can be one of list:
#                       Win       - For Windows based OS
#                       DarwinARM - For MacOS ARM based OS
#                       Unix      - For Linux based OS
#------------------------------------------------------------------------------#
function(ArtifactsHandler_Get_OsVersion OS_VERSION_ARG)

    if(${CMAKE_HOST_SYSTEM_NAME} STREQUAL "Windows")
        set(${OS_VERSION_ARG} "${ARTIFACTS_HANDLER_OS_WIN}" PARENT_SCOPE)
        message(DEBUG "Windows OS system detected.")
    elseif(${CMAKE_HOST_SYSTEM_NAME} STREQUAL "Darwin")
        set(${OS_VERSION_ARG} "${ARTIFACTS_HANDLER_OS_MAC}" PARENT_SCOPE)
        message(DEBUG "Rotten fruit OS system detected.")
    else()
        set(${OS_VERSION_ARG} "${ARTIFACTS_HANDLER_OS_UNIX}" PARENT_SCOPE)
        message(DEBUG "Unix based OS system detected.")
    endif()

endfunction()


#------------------------------------------------------------------------------#
# Returns list of artifacts required for building.
#
# ARTIFACTS_CONFIG_FILE_PATH_ARG  [in]: Path to the ArtifactsConfig.txt file
# ARTIFACTS_LIST_ARG             [out]: List of Required Artifacts.
#------------------------------------------------------------------------------#
function(ArtifactsHandler_Get_RequiredArtifactsList ARTIFACTS_CONFIG_FILE_PATH_ARG 
                                                    ARTIFACTS_LIST_ARG)

    set(ARTIFACTS_LIST_SRC "")
    set(REQUIRED_ARTIFACTS_LIST "")
    set(ARTIFACTS_CONFIG_FILE_PATH "")

    # Read source of Required Artifacts List
    ArtifactsHandler_Get_RequiredArtifactsList_Source(ARTIFACTS_LIST_SRC)

    if(ARTIFACTS_LIST_SRC STREQUAL ARTIFACTS_HANDLER_ARTIFACT_LIST_SRC_FILE)

        ConfigFileHandler_Get_ArtifactsList(${ARTIFACTS_CONFIG_FILE_PATH_ARG} REQUIRED_ARTIFACTS_LIST)

    elseif(ARTIFACTS_LIST_SRC STREQUAL ARTIFACTS_HANDLER_ARTIFACT_LIST_SRC_PARAM)

        # Read list of Required Artifacts entered through CMake parameters
        ParamsHandler_Get_ArtifactsList(REQUIRED_ARTIFACTS_LIST)

    elseif(ARTIFACTS_LIST_SRC STREQUAL ARTIFACTS_HANDLER_ARTIFACT_LIST_SRC_ENV)

    else()

        message(FATAL_ERROR "No source for Required Artifacts List configured.")

    endif()

    set(${ARTIFACTS_LIST_ARG} "${REQUIRED_ARTIFACTS_LIST}" PARENT_SCOPE)

endfunction(ArtifactsHandler_Get_RequiredArtifactsList)


#------------------------------------------------------------------------------#
# Returns source of Required Artifacts List.
#
# User can configure source of Required Artifacts List in following order:
# 1: CMake parameter "-DARTIFACTS_HANDLER_REQ_LIST="ListOfArtifacts" 
# 2: Enviromental Variable "ARTIFACTS_HANDLER_REQ_LIST"
# 3: ArtifactsConfig.txt file
#
# where ListOfArtifacts is in format: ArtifactName;BinVersion;HandlerVersion
#
# ARTIFACTS_LIST_SRC_ARG [out]: List of Required Artifacts.
#------------------------------------------------------------------------------#
function(ArtifactsHandler_Get_RequiredArtifactsList_Source ARTIFACTS_LIST_SRC_ARG)

    if(DEFINED ARTIFACTS_HANDLER_REQ_LIST AND NOT ARTIFACTS_HANDLER_REQ_LIST AND "")

        # Required Artifacts List is configured through CMake parameter.
        set(${ARTIFACTS_LIST_SRC_ARG} "${ARTIFACTS_HANDLER_ARTIFACT_LIST_SRC_PARAM}" PARENT_SCOPE)
        
        message(DEBUG "List of required artifacts is entered through parameter.")
    
    elseif(DEFINED ENV{ARTIFACTS_HANDLER_REQ_LIST} AND NOT "$ENV{ARTIFACTS_HANDLER_REQ_LIST}" STREQUAL "")

        # Required Artifacts List is configured through Enviromental variable.
        set(${ARTIFACTS_LIST_SRC_ARG} "${ARTIFACTS_HANDLER_ARTIFACT_LIST_SRC_ENV}" PARENT_SCOPE)

        message(DEBUG "List of required artifacts is entered through eniromental variable.")

    else()

        # Required Artifacts List is configured through ArtifactsConfig.txt file.
        set(${ARTIFACTS_LIST_SRC_ARG} "${ARTIFACTS_HANDLER_ARTIFACT_LIST_SRC_FILE}" PARENT_SCOPE)
        
        message(DEBUG "List of required artifacts is entered from ArtifactsConfig.txt.")

    endif()

endfunction(ArtifactsHandler_Get_RequiredArtifactsList_Source)


#------------------------------------------------------------------------------#
# Returns list of sub-folders.
#
# FOLDER_PATH_ARG  [in]: Path to the folder where sub-folders has to be listed.
# FOLDER_LIST_ARG [out]: List of sub-folders.
#------------------------------------------------------------------------------#
function(ArtifactsHandler_Get_FolderList FOLDER_PATH_ARG 
                                         FOLDER_LIST_ARG)

    set(SUBDIRS_LIST "")
    
    if(NOT EXISTS "${FOLDER_PATH_ARG}" OR NOT IS_DIRECTORY "${FOLDER_PATH_ARG}")
        set(${FOLDER_LIST_ARG} "${SUBDIRS_LIST}" PARENT_SCOPE)
        message(STATUS "Folder not found: ${FOLDER_PATH_ARG}")
    endif()

    file(GLOB FOLDER_ITEMS "${FOLDER_PATH_ARG}/*")

    if(NOT FOLDER_ITEMS)
        set(${FOLDER_LIST_ARG} "" PARENT_SCOPE)
        return()
    endif()

    foreach(FOLDER_NAME IN LISTS FOLDER_ITEMS)
        if(IS_DIRECTORY "${FOLDER_NAME}")
            get_filename_component(name "${FOLDER_NAME}" NAME)
            if(NOT name MATCHES "^\\.")
                list(APPEND SUBDIRS_LIST "${name}")
            endif()
        endif()
    endforeach()

    set(${FOLDER_LIST_ARG} "${SUBDIRS_LIST}" PARENT_SCOPE)
    
endfunction(ArtifactsHandler_Get_FolderList)


#------------------------------------------------------------------------------#
# Returns path to the location, where the Artifacts shall be cached (installed).
#
# Artifacts cache path can be provided through:
#   1: Parameter ("-DARTIFACTS_HANDLER_CACHE_PATH=D:/Artifacts")
#   2: Enviromental variable ("ARTIFACTS_HANDLER_CACHE_PATH")
#   3: ArtifactsConfig.txt file (The file shall contain "ARTIFACTS_HANDLER_CACHE_PATH=XYZ")
#
# The Artifacts configuration can be read from 
#
# ARTIFACTS_CONFIG_FILE_PATH_ARG [in]: Path to the ArtifactsConfig.txt file
# CACHE_PATH_ARG                [out]: Path to the Artifacts Cache folder
#------------------------------------------------------------------------------#
function(ArtifactsHandler_Get_ArtifactsCachePath ARTIFACTS_CONFIG_FILE_PATH_ARG 
                                                 CACHE_PATH_ARG)

    if(DEFINED ARTIFACTS_HANDLER_CACHE_PATH AND NOT ARTIFACTS_HANDLER_CACHE_PATH STREQUAL "")

        # Path to the ARTIFACTS_HANDLER_CACHE_PATH is passed through argument.
        set(${CACHE_PATH_ARG} "${ARTIFACTS_HANDLER_CACHE_PATH}" PARENT_SCOPE)
        
        message(DEBUG "The cache path will be used from CMake parameter:${ARTIFACTS_HANDLER_CACHE_PATH}")

    elseif(DEFINED ENV{ARTIFACTS_HANDLER_CACHE_PATH} AND NOT "$ENV{ARTIFACTS_HANDLER_CACHE_PATH}" STREQUAL "")

        # Path to the ARTIFACTS_HANDLER_CACHE_PATH is passed through enviromental variable.
        set(${CACHE_PATH_ARG} "$ENV{ARTIFACTS_HANDLER_CACHE_PATH}" PARENT_SCOPE)
        
        message(DEBUG "The cache path will be used from enviromental variable:${ARTIFACTS_HANDLER_CACHE_PATH}")

    else()

        # Read cache path from configuration file
        ConfigFileHandler_Get_CachePath("${ARTIFACTS_CONFIG_FILE_PATH_ARG}" CACHE_PATH)

        if(NOT "${CACHE_PATH}" STREQUAL "-" AND IS_DIRECTORY "${CACHE_PATH}")

            # Use cache path from configuration file, but only if it actually
            # exists on this machine. This is a simple guard for a config file
            # shared between Windows and Unix that only makes sense on one of them.
            set(${CACHE_PATH_ARG} "${CACHE_PATH}" PARENT_SCOPE)
            
            message(DEBUG "The cache path will be used from configuration file:${CACHE_PATH}")
            
        else()

            if(NOT "${CACHE_PATH}" STREQUAL "-")
                message(STATUS "Configured cache path '${CACHE_PATH}' does not exist on this system, falling back to default cache path.")
            endif()

            # Use default cache path
            set(${CACHE_PATH_ARG} "${ARTIFACTS_HANDLER_DEFAULT_CACHE_PATH}" PARENT_SCOPE)
            
            message(DEBUG "The default cache path will be:${ARTIFACTS_HANDLER_DEFAULT_CACHE_PATH}")
            
        endif()
        
    endif()
    
endfunction(ArtifactsHandler_Get_ArtifactsCachePath)


#------------------------------------------------------------------------------#
# Checks, if OFFLINE mode is active or not.
#
# User can activate "OFFLINE" mode by setting CMake parameter 
# "ARTIFACTS_HANDLER_OFFLINE_MODE". If activate, the Artifacts Handler will not
# try to download any artifacts.
#
# Example with OFFLINE mode active:
# cmake -P -DARTIFACTS_HANDLER_OFFLINE_MODE=TRUE ArtifactsHandler.cmake
#
# OFFLINE_MODE_STATE_ARG [out]: OFFLINE mode activation state
#------------------------------------------------------------------------------#
function(ArtifactsHandler_Get_OfflineModeState OFFLINE_MODE_STATE_ARG)

    if(NOT DEFINED ARTIFACTS_HANDLER_OFFLINE_MODE OR ARTIFACTS_HANDLER_OFFLINE_MODE STREQUAL "FALSE")
        set(${OFFLINE_MODE_STATE_ARG} "FALSE" PARENT_SCOPE)
        message(DEBUG "OFFLINE mode is inactive")
    else()
        set(${OFFLINE_MODE_STATE_ARG} "TRUE" PARENT_SCOPE)
        message(DEBUG "OFFLINE mode active")
    endif()
endfunction(ArtifactsHandler_Get_OfflineModeState)


#------------------------------------------------------------------------------#
# Install Binary part of artifact.
#
# The artifact archive file will be extracted into cache folder and necessary 
# files will be copied from repository to cache folder.
#
# ARTIFACT_NAME_ARG [in]: Name of artifact to be processed (name of directory in 
#                         root artifacts repository)
#------------------------------------------------------------------------------#
function(ArtifactsHandler_InstallArtifact_Bin CACHED_ARTIFACTS_PATH_ARG
                                              TEMP_FOLDER_PATH_ARG
                                              ARTIFACT_NAME_ARG 
                                              ARTIFACT_BIN_VERSION_ARG)

    set(ARTIFACT_CACHE_BIN_PATH "${CACHED_ARTIFACTS_PATH_ARG}/${ARTIFACT_NAME_ARG}/Bin/${ARTIFACT_BIN_VERSION_ARG}")

    # Get list of all archives in artifact submodule folder
    file(GLOB ZIP_FILES "${TEMP_FOLDER_PATH_ARG}/${ARTIFACT_NAME_ARG}/*.zip")

    # Brocess Binary part of artifact
    if(NOT ZIP_FILES)
        message(WARNING "No Binary artifacts downloaded in ${ARTIFACT_NAME_ARG}")
    else()
    
        if(EXISTS "${ARTIFACT_CACHE_BIN_PATH}")
            if(ARTIFACTS_HANDLER_FORCE_INIT STREQUAL "TRUE")
                # Remove the folder
                file(REMOVE_RECURSE "${ARTIFACT_CACHE_BIN_PATH}")
            else()
                message(STATUS "Artifact ${ARTIFACT_NAME_ARG} with version ${ARTIFACT_BIN_VERSION_ARG} is already installed in cache.")
                return()
            endif()
        endif()
    
        list(GET ZIP_FILES 0 FIRST_ZIP_FILE)
        
        file(ARCHIVE_EXTRACT
             INPUT "${FIRST_ZIP_FILE}"
             DESTINATION "${ARTIFACT_CACHE_BIN_PATH}/")
    endif()

endfunction(ArtifactsHandler_InstallArtifact_Bin)


#------------------------------------------------------------------------------#
# Install Core part of artifact.
#
# Necessary files will be copied from repository to cache folder.
#
# ARTIFACT_NAME_ARG [in]: Name of artifact to be processed (name of directory in 
#                         root artifacts repository)
#------------------------------------------------------------------------------#
function(ArtifactsHandler_InstallArtifact_Core CACHED_ARTIFACTS_PATH_ARG 
                                               TEMP_FOLDER_PATH_ARG
                                               ARTIFACT_NAME_ARG 
                                               ARTIFACT_CORE_VERSION_ARG)

    set(ARTIFACT_CACHE_CORE_PATH "${CACHED_ARTIFACTS_PATH_ARG}/${ARTIFACT_NAME_ARG}/Core/${ARTIFACT_CORE_VERSION_ARG}")

    set(ARTIFACT_NAME_UNDERSCORE "${ARTIFACT_NAME_ARG}")
    string(REPLACE "-" "_" ARTIFACT_NAME_UNDERSCORE "${ARTIFACT_NAME_UNDERSCORE}")
    
    set(ARTIFACT_NAME_ORIGINAL "${ARTIFACT_NAME_ARG}")

    
    if(IS_DIRECTORY "${TEMP_FOLDER_PATH_ARG}/${ARTIFACT_NAME_UNDERSCORE}")
    
        set(SOURCE_DIR "${TEMP_FOLDER_PATH_ARG}/${ARTIFACT_NAME_UNDERSCORE}/")
    
    elseif(IS_DIRECTORY "${TEMP_FOLDER_PATH_ARG}/${ARTIFACT_NAME_ORIGINAL}")
    
        set(SOURCE_DIR "${TEMP_FOLDER_PATH_ARG}/${ARTIFACT_NAME_ORIGINAL}/")
    
    endif()
    
    file(COPY "${SOURCE_DIR}/"
         DESTINATION "${ARTIFACT_CACHE_CORE_PATH}"
         PATTERN ".*" EXCLUDE)

endfunction(ArtifactsHandler_InstallArtifact_Core)


#------------------------------------------------------------------------------#
# Returns latest artifact release on server.
#
# ARTIFACT_OS_VERSION [in]: Version of used OS [Win/Unix]
# ARTIFACT_NAME       [in]: Name of artifact to be processed (name of directory 
#                           in root artifacts repository)
# ARTIFACT_VERSION   [out]: Latest artifact version (in format X.Y.Z)
#------------------------------------------------------------------------------#
function(GetLatestRemoteRelease ARTIFACT_OS_VERSION ARTIFACT_NAME ARTIFACT_VERSION)

    set(SUBMODULE_DIR "${ROOT_REPO_DIR}/${ARTIFACT_NAME}")
    
    # Re-format path to standard format (remove un-necessary /./ in string)
    cmake_path(NORMAL_PATH SUBMODULE_DIR)
    
    if(NOT EXISTS ${SUBMODULE_DIR})
        message(FATAL_ERROR "Artifact '${ARTIFACT_NAME}' not found in root repository.")
        continue()
    endif()

    # Fetch only branch list (no data)
    execute_process(COMMAND git ls-remote --heads origin
                    WORKING_DIRECTORY "${SUBMODULE_DIR}"
                    OUTPUT_VARIABLE BRANCH_LIST
                    OUTPUT_STRIP_TRAILING_WHITESPACE
                    ERROR_QUIET)

    if(NOT BRANCH_LIST)
        message(WARNING "No remote branches found in ${SUBMODULE_DIR}")
        set(${ARTIFACT_VERSION} "" PARENT_SCOPE)
        return()
    endif()
    
        # Separate list to rows
    string(REPLACE "\n" ";" BRANCH_LIST "${BRANCH_LIST}")
    
    # System has to find latest release version
    foreach(BRANCH IN LISTS BRANCH_LIST)
    
        if("${BRANCH}" MATCHES "${ARTIFACT_OS_VERSION}")
        
            # 1. Extract part after tab
            string(REPLACE "\t" ";" PARTS "${BRANCH}")
            list(GET PARTS 1 BRANCH_NAME)
            
            string(REPLACE "refs/heads/" "" BRANCH_NAME "${BRANCH_NAME}")
            
            # 2. Remove suffix (eg. -Win, -Linux, -Mac)
            string(REGEX REPLACE "-(Win|Linux|Mac)$" "" VERSION_WITHOUT_OS "${BRANCH_NAME}")
            
            # 3. Version extraction
            string(REGEX MATCH "[0-9]+\\.[0-9]+\\.[0-9]+" VERSION "${VERSION_WITHOUT_OS}")
            
            # 4. Append version to list
            list(APPEND RELEASE_VERSION_LIST "${VERSION}")
            
        endif()
        
    endforeach()
       
    # Sort versions naturally
    list(SORT RELEASE_VERSION_LIST COMPARE NATURAL)

    # Get latest
    list(GET RELEASE_VERSION_LIST -1 LATEST_VERSION)

    set(${ARTIFACT_VERSION} "${LATEST_VERSION}" PARENT_SCOPE)
    
endfunction(GetLatestRemoteRelease)


#------------------------------------------------------------------------------#
# Returns latest artifact release on local.
#
# ARTIFACT_OS_VERSION [in]: Version of used OS [Win/Unix]
# ARTIFACT_NAME       [in]: Name of artifact to be processed (name of directory 
#                           in root artifacts repository)
# ARTIFACT_VERSION   [out]: Latest artifact version (in format X.Y.Z)
#------------------------------------------------------------------------------#
function(GetLatestLocalRelease ARTIFACT_OS_VERSION ARTIFACT_NAME ARTIFACT_VERSION)

    set(SUBMODULE_DIR "${ROOT_REPO_DIR}/${ARTIFACT_NAME}")
    
    # Re-format path to standard format (remove un-necessary /./ in string)
    cmake_path(NORMAL_PATH SUBMODULE_DIR)
    
    if(NOT EXISTS ${SUBMODULE_DIR})
        message(FATAL_ERROR "Artifact '${ARTIFACT_NAME}' not found in root repository.")
        continue()
    endif()
    
    # Get local branch list
    execute_process(COMMAND git branch --list
                    WORKING_DIRECTORY "${SUBMODULE_DIR}"
                    OUTPUT_VARIABLE BRANCH_LIST
                    OUTPUT_STRIP_TRAILING_WHITESPACE
                    ERROR_QUIET)

    if(NOT BRANCH_LIST)
        message(WARNING "No local branches found in ${SUBMODULE_DIR}")
        set(${ARTIFACT_VERSION} "" PARENT_SCOPE)
        return()
    endif()
    
        # Separate list to rows
    string(REPLACE "\n" ";" BRANCH_LIST "${BRANCH_LIST}")
    
    # System has to find latest release version
    foreach(BRANCH IN LISTS BRANCH_LIST)
    
        if("${BRANCH}" MATCHES "${ARTIFACT_OS_VERSION}")
        
            # 1. Extract part after tab
            string(REPLACE "\t" ";" PARTS "${BRANCH}")
            
            # 2. Remove suffix (eg. -Win, -Linux, -Mac)
            string(REGEX REPLACE "-(Win|Linux|Mac)$" "" VERSION_WITHOUT_OS "${BRANCH}")
            
            # 3. Version extraction
            string(REGEX MATCH "[0-9]+\\.[0-9]+\\.[0-9]+" VERSION "${VERSION_WITHOUT_OS}")
            
            # 4. Append version to list
            list(APPEND RELEASE_VERSION_LIST "${VERSION}")
            
        endif()
        
    endforeach()
       
    # Sort versions naturally
    list(SORT RELEASE_VERSION_LIST COMPARE NATURAL)

    # Get latest
    list(GET RELEASE_VERSION_LIST -1 LATEST_VERSION)

    set(${ARTIFACT_VERSION} "${LATEST_VERSION}" PARENT_SCOPE)
    
endfunction(GetLatestLocalRelease)


#------------------------------------------------------------------------------#
# Returns version of installed artifact.
#
# ARTIFACT_NAME     [in]: Name of artifact to be processed (name of folder in 
#                         installation directory)
# ARTIFACT_VERSION [out]: Version of required artifact (in format X.Y.Z)
#------------------------------------------------------------------------------#
function(GetInitializedArtifactVersion ARTIFACT_NAME ARTIFACT_VERSION)

    # Check if the current path is a directory
    if(IS_DIRECTORY "${ARTIFACTS_INSTAL_DIR}/${ARTIFACT_NAME}")
    
        # Construct the full path to the config file
        set(full_path "${ARTIFACTS_INSTAL_DIR}/${ARTIFACT_NAME}/${ARTIFACTS_CONFIG_FILE}")
    
        # Check if the config file exists in the current subdirectory
        if(EXISTS "${full_path}")
            
            set(FUNCTION_NAME "${ARTIFACT_NAME}_GetArtifactVersion")
            
            # Check if artifact support getter for version getting.
            if(COMMAND ${FUNCTION_NAME})
            
                set(RET_VERSION "")
                # Call artifact version getter
                cmake_language(CALL "${FUNCTION_NAME}" RET_VERSION)
                
                # Set value for the parent scope
                set(${ARTIFACT_VERSION} "${RET_VERSION}" PARENT_SCOPE)
                
            else()
                
                set(${ARTIFACT_VERSION} "0.0.0" PARENT_SCOPE)
                
                message(STATUS "Artifact: ${ARTIFACT_NAME} does not support function ${FUNCTION_NAME}!")
                
            endif()
            
        else()
        
            message(STATUS "Config file not found in: ${ARTIFACT_NAME}")
            
        endif()
        
    else()
    
        message(WARNING "Required artifact path is not correct ${ARTIFACT_NAME}.") 
        
    endif()

endfunction(GetInitializedArtifactVersion)


#------------------------------------------------------------------------------#
# Initialize installed artifact.
#
# ARTIFACT_NAME [in]: Name of artifact to be processed (name of folder in 
#                     install directory)
#------------------------------------------------------------------------------#
function(InitArtifact ARTIFACT_NAME)

    # Check if the current path is a directory
    if(IS_DIRECTORY "${ARTIFACTS_INSTAL_DIR}/${ARTIFACT_NAME}")
    
        # Construct the full path to the config file
        set(full_path "${ARTIFACTS_INSTAL_DIR}/${ARTIFACT_NAME}/${ARTIFACTS_CONFIG_FILE}")
    
        # Check if the config file exists in the current subdirectory
        if(EXISTS "${full_path}")
        
            # Include the config file
            include("${full_path}")
            
            set(FUNCTION_NAME "${ARTIFACT_NAME}_ArtifactInit")
            
            # Check if artifact support getter for version getting.
            if(COMMAND ${FUNCTION_NAME})
            
                # Call artifact version getter
                cmake_language(CALL "${FUNCTION_NAME}")
                
            else()
                
                message(STATUS "Artifact: ${ARTIFACT_NAME} does not support function ${FUNCTION_NAME}!")
                
            endif()
            
        else()
        
            message(STATUS "Config file not found in: ${ARTIFACT_NAME}")
            
        endif()
        
    else()
    
        message(WARNING "Required artifact path is not correct ${ARTIFACT_NAME}.") 
        
    endif()

endfunction(InitArtifact)


#------------------------------------------------------------------------------#
# Returns artifact details in repository directory 
#
# ARTIFACT_NAME        [in]: Name of artifact to be processed (name of directory 
#                            in root artifacts repository)
# ARTIFACT_NAME       [out]: Name of artifact.
# ARTIFACT_VERSION    [out]: Version of artifact.
# ARTIFACT_OS_VERSION [out]: Target OS for current artefact
#------------------------------------------------------------------------------#
function(GetDownloadedArtifactDetails ARTIFACT_FOLDER ARTIFACT_NAME ARTIFACT_VERSION ARTIFACT_OS_VERSION)

    # Get list of all archives in artifact submodule folder
    file(GLOB ZIP_FILES "${ROOT_REPO_DIR}/${ARTIFACT_FOLDER}/*.zip")

    get_filename_component(name "${ZIP_FILES}" NAME)
    
    # regex with three capture groups: (pre) - (version) - (post)
    string(REGEX MATCH "^(.*)-([0-9]+\\.[0-9]+\\.[0-9]+)-([^-]+)$" _ UNUSED "${ZIP_FILES}")
    
    # Get capture groups
    set(ARTIFACT_PREFIX "${CMAKE_MATCH_1}")
    set(ARTIFACT_VERSION "${CMAKE_MATCH_2}")
    set(ARTIFACT_SUFFIX "${CMAKE_MATCH_3}")
    
    message(STATUS "File name: ${ZIP_FILES}")
    
    message(STATUS "Prefix: ${ARTIFACT_PREFIX}")
    message(STATUS "Version: ${ARTIFACT_VERSION}")
    message(STATUS "Suffix: ${ARTIFACT_SUFFIX}")
    
    set(${ARTIFACT_NAME} "${ARTIFACT_PREFIX}" PARENT_SCOPE)
    set(${ARTIFACT_VERSION} "${ARTIFACT_VERSION}" PARENT_SCOPE)
    set(${ARTIFACT_OS_VERSION} "${ARTIFACT_SUFFIX}" PARENT_SCOPE)

endfunction(GetDownloadedArtifactDetails)


#------------------------------------------------------------------------------#
# Main function for artifacts handler module.
#------------------------------------------------------------------------------#
function(ArtifactsHandler_Main)

    # --- Precondition Step 1: Read path to the artifacts configuration file
    ArtifactsHandler_Get_ArtifactsConfigFile_Path(ARTIFACTS_CONFIG_FILE_PATH)
    
    # --- Precondition Step 2: Read Root repository URL
    ArtifactsHandler_Get_RootRepoURL("${ARTIFACTS_CONFIG_FILE_PATH}" ROOT_REPO_URL)
    
    # --- Step 1: Get list of required Artifacts
    ArtifactsHandler_Get_RequiredArtifactsList("${ARTIFACTS_CONFIG_FILE_PATH}" REQUIRED_ARTIFACTS_LIST)

    # --- Step 2: Detect OS version
    ArtifactsHandler_Get_OsVersion(OS_VERSION)

    # --- Step 3: Get ArtifactsCache path.
    ArtifactsHandler_Get_ArtifactsCachePath("${ARTIFACTS_CONFIG_FILE_PATH}" ARTIFACTS_CACHE_PATH)

    ArtifactsHandler_Get_OfflineModeState(OFFLINE_MODE_STATE)
    
    if(OFFLINE_MODE_STATE STREQUAL "FALSE")
        RootRepoHandler_Prepare("${OFFLINE_MODE_STATE}" "${ROOT_REPO_URL}" "${ARTIFACTS_HANDLER_ROOT_REPO_PATH}")
    endif()

    # --- Step 4: Loop through all required artifacts
    foreach(ARTIFACT_RECORD IN LISTS REQUIRED_ARTIFACTS_LIST)
    
        list(GET ARTIFACT_RECORD 0 ARTIFACT_NAME)
        list(GET ARTIFACT_RECORD 1 BINARY_VERSION)
        list(GET ARTIFACT_RECORD 2 CORE_VERSION)
    
        message(STATUS "--------------------------------------------------------------------------------")
        message(STATUS "Processing artifact ${ARTIFACT_NAME} with Bin version ${BINARY_VERSION} and Core version ${CORE_VERSION}.")
        message(STATUS "--------------------------------------------------------------------------------")

        # --- Step 5: Check if required artifact binary exist in cache with required version.
        ArtifactsHandler_Check_CachedArtifact_Core(${ARTIFACTS_CACHE_PATH}
                                                   ${ARTIFACT_NAME}
                                                   ${CORE_VERSION}
                                                   ARTIFACT_CORE_CACHE_STATE
                                                   CORE_CACHED_VERSION)
        set(API_STATE "FALSE")
        
        if(OFFLINE_MODE_STATE STREQUAL "FALSE")
            RootRepoHandler_Get_ApiAccess(${ARTIFACTS_HANDLER_TEMP_PATH} API_STATE)
        endif()

        if(NOT ARTIFACT_CORE_CACHE_STATE AND OFFLINE_MODE_STATE STREQUAL "FALSE" AND API_STATE STREQUAL "TRUE")
        
            message(DEBUG "Artifact ${ARTIFACT_NAME} is not available in chache folder.")
            
            # --- Step 6: Download artifact.
            RootRepoHandler_DownloadArtifact_Core(${ARTIFACTS_HANDLER_ROOT_REPO_PATH}
                                                  ${ARTIFACT_NAME}
                                                  ${CORE_VERSION}
                                                  CORE_ACTIVE_VERSION)
            
            ArtifactsHandler_InstallArtifact_Core(${ARTIFACTS_CACHE_PATH}
                                                  ${ARTIFACTS_HANDLER_ROOT_REPO_PATH}
                                                  ${ARTIFACT_NAME}
                                                  ${CORE_ACTIVE_VERSION})
        
        else()
            if(ARTIFACT_CORE_CACHE_STATE AND OFFLINE_MODE_STATE STREQUAL "TRUE")
                message(FATAL_ERROR "Artifact ${ARTIFACT_NAME} is not cached and OFFLINE mode is active.")
            elseif(API_STATE STREQUAL "FALSE")
                message(FATAL_ERROR "Connection API is not available right now.")
            else()
                set(CORE_ACTIVE_VERSION "${CORE_CACHED_VERSION}")
            endif()
        endif()
        
        # --- Step 5: Check if required artifact binary exist in cache with required version.
        CacheHandler_Check_CachedArtifact_Bin(${ARTIFACTS_CACHE_PATH}
                                              ${ARTIFACT_NAME}
                                              ${BINARY_VERSION}
                                              ARTIFACT_BIN_CACHE_STATE
                                              BIN_CACHED_VERSION)

        if(NOT ARTIFACT_BIN_CACHE_STATE AND OFFLINE_MODE_STATE STREQUAL "FALSE" AND API_STATE STREQUAL "TRUE")
        
            # --- Step 6: Download artifact.
            RootRepoHandler_DownloadArtifact_Bin(${ARTIFACTS_HANDLER_ROOT_REPO_PATH}
                                                 ${ARTIFACT_NAME}
                                                 ${BINARY_VERSION}
                                                 ${OS_VERSION}
                                                 ${ARTIFACTS_HANDLER_BIN_TEMP_PATH}
                                                 BIN_ACTIVE_VERSION)
            
            ArtifactsHandler_InstallArtifact_Bin(${ARTIFACTS_CACHE_PATH}
                                                 ${ARTIFACTS_HANDLER_BIN_TEMP_PATH}
                                                 ${ARTIFACT_NAME}
                                                 ${BIN_ACTIVE_VERSION})
            
        else()
            if(ARTIFACT_CORE_CACHE_STATE AND OFFLINE_MODE_STATE STREQUAL "TRUE")
                message(FATAL_ERROR "Artifact ${ARTIFACT_NAME} is not cached and OFFLINE mode is active.")
            elseif(API_STATE STREQUAL "FALSE")
                message(FATAL_ERROR "Connection API is not available right now.")
            else()
                set(BIN_ACTIVE_VERSION "${BIN_CACHED_VERSION}")
            endif()
        endif()
        
        # --- Step 7: Prepare artifact for build.
        CacheHandler_InitArtifact(${ARTIFACTS_CACHE_PATH}
                                  ${ARTIFACT_NAME}
                                  ${CORE_ACTIVE_VERSION}
                                  ${BIN_ACTIVE_VERSION})
        
        # --- Step 8: Check artifact version.                              
        CacheHandler_Get_ArtifactVersion(${ARTIFACT_NAME}
                                         DETECTED_VERSION)
    
        if(("${DETECTED_VERSION}" STREQUAL "${BINARY_VERSION}") OR 
           (("${BINARY_VERSION}" STREQUAL "latest") AND 
            (NOT "${DETECTED_VERSION}" STREQUAL "")))
            message(STATUS "Artifact ${ARTIFACT_NAME} installed with version: ${DETECTED_VERSION}")
        else()
            message(WARNING "Artifact ${ARTIFACT_NAME} installed with unknown version")
        endif()
    
    endforeach()

endfunction(ArtifactsHandler_Main)

#==============================================================================#
# Main functionality
#==============================================================================#

ArtifactsHandler_Main()
