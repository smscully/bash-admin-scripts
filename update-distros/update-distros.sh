#!/usr/bin/env bash
set -Eeuo pipefail

# update-distros.sh
#
# Updates installed packages after determining the current distribution.
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
  readonly OS_RELEASE="/etc/os-release"

  # Exit codes
  readonly ERR_INV_OPT=50         # Invalid script option
  readonly ERR_LOCK=51            # Unable to lock script
  readonly ERR_ROOT_PRIV=52       # Root privileges required

  # Global variables
  lock_fd=""
  no_color="false"

  # Text colors: only when stdout and stderr are terminals and NO_COLOR is unset
  noformat=""
  red=""
  if [[ -t 1 && -t 2 && -z "${NO_COLOR:-}" ]]; then
    noformat=$'\033[0;0m'
    red=$'\033[0;31m'
  fi
}

########################################
# Lock script 
# Arguments:
#   None
########################################
function lock_script() {
  local lock_dir
  local lock_file

  # Root uses /run, which only root can write. Other users use their private
  # runtime directory, falling back to /tmp (for example under cron).
  if [[ "${EUID}" -eq 0 ]]; then
    lock_dir="/run"
  else
    lock_dir="${XDG_RUNTIME_DIR:-/tmp}"
  fi
  if [[ ! -d "${lock_dir}" || ! -w "${lock_dir}" ]]; then
    lock_dir="/tmp"
  fi
  lock_file="${lock_dir}/${SCRIPT_NAME}.lock"

  # flock holds the lock on an open file descriptor. The kernel releases it
  # when the script exits, even after kill -9, so a stale lock cannot block
  # the next run.
  if ! { exec {lock_fd}>>"${lock_file}"; } 2>/dev/null || ! flock -n "${lock_fd}"; then
    exit_script "${ERR_LOCK}" "${red}Script lock could not be acquired. Please close other instances of the script, then rerun.${noformat}"
  fi
}

########################################
# Clean up tasks, such as deleting temp resources. Runs from the EXIT trap.
# Arguments:
#   None
########################################
function cleanup_script(){
  # The script lock is released automatically on exit. Add other tasks
  # here, such as deleting temporary files.
  :
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
    printf '%s\n' "$2" >&2
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

  while [[ $# -gt 0 ]];do
    param="$1"
    shift
    case "${param}" in
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
      -*)
        exit_script "${ERR_INV_OPT}" "${red}Invalid option: ${param}. Please use the -h option to view Help.${noformat}"
        ;;
      *)
        exit_script "${ERR_INV_OPT}" "${red}Unexpected argument: ${param}. Please use the -h option to view Help.${noformat}"
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
# Arguments:
#   None
########################################
function unset_colors() {
  if [[ "${no_color}" == "true" ]]; then
    noformat=""
    red=""
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
# Determine Linux distribution and run appropriate update commands
# Arguments:
#   None 
# Ouputs:
#   Writes command output to stdout
########################################
function update_distro() {
  # RHEL
  if [[ $(grep -Ei "rhel|centos|fedora|rocky" "${OS_RELEASE}") ]]; then
    if [[ $(command -v dnf) ]]; then
      dnf -y update
    else
      yum -y update
    fi
  fi	

  # Arch
  if [[ $(grep -Ei "arch" "${OS_RELEASE}") ]]; then
    pacman -Syu --noconfirm
  fi	

  # Debian
  if [[ $(grep -Ei "debian|ubuntu|mint" "${OS_RELEASE}") ]]; then
    apt-get -y update && apt-get -y upgrade
  fi	

  #  SUSE
  if [[ $(grep -Ei "suse|opensuse" "${OS_RELEASE}") ]]; then
    zypper -n update
  fi	
}

########################################
# Main function
# Arguments:
#   $@ (required): Positional parameters passed to script 
########################################
function main() {
  # Clean up on every exit, including errors caught by 'set -e'.
  # A signal must also stop the script, so exit with 128 + signal number.
  trap cleanup_script EXIT
  trap 'exit 130' SIGINT
  trap 'exit 143' SIGTERM

  init_script "${@}"
  parse_params "${@}"
  unset_colors 
  check_root
  lock_script
  update_distro
  exit_script 0 ""
}

########################################
# Invoke main function
########################################
main "${@}"
