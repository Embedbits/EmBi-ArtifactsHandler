###############################################################################
# Artifacts Root Repository temporary folder handler functionality
###############################################################################


#------------------------------------------------------------------------------#
# Function used to initialize git submodules in artifacts root repository.
#
# ROOT_REPO_PATH_ARG [in]: Path to the artifacts root repository directory
#------------------------------------------------------------------------------#
function(RootRepoHandler_UpdateSubmodules ROOT_REPO_PATH_ARG)

    message(STATUS "Updating artifacts submodules")

    # Get list of all items in folder (artifacts)
    file(GLOB GIT_ROOT_REPO_ITEMS "${ROOT_REPO_PATH_ARG}/*")
    
    # Initialize all git submodules
    foreach(SUBMODULE_DIR IN LISTS GIT_ROOT_REPO_ITEMS)
        
        get_filename_component(DIR_NAME "${SUBMODULE_DIR}" NAME)
        
        if(IS_DIRECTORY "${SUBMODULE_DIR}" AND NOT DIR_NAME STREQUAL ".git")
        
            if(NOT DIR_NAME MATCHES "^\\.")
            
                message(DEBUG "Artifact ${DIR_NAME} will be updated.")
                
                execute_process(COMMAND git submodule update --init --depth=1 --checkout --remote ${DIR_NAME}
                                WORKING_DIRECTORY "${ROOT_REPO_PATH_ARG}"
                                OUTPUT_QUIET
                                ERROR_QUIET)

            endif()
        endif()
    endforeach()
    
endfunction(RootRepoHandler_UpdateSubmodules)


#------------------------------------------------------------------------------#
# Function used to check, if the repo was checked today.
#
# REPO_PATH_ARG    [in]: Path to the repository to check fetch date
# FETCH_STATE_ARG [out]: State of fetch. If repo was already fetched within 
#                    timeframe, returns TRUE. Othervise returns FALSE.
#------------------------------------------------------------------------------#
function(RootRepoHandler_CheckLastUpdate REPO_PATH_ARG FETCH_STATE_ARG)

    # Get date of last FETCH_HEAD modification in format YYYY-MM-DD
    set(FETCH_HEAD_FILE "${REPO_PATH_ARG}/.git/FETCH_HEAD")
    set(HEAD_FILE "${REPO_PATH_ARG}/.git/HEAD")
    
    if(EXISTS "${FETCH_HEAD_FILE}")
        file(TIMESTAMP "${FETCH_HEAD_FILE}" LAST_UPDATE_DATE "%Y-%m-%d")
    elseif(EXISTS "${HEAD_FILE}")
        file(TIMESTAMP "${HEAD_FILE}" LAST_UPDATE_DATE "%Y-%m-%d")
    else()
        set(LAST_UPDATE_DATE "")
    endif()
    
    # Get actual date in format YYYY-MM-DD
    string(TIMESTAMP TODAY "%Y-%m-%d")
    
    # Compare dates
    if(NOT LAST_UPDATE_DATE STREQUAL TODAY)    
        set(${FETCH_STATE_ARG} "FALSE" PARENT_SCOPE)
    else()
        set(${FETCH_STATE_ARG} "TRUE" PARENT_SCOPE)
    endif()

endfunction(RootRepoHandler_CheckLastUpdate)


#------------------------------------------------------------------------------#
# Prepare local version of Artifactory Root Repository
#
# OFFLINE_MODE_STATE_ARG [in]: Offline mode (true/false)
# ROOT_REPO_URL_ARG      [in]: Artifacts root repository URL
# ROOT_REPO_PATH_ARG     [in]: Path to the Root repository temp location
#------------------------------------------------------------------------------#
function(RootRepoHandler_Prepare OFFLINE_MODE_STATE_ARG
                                 ROOT_REPO_URL_ARG
                                 ROOT_REPO_PATH_ARG)

    if(NOT EXISTS "${ROOT_REPO_PATH_ARG}/.git")
    
        # Artifacts root repository is not cloned. Clone repo (without submodules)
        message(STATUS "Cloning root repository (without submodules)...")
        execute_process(COMMAND git clone --depth=1 --recurse-submodules=no ${ROOT_REPO_URL_ARG} ${ROOT_REPO_PATH_ARG}
                        RESULT_VARIABLE CLONE_RES
                        OUTPUT_VARIABLE CLONE_OUT
                        ERROR_VARIABLE CLONE_ERR)

        if(NOT CLONE_RES EQUAL 0)
            message(WARNING "Git clone failed:\n${CLONE_OUT}\n${CLONE_ERR}")
        endif()
                        
        if(NOT CLONE_RES EQUAL 0)
            message(FATAL_ERROR "Failed to clone root repository.")
        else()
            RootRepoHandler_UpdateSubmodules(${ROOT_REPO_PATH_ARG})
        endif()
        
    else()
    
        # Chek, if artifact root repository was already updated today
        RootRepoHandler_CheckLastUpdate(${ROOT_REPO_PATH_ARG} UPDATE_STATUS)
        
        if(NOT UPDATE_STATUS)
        
            message(STATUS "Updating artifacts root repository.")
            
            execute_process(COMMAND git fetch --no-recurse-submodules --depth=1 origin
                            WORKING_DIRECTORY "${ROOT_REPO_PATH_ARG}"
                            RESULT_VARIABLE FETCH_RES
                            OUTPUT_VARIABLE FETCH_OUT
                            ERROR_VARIABLE FETCH_ERR)
                            
            if(NOT FETCH_RES EQUAL 0)
                message(WARNING "Git fetch failed:\n${FETCH_OUT}\n${FETCH_ERR}")
            endif()
                            
            execute_process(COMMAND git pull --no-recurse-submodules origin
                            WORKING_DIRECTORY "${ROOT_REPO_PATH_ARG}"
                            RESULT_VARIABLE PULL_RES
                            OUTPUT_VARIABLE PULL_OUT
                            ERROR_VARIABLE PULL_ERR)

            if(NOT PULL_RES EQUAL 0)
                message(WARNING "Git pull failed:\n${PULL_OUT}\n${PULL_ERR}")
            endif()
                            
            RootRepoHandler_UpdateSubmodules(${ROOT_REPO_PATH_ARG})
        
        else()
            message(DEBUG "Artifacts Source Root repository will not be updated.")
        endif() 
        
    endif()

endfunction(RootRepoHandler_Prepare)


#------------------------------------------------------------------------------#
# Checks, if the Bin branch already directly contains the required zip
# archive at the currently checked-out commit (i.e. the archive is committed
# in the repository itself, not only published as a GitHub release asset).
#
# If found, the archive is copied to the Bin temp folder under the same path
# a downloaded release asset would use, so the rest of the flow (Install_Bin)
# does not need to know where the file came from.
#
# SUBMODULE_DIR_ARG    [in]: Path to the checked-out artifact submodule
# ARTIFACT_NAME_ARG    [in]: Name of the artifact being processed
# TEMP_FOLDER_PATH_ARG [in]: Path to the Bin temp folder
# FOUND_LOCAL_ZIP_ARG [out]: TRUE if a local zip archive was found (and
#                            copied), otherwise FALSE
#------------------------------------------------------------------------------#
function(RootRepoHandler_Get_LocalBinZip SUBMODULE_DIR_ARG
                                         ARTIFACT_NAME_ARG
                                         TEMP_FOLDER_PATH_ARG
                                         FOUND_LOCAL_ZIP_ARG)

    set(${FOUND_LOCAL_ZIP_ARG} "FALSE" PARENT_SCOPE)

    # Get list of all archives directly in the checked-out submodule folder
    file(GLOB LOCAL_ZIP_FILES "${SUBMODULE_DIR_ARG}/*.zip")

    if(NOT LOCAL_ZIP_FILES)
        message(DEBUG "Bin branch does not directly contain a zip archive, release asset will be used.")
        return()
    endif()

    list(GET LOCAL_ZIP_FILES 0 LOCAL_ZIP_FILE)

    get_filename_component(LOCAL_ZIP_NAME "${LOCAL_ZIP_FILE}" NAME)

    set(ARTIFACT_DOWNLOAD_PATH "${TEMP_FOLDER_PATH_ARG}/${ARTIFACT_NAME_ARG}")
    file(MAKE_DIRECTORY "${ARTIFACT_DOWNLOAD_PATH}")

    if(NOT EXISTS "${ARTIFACT_DOWNLOAD_PATH}/${LOCAL_ZIP_NAME}")
        file(COPY "${LOCAL_ZIP_FILE}" DESTINATION "${ARTIFACT_DOWNLOAD_PATH}")
    endif()

    message(STATUS "Zip archive '${LOCAL_ZIP_NAME}' found directly in Bin branch, release asset download skipped.")

    set(${FOUND_LOCAL_ZIP_ARG} "TRUE" PARENT_SCOPE)

endfunction(RootRepoHandler_Get_LocalBinZip)


#------------------------------------------------------------------------------#
# The binary part of the artifact shall be downloaded to the temporary location.
#
# ROOT_REPO_PATH_ARG                [in]: Path to the Root repository temp location
# ARTIFACT_NAME_ARG                 [in]: Name of the artifact to be processed
# ARTIFACT_BIN_VERSION_ARG          [in]: Required version of artifact binary
# ARTIFACT_OS_ARG                   [in]: Required OS type of the artifact binary
# TEMP_FOLDER_PATH_ARG              [in]: Path to the temporary folder
# ARTIFACT_CORE_VERSION_ACTIVE_ARG [out]: Found the artifact core version
#------------------------------------------------------------------------------#
function(RootRepoHandler_DownloadArtifact_Bin ROOT_REPO_PATH_ARG
                                              ARTIFACT_NAME_ARG
                                              ARTIFACT_BIN_VERSION_ARG
                                              ARTIFACT_OS_ARG
                                              TEMP_FOLDER_PATH_ARG
                                              ARTIFACT_BIN_VERSION_ACTIVE_ARG)

    set(BRANCH_NAME "Bin")
    
    RootRepoHandler_Get_ArtifactFolderName(${ROOT_REPO_PATH_ARG}
                                           ${ARTIFACT_NAME_ARG}
                                           ARTIFACT_FOUND_NAME)
    
    set(SUBMODULE_DIR "${ROOT_REPO_PATH_ARG}/${ARTIFACT_FOUND_NAME}")
    
    set(REQUIRED_VERSION "${ARTIFACT_BIN_VERSION_ARG}")

    execute_process(COMMAND git fetch --filter=blob:none origin ${BRANCH_NAME}
                    WORKING_DIRECTORY "${SUBMODULE_DIR}"
                    RESULT_VARIABLE GIT_FETCH_RESULT
                    OUTPUT_QUIET
                    ERROR_QUIET)
                    
    if(NOT GIT_FETCH_RESULT EQUAL 0)
        message(FATAL_ERROR "Git fetch failed on branch ${BRANCH_NAME_ARG}")
    endif()
                    
    execute_process(COMMAND git log FETCH_HEAD --pretty=format:%H||%s
                    OUTPUT_VARIABLE GIT_LOG_OUTPUT
                    RESULT_VARIABLE GIT_LOG_RESULT
                    WORKING_DIRECTORY "${SUBMODULE_DIR}"
                    ERROR_QUIET)
                    
    if(NOT GIT_LOG_RESULT EQUAL 0)
        message(FATAL_ERROR "Command Git log failed.")
    endif()
    
    # Separate list to rows
    string(REPLACE "\n" ";" COMMIT_LINES "${GIT_LOG_OUTPUT}")

    # Prvy prechod: zisti, ci nejaky commit na tomto branchi vobec spomina OS.
    # Ak ano, artefakt je OS-dependent a OS filter sa vynuti. Ak nie, artefakt
    # je OS-independent a filter sa preskoci uplne.
    set(BIN_IS_OS_DEPENDENT FALSE)
    foreach(LINE ${COMMIT_LINES})
        string(REPLACE "||" ";" LINE_PARTS "${LINE}")
        list(GET LINE_PARTS 1 COMMIT_MESSAGE)
        if(COMMIT_MESSAGE MATCHES "(${ARTIFACTS_HANDLER_OS_WIN}|${ARTIFACTS_HANDLER_OS_UNIX}|${ARTIFACTS_HANDLER_OS_MAC})")
            set(BIN_IS_OS_DEPENDENT TRUE)
            break()
        endif()
    endforeach()

    set(FOUND_COMMIT_HASH "")
    
    foreach(LINE ${COMMIT_LINES})
        # Separate hash and commit message by "||"
        string(REPLACE "||" ";" LINE_PARTS "${LINE}")
        list(GET LINE_PARTS 0 COMMIT_HASH)
        list(GET LINE_PARTS 1 COMMIT_MESSAGE)
    
        # OS filter - vynuti sa len pre artefakty, ktore OS naozaj rozlisuju
        if(BIN_IS_OS_DEPENDENT AND NOT COMMIT_MESSAGE MATCHES "${ARTIFACT_OS_ARG}")
            continue()
        endif()
    
        if(NOT COMMIT_MESSAGE MATCHES "([0-9]+\\.[0-9]+\\.[0-9]+)")
            continue()
        endif()
        set(COMMIT_VERSION "${CMAKE_MATCH_1}")
        
        message(DEBUG "Adding version ${COMMIT_VERSION} to the available list.")
    
        list(APPEND MATCHING_COMMITS "${COMMIT_HASH}|${COMMIT_VERSION}")
    endforeach()
    
    if(MATCHING_COMMITS STREQUAL "")
        message(FATAL_ERROR "No commit found for OS version ${ARTIFACT_OS_ARG} in branch ${BRANCH_NAME_ARG}")
    endif()
    
    
    set(TARGET_HASH "")
    set(TARGET_VERSION "")
    
    # Process releases to find latest version
    if("${ARTIFACT_BIN_VERSION_ARG}" STREQUAL "latest")

        set(BEST_HASH "")
        set(BEST_VERSION "")
        
        foreach(ENTRY ${MATCHING_COMMITS})
            string(REPLACE "|" ";" ENTRY_PARTS "${ENTRY}")
            list(GET ENTRY_PARTS 0 ENTRY_HASH)
            list(GET ENTRY_PARTS 1 ENTRY_VERSION)
        
            if(BEST_VERSION STREQUAL "" OR ENTRY_VERSION VERSION_GREATER BEST_VERSION)
                set(BEST_VERSION "${ENTRY_VERSION}")
                set(BEST_HASH "${ENTRY_HASH}")
            endif()
        endforeach()
        
        set(TARGET_HASH ${BEST_HASH})
        set(TARGET_VERSION ${BEST_VERSION})
        
    else()
        # User selected exact version
        foreach(ENTRY ${MATCHING_COMMITS})
            string(REPLACE "|" ";" ENTRY_PARTS "${ENTRY}")
            list(GET ENTRY_PARTS 0 ENTRY_HASH)
            list(GET ENTRY_PARTS 1 ENTRY_VERSION)
        
            if(ENTRY_VERSION VERSION_EQUAL ARTIFACT_BIN_VERSION_ARG)
                set(TARGET_HASH "${ENTRY_HASH}")
                set(TARGET_VERSION "${ENTRY_VERSION}")
                break()
            endif()
        endforeach()
        
        if(TARGET_HASH STREQUAL "")
            message(FATAL_ERROR "Version ${TARGET_VERSION} not found")
        endif()
    endif()
    
    message(STATUS "The version ${TARGET_VERSION} of artifacts Bin part will be used.")

    # Checkout na nájdený commit
    execute_process(COMMAND git checkout ${TARGET_HASH}
                    WORKING_DIRECTORY "${SUBMODULE_DIR}"
                    RESULT_VARIABLE GIT_CHECKOUT_RESULT
                    OUTPUT_QUIET
                    ERROR_QUIET)
                    
    if(NOT GIT_CHECKOUT_RESULT EQUAL 0)
        message(FATAL_ERROR "Checkout to ${FOUND_COMMIT_HASH} failed")
    else()
        set(${ARTIFACT_BIN_VERSION_ACTIVE_ARG} ${TARGET_VERSION} PARENT_SCOPE)
        message(DEBUG "Switched to artifact Bin version ${TARGET_VERSION}")
    endif()
    
    RootRepoHandler_DownloadBin(${ROOT_REPO_PATH_ARG}
                                ${ARTIFACT_NAME_ARG}
                                ${TARGET_HASH}
                                ${TEMP_FOLDER_PATH_ARG}
                                ${ARTIFACT_OS_ARG})

endfunction(RootRepoHandler_DownloadArtifact_Bin)


#------------------------------------------------------------------------------#
# The binary part of the artifact shall be downloaded to the temporary location.
#
# ROOT_REPO_PATH_ARG                [in]: Path to the Root repository temp location
# ARTIFACT_NAME_ARG                 [in]: Name of the artifact to be processed
# ARTIFACT_CORE_VERSION_ARG         [in]: Required version of artifact core
# ARTIFACT_CORE_VERSION_ACTIVE_ARG [out]: Found the artifact core version
#------------------------------------------------------------------------------#
function(RootRepoHandler_DownloadArtifact_Core ROOT_REPO_PATH_ARG 
                                               ARTIFACT_NAME_ARG
                                               ARTIFACT_CORE_VERSION_ARG
                                               ARTIFACT_CORE_VERSION_ACTIVE_ARG)

    set(BRANCH_NAME "Core")
    
    RootRepoHandler_Get_ArtifactFolderName(${ROOT_REPO_PATH_ARG}
                                           ${ARTIFACT_NAME_ARG}
                                           ARTIFACT_FOUND_NAME)
                                           
    set(REQUIRED_VERSION "${ARTIFACT_CORE_VERSION_ARG}")
    
    set(SUBMODULE_DIR "${ROOT_REPO_PATH_ARG}/${ARTIFACT_FOUND_NAME}")

    execute_process(COMMAND git fetch --filter=blob:none origin ${BRANCH_NAME}
                    WORKING_DIRECTORY "${SUBMODULE_DIR}"
                    RESULT_VARIABLE GIT_FETCH_RESULT
                    OUTPUT_QUIET
                    ERROR_QUIET)
                    
    if(NOT GIT_FETCH_RESULT EQUAL 0)
        message(FATAL_ERROR "Git fetch failed on branch ${BRANCH_NAME} in ${SUBMODULE_DIR}.")
    endif()
                    
    execute_process(COMMAND git log FETCH_HEAD --pretty=format:%H||%s
                    OUTPUT_VARIABLE GIT_LOG_OUTPUT
                    RESULT_VARIABLE GIT_LOG_RESULT
                    WORKING_DIRECTORY "${SUBMODULE_DIR}"
                    ERROR_QUIET)
                    
    if(NOT GIT_LOG_RESULT EQUAL 0)
        message(FATAL_ERROR "Command Git log failed.")
    endif()
    
    # Separate list to rows
    string(REPLACE "\n" ";" COMMIT_LINES "${GIT_LOG_OUTPUT}")
    
    set(FOUND_COMMIT_HASH "")
    
    foreach(LINE ${COMMIT_LINES})
        # Separate hash and commit message by "||"
        string(REPLACE "||" ";" LINE_PARTS "${LINE}")
        list(GET LINE_PARTS 0 COMMIT_HASH)
        list(GET LINE_PARTS 1 COMMIT_MESSAGE)
    
        if(NOT COMMIT_MESSAGE MATCHES "([0-9]+\\.[0-9]+\\.[0-9]+)")
            continue()
        endif()
        set(COMMIT_VERSION "${CMAKE_MATCH_1}")
        
        message(DEBUG "Adding version ${COMMIT_VERSION} to the available list.")
    
        list(APPEND MATCHING_COMMITS "${COMMIT_HASH}|${COMMIT_VERSION}")
    endforeach()
    
    if(MATCHING_COMMITS STREQUAL "")
        message(FATAL_ERROR "No commit found for OS version ${ARTIFACT_OS_ARG} in branch ${BRANCH_NAME_ARG}")
    endif()
    
    
    set(TARGET_HASH "")
    set(TARGET_VERSION "")
    
    # Process releases to find latest version
    if("${ARTIFACT_CORE_VERSION_ARG}" STREQUAL "latest")

        set(BEST_HASH "")
        set(BEST_VERSION "")
        
        foreach(ENTRY ${MATCHING_COMMITS})
            string(REPLACE "|" ";" ENTRY_PARTS "${ENTRY}")
            list(GET ENTRY_PARTS 0 ENTRY_HASH)
            list(GET ENTRY_PARTS 1 ENTRY_VERSION)
        
            if(BEST_VERSION STREQUAL "" OR ENTRY_VERSION VERSION_GREATER BEST_VERSION)
                set(BEST_VERSION "${ENTRY_VERSION}")
                set(BEST_HASH "${ENTRY_HASH}")
            endif()
        endforeach()
        
        set(TARGET_HASH ${BEST_HASH})
        set(TARGET_VERSION ${BEST_VERSION})
        
    else()
        # User selected exact version
        foreach(ENTRY ${MATCHING_COMMITS})
            string(REPLACE "|" ";" ENTRY_PARTS "${ENTRY}")
            list(GET ENTRY_PARTS 0 ENTRY_HASH)
            list(GET ENTRY_PARTS 1 ENTRY_VERSION)
        
            if(ENTRY_VERSION VERSION_EQUAL ARTIFACT_CORE_VERSION_ARG)
                set(TARGET_HASH "${ENTRY_HASH}")
                set(TARGET_VERSION ${ENTRY_VERSION})
                break()
            endif()
        endforeach()
        
        if(TARGET_HASH STREQUAL "")
            message(FATAL_ERROR "Version ${TARGET_VERSION} not found")
        endif()
    endif()
    
    message(STATUS "The version ${TARGET_VERSION} of artifacts Core part will be used.")

    # Checkout to found commit
    execute_process(COMMAND git checkout ${TARGET_HASH}
                    WORKING_DIRECTORY "${SUBMODULE_DIR}"
                    RESULT_VARIABLE GIT_CHECKOUT_RESULT
                    OUTPUT_QUIET
                    ERROR_QUIET)
                    
    if(NOT GIT_CHECKOUT_RESULT EQUAL 0)
        message(FATAL_ERROR "Checkout to ${FOUND_COMMIT_HASH} failed")
    else()
        set(${ARTIFACT_CORE_VERSION_ACTIVE_ARG} ${TARGET_VERSION} PARENT_SCOPE)
        message(DEBUG "Switched to artifact Core version: ${TARGET_VERSION}")
    endif()

endfunction(RootRepoHandler_DownloadArtifact_Core)


#------------------------------------------------------------------------------#
# Check, if the Github API is available or neither.
#
# TEMP_FOLDER_PATH_ARG [in]: Path to the temporary folder
# OUT_ACCESSIBLE_ARG  [out]: FALSE if the API is not accessible, otherwise TRUE
#------------------------------------------------------------------------------#
function(RootRepoHandler_Get_ApiAccess TEMP_FOLDER_PATH_ARG
                                       OUT_ACCESSIBLE_ARG)

    set(RATE_LIMIT_FILE "${TEMP_FOLDER_PATH_ARG}/rate_limit.json")

    file(DOWNLOAD "https://api.github.com/rate_limit" "${RATE_LIMIT_FILE}"
        HTTPHEADER "Accept: application/vnd.github+json"
        STATUS DOWNLOAD_STATUS)
        
    list(GET DOWNLOAD_STATUS 0 STATUS_CODE)
    
    if(NOT STATUS_CODE EQUAL 0)
        list(GET DOWNLOAD_STATUS 1 STATUS_MESSAGE)
        message(WARNING "Failed to check GitHub API rate limit: ${STATUS_MESSAGE}")
        set(${OUT_ACCESSIBLE_ARG} "FALSE" PARENT_SCOPE)
        return()
    endif()

    file(READ "${RATE_LIMIT_FILE}" RATE_LIMIT_JSON)
    string(JSON REMAINING GET "${RATE_LIMIT_JSON}" "resources" "core" "remaining")
    string(JSON RESET_EPOCH GET "${RATE_LIMIT_JSON}" "resources" "core" "reset")

    if(REMAINING GREATER 0)
        message(DEBUG "GitHub API is available, there is ${REMAINING} remaining requests")
        set(${OUT_ACCESSIBLE_ARG} "TRUE" PARENT_SCOPE)
        return()
    endif()

    # There is no free limit - calculate timestamp to real time format
    string(TIMESTAMP CURRENT_EPOCH "%s" UTC)
    math(EXPR SECONDS_REMAINING "${RESET_EPOCH} - ${CURRENT_EPOCH}")
    math(EXPR MINUTES_REMAINING "${SECONDS_REMAINING} / 60")

    
    message(WARNING "GitHub API rate limit is done. It will be reset in ${MINUTES_REMAINING} min")

    set(${OUT_ACCESSIBLE_ARG} "FALSE" PARENT_SCOPE)
    
endfunction()


#------------------------------------------------------------------------------#
# The binary part of the artifact shall be downloaded to the temporary location.
#
# ROOT_REPO_PATH_ARG   [in]: Path to the Root repository temp location
# ARTIFACT_NAME_ARG    [in]: Name of the artifact to be processed
# COMMIT_HASH_ARG      [in]: Hash of commit connected to the release
# TEMP_FOLDER_PATH_ARG [in]: Path to the temporary folder
#------------------------------------------------------------------------------#
function(RootRepoHandler_DownloadBin ROOT_REPO_PATH_ARG 
                                     ARTIFACT_NAME_ARG
                                     COMMIT_HASH_ARG
                                     TEMP_FOLDER_PATH_ARG
                                     ARTIFACT_OS_ARG)
                                     
    set(ARTIFACT_DOWNLOAD_PATH "${TEMP_FOLDER_PATH_ARG}/${ARTIFACT_NAME_ARG}")
    
    set(ASSET_PATTERN ".zip")
                                     
    RootRepoHandler_Get_ArtifactFolderName(${ROOT_REPO_PATH_ARG}
                                           ${ARTIFACT_NAME_ARG}
                                           ARTIFACT_FOUND_NAME)
    
    # Get Github repository and owner
    RootRepoHandler_Get_GithubOwnerRepo("${ROOT_REPO_PATH_ARG}/${ARTIFACT_FOUND_NAME}" 
                                        GITHUB_OWNER
                                        GITHUB_REPO)
                                        
    message(DEBUG "Owner: ${GITHUB_OWNER}, Repo: ${GITHUB_REPO}")
    
    set(RELEASES_CACHE_FILE_PATH "${TEMP_FOLDER_PATH_ARG}/${ARTIFACT_NAME_ARG}/releases.json")
    set(TAGS_CACHE_FILE_PATH "${TEMP_FOLDER_PATH_ARG}/${ARTIFACT_NAME_ARG}/tags.json")
    
    RootRepoHandler_Get_PaginatedGithubList("${GITHUB_OWNER}" 
                                            "${GITHUB_REPO}" 
                                            "releases" 
                                            "${TEMP_FOLDER_PATH_ARG}" 
                                            "${RELEASES_CACHE_FILE_PATH}")
                                            
    RootRepoHandler_Get_PaginatedGithubList("${GITHUB_OWNER}" 
                                            "${GITHUB_REPO}" 
                                            "tags" 
                                            "${TEMP_FOLDER_PATH_ARG}" 
                                            "${TAGS_CACHE_FILE_PATH}")
    
    RootRepoHandler_Get_VersionTag("${TAGS_CACHE_FILE_PATH}" 
                                   "${REQUIRED_VERSION}" 
                                   "${ARTIFACT_OS_ARG}"
                                   FOUND_TAG_NAME 
                                   FOUND_TAG_NAME_SHA)
    
    if(FOUND_TAG_NAME STREQUAL "")
        message(FATAL_ERROR "No tag found for commit ${COMMIT_HASH}")
    else()
        message(DEBUG "Tag found: ${FOUND_TAG_NAME}")
    endif()
    
    
    RootRepoHandler_Get_ReleaseIndexTag("${RELEASES_CACHE_FILE_PATH}" 
                                        "${FOUND_TAG_NAME}"
                                        "${ASSET_PATTERN}"
                                        RELEASE_INDEX
                                        FOUND_ASSET_NAME)
    
    if(RELEASE_INDEX EQUAL -1)
        message(FATAL_ERROR "No release found for tag ${FOUND_TAG_NAME}")
    endif()
    
    message(DEBUG "Release found on index: ${RELEASE_INDEX}")
    
    set(ASSET_PATH "${ARTIFACT_DOWNLOAD_PATH}/${FOUND_ASSET_NAME}")
    
    if(NOT EXISTS "${ASSET_PATH}")
    
        RootRepoHandler_Download_ReleaseAsset("${RELEASES_CACHE_FILE_PATH}" 
                                              "${RELEASE_INDEX}"
                                              "${ASSET_PATTERN}" 
                                              "${ARTIFACT_DOWNLOAD_PATH}/" 
                                              DOWNLOADED_ASSET_PATH)
    
        message(DEBUG "File downloaded to: ${DOWNLOADED_ASSET_PATH}")
        
    else()
        message(DEBUG "File ${FOUND_ASSET_NAME} already downloaded.")
    endif()
    
endfunction()


# ==============================================================================
# Returns github owner and repository from submodule remote URL 
#
# SUBMODULE_DIR_ARG [in]: Path to the git submodule
# OUT_OWNER_ARG    [out]: Owner name
# OUT_REPO_ARG     [out]: Repository name
# ==============================================================================
function(RootRepoHandler_Get_GithubOwnerRepo SUBMODULE_DIR_ARG 
                                             OUT_OWNER_ARG
                                             OUT_REPO_ARG)
                                             
    execute_process(COMMAND git config --get remote.origin.url
                    WORKING_DIRECTORY "${SUBMODULE_DIR_ARG}"
                    OUTPUT_VARIABLE REMOTE_URL
                    OUTPUT_STRIP_TRAILING_WHITESPACE
                    RESULT_VARIABLE GIT_RESULT)
                    
    if(NOT GIT_RESULT EQUAL 0)
        message(FATAL_ERROR "The URL in ${SUBMODULE_DIR_ARG} submodule not found.")
    endif()

    if(REMOTE_URL MATCHES "github\\.com[:/]([^/]+)/([^/.]+)(\\.git)?$")
        set(${OUT_OWNER_ARG} "${CMAKE_MATCH_1}" PARENT_SCOPE)
        set(${OUT_REPO_ARG} "${CMAKE_MATCH_2}" PARENT_SCOPE)
    else()
        message(FATAL_ERROR "Parsing owner/repo from URL: ${REMOTE_URL} failed")
    endif()
endfunction()


# ==============================================================================
# Download paging list from GitHub API to single file
# ==============================================================================
function(RootRepoHandler_Get_PaginatedGithubList REPO_OWNER_ARG
                                                 REPO_NAME_ARG
                                                 API_PATH
                                                 BIN_TEMP_PATH_ARG
                                                 OUTPUT_FILE_ARG)
    file(MAKE_DIRECTORY "${BIN_TEMP_PATH_ARG}")

    if(EXISTS "${OUTPUT_FILE_ARG}")
        file(TIMESTAMP "${OUTPUT_FILE_ARG}" FILE_MODIFIED_EPOCH "%s")
        string(TIMESTAMP CURRENT_EPOCH "%s" UTC)

        math(EXPR FILE_AGE_SECONDS "${CURRENT_EPOCH} - ${FILE_MODIFIED_EPOCH}")
        set(CACHE_MAX_AGE_SECONDS 3600)

        if(FILE_AGE_SECONDS LESS CACHE_MAX_AGE_SECONDS)
            message(STATUS "Cache file already exist, no new download will be executed: ${OUTPUT_FILE_ARG}")
            return()
        endif()

        message(STATUS "Cache file is older than 1 hour (${FILE_AGE_SECONDS}s), refreshing: ${OUTPUT_FILE_ARG}")
        file(REMOVE "${OUTPUT_FILE_ARG}")
    endif()

    set(COMBINED_JSON "[]")
    set(COMBINED_LENGTH 0)
    set(PAGE 1)

    while(TRUE)
        set(PAGE_FILE "${BIN_TEMP_PATH_ARG}/page_${PAGE}.json")

        file(DOWNLOAD "https://api.github.com/repos/${REPO_OWNER_ARG}/${REPO_NAME_ARG}/${API_PATH}?per_page=10000&page=${PAGE}" "${PAGE_FILE}"
             HTTPHEADER "Accept: application/vnd.github+json"
             STATUS DOWNLOAD_STATUS)

        list(GET DOWNLOAD_STATUS 0 STATUS_CODE)

        if(NOT STATUS_CODE EQUAL 0)
            list(GET DOWNLOAD_STATUS 1 STATUS_MESSAGE)
            message(FATAL_ERROR "Downloading ${API_PATH} (page ${PAGE}) failed: ${STATUS_MESSAGE}")
        endif()

        file(READ "${PAGE_FILE}" PAGE_JSON)

        string(JSON PAGE_COUNT LENGTH "${PAGE_JSON}")

        file(REMOVE "${PAGE_FILE}")

        if(PAGE_COUNT EQUAL 0)
            break()
        endif()

        math(EXPR PAGE_LAST_INDEX "${PAGE_COUNT} - 1")
        foreach(I RANGE ${PAGE_LAST_INDEX})
            string(JSON ITEM GET "${PAGE_JSON}" ${I})
            string(JSON COMBINED_JSON SET "${COMBINED_JSON}" ${COMBINED_LENGTH} "${ITEM}")
            math(EXPR COMBINED_LENGTH "${COMBINED_LENGTH} + 1")
        endforeach()

        if(PAGE_COUNT LESS 100)
            break()
        endif()
        math(EXPR PAGE "${PAGE} + 1")
    endwhile()

    file(WRITE "${OUTPUT_FILE_ARG}" "${COMBINED_JSON}")
    message(DEBUG "Stored: ${OUTPUT_FILE_ARG} (${COMBINED_LENGTH} records)")

endfunction()


# ==============================================================================
# 4. Nájdenie tagu, ktorý ukazuje na daný commit (z lokálneho tags cache súboru)
# ==============================================================================
function(RootRepoHandler_Get_TagForCommit TAGS_FILE 
                                          COMMIT_HASH 
                                          OUT_TAG)
                                          
    file(READ "${TAGS_FILE}" TAGS_JSON)
    string(JSON TAG_COUNT LENGTH "${TAGS_JSON}")

    set(${OUT_TAG} "" PARENT_SCOPE)
    if(TAG_COUNT EQUAL 0)
        return()
    endif()

    math(EXPR LAST_INDEX "${TAG_COUNT} - 1")
    foreach(I RANGE ${LAST_INDEX})
        string(JSON TAG_SHA GET "${TAGS_JSON}" ${I} "commit" "sha")
        if(TAG_SHA STREQUAL COMMIT_HASH)
            string(JSON TAG_NAME GET "${TAGS_JSON}" ${I} "name")
            set(${OUT_TAG} "${TAG_NAME}" PARENT_SCOPE)
            return()
        endif()
    endforeach()
endfunction()


#------------------------------------------------------------------------------#
# Finds Release index for given tag, and locates a matching asset within it.
#
# RELEASES_FILE_PATH      [in]: Path to cached releases.json.
# TAG_NAME_ARG            [in]: Tag name to search for.
# ASSET_NAME_PATTERN_ARG  [in]: Regex pattern to match against asset names.
# OUT_RELEASE_INDEX_ARG  [out]: Index of the found release (-1 if not found).
# OUT_ASSET_NAME_ARG     [out]: Name of the matching asset file (empty if not found).
#------------------------------------------------------------------------------#
function(RootRepoHandler_Get_ReleaseIndexTag RELEASES_FILE_PATH
                                             TAG_NAME_ARG
                                             ASSET_NAME_PATTERN_ARG
                                             OUT_RELEASE_INDEX_ARG
                                             OUT_ASSET_NAME_ARG)

    file(READ "${RELEASES_FILE_PATH}" RELEASES_JSON)
    string(JSON RELEASE_COUNT LENGTH "${RELEASES_JSON}")

    set(${OUT_RELEASE_INDEX_ARG} -1 PARENT_SCOPE)
    set(${OUT_ASSET_NAME_ARG} "" PARENT_SCOPE)

    if(RELEASE_COUNT EQUAL 0)
        return()
    endif()

    math(EXPR LAST_INDEX "${RELEASE_COUNT} - 1")
    foreach(I RANGE ${LAST_INDEX})
        string(JSON RELEASE_TAG GET "${RELEASES_JSON}" ${I} "tag_name")
        if(RELEASE_TAG STREQUAL TAG_NAME_ARG)
            set(${OUT_RELEASE_INDEX_ARG} ${I} PARENT_SCOPE)

            # Prehľadaj assets tohto release-u a nájdi ten, ktorý zodpovedá vzoru
            string(JSON ASSET_COUNT LENGTH "${RELEASES_JSON}" ${I} "assets")
            if(ASSET_COUNT GREATER 0)
                math(EXPR ASSET_LAST_INDEX "${ASSET_COUNT} - 1")
                foreach(J RANGE ${ASSET_LAST_INDEX})
                    string(JSON ASSET_NAME GET "${RELEASES_JSON}" ${I} "assets" ${J} "name")
                    if(ASSET_NAME MATCHES "${ASSET_NAME_PATTERN_ARG}")
                        set(${OUT_ASSET_NAME_ARG} "${ASSET_NAME}" PARENT_SCOPE)
                        return()
                    endif()
                endforeach()
            endif()

            return()
        endif()
    endforeach()

endfunction()


#------------------------------------------------------------------------------#
# Finds Git Tag for required version and OS
#
# TAGS_FILE_PATH_ARG        [in]: Path to the JSON file with tag list
# REQUIRED_VERSION_ARG      [in]: Required artifact version ("latest" or exact version)
# ARTIFACT_OS_ARG           [in]: OS/platform suffix to filter tags by (e.g. Unix, Win, DarwinARM)
# OUT_TAG_NAME_ARG         [out]: Name of the found tag
# OUT_TAG_SHA_ARG          [out]: Commit SHA of the found tag
#------------------------------------------------------------------------------#
function(RootRepoHandler_Get_VersionTag TAGS_FILE_PATH_ARG
                                         REQUIRED_VERSION_ARG
                                         ARTIFACT_OS_ARG
                                         OUT_TAG_NAME_ARG
                                         OUT_TAG_SHA_ARG)

    file(READ "${TAGS_FILE_PATH_ARG}" TAGS_JSON)
    string(JSON TAG_COUNT LENGTH "${TAGS_JSON}")

    set(${OUT_TAG_NAME_ARG} "" PARENT_SCOPE)
    set(${OUT_TAG_SHA_ARG} "" PARENT_SCOPE)

    if(TAG_COUNT EQUAL 0)
        message(DEBUG "No tags found in ${TAGS_FILE_PATH_ARG}")
        return()
    endif()

    math(EXPR LAST_INDEX "${TAG_COUNT} - 1")

    # Zisti, ci je artefakt OS-dependent vobec - ak ma HOCIJEDEN tag OS suffix,
    # berieme cely artefakt ako OS-dependent a vyzadujeme presnu zhodu OS.
    # Len ak ZIADEN tag OS suffix nema, akceptujeme "holé" X.Y.Z tagy.
    set(ARTIFACT_IS_OS_DEPENDENT FALSE)
    foreach(I RANGE ${LAST_INDEX})
        string(JSON T_NAME GET "${TAGS_JSON}" ${I} "name")
        if(T_NAME MATCHES "[0-9]+\\.[0-9]+\\.[0-9]+-(${ARTIFACTS_HANDLER_OS_WIN}|${ARTIFACTS_HANDLER_OS_UNIX}|${ARTIFACTS_HANDLER_OS_MAC})$")
            set(ARTIFACT_IS_OS_DEPENDENT TRUE)
            break()
        endif()
    endforeach()

    if(ARTIFACT_IS_OS_DEPENDENT)
        set(VERSION_PATTERN "([0-9]+\\.[0-9]+\\.[0-9]+)-${ARTIFACT_OS_ARG}$")
    else()
        set(VERSION_PATTERN "([0-9]+\\.[0-9]+\\.[0-9]+)$")
    endif()

    if(REQUIRED_VERSION_ARG STREQUAL "latest")
        set(BEST_VERSION "")
        set(BEST_NAME "")
        set(BEST_SHA "")

        foreach(I RANGE ${LAST_INDEX})
            string(JSON T_NAME GET "${TAGS_JSON}" ${I} "name")

            if(T_NAME MATCHES "${VERSION_PATTERN}")
                set(T_VERSION "${CMAKE_MATCH_1}")

                if(BEST_VERSION STREQUAL "" OR T_VERSION VERSION_GREATER BEST_VERSION)
                    set(BEST_VERSION "${T_VERSION}")
                    set(BEST_NAME "${T_NAME}")
                    string(JSON BEST_SHA GET "${TAGS_JSON}" ${I} "commit" "sha")
                endif()
            endif()
        endforeach()

        if(NOT BEST_NAME STREQUAL "")
            set(${OUT_TAG_NAME_ARG} "${BEST_NAME}" PARENT_SCOPE)
            set(${OUT_TAG_SHA_ARG} "${BEST_SHA}" PARENT_SCOPE)
        endif()
        return()
    endif()

    foreach(I RANGE ${LAST_INDEX})
        string(JSON T_NAME GET "${TAGS_JSON}" ${I} "name")

        if(T_NAME MATCHES "${VERSION_PATTERN}")
            set(T_VERSION "${CMAKE_MATCH_1}")
            if(T_VERSION VERSION_EQUAL REQUIRED_VERSION_ARG)
                string(JSON T_SHA GET "${TAGS_JSON}" ${I} "commit" "sha")
                set(${OUT_TAG_NAME_ARG} "${T_NAME}" PARENT_SCOPE)
                set(${OUT_TAG_SHA_ARG} "${T_SHA}" PARENT_SCOPE)
                return()
            endif()
        endif()
    endforeach()

endfunction()


# ==============================================================================
# 6. Stiahnutie jedného assetu (podľa regex vzoru) z release-u na danom indexe
# ==============================================================================
function(RootRepoHandler_Download_ReleaseAsset RELEASES_FILE_ARG 
                                               RELEASE_INDEX_ARG 
                                               ASSET_NAME_PATTERN_ARG 
                                               OUTPUT_DIR_ARG 
                                               OUT_DOWNLOADED_PATH_ARG)
                                               
    file(READ "${RELEASES_FILE_ARG}" RELEASES_JSON)
    
    string(JSON ASSET_COUNT LENGTH "${RELEASES_JSON}" ${RELEASE_INDEX_ARG} "assets")

    set(${OUT_DOWNLOADED_PATH_ARG} "" PARENT_SCOPE)
    
    if(ASSET_COUNT EQUAL 0)
        message(FATAL_ERROR "No assets found for release with index ${RELEASE_INDEX_ARG}")
    endif()

    file(MAKE_DIRECTORY "${OUTPUT_DIR_ARG}")

    math(EXPR LAST_INDEX "${ASSET_COUNT} - 1")
    
    foreach(I RANGE ${LAST_INDEX})
        string(JSON ASSET_NAME GET "${RELEASES_JSON}" ${RELEASE_INDEX_ARG} "assets" ${I} "name")

        if(ASSET_NAME MATCHES "${ASSET_NAME_PATTERN_ARG}")
        
            string(JSON ASSET_URL GET "${RELEASES_JSON}" ${RELEASE_INDEX_ARG} "assets" ${I} "browser_download_url")
            
            set(DEST_PATH "${OUTPUT_DIR_ARG}/${ASSET_NAME}")
            
            string(TOUPPER "${CMAKE_MESSAGE_LOG_LEVEL}" LOG_LEVEL_UPPER)
            
            if(LOG_LEVEL_UPPER STREQUAL "DEBUG")
            
                file(DOWNLOAD "${ASSET_URL}" "${DEST_PATH}"
                     STATUS DOWNLOAD_STATUS
                     SHOW_PROGRESS)
                     
            else()
            
                file(DOWNLOAD "${ASSET_URL}" "${DEST_PATH}"
                     STATUS DOWNLOAD_STATUS)
                     
            endif()


                
            list(GET DOWNLOAD_STATUS 0 STATUS_CODE)
            
            if(NOT STATUS_CODE EQUAL 0)
                list(GET DOWNLOAD_STATUS 1 STATUS_MESSAGE)
                message(FATAL_ERROR "Downloading ${ASSET_NAME} failed: ${STATUS_MESSAGE}")
            endif()

            set(${OUT_DOWNLOADED_PATH_ARG} "${DEST_PATH}" PARENT_SCOPE)
            return()
        endif()
    endforeach()

    message(FATAL_ERROR "No asset '${ASSET_NAME_PATTERN_ARG}' found in release.")
    
endfunction()


#------------------------------------------------------------------------------#
# Returns the real name of artifact folder from selected folder.
#
# This function can be used to check real folder name in case, the artifact 
# uses '_' instead of '-'
#
# ARTIFACTS_PATH_ARG       [in]: Path to the repository folder.
# ARTIFACT_NAME_ARG        [in]: Name of artifact.
# ARTIFACT_FOUND_NAME_ARG [out]: Name of the found folder
#------------------------------------------------------------------------------#
function(RootRepoHandler_Get_ArtifactFolderName ARTIFACTS_PATH_ARG 
                                                ARTIFACT_NAME_ARG
                                                ARTIFACT_FOUND_NAME_ARG)
                                                
    set(ARTIFACT_NAME_UNDERSCORE "${ARTIFACT_NAME_ARG}")
    string(REPLACE "-" "_" ARTIFACT_NAME_UNDERSCORE "${ARTIFACT_NAME_UNDERSCORE}")
    
    set(ARTIFACT_NAME_ORIGINAL "${ARTIFACT_NAME_ARG}")

    
    if(IS_DIRECTORY "${ARTIFACTS_PATH_ARG}/${ARTIFACT_NAME_UNDERSCORE}")
    
        set(${ARTIFACT_FOUND_NAME_ARG} "${ARTIFACT_NAME_UNDERSCORE}" PARENT_SCOPE)
        
        message(DEBUG "Artifact folder name found: ${ARTIFACT_NAME_UNDERSCORE}")
    
    elseif(IS_DIRECTORY "${ARTIFACTS_PATH_ARG}/${ARTIFACT_NAME_ORIGINAL}")
    
        set(${ARTIFACT_FOUND_NAME_ARG} "${ARTIFACT_NAME_ORIGINAL}" PARENT_SCOPE)
        
        message(DEBUG "Artifact folder name found: ${ARTIFACT_NAME_ORIGINAL}")
    
    else()
        message(WARNING "No artifact folder name found!")
    endif()
    
endfunction(RootRepoHandler_Get_ArtifactFolderName)