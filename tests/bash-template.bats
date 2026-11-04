#!/usr/bin/env bats

load test_helper

setup() {
  common_setup
  SCRIPT="${REPO_ROOT}/bash-template/bash-template.sh"
}

@test "template: parses without syntax errors" {
  run bash -n "${SCRIPT}"
  [ "${status}" -eq 0 ]
}

@test "template: --help works without root" {
  run bash "${SCRIPT}" --help
  [ "${status}" -eq 0 ]
  [[ "${output}" == *"Usage: bash-template.sh"* ]]
}

@test "template: no arguments exits 52" {
  run bash "${SCRIPT}"
  [ "${status}" -eq 52 ]
}

@test "template: invalid option exits 50" {
  run bash "${SCRIPT}" --bogus
  [ "${status}" -eq 50 ]
  [[ "${output}" == *"Invalid option: --bogus"* ]]
}

@test "template: stray argument exits 50" {
  run bash "${SCRIPT}" foo
  [ "${status}" -eq 50 ]
  [[ "${output}" == *"Unexpected argument: foo"* ]]
}

@test "template: a normal user gets exit 53" {
  skip_if_root
  run bash "${SCRIPT}" -n
  [ "${status}" -eq 53 ]
}

@test "template: no color escapes when output is not a terminal" {
  run bash "${SCRIPT}" --bogus
  [[ "${output}" != *$'\033'* ]]
}
