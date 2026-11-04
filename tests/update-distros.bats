#!/usr/bin/env bats

load test_helper

setup() {
  common_setup
  SCRIPT="${REPO_ROOT}/update-distros/update-distros.sh"
  OS_RELEASE="${BATS_TEST_TMPDIR}/os-release"
}

# Write an os-release file from KEY=VALUE lines
os_release() {
  printf '%s\n' "$@" > "${OS_RELEASE}"
}

# Run detect_distro on the os-release file
detect() {
  # shellcheck disable=SC2016  # expanded by the inner bash
  run "${BASH}" -c 'source "$1" && detect_distro "$2"' _ "${SCRIPT}" "${OS_RELEASE}"
}

# Run update_distro with a PATH that holds only the stub commands, so no
# real package manager can run
update() {
  # shellcheck disable=SC2016  # expanded by the inner bash
  run env PATH="${STUB_DIR}" "${BASH}" -c \
    'source "$1" && init_script && update_distro "$2"' _ "${SCRIPT}" "${OS_RELEASE}"
}

@test "update-distros: --help works without root" {
  run bash "${SCRIPT}" --help
  [ "${status}" -eq 0 ]
  [[ "${output}" == *"Usage: update-distros.sh"* ]]
}

@test "update-distros: a normal user gets exit 53" {
  skip_if_root
  run bash "${SCRIPT}"
  [ "${status}" -eq 53 ]
}

@test "update-distros: invalid option and stray argument exit 50" {
  run bash "${SCRIPT}" --bogus
  [ "${status}" -eq 50 ]
  run bash "${SCRIPT}" foo
  [ "${status}" -eq 50 ]
}

@test "detect_distro: maps ID and ID_LIKE to one family" {
  local expected id id_like
  while IFS='|' read -r expected id id_like; do
    os_release "ID=${id}" "ID_LIKE=${id_like}"
    detect
    echo "ID=${id} ID_LIKE=${id_like}: got '${output}', expected '${expected}'"
    [ "${status}" -eq 0 ]
    [ "${output}" = "${expected}" ]
  done <<'EOF'
debian|ubuntu|debian
debian|debian|
debian|linuxmint|"ubuntu debian"
debian|kali|debian
rhel|"rocky"|"rhel centos fedora"
rhel|fedora|
rhel|centos|"rhel fedora"
arch|arch|
arch|manjaro|arch
suse|"opensuse-leap"|"suse opensuse"
suse|sles|
EOF
}

@test "detect_distro: ignores names that appear outside ID and ID_LIKE" {
  os_release 'ID=kali' 'ID_LIKE=debian' 'HOME_URL="https://example.org/search/arch/suse"'
  detect
  [ "${status}" -eq 0 ]
  [ "${output}" = "debian" ]
}

@test "detect_distro: unknown distro or missing file returns 1" {
  os_release 'ID=gentoo'
  detect
  [ "${status}" -eq 1 ]
  rm "${OS_RELEASE}"
  detect
  [ "${status}" -eq 1 ]
}

@test "update_distro: Debian-like runs apt-get update then upgrade, nothing else" {
  make_stub apt-get
  make_stub dnf
  make_stub pacman
  make_stub zypper
  os_release 'ID=ubuntu' 'ID_LIKE=debian'
  update
  [ "${status}" -eq 0 ]
  [ "$(cat "${STUB_LOG}")" = $'apt-get -y update\napt-get -y upgrade' ]
}

@test "update_distro: RHEL-like uses dnf when it is installed" {
  make_stub dnf
  make_stub yum
  os_release 'ID="rocky"' 'ID_LIKE="rhel centos fedora"'
  update
  [ "${status}" -eq 0 ]
  [ "$(cat "${STUB_LOG}")" = "dnf -y update" ]
}

@test "update_distro: RHEL-like falls back to yum without dnf" {
  make_stub yum
  os_release 'ID="centos"' 'ID_LIKE="rhel fedora"'
  update
  [ "${status}" -eq 0 ]
  [ "$(cat "${STUB_LOG}")" = "yum -y update" ]
}

@test "update_distro: Arch and SUSE use pacman and zypper" {
  make_stub pacman
  make_stub zypper
  os_release 'ID=arch'
  update
  [ "${status}" -eq 0 ]
  os_release 'ID="opensuse-tumbleweed"' 'ID_LIKE="opensuse suse"'
  update
  [ "${status}" -eq 0 ]
  [ "$(cat "${STUB_LOG}")" = $'pacman -Syu --noconfirm\nzypper -n update' ]
}

@test "update_distro: unknown distro exits 54 and runs nothing" {
  make_stub apt-get
  make_stub dnf
  os_release 'ID=gentoo'
  update
  [ "${status}" -eq 54 ]
  [[ "${output}" == *"Unsupported or unknown distribution"* ]]
  [ ! -s "${STUB_LOG}" ]
}

@test "update_distro: a failing package manager fails the script" {
  make_stub apt-get 100
  os_release 'ID=debian'
  update
  [ "${status}" -eq 100 ]
}
