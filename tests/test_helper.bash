# Shared setup for the bats tests.
# shellcheck shell=bash

REPO_ROOT="$(cd "$(dirname "${BATS_TEST_FILENAME}")/.." && pwd)"
export REPO_ROOT

# Give every test its own lock directory and stub directory.
common_setup() {
  export XDG_RUNTIME_DIR="${BATS_TEST_TMPDIR}/run"
  mkdir -p "${XDG_RUNTIME_DIR}"

  STUB_DIR="${BATS_TEST_TMPDIR}/stubs"
  mkdir -p "${STUB_DIR}"
  export STUB_LOG="${BATS_TEST_TMPDIR}/stub.log"
  : > "${STUB_LOG}"

  unset NO_COLOR
}

# Create a stub command that logs "NAME ARGS" to STUB_LOG and exits.
# Arguments:
#   $1: command name
#   $2: exit code (default 0)
make_stub() {
  local name="$1"
  local code="${2:-0}"

  # Use bash's absolute path, since some tests run with PATH set to the
  # stub directory only
  cat > "${STUB_DIR}/${name}" <<EOF
#!${BASH}
echo "${name} \$*" >> "\${STUB_LOG}"
exit ${code}
EOF
  chmod +x "${STUB_DIR}/${name}"
}

# Skip a test that needs a normal (non-root) user.
skip_if_root() {
  if [[ "${EUID}" -eq 0 ]]; then
    skip "needs a non-root user"
  fi
}
