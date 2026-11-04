#!/usr/bin/env bats

load test_helper

# Each test gets a copy of the script, a backup.settings file, a source
# directory, and local and "remote" save directories. The names contain
# spaces and a '%' to catch quoting and printf format bugs. A fake ssh runs
# the remote side locally, so the real tar, find and rsync are exercised.
setup() {
  common_setup

  APP_DIR="${BATS_TEST_TMPDIR}/app dir"
  SRC_DIR="${BATS_TEST_TMPDIR}/src"
  LOCAL_DIR="${BATS_TEST_TMPDIR}/local 100% dir"
  REMOTE_DIR="${BATS_TEST_TMPDIR}/remote 100% dir"
  SSH_KEY="${BATS_TEST_TMPDIR}/backup key"
  mkdir -p "${APP_DIR}" "${SRC_DIR}" "${REMOTE_DIR}"
  mkdir -p "${LOCAL_DIR}/daily" "${LOCAL_DIR}/weekly" "${LOCAL_DIR}/monthly" "${LOCAL_DIR}/once"
  echo "data" > "${SRC_DIR}/file one.txt"
  echo "key" > "${SSH_KEY}"

  cp "${REPO_ROOT}/backup-tar-rsync/backup-tar-rsync.sh" "${APP_DIR}/"
  SCRIPT="${APP_DIR}/backup-tar-rsync.sh"
  SETTINGS="${APP_DIR}/backup.settings"
  write_settings

  # Fake ssh: skip the options and host, then run the command locally
  cat > "${STUB_DIR}/ssh" <<'EOF'
#!/usr/bin/env bash
while [[ "$1" == -* ]]; do
  [[ "$1" =~ ^-[ilpo]$ ]] && shift
  shift
done
shift
echo "ssh $*" >> "${STUB_LOG}"
exec bash -c "$*"
EOF
  chmod +x "${STUB_DIR}/ssh"
  export PATH="${STUB_DIR}:${PATH}"
}

# Write backup.settings, leaving out any section named in the arguments.
write_settings() {
  {
    [[ " $* " == *" TAR_FILES "* ]] || printf -- '--TAR_FILES--\n%s\n\n' "${SRC_DIR#/}"
    [[ " $* " == *" SAVE_DIR_LOCAL "* ]] || printf -- '--SAVE_DIR_LOCAL--\n%s/\n' "${LOCAL_DIR}"
    [[ " $* " == *" SAVE_DIR_REMOTE "* ]] || printf -- '--SAVE_DIR_REMOTE--\n%s/\n' "${REMOTE_DIR}"
    [[ " $* " == *" SSH_SERVER "* ]] || printf -- '--SSH_SERVER--\nbackup@example\n'
    [[ " $* " == *" SSH_KEY "* ]] || printf -- '--SSH_KEY--\n%s\n' "${SSH_KEY}"
    printf -- '--EOF--\n'
  } > "${SETTINGS}"
}

# Print the number of archives in a directory
count_archives() {
  find "$1" -name 'backup-*.tgz' | wc -l
}

@test "backup: --help exits 0" {
  run bash "${SCRIPT}" --help
  [ "${status}" -eq 0 ]
  [[ "${output}" == *"Usage: backup-tar-rsync.sh"* ]]
}

@test "backup: no arguments exits 52" {
  run bash "${SCRIPT}"
  [ "${status}" -eq 52 ]
}

@test "backup: no frequency option exits 52 and writes nothing" {
  run bash "${SCRIPT}" -n
  [ "${status}" -eq 52 ]
  [ "$(count_archives "${LOCAL_DIR}")" -eq 0 ]
}

@test "backup: two frequency options exit 52" {
  run bash "${SCRIPT}" -d -w
  [ "${status}" -eq 52 ]
}

@test "backup: invalid option and stray argument exit 50" {
  run bash "${SCRIPT}" -d --bogus
  [ "${status}" -eq 50 ]
  run bash "${SCRIPT}" -d foo
  [ "${status}" -eq 50 ]
}

@test "backup: missing settings file exits 54" {
  rm "${SETTINGS}"
  run bash "${SCRIPT}" -d
  [ "${status}" -eq 54 ]
}

@test "backup: each missing settings section exits 54 before tar runs" {
  local section
  for section in TAR_FILES SAVE_DIR_LOCAL SAVE_DIR_REMOTE SSH_SERVER SSH_KEY; do
    write_settings "${section}"
    run bash "${SCRIPT}" -d
    echo "section ${section}: status ${status}: ${output}"
    [ "${status}" -eq 54 ]
  done
  [ "$(count_archives "${BATS_TEST_TMPDIR}")" -eq 0 ]
}

@test "backup: missing local frequency directory exits 54" {
  rmdir "${LOCAL_DIR}/daily"
  run bash "${SCRIPT}" -d
  [ "${status}" -eq 54 ]
}

@test "backup: settings file without a final newline is read" {
  printf -- '--TAR_FILES--\n%s\n--SAVE_DIR_LOCAL--\n%s\n--SAVE_DIR_REMOTE--\n%s\n--SSH_SERVER--\nbackup@example\n--SSH_KEY--\n%s' \
    "${SRC_DIR#/}" "${LOCAL_DIR}" "${REMOTE_DIR}" "${SSH_KEY}" > "${SETTINGS}"
  run bash "${SCRIPT}" -d
  [ "${status}" -eq 0 ]
}

@test "backup: daily run creates the archive locally and remotely" {
  run bash "${SCRIPT}" -d
  [ "${status}" -eq 0 ]
  [ "$(count_archives "${LOCAL_DIR}/daily")" -eq 1 ]
  [ "$(count_archives "${REMOTE_DIR}/daily")" -eq 1 ]
  # The '%' in the path is printed as is, not treated as a format directive
  [[ "${output}" == *"backup@example:${REMOTE_DIR}/daily"* ]]
  tar -tzf "${REMOTE_DIR}"/daily/backup-*.tgz | grep -q "file one.txt"
  [ -z "$(find "${LOCAL_DIR}" -name '*.partial')" ]
}

@test "backup: old archives are pruned locally and remotely, others kept" {
  mkdir -p "${REMOTE_DIR}/daily"
  touch -d '10 days ago' "${LOCAL_DIR}/daily/backup-old.tgz" "${REMOTE_DIR}/daily/backup-old.tgz"
  touch -d '2 days ago' "${LOCAL_DIR}/daily/backup-recent.tgz" "${REMOTE_DIR}/daily/backup-recent.tgz"
  touch -d '10 days ago' "${REMOTE_DIR}/daily/notes.txt"

  run bash "${SCRIPT}" -d
  [ "${status}" -eq 0 ]
  [ ! -e "${LOCAL_DIR}/daily/backup-old.tgz" ]
  [ ! -e "${REMOTE_DIR}/daily/backup-old.tgz" ]
  [ -e "${LOCAL_DIR}/daily/backup-recent.tgz" ]
  [ -e "${REMOTE_DIR}/daily/backup-recent.tgz" ]
  [ -e "${REMOTE_DIR}/daily/notes.txt" ]
}

@test "backup: local deletions and changes do not reach the remote copy" {
  mkdir -p "${REMOTE_DIR}/daily"
  echo "original" > "${REMOTE_DIR}/daily/backup-changed.tgz"
  echo "only remote" > "${REMOTE_DIR}/daily/backup-deleted-locally.tgz"
  echo "ENCRYPTED" > "${LOCAL_DIR}/daily/backup-changed.tgz"

  run bash "${SCRIPT}" -d
  [ "${status}" -eq 0 ]
  [ "$(cat "${REMOTE_DIR}/daily/backup-changed.tgz")" = "original" ]
  [ -e "${REMOTE_DIR}/daily/backup-deleted-locally.tgz" ]
}

@test "backup: SIGTERM stops the run, exits 143 and removes the partial archive" {
  # A slow tar that creates its output file, so the signal arrives mid-run
  cat > "${STUB_DIR}/tar" <<'EOF'
#!/usr/bin/env bash
touch "$2"
sleep 2
EOF
  chmod +x "${STUB_DIR}/tar"

  bash "${SCRIPT}" -d > "${BATS_TEST_TMPDIR}/out" 2>&1 &
  local pid=$!

  for _ in $(seq 50); do
    [ -n "$(find "${LOCAL_DIR}/daily" -name '*.partial')" ] && break
    sleep 0.1
  done
  kill -TERM "${pid}"
  local rc=0
  wait "${pid}" || rc=$?

  [ "${rc}" -eq 143 ]
  [ -z "$(find "${LOCAL_DIR}" -name '*.partial')" ]
  [ "$(count_archives "${LOCAL_DIR}")" -eq 0 ]
  # The run stopped before rsync or the remote prune
  [ ! -s "${STUB_LOG}" ]
}

@test "backup: a second instance exits 51 while the lock is held" {
  exec 9>>"${XDG_RUNTIME_DIR}/backup-tar-rsync.sh.lock"
  flock -n 9
  run bash "${SCRIPT}" -d
  exec 9>&-
  [ "${status}" -eq 51 ]
}

@test "backup: a leftover lock file from a killed run does not block" {
  touch "${XDG_RUNTIME_DIR}/backup-tar-rsync.sh.lock"
  run bash "${SCRIPT}" -d
  [ "${status}" -eq 0 ]
}

@test "backup: no color escapes when output is not a terminal" {
  run bash "${SCRIPT}" --bogus
  [[ "${output}" != *$'\033'* ]]
}
