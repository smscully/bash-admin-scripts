# Backup Using Tar and Rsync
The [backup-tar-rsync.sh](./backup-tar-rsync.sh) script creates a gzip compressed tar archive of selected files and/or directories and uses `rsync` to copy the tar archive to a remote SSH server. The script supports daily, weekly, and monthly backups, which will typically be scheduled as `cron` jobs. One-time backups can be run on an ad hoc basis.

## Description
Upon invocation, the script calls the `main` function, which first initializes variables, checks for root privileges, parses parameters, determines text color settings, and initiates a script lock. The script then calls the `backup` function, as described below.

### Creating the Archive, Deleting Old Archives, and Copying the Archive to the Remote SSH Server
The `backup` function performs the primary work of the script. The function first reads the `backup.settings` file, which stores data regarding the backup files and/or directories, the local and remote save directories for the tar archive, the rsync remote SSH server (and port if non-standard), and the absolute path to local SSH key file. Thereafter, the function calls the `tar` command to create the archive with gzip compression, runs the `find` command to delete old archives, and copies the tar archive to the remote SSH server using `rsync`.

### The `cleanup_script` Function and Exit Codes
Upon receiving a SIGINT, SIGTERM, ERR, or EXIT signal, the `trap` command calls the `cleanup_script` function, which deletes the directory created for the script lock.

If the script errors out on a Bash command, the command's exit code will return. For errors handled internally by the script, exit codes include:

|Exit Code|Description|
|---------|-----------|
|50|Invalid script option|
|51|Unable to lock script|
|52|Incorrect number of parameters|

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
