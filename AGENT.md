# AGENT.md - Ubuntu Node Setup Scripts

## Build/Test Commands
- Test scripts: `chmod +x *.sh && bash -n <script_name>.sh` (syntax check)
- Run single script: `./<script_name>.sh` (must have execute permissions)
- Full setup test: Run scripts 01-06 in sequence on fresh Ubuntu VM
- Add apps: Run script 07 for first app and all additional apps

## Code Style Guidelines

### Shell Script Conventions
- All scripts start with `#!/bin/bash` and `set -e` for error handling
- Use standard comment header: `# Exit immediately if a command exits with a non-zero status.`
- Progress messages use format: `echo "--- Description..."`
- Error messages include "Exiting." and use `exit 1`
- Input validation: Check for empty strings with `[ -z "$VAR" ]`
- Use regex validation where appropriate: `[[ "$VAR" =~ ^pattern$ ]]`

### Variable Naming
- User input variables: ALL_CAPS with descriptive names (e.g., `NEW_USERNAME`, `GIT_REPO_URL`)
- Default values: `DEFAULT_<NAME>` pattern with fallback using `${VAR:-$DEFAULT}`
- File paths: Use descriptive names (e.g., `AUTH_KEYS_FILE`, `BACKUP_FILE`)

### Error Handling & Validation
- Always validate user input before proceeding
- Provide clear error messages explaining what went wrong
- Use consistent exit codes (exit 1 for user errors)
- Back up files before modification (e.g., sshd_config backup)