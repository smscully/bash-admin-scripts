#!/bin/bash -i
set -Eeuo pipefail

# script-name.sh
#
# Short description of script.
#
# This program is licensed under the terms of the GNU General Public License v3.0.

########################################
# Initialize constants, exit codes, and global variables
# Arguments:
#   $@ (required): Positional parameters passed to script 
########################################
function init_script(){
  # Constants
  readonly SCRIPT_PATH="${BASH_SOURCE[0]}"
  readonly SCRIPT_NAME="$(basename "${SCRIPT_PATH}")"
  readonly SCRIPT_PARAMS="${@}"

  # Exit codes
  readonly ERR_INV_OPT=50         # Invalid script option
  readonly ERR_LOCK=51            # Unable to lock script
  readonly ERR_NUM_PARAMS=52      # Incorrect number of parameters
  readonly ERR_ROOT_PRIV=53       # Root privileges required

  # Global variables
  script_lock=""
  no_color="false"
  noformat="\033[0;0m"
  red="\033[0;31m"
  green="\033[0;32m"
  yellow="\033[0;33m"
  blue="\033[0;34m"
}

########################################
# Lock script 
# Arguments:
#   None
########################################
function lock_script() {
  local lock_dir="/tmp/${SCRIPT_NAME}.lock"

  if /usr/bin/mkdir "${lock_dir}"; then
    script_lock="${lock_dir}"
  else
    exit_script "${ERR_LOCK}" "${red}Script lock could not be acquired. Please close other instances of the script, then rerun.${noformat}"
  fi
}

########################################
# Clean up tasks, such as deleting temp resources
# Arguments:
#   None
########################################
function cleanup_script(){
  # disable trap handler to avoid recursion
  trap - SIGINT SIGTERM ERR EXIT

  if [[ -d "${script_lock}" ]]; then
    /usr/bin/rmdir "${script_lock}"
  fi 
}

########################################
# Exit script 
# Arguments:
#   $1 (required): Script-specific exit code
#   $2 (required): Message to print on exit
# Ouputs:
#   If provided, writes exit message to stderr
########################################
function exit_script() {
  if [[ -n "$2" ]]; then
    printf "$2\n" >&2
  fi
  exit "$1"
}

########################################
# Parse script parameters
# Arguments:
#   $@ (required): Positional parameters passed to script
########################################
function parse_params() {
  local param

  # OPTIONAL: Use this conditional only if there is a required number of parameters 
  # If fewer than required parameters passed, exit
  if [[ "$#" -lt 1 ]]; then
    exit_script "${ERR_NUM_PARAMS}" "${red}Incorrect number of parameters. Please use the -h option to view Help.${noformat}"
  fi

  while [[ $# -gt 0 ]];do
    param="$1"
    shift
    case "${param}" in
      # Insert additional options alphabetically
      -h | --help)
        usage
        ;;
      -n | --no-color)
        no_color="true"
        ;;
      -v | --verbose)
        PS4='$LINENO:'
        set -x
        ;;
      -* | --*) 
        exit_script "${ERR_INV_OPT}" "${red}Invalid option: ${param}. Please use the -h option to view Help.${noformat}"
        ;;
    esac
  done
}

########################################
# Unset colors 
# Globals:
#   no_color
#   noformat
#   red
#   green
#   yellow
#   blue
# Arguments:
#   None
########################################
function unset_colors() {
  if [[ "${no_color}" == "true" ]]; then
    noformat=""
    red=""
    green=""
    yellow=""
    blue=""
  fi 
}

########################################
# Usage
# Arguments:
#   None
# Ouputs:
#   Writes usage instructions to stdout 
########################################
function usage() {
cat <<EOF

Usage: ${SCRIPT_NAME} [-h|--help] [-n|--no-color] [-v|--verbose]

Updates installed packages after determining the distribution type.

Available options:
        -h|--help          Display help
        -n|--no-color     Turn off text colors
        -v|--verbose       Enable verbose mode

EOF
  exit_script 0 ""
}

########################################
# Check for root privileges
# Arguments:
#   None
########################################
function check_root() {
  if [[ "${UID}" -ne 0 ]]; then
    exit_script "${ERR_ROOT_PRIV}" "${red}Root privileges are required. Please run as root or with sudo.${noformat}"
  fi
}

########################################
# Description of function
# Globals:
#   GLOBAL
# Arguments:
#   $1 (required): Required argument
#   $2 (optional): Optional argument
# Ouputs:
#   Description of output to stdout
# Returns:
#   Description of return values
########################################
function function_name() {
  # Function code
}

########################################
# Main function
# Arguments:
#   $@ (required): Positional parameters passed to script 
########################################
function main() {
  trap cleanup_script SIGINT SIGTERM ERR EXIT

  init_script "${@}"
  check_root
  parse_params "${@}"
  unset_colors 
  lock_script
  # Insert additional functions
  exit_script 0 ""
}

########################################
# Invoke main function
########################################
main "${@}"
