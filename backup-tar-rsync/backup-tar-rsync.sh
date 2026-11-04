#!/usr/bin/env bash
set -Eeuo pipefail

# backup-tar-rsync.sh
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
  readonly SETTINGS_FILE="$(dirname "${SCRIPT_PATH}")/backup.settings"

  # Exit codes
  readonly ERR_INV_OPT=50         # Invalid script option
  readonly ERR_LOCK=51            # Unable to lock script
  readonly ERR_NUM_PARAMS=52      # Incorrect number of parameters
  readonly ERR_SETTINGS=54        # Missing or invalid backup.settings value

  # Global variables
  backup_del=""
  backup_freq=""
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
#   Writes exit message to stderr
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
  local freq_count=0

  while [[ $# -gt 0 ]];do
    param="$1"
    shift
    case "${param}" in
      -d | --daily)
        backup_freq="daily"
        backup_del=7
        freq_count=$((freq_count + 1))
        ;;
      -h | --help)
        usage
        ;;
      -m | --monthly)
        backup_freq="monthly"
        backup_del=365
        freq_count=$((freq_count + 1))
        ;;
      -n | --no-color)
        no_color="true"
        ;;
      -o | --once)
        backup_freq="once"
        backup_del=0
        freq_count=$((freq_count + 1))
        ;;
      -v | --verbose)
        PS4='$LINENO:'
        set -x
        ;;
      -w | --weekly)
        backup_freq="weekly"
        backup_del=30
        freq_count=$((freq_count + 1))
        ;;
      -*)
        exit_script "${ERR_INV_OPT}" "${red}Invalid option: ${param}. Please use the -h option to view Help.${noformat}"
        ;;
      *)
        exit_script "${ERR_INV_OPT}" "${red}Unexpected argument: ${param}. Please use the -h option to view Help.${noformat}"
        ;;
    esac
  done

  # Exactly one frequency option is required (-h exits above, inside usage)
  if [[ "${freq_count}" -ne 1 ]]; then
    exit_script "${ERR_NUM_PARAMS}" "${red}Exactly one frequency option (-d, -w, -m or -o) is required. Please use the -h option to view Help.${noformat}"
  fi
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

  if [[ ! -r "${SETTINGS_FILE}" ]]; then
    exit_script "${ERR_SETTINGS}" "${red}Settings file not found or not readable: ${SETTINGS_FILE}${noformat}"
  fi

  # Read backup.settings file; assign entries to variables. Lines are read
  # verbatim (no backslash or whitespace processing), and blank lines are
  # skipped. The '|| [[ -n ]]' keeps a last line that has no newline.
  while IFS= read -r line || [[ -n "${line}" ]];do
    case "${line}" in
      "")
        ;;
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
  done < "${SETTINGS_FILE}"

  # Check every setting before running anything that writes or deletes
  if [[ "${#tar_files[@]}" -eq 0 ]]; then
    exit_script "${ERR_SETTINGS}" "${red}No files listed under --TAR_FILES-- in ${SETTINGS_FILE}${noformat}"
  fi
  if [[ -z "${save_dir_local}" ]]; then
    exit_script "${ERR_SETTINGS}" "${red}No directory set under --SAVE_DIR_LOCAL-- in ${SETTINGS_FILE}${noformat}"
  fi
  if [[ ! -d "${save_dir_local}/${backup_freq}" ]]; then
    exit_script "${ERR_SETTINGS}" "${red}Local save directory does not exist: ${save_dir_local}/${backup_freq}${noformat}"
  fi
  if [[ -z "${save_dir_remote}" ]]; then
    exit_script "${ERR_SETTINGS}" "${red}No directory set under --SAVE_DIR_REMOTE-- in ${SETTINGS_FILE}${noformat}"
  fi
  if [[ -z "${ssh_server}" ]]; then
    exit_script "${ERR_SETTINGS}" "${red}No server set under --SSH_SERVER-- in ${SETTINGS_FILE}${noformat}"
  fi
  if [[ -z "${ssh_key}" || ! -r "${ssh_key}" ]]; then
    exit_script "${ERR_SETTINGS}" "${red}SSH key under --SSH_KEY-- is missing or not readable: ${ssh_key}${noformat}"
  fi

  # Create tar archive with gzip compression
  tar -zcf "${save_dir_local}/${backup_freq}/${tar_archive}" -C / "${tar_files[@]}"

  # Delete older archives based on frequency
  find ${save_dir_local}/${backup_freq} -type f -mtime +"${backup_del}" -delete

  # Copy archive to remote SSH and delete extraneous 
  rsync -e "ssh -i ${ssh_key}" -a --delete "${save_dir_local}/${backup_freq}" "${ssh_server}:${save_dir_remote}"

  printf 'The tar archive %s was created and saved to the remote backup location at: %s:%s/%s\n' \
    "${tar_archive}" "${ssh_server}" "${save_dir_remote}" "${backup_freq}"
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
  lock_script
  backup
  exit_script 0 ""
}

########################################
# Invoke main function
########################################
main "${@}"
