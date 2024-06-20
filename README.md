# Update Installed Packages Based On Distribution
The [bash-update-distros.sh](./bash-update-distros.sh) script determines the current distribution and runs the corresponding package manager update commands.

## Description
Upon invocation, the script first initializes variables, checks for root privileges, and parses parameters. Next, the text colors are determined and a script lock is initiated. Finally, the `update_distro` function is called. 

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
To install the script, clone the [bash-update-distros](.) repo or download the file to the local host. 

## Usage
To run the script without any options, use the syntax below:

```bash
sudo ./bash-update-distros.sh 
```

The following options are available:

|Short Option|Long Option|Description|
|---------|---------|-----------|
|-h|--help|Display help|
|-n|--no-color|Turn off text colors|
|-v|--verbose|Enable verbose mode|

## License
Licensed under the [GNU General Public License v3.0](./LICENSE).
