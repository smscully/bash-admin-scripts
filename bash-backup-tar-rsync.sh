#!/bin/bash
set -Eeuo pipefail

# bash-backup-tar-rsync.sh
#
# Performs a backup using tar with gzip, then copies the tar archive to a remote server using rsync.
# Reads a settings file to determine the backup files and/or directories, the local and remote save
# directories for the tar archive, the rsync remote SSH server (and port if non-standard), and the
# absolute path to the local SSH key file.
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
  readonly SETTINGS_FILE="$(dirname ${SCRIPT_PATH})/backup.settings"

  # Exit codes
  readonly ERR_INV_OPT=50         # Invalid script option
  readonly ERR_LOCK=51            # Unable to lock script
  readonly ERR_NUM_PARAMS=52      # Incorrect number of parameters

  # Global variables
  backup_del=""
  backup_freq=""
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
  # Disable trap handler to avoid recursion
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
#   Writes exit message to stderr
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

  # If no parameters passed, exit
  if [[ "$#" -eq 0 ]]; then
    exit_script "${ERR_NUM_PARAMS}" "${red}Incorrect number of parameters. Please use the -h option to view Help.${noformat}"
  fi

  while [[ $# -gt 0 ]];do
    param="$1"
    shift
    case "${param}" in
      -d | --daily)
        backup_freq="daily"
        backup_del=7
        ;;
      -h | --help)
        usage
        ;;
      -m | --monthly)
        backup_freq="monthly"
        backup_del=365
        ;;
      -n | --no-color)
        no_color="true"
        ;;
      -o | --once)
        backup_freq="once"
        backup_del=0
        ;;
      -v | --verbose)
        PS4='$LINENO:'
        set -x
        ;;
      -w | --weekly)
        backup_freq="weekly"
        backup_del=30
        ;;
      -*) 
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

Usage: ${SCRIPT_NAME} [-d|--daily] [-h|--help] [-m|--monthly] [-n|--no-color] [-o|--once] [-v|--verbose] [-w|--weekly]

Performs a backup of files and/or directories using tar with gzip, then
copies the tar archive to a remote SSH server using rsync. Maintains
monthly backups for 365 days, weekly backups for 30 days, and daily backups
for seven days.

User-defined values must be added to the backup.settings file. This includes
the backup files and/or directories, the local and remote save directories
for the tar archive, the rsync remote SSH server (and port if non-standard),
and the absolute path to the local SSH key file. The backup.settings file
must be stored in the same directory as ${SCRIPT_NAME}.

Available options:
        -d|--daily         Daily frequency
        -h|--help          Display help
        -m|--monthly       Monthly frequency
        -n|--no-color      Turn off text colors
        -o|--once          One-time frequency
        -v|--verbose       Enable verbose mode
        -w|--weekly        Weekly frequency

EOF
  exit_script 0 ""
}

########################################
# Create tar archive with gzip compression and send to remote SSH server
# Arguments:
#   None
########################################
backup() {
  local line=""
  local tar_archive="backup-$(date +%Y-%m-%d-%H-%M-%S).tgz"
  local tar_files=()
  local save_dir_local=""
  local save_dir_remote=""
  local ssh_key=""
  local ssh_server=""
  local section=""

  # Read backup.settings file; assign entries to variables
  while read line;do
    case $line in
      --TAR_FILES--)
        section="F"
        ;;
      --SAVE_DIR_LOCAL--)
        section="L"
        ;;
      --SAVE_DIR_REMOTE--)
        section="R"
        ;;
      --SSH_SERVER--)
        section="S"
        ;;
      --SSH_KEY--)
        section="K"
        ;;
      --EOF--)
        break
        ;;
      *)
        if [[ "${section}" == "F" ]];then
          tar_files+=("${line}") 
        elif [[ "${section}" == "L" ]];then
          save_dir_local="${line}" 
        elif [[ "${section}" == "R" ]];then
          save_dir_remote="${line}" 
        elif [[ "${section}" == "S" ]];then
          ssh_server="${line}" 
        elif [[ "${section}" == "K" ]];then
          ssh_key="${line}" 
        fi
        ;;
    esac
  done < $SETTINGS_FILE

  # Create tar archive with gzip compression
  /usr/bin/tar -zcf "${save_dir_local}/${backup_freq}/${tar_archive}" -C / "${tar_files[@]}"

  # Delete older archives based on frequency
  /usr/bin/find ${save_dir_local}/${backup_freq} -type f -mtime +"${backup_del}" -delete

  # Copy archive to remote SSH and delete extraneous 
  /usr/bin/rsync -e "ssh -i ${ssh_key}" -a --delete "${save_dir_local}/${backup_freq}" "${ssh_server}:${save_dir_remote}"

  printf "The tar archive ${tar_archive} was created and saved to the remote backup location at: ${ssh_server}:${save_dir_remote}/${backup_freq}\n"
}

########################################
# Main function
# Arguments:
#   $@ (required): Positional parameters passed to script 
########################################
function main() {
  trap cleanup_script SIGINT SIGTERM ERR EXIT

  init_script "${@}"
  parse_params "${@}"
  unset_colors 
  lock_script
  backup
  exit_script 0 ""
}

########################################
# Invoke main function
########################################
main "${@}"
