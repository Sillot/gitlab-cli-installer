# GitLab CLI (glab) - Automated Installer

This repository contains an automated installation script for GitLab CLI (glab) with dependency management and post-installation verification.

## Table of Contents

- [Installation](#installation)
- [Usage](#usage)
- [Updates](#updates)
- [Troubleshooting](#troubleshooting)

## Installation

### Automated Installation with Script

```bash
# Make the script executable
chmod +x install-glab.sh

# Install the latest version
./install-glab.sh

# Install a specific version
./install-glab.sh 1.61.0
```

### Script Features

- **Auto-detection** of the latest available version
- **Version checking** of currently installed version
- **Automatic installation** of missing dependencies
- **Clean installation** with automatic cleanup of temporary files
- **Robust JSON parsing** with jq for GitLab API
- **Post-installation verification** of proper functionality
- **Robust error handling** with colored messages

### Prerequisites

The script automatically manages the installation of the following dependencies:

#### Required Dependencies

- `wget` - For downloading packages
- `dpkg` - For installing .deb packages
- `jq` - For parsing JSON responses from GitLab API
- `git` - Required for all Git functionality in glab
- `ssh` - For SSH authentication with GitLab
- `gpg` - For signature verification (recommended for security)

> **Note:** If any dependencies are missing, the script will automatically install them via `apt-get`. Administrator privileges required.

### First Use

After installation, start by authenticating:

```bash
# Authentication with GitLab.com
glab auth login

# Or with a custom GitLab instance
glab auth login --hostname gitlab.example.com
```

The script automatically verifies that glab works correctly after installation.

## Usage

For detailed usage instructions and command reference, please refer to the [official glab documentation](https://gitlab.com/gitlab-org/cli).

## Updates

```bash
# Update to the latest version
./install-glab.sh

# Install a specific version
./install-glab.sh 1.62.0

# Display help to see all options
./install-glab.sh --help
```

The script automatically checks currently installed version, missing dependencies, and proper functionality after update.

## Uninstallation

To completely remove glab from your system:

```bash
# Uninstall glab
./install-glab.sh --uninstall
```

The uninstallation process will:

1. Remove the glab package from your system
2. Optionally delete configuration files (`~/.config/glab-cli/`)

> **Note:** You will be prompted whether to keep or delete your configuration files during uninstallation.

## Troubleshooting

### Issue: "none of the git remotes configured"

**Error:**

```
ERROR: none of the git remotes configured for this repository point to a known GitLab host.
```

**Solution:**

1. Check your remotes: `git remote -v`
2. Ensure the remote domain matches your glab configuration
3. Use `glab auth login --hostname your-gitlab-domain.com` to configure the correct host

### Issue: "tls: first record does not look like a TLS handshake"

**Cause:** The configured port does not respond with HTTPS/TLS.

**Solution:**

1. Verify the correct domain for the web API
2. Test connectivity: `curl -I https://your-gitlab-domain.com`
3. Use the correct domain in `glab auth login`

### Issue: "i/o timeout"

**Cause:** Network connectivity issue or closed port.

**Solution:**

1. Check your network connection
2. Test connectivity with curl
3. Check corporate firewalls/proxies

### Configuration Verification

```bash
# View current configuration
glab config get

# View configured hosts
cat ~/.config/glab-cli/config.yml

# Test connection
glab api projects
```

### Dependency Verification

If you encounter issues, verify that all dependencies are installed:

```bash
# Check for essential tools
command -v wget && echo "[OK] wget installed" || echo "[MISSING] wget missing"
command -v git && echo "[OK] git installed" || echo "[MISSING] git missing"
command -v ssh && echo "[OK] ssh installed" || echo "[MISSING] ssh missing"
command -v jq && echo "[OK] jq installed" || echo "[MISSING] jq missing"
command -v gpg && echo "[OK] gpg installed" || echo "[MISSING] gpg missing"

# Re-run the script to install missing dependencies
./install-glab.sh --help  # Shows help and dependency list
```

## Important Notes

- **Automatic Installation**: The script automatically installs all necessary dependencies
- **Personal Tokens**: Keep your tokens secure and never commit them
- **Permissions**: Ensure your tokens have `api` and `write_repository` scopes
- **Administrator Privileges**: Required for automatic dependency installation
- **Enterprise Environments**: Configurations may vary based on your infrastructure
- **Backup**: Always backup your configuration before making changes
- **Post-installation Verification**: The script automatically tests glab functionality

## Additional Resources

- [Official glab Documentation](https://gitlab.com/gitlab-org/cli)
- [GitLab Personal Access Tokens](https://docs.gitlab.com/ee/user/profile/personal_access_tokens.html)
- [GitLab API Documentation](https://docs.gitlab.com/ee/api/)

## Contributing

If you encounter issues specific to your environment or have improvements to suggest for the script, feel free to contribute!

---
