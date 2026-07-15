#!/bin/bash

# home folders are mounted from data node,
# ssh to data node and check if the user is still valid in the system
# the name of the data node is data
# e.g ssh data "do something"

# To check a user, we can use a tool, called ldap_user, 
# which queries the LDAP server for user information.
# the tool will be locaed in the same folder as this script

# that is how a successfull query looks like:
# > ./ldap_user -search -search_userid safi
# uid: safi
# dn: CN=Nasti Safi,OU=openldap,DC=ad,DC=domain,DC=de
# cn: Nasti Safi
# mail: Nasti.Safi@domain.de
# memberOf: [mygroup_public]
# uidNumber: 5678
# gidNumber: 1234

# that is how a failed query looks like, when a user is not found in the system:
# > ./ldap_user -search -search_userid suki
# 2026/07/15 14:19:27 User not found

# here is an example of a user that is deactivated in the system:
# > ./ldap_user -search -search_userid said
# uid: said
# dn: CN=Simon Said,OU=User_deaktiviert,OU=INST,DC=ad,DC=domain,DC=de
# cn: Simon Said
# mail:
# memberOf: [mygroup_public]
# uidNumber: 5678
# gidNumber: 1235

# an active user must have a valid uidNumber and gidNumber, 
# and must be in OU=openldap

set -uo pipefail

# Configuration via environment variables is supported for flexibility.
PATH_HOME="${PATH_HOME:-/home}"
DATA_NODE="${DATA_NODE:-data}"
LIST_HOME_VIA_SSH="${LIST_HOME_VIA_SSH:-1}"

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
LDAP_TOOL="${SCRIPT_DIR}/ldap_user"

if [[ ! -x "${LDAP_TOOL}" ]]; then
	echo "ERROR: ldap_user tool is missing or not executable: ${LDAP_TOOL}" >&2
	exit 1
fi

list_home_users() {
	if [[ "${LIST_HOME_VIA_SSH}" == "1" ]]; then
		ssh -o BatchMode=yes -o ConnectTimeout=10 "${DATA_NODE}" \
			"find '${PATH_HOME}' -mindepth 1 -maxdepth 1 -type d -printf '%f\\n'"
	else
		find "${PATH_HOME}" -mindepth 1 -maxdepth 1 -type d -printf '%f\n'
	fi
}

is_active_user() {
	local user="$1"
	local output
	local uid_number
	local gid_number

	# ldap_user may print errors to stderr, so merge both streams.
	output="$("${LDAP_TOOL}" -search -search_userid "${user}" 2>&1)"

	# User must exist and be in OU=openldap.
	if ! grep -qiE '^dn: .*OU=openldap,' <<<"${output}"; then
		return 1
	fi

	uid_number="$(awk -F': *' '/^uidNumber:/{print $2; exit}' <<<"${output}")"
	gid_number="$(awk -F': *' '/^gidNumber:/{print $2; exit}' <<<"${output}")"

	# Active users require numeric uid/gid > 0.
	if [[ "${uid_number}" =~ ^[0-9]+$ ]] && [[ "${gid_number}" =~ ^[0-9]+$ ]] \
		&& (( uid_number > 0 )) && (( gid_number > 0 )); then
		return 0
	fi

	return 1
}

invalid_users=()
home_users_output=""

if ! home_users_output="$(list_home_users)"; then
  echo "ERROR: failed to list home directories from ${PATH_HOME}." >&2
  exit 1
fi

while IFS= read -r home_user; do
	[[ -z "${home_user}" ]] && continue

	if ! is_active_user "${home_user}"; then
		invalid_users+=("${home_user}")
	fi
done <<<"${home_users_output}"

if (( ${#invalid_users[@]} == 0 )); then
	echo "No invalid users found in ${PATH_HOME}."
	exit 0
fi

printf '%s\n' "Invalid users in ${PATH_HOME}:"
printf '%s\n' "${invalid_users[@]}"
