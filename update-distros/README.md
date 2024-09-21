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
+ `check_root`: checks for root privileges and exits on failure.
+ `parse_params`: parses parameters provided by the user, assigning values and calling functions such as `usage` for script help.
+ `unset_colors`: determines text color settings.
+ `lock_script`: initiates a script lock.

### 2. Core Script Function: `update_distro`
Once the script is successfully locked, indicating that only one instance of the script is running, `main` proceeds to the core script function, `update_distro`. This function determines the distribution via a set of conditionals that test grep searches of the `/etc/os-release` file. Each conditional searches for distribution-specific keywords. Once a conditional returns true, the script runs the distribution-specific package manager update commands.

### 3. Exit and Cleanup Functions
If the script runs without an error, `main` invokes the `exit_script` function, gracefully exiting with an exit code of 0. The `exit_script` function is also used throughout the script to provide exit codes and messages for errors handled internally by the script. The exit codes are as follows:

|Exit Code|Description|
|---------|-----------|
|50|Invalid script option|
|51|Unable to lock script|
|52|Root privileges required|

If the script errors out on a Bash command, the command's exit code will return. 

As a final step, upon receiving a SIGINT, SIGTERM, ERR, or EXIT signal, the `trap` command calls the `cleanup_script` function, which deletes the directory created for the script lock. 

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
