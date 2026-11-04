# Update Installed Packages Based On Distribution
The [update-distros.sh](./update-distros.sh) script determines the current distribution and runs the corresponding package manager update commands. The script requires root privileges.

## Description
To support modularization and improve readability, the script is comprised of three general function classifications: 

+ Utility Functions
+ Core Script Function: `update_distro`
+ Exit and Cleanup Functions

These functions are called in logical fashion by the `main` function, which establishes the run order upon script invocation.

> **NOTE:** For a Bash template that includes the utility, exit, and cleanup functions described below, click [here](../bash-template).

### 1. Utility Functions
The `main` function first calls the following utility functions:

+ `init_script`: initializes constants, exit codes, and global variables. 
+ `parse_params`: parses parameters provided by the user, assigning values and calling functions such as `usage` for script help.
+ `unset_colors`: determines text color settings.
+ `check_root`: checks for root privileges and exits on failure. This runs after `parse_params`, so `--help` works without root.
+ `lock_script`: initiates a script lock, so only one instance runs at a time.

### 2. Core Script Function: `update_distro`
Once the script is successfully locked, indicating that only one instance of the script is running, `main` proceeds to the core script function, `update_distro`. The `detect_distro` function reads the `ID` and `ID_LIKE` fields of `/etc/os-release` (without sourcing the file) and maps the first recognized value to one package manager: `dnf` (or `yum`) for RHEL-like systems, `pacman` for Arch-like, `apt-get` for Debian-like, and `zypper` for SUSE-like. `ID` is checked before `ID_LIKE`, so derivatives such as Mint, Kali, Manjaro, or Rocky are matched through their parent distribution. If no value is recognized, the script exits with code 54 instead of doing nothing. `update_distro` then runs that package manager's update commands.

### 3. Exit and Cleanup Functions
If the script runs without an error, `main` invokes the `exit_script` function, gracefully exiting with an exit code of 0. The `exit_script` function is also used throughout the script to provide exit codes and messages for errors handled internally by the script. The exit codes are as follows:

|Exit Code|Description|
|---------|-----------|
|50|Invalid script option or unexpected argument|
|51|Unable to lock script|
|53|Root privileges required (was 52 before the exit codes were aligned with the template)|
|54|Unsupported or unknown distribution|

If the script errors out on a Bash command, the command's exit code will return. 

If the script is stopped by SIGINT or SIGTERM, it exits with code 130 or 143 respectively. As a final step, whenever the script exits, the `trap` command calls the `cleanup_script` function. The script lock is held with `flock` (in `/run` when running as root, otherwise in `$XDG_RUNTIME_DIR` or `/tmp`) and is released automatically when the script exits. 

## Getting Started

### Dependencies

+ OS: Linux (Standard distros: Debian/Ubuntu, Arch, RHEL, openSUSE)

> **NOTE:** The script has been tested on numerous distributions, including Rocky, CentOS, Debian, Ubuntu, Mint, Arch, Kali, and openSUSE.

### Installation
To install the script, either clone the [bash-admin-scripts](..) repo or download the [update-distros.sh](./update-distros.sh) file to the local host. As with all Bash scripts, the script can be saved to `usr/local/bin` for system-wide availability, although this is not required.

## Usage
To run the script without any options, use the syntax below:

```bash
sudo ./update-distros.sh 
```

The following options are available:

|Short Option|Long Option|Description|
|---------|---------|-----------|
|-h|--help|Display help|
|-n|--no-color|Turn off text colors|
|-v|--verbose|Enable verbose mode|

## License
Licensed under the [GNU General Public License v3.0](../LICENSE).
