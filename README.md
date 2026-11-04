# Bash Administration Scripts
This repository contains Bash scripts for various Linux administration tasks. Click on the directories to view the scripts. Each directory also includes a README.md file with detailed descriptions of the script functions, as well as getting started and usage instructions.

## Testing
Every push and pull request runs two checks in GitHub Actions ([ci.yml](./.github/workflows/ci.yml)):

+ [ShellCheck](https://www.shellcheck.net/) on every script and test file.
+ [bats](https://github.com/bats-core/bats-core) tests in the [tests](./tests) directory. These cover the options, exit codes, and failure paths of each script, and check that the functions shared between the standalone scripts have not drifted apart. Commands that change the system (package managers, `ssh`) are replaced by stubs, so the tests are safe to run on any machine.

To run the checks locally (bats and rsync are packaged on most distributions, e.g. `sudo apt-get install bats rsync`):

```bash
shellcheck -x ./*/*.sh tests/*.bash tests/*.bats
bats tests
```

## License
Licensed under the [GNU General Public License v3.0](./LICENSE).
