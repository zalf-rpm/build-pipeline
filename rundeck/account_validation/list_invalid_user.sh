#!/bin/bash

# this script is used to iterate over all home,data01 and beegfs directories
# and check:
# if the user is valid in the system
# if the folder structure is intact 


# a valid user should have a home directory and a beegfs directory
# and an optional data01 directory in one of PB sub folders

PB_SUBFOLDERS=(PB1 PB2 PB3 FDS EIP) # maybe in future add IAT
PATH_HOME=/home
PATH_BEEGFS=/beegfs
PATH_DATA01=/data01 # + PB_SUBFOLDERS

# list directory names safely (one level deep)
list_dirnames() {
    local base_path="$1"
    local entry

    [ -d "$base_path" ] || return 0

    for entry in "$base_path"/*; do
        [ -d "$entry" ] || continue
        basename "$entry"
    done
}

# list all users in home
mapfile -t USERS_IN_HOME < <(list_dirnames "$PATH_HOME")

# list all users in beegfs
mapfile -t USERS_IN_BEEGFS < <(list_dirnames "$PATH_BEEGFS")
# list all users in data01 subfolders
USERS_IN_DATA01=()
for subfolder in "${PB_SUBFOLDERS[@]}"; do
    if [ -d "$PATH_DATA01/$subfolder" ]; then
        while IFS= read -r user; do
            USERS_IN_DATA01+=("$user")
        done < <(list_dirnames "$PATH_DATA01/$subfolder")
    fi
done

# index users in home for exact membership checks
declare -A HOME_USERS=()
for user in "${USERS_IN_HOME[@]}"; do
    HOME_USERS["$user"]=1
done

# users in beegfs but not in home
INVALID_USERS_BEEGFS=()
for user in "${USERS_IN_BEEGFS[@]}"; do
    if [[ -z "${HOME_USERS[$user]+x}" ]] ; then
        INVALID_USERS_BEEGFS+=("$user")
    fi
done
# users in data01 but not in home
INVALID_USERS_DATA01=()
for user in "${USERS_IN_DATA01[@]}"; do
    if [[ -z "${HOME_USERS[$user]+x}" ]] ; then
        INVALID_USERS_DATA01+=("$user")
    fi
done

# print invalid users
echo "Invalid users in beegfs: ${INVALID_USERS_BEEGFS[@]}"
echo "Invalid users in data01: ${INVALID_USERS_DATA01[@]}"

# check users in home if the account is still active in the system
# LDAP/AD check if the user is still valid in the system
INVALID_USERS_HOME=()
for user in "${USERS_IN_HOME[@]}"; do
    if ! id "$user" &>/dev/null ; then
        INVALID_USERS_HOME+=("$user")
    fi
done
echo "Invalid users in home: ${INVALID_USERS_HOME[@]}"

