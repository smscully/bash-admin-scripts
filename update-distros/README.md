# Update Installed Packages Based On Distribution
The [update-distros.sh](./update-distros.sh) script determines the current distribution and runs the corresponding package manager update commands.

## Description
Upon invocation, the script calls the `main` function, which first initializes variables, checks for root privileges, parses parameters, determines text color settings, and initiates a script lock.

Next, the `update_distro` function is called, as described below.

### Determining Distribution and Updating Installed Packages
The `update_distro` function determines the distribution via a set of conditionals that test grep searches of the `/etc/os-release` file for distribution-specific keywords. Once a conditional returns true, the script runs the distribution-specific package manager update commands.

### The `cleanup_script` Function and Exit Codes
Upon receiving a SIGINT, SIGTERM, ERR, or EXIT signal, the `trap` command calls the `cleanup_script` function, which deletes the directory created for the script lock.

If the script errors out on a Bash command, the command's exit code will return. For errors handled internally by the script, exit codes include:

|Exit Code|Description|
|---------|-----------|
|50|Invalid script option|
|51|Unable to lock script|
|52|Root privileges required|

## Getting Started

### Dependencies

+ OS: Linux (Standard distros: Debian/Ubuntu, Arch, RHEL, openSUSE)

**NOTE:** The script has been tested on numerous distributions, including Rocky, CentOS, Debian, Ubuntu, Mint, Arch, Kali, and openSUSE.

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
