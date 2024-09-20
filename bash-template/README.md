# Bash Script Template
The [bash-template.sh](./bash-template.sh) file serves as a Bash scripting template with standard core functions and features such as setting shell options, signal handling, parameter parsing, cleanup, help, script locking, text colors, and checking for root privileges.

## Description
The template provides the functions and features described in detail below.

### Setting Shell Execution Options
The `set -Eeuo pipefail` statement configures the script execution options:

+ E: Ensures the ERR trap is inherited by shell functions, command substitutions, and commands executed in subshells.
+ e: Causes the script to exit immediately upon a command failure.
+ u: Exits immediately on unset variables.
+ o pipefail: Sets the exit code of a pipeline to the value of the last command with a non-zero exit code, or zero if all commands are successful.

The Bash Builtins man page provides an in-depth explanation of these options, as does this excellent [blog post](https://vaneyckt.io/posts/safer_bash_scripts_with_set_euxo_pipefail/).

### Initializing Script Variables
All constants, exit codes, and global variables are initialized in the `init_script` function. This includes the color variables because the default state for text color is true.

### Locking the Script
There are several methods to ensure only one instance of a script is running. (For a detailed explanation of the most common techniques, read [this article](https://www.baeldung.com/linux/bash-ensure-instance-running).) In the template, the `lock_script` function creates a temporary directory to indicate the script is in use, then removes the directory once the script completes.

### Performing Cleanup Tasks
Upon receiving a SIGINT, SIGTERM, ERR, or EXIT signal, the `trap` command calls the `cleanup_script` function. For the template, the function simply deletes the directory created for the script lock. However, for complex scripts, additional tasks can be added, e.g. deleting temporary data files.

### Exiting the Script Gracefully
Calls to the `exit_script` function will exit the script with the exit code passed as the first script argument. If a message is provided as a second argument, the message will be printed to stderr.

### Parsing Parameters
The `parse_params` function reads and processes script options. The function is designed to support both short (-) and long (--) options.

First, the function uses a conditional to check for the required number of parameters, exiting the function if the check fails. Note that the conditional can be removed if there is no explicit required number of parameters.

Next, a `while` loop with a `shift` statement cycles through the parameters, using a `case` statement to read the option value and take appropriate actions, e.g. assign variables, call functions, or perform other tasks. If an invalid option is passed, the script exits with a message notifying as such.

Presently, the template parses options but not arguments. To modify the `parse_params` function to include arguments, review this [post](https://medium.com/@Drew_Stokes/bash-argument-parsing-54f3b81a6a8f) by Drew Stokes, which provides an excellent explanation of how to parse options with their arguments.

### Text Colors
By default, text colors are set to true, as the `init_script` function assigns color variables and sets the global variable `no_color` to false. Running the script with the -n or --no-color option resets `no_color` to true, and the `unset_colors` function will then reset the color variables to null values.

In the template, the only use of color is by the `exit_script` function, which prints color-formatted error messages to stderr. Color functionality, though, can be added to other print statements as needed. Doing so is as simple as adding a color tag (e.g., `${red}`) at the beginning of the text and a noformat tag (`${noformat}`) after the text. The following call to `exit_script` provides an example:

```bash
exit_script "${ERR_ROOT_PRIV}" "${red}Root privileges are required. Please run as root or with sudo.${noformat}"
```

### Script Help
Script help is encapsulated in the `usage` function. At a minimum, script help should provide usage instructions, a general description of the script, and a list of available options.

### Checking for Root Privileges
If the script requires root privileges, ensure that the `main` function includes a call to the `check_root` function. The call, and indeed the function itself, can be removed when the script does not require root privileges.

### Generic Function Skeleton
The generic function called `function_name` serves as skeleton to be customized as appropriate. It should be renamed as appropriate, and the header modified to reflect its global variables, arguments, outputs, and returns.

### The `main` Function
The logical flow of the script is contained within the `main` function, which makes calls to the other primary script functions. The last non-comment line of the script calls `main`. 

## Style Guide
Best efforts are made to follows the rules outlined in the [Google Shell Style Guide](https://google.github.io/styleguide/shellguide.html). While there may be instances of divergence, the template generally adheres to the guidelines promulgated for formatting, naming conventions, and comments. 

## Additional Resources
The following sites provide excellent guidance for Bash template best practices:

+ <https://github.com/ralish/bash-script-template/blob/main/template.sh>
+ <https://betterdev.blog/minimal-safe-bash-script-template/>

## License
Licensed under the [GNU General Public License v3.0](../LICENSE).
