#!/usr/bin/env bats

# The scripts are standalone, so each carries its own copy of the shared
# functions. These tests fail when the copies drift apart: a fix made in one
# script must be made in all of them.

load test_helper

TEMPLATE="bash-template/bash-template.sh"
SCRIPTS=(
  "backup-tar-rsync/backup-tar-rsync.sh"
  "update-distros/update-distros.sh"
)

# Print a function's definition, normalized by bash, from a script
function_body() {
  # shellcheck disable=SC2016  # expanded by the inner bash
  "${BASH}" -c 'source "$1" && declare -f "$2"' _ "${REPO_ROOT}/$1" "$2"
}

@test "shared: every script parses without syntax errors" {
  local script
  for script in "${TEMPLATE}" "${SCRIPTS[@]}"; do
    bash -n "${REPO_ROOT}/${script}"
  done
}

@test "shared: exit_script, lock_script and unset_colors match the template" {
  local fn script expected
  for fn in exit_script lock_script unset_colors; do
    expected="$(function_body "${TEMPLATE}" "${fn}")"
    [ -n "${expected}" ]
    for script in "${SCRIPTS[@]}"; do
      if [ "$(function_body "${script}" "${fn}")" != "${expected}" ]; then
        echo "${fn} in ${script} differs from ${TEMPLATE}"
        return 1
      fi
    done
  done
}

@test "shared: check_root matches the template wherever it is defined" {
  local script body expected
  expected="$(function_body "${TEMPLATE}" check_root)"
  for script in "${SCRIPTS[@]}"; do
    body="$(function_body "${script}" check_root || true)"
    if [ -n "${body}" ] && [ "${body}" != "${expected}" ]; then
      echo "check_root in ${script} differs from ${TEMPLATE}"
      return 1
    fi
  done
}

@test "shared: exit codes 50 to 53 mean the same thing in every script" {
  local script line
  for script in "${SCRIPTS[@]}"; do
    while IFS= read -r line; do
      if ! grep -qxF -- "${line}" "${REPO_ROOT}/${TEMPLATE}"; then
        echo "${script}: '${line}' does not match ${TEMPLATE}"
        return 1
      fi
    done < <(grep -E '^  readonly ERR_[A-Z_]+=5[0-3] ' "${REPO_ROOT}/${script}")
  done
}

@test "shared: signal and exit traps match the template" {
  local script expected
  expected="$(grep -E '^  trap ' "${REPO_ROOT}/${TEMPLATE}")"
  for script in "${SCRIPTS[@]}"; do
    [ "$(grep -E '^  trap ' "${REPO_ROOT}/${script}")" = "${expected}" ]
  done
}
