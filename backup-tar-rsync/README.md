# Backup Using Tar and Rsync
The [backup-tar-rsync.sh](./backup-tar-rsync.sh) script creates a gzip compressed tar archive of selected files and/or directories and uses `rsync` to copy the tar archive to a remote SSH server. The script supports daily, weekly, and monthly backups, which will typically be scheduled as `cron` jobs. One-time backups can be run on an ad hoc basis.

## Description
To support modularization and improve readability, the script is comprised of three general function classifications: 

+ Utility Functions
+ Core Script Function: `backup`
+ Exit and Cleanup Functions

These functions are called in logical fashion by the `main` function, which establishes the run order upon script invocation.

> **NOTE:** For a Bash template that includes the utility, exit, and cleanup functions described below, click [here](../bash-template).

### 1. Utility Functions
The `main` function first calls the following utility functions:

+ `init_script`: initializes constants, exit codes, and global variables. 
+ `parse_params`: parses parameters provided by the user, assigning values and calling functions such as `usage` for script help.
+ `unset_colors`: determines text color settings.
+ `lock_script`: initiates a script lock.

### 2. Core Script Function: `backup`
Once the script is successfully locked, indicating that only one instance of the script is running, `main` proceeds to the core script function, `backup`. This function first reads the `backup.settings` file, which stores data regarding the backup files and/or directories, the local and remote save directories for the tar archive, the rsync remote SSH server (and port if non-standard), and the absolute path to local SSH key file. Then the function calls the `tar` command to create the archive with gzip compression, runs the `find` command to delete old archives, and copies the tar archive to the remote SSH server using `rsync`.

### 3. Exit and Cleanup Functions
If the script runs without an error, `main` invokes the `exit_script` function, gracefully exiting with an exit code of 0. The `exit_script` function is also used throughout the script to provide exit codes and messages for errors handled internally by the script. The exit codes are as follows:

|Exit Code|Description|
|---------|-----------|
|50|Invalid script option|
|51|Unable to lock script|
|52|Incorrect number of parameters|

If the script errors out on a Bash command, the command's exit code will return. 

As a final step, upon receiving a SIGINT, SIGTERM, ERR, or EXIT signal, the `trap` command calls the `cleanup_script` function, which deletes the directory created for the script lock. 

## Getting Started

### Dependencies

+ OS: Linux 
+ SSH connection: The script uses `rsync` to transfer the tar archive from the local host to the remote SSH server, necessitating an SSH connection between the two.

### 1. Installation
To install the script, either clone the [bash-admin-scripts](..) repo or download the [backup-tar-rsync.sh](./backup-tar-rsync.sh) and [backup.settings](./backup.settings) files to the local host. As with all Bash scripts, the script can be saved to `usr/local/bin` for system-wide availability, although this is not required.

### 2. Create Backup Save Directories and Subdirectories
On each of the local host and remote SSH server, create a save directory, which is where the tar archives will be saved. For simplicity, these can be identically named, but they need not be. For example:

+ Save Local: /home/user01/backup
+ Save Remote: /backup/user01

Within the local directory, create the following subdirectory structure:

/daily\
/monthly\
/once\
/weekly

These subdirectories need not be created in the remote save directory, as `rsync` will automatically create them during the backup.

### 3. Create the SSH Key
Because the script employs `rsync`, the local host and remote server must connect via SSH. An SSH key must be created on the local host, with its public key copied to the remote SSH server. The passphrase value of the SSH key should be left empty, since it is not realistic to schedule a `cron` job that would require user input.

### 4. Customize the `backup.settings` File
Using the provided backup.settings file, make the following customizations:

+ Below the --TAR_FILES-- line: Enter the backup files and/or directories
+ below the --SAVE_DIR_LOCAL-- line: Enter the local save directory 
+ Below the --SAVE_DIR_REMOTE-- line: Enter the remote save directory
+ Below the --SSH_SERVER-- line: Enter the SSH server (and port if non-standard) 
+ Below the --SSH_KEY-- line: Enter the absolute path to the local SSH key file

For reference, below is the text of the sample backup.settings file:

```bash
--TAR_FILES--
home/user01/Pictures
home/user01/Documents/test.txt
--SAVE_DIR_LOCAL--
/home/user01/backup/
--SAVE_DIR_REMOTE--
/backup/user01/
--SSH_SERVER--
backup@10.0.2.6
--SSH_KEY--
/home/user01/.ssh/backup_key
--EOF--
```

Each backup file or directory must be listed on a separate line. Additionally, the [backup.settings](./backup.settings) file must be stored in the same directory as the [backup-tar-rsync.sh](./backup-tar-rsync.sh) file.

### 5. Configure `cron` Jobs (Optional)
While the script can be run on an ad hoc basis, the daily, weekly, and monthly options are designed to support a standard backup regimen using `cron` jobs. In this connection, the script deletes daily backups older than 7 days, weekly backups older than 30 days, and monthly backups older than 365 days.

As an example, to schedule a weekly backup at 12:30 a.m. every Sunday, create the following `cron` entry:

```bash
30 0 * * 0 /user/local/bin/backup-tar-rsync -w
```

## Usage
The script requires at least one of the following options:

|Short Option|Long Option|Description|
|---------|---------|-----------|
|-d|--daily|Daily frequency|
|-h|--help|Display help|
|-m|--monthly|Monthly frequency|
|-n|--no-color|Turn off text colors|
|-o|--once|One-time frequency|
|-v|--verbose|Enable verbose mode|
|-w|--weekly|Weekly frequency|

Multiple options can be provided, such as a weekly backup in verbose mode:

```bash
sudo ./backup-tar-rsync.sh -w -v
```
However, please note the following caveats:

+ The script exits after displaying help, and calls the `usage` function before the `backup` function. As such, if both help and backup options are provided, only help will run.
+ Only one backup option is processed. If multiple backup options are provided, only the last will take effect. 
+ The script will throw an error if neither a frequency option (-d, -m, -o, -w) nor the help option (-h) is provided.

## License
Licensed under the [GNU General Public License v3.0](../LICENSE).
