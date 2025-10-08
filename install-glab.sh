#!/bin/bash

# Script to install/update GitLab CLI (glab) from sources
# Usage: ./install-glab.sh [version]
# If no version is specified, uses the latest available version
#
# Required dependencies (automatically installed if missing):
# - wget : file downloading
# - dpkg : .deb package installation
# - jq : JSON parsing of GitLab API responses
# - git : for glab Git features
# - ssh : for SSH authentication with GitLab
# - gpg : for signature verification (recommended)

set -e  # Stop on error

# Global variables
TEMP_DIR=""

# Colors for display
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Display functions with colors
print_info() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

print_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

print_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

print_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

# Check dependencies
check_dependencies() {
    local deps=("wget" "dpkg" "jq" "git" "ssh" "gpg")
    local missing_deps=()

    for dep in "${deps[@]}"; do
        if ! command -v "$dep" &> /dev/null; then
            missing_deps+=("$dep")
        fi
    done

    if [ ${#missing_deps[@]} -ne 0 ]; then
        print_warning "Missing dependencies detected: ${missing_deps[*]}"
        install_dependencies "${missing_deps[@]}"
    fi
}

# Install missing dependencies
install_dependencies() {
    local deps=("$@")
    print_info "Installing missing dependencies..."

    # Map dependencies to Ubuntu/Debian package names
    local packages=()
    for dep in "${deps[@]}"; do
        case "$dep" in
            "wget") packages+=("wget") ;;
            "dpkg") packages+=("dpkg") ;;
            "jq") packages+=("jq") ;;
            "git") packages+=("git") ;;
            "ssh") packages+=("openssh-client") ;;
            "gpg") packages+=("gnupg2") ;;
            *) packages+=("$dep") ;;
        esac
    done

    # Check if we can use sudo
    if ! sudo -n true 2>/dev/null; then
        print_info "Administrator privileges required to install dependencies"
    fi

    # Update package list
    print_info "Updating package list..."
    if ! sudo apt-get update; then
        print_error "Unable to update package list"
        exit 1
    fi

    # Install dependencies
    print_info "Installing packages: ${packages[*]}"
    if sudo apt-get install -y "${packages[@]}"; then
        print_success "Dependencies installed successfully"
    else
        print_error "Failed to install dependencies"
        print_info "Please install manually: sudo apt-get install ${packages[*]}"
        exit 1
    fi

    # Check that all dependencies are now available
    local still_missing=()
    for dep in "${deps[@]}"; do
        if ! command -v "$dep" &> /dev/null; then
            still_missing+=("$dep")
        fi
    done

    if [ ${#still_missing[@]} -ne 0 ]; then
        print_error "Some dependencies are still missing: ${still_missing[*]}"
        exit 1
    fi
}

# Get the latest version from GitLab API
get_latest_version() {
    local api_url="https://gitlab.com/api/v4/projects/gitlab-org%2Fcli/releases"
    
    # Use wget with jq for robust JSON parsing
    local version
    version=$(wget -qO- "$api_url" | jq -r '.[0].tag_name' | sed 's/^v//')

    if [ -z "$version" ] || [ "$version" = "null" ]; then
        print_error "Unable to retrieve the latest version"
        print_info "Check your internet connection and try again"
        exit 1
    fi

    echo "$version"
}

# Validate version format
validate_version_format() {
    local version=$1

    # Check that the version follows the X.Y.Z format (e.g., 1.61.0)
    if [[ ! "$version" =~ ^[0-9]+\.[0-9]+\.[0-9]+$ ]]; then
        print_error "Invalid version format: '$version'"
        print_info "Expected format is X.Y.Z (e.g., 1.61.0, 1.62.1)"
        print_info "Examples of valid versions:"
        print_info "  - 1.61.0"
        print_info "  - 1.62.1"
        print_info "  - 2.0.0"
        return 1
    fi

    return 0
}

# Check if glab is already installed and its version
check_current_version() {
    if command -v glab &> /dev/null; then
        local current_version=$(glab version 2>/dev/null | grep -oP 'glab \K[0-9.]+' || echo "unknown")
        echo "$current_version"
    else
        echo "not_installed"
    fi
}

# Clean temporary files
cleanup() {
    if [ -n "$TEMP_DIR" ] && [ -d "$TEMP_DIR" ]; then
        print_info "Cleaning temporary directory..."
        rm -rf "$TEMP_DIR"
    fi
}

# Install glab
install_glab() {
    local version=$1
    TEMP_DIR=$(mktemp -d)
    local current_dir=$(pwd)

    # Ensure temporary directory will be cleaned up
    trap 'cleanup; exit 1' INT TERM EXIT

    cd "$TEMP_DIR"

    # File URLs
    local base_url="https://gitlab.com/gitlab-org/cli/-/releases/v${version}/downloads"
    local deb_file="glab_${version}_linux_amd64.deb"

    print_info "Downloading glab v${version}..."

    # Download the .deb file directly
    if wget --progress=bar:force:noscroll "${base_url}/${deb_file}" 2>&1; then
        print_success "Download complete"
    else
        print_error "Download failed"
        cd "$current_dir"
        cleanup
        exit 1
    fi

    # Install the package
    print_info "Installing glab..."
    if sudo dpkg -i "$deb_file" 2>/dev/null; then
        print_success "glab v${version} installed successfully"
    else
        print_warning "Failed to install with dpkg, resolving dependencies..."
        sudo apt-get update
        sudo apt-get install -f -y
        if sudo dpkg -i "$deb_file"; then
            print_success "glab v${version} installed successfully"
        else
            print_error "Installation failed"
            cd "$current_dir"
            cleanup
            exit 1
        fi
    fi

    # Return to original directory and clean up
    cd "$current_dir"
    trap - INT TERM EXIT  # Disable trap
    cleanup
}

# Verify that glab is working correctly
verify_glab_installation() {
    print_info "Verifying glab functionality..."
    
    # Basic version command test
    if ! glab version &>/dev/null; then
        print_warning "Potential issue: unable to run 'glab version'"
        return 1
    fi
    
    # Help test
    if ! glab --help &>/dev/null; then
        print_warning "Potential issue: unable to display glab help"
        return 1
    fi
    
    # Check that important dependencies are available for glab
    local glab_deps=("git" "ssh")
    local missing_glab_deps=()
    
    for dep in "${glab_deps[@]}"; do
        if ! command -v "$dep" &> /dev/null; then
            missing_glab_deps+=("$dep")
        fi
    done
    
    if [ ${#missing_glab_deps[@]} -ne 0 ]; then
        print_warning "Missing dependencies for optimal glab functionality: ${missing_glab_deps[*]}"
        print_info "Some features may not work properly"
        return 1
    fi
    
    print_success "glab appears to be working correctly"
    return 0
}

# Uninstallation function
uninstall_glab() {
    print_info "Uninstalling GitLab CLI (glab)"
    echo

    # Check if glab is installed
    if ! command -v glab &> /dev/null; then
        print_warning "glab is not installed on this system"
        exit 0
    fi

    # Display current version
    local current_version=$(glab version 2>/dev/null | grep -oP 'glab \K[0-9.]+' || echo "unknown")
    print_info "Currently installed version: v${current_version}"
    echo

    # Ask for confirmation
    print_warning "This action will uninstall glab from your system."
    print_info "Do you also want to remove configuration files? (y/N)"
    
    read -r delete_config
    echo

    # Uninstall the package
    print_info "Uninstalling glab..."
    
    if sudo dpkg -r glab 2>/dev/null; then
        print_success "glab has been uninstalled successfully"
    else
        print_error "Failed to uninstall glab package"
        print_info "Trying with apt-get remove..."
        if sudo apt-get remove -y glab 2>/dev/null; then
            print_success "glab has been uninstalled successfully"
        else
            print_error "Unable to uninstall glab"
            exit 1
        fi
    fi

    # Remove configuration files if requested
    case "$delete_config" in
        [yY]|[yY][eE][sS]|[oO]|[oO][uU][iI])
            if [ -d "$HOME/.config/glab-cli" ]; then
                print_info "Removing configuration files..."
                rm -rf "$HOME/.config/glab-cli"
                print_success "Configuration files removed"
            else
                print_info "No configuration files found"
            fi
            ;;
        *)
            print_info "Configuration files kept in: $HOME/.config/glab-cli"
            print_info "You can remove them manually with: rm -rf ~/.config/glab-cli"
            ;;
    esac

    echo
    print_success "Uninstallation complete!"
    
    # Check that glab is no longer available
    if command -v glab &> /dev/null; then
        print_warning "glab still seems available, you may need to close and reopen your terminal"
    fi
}

# Check if glab is configured and offer configuration
check_and_offer_configuration() {
    # Use glab auth status to check if at least one valid configuration exists
    print_info "Checking glab configuration..."
    
    if glab auth status &>/dev/null; then
        # At least one valid configuration exists
        print_success "Valid glab configuration detected."
    else
        # No valid configuration found
        echo
        print_info "No valid glab configuration detected."
        print_info "Do you want to configure GitLab access now? (y/N)"
        
        read -r response
        case "$response" in
            [yY]|[yY][eE][sS]|[oO]|[oO][uU][iI])
                echo
                print_info "Starting glab configuration..."
                glab auth login
                ;;
            *)
                print_info "Configuration deferred. Use 'glab auth login' when you're ready."
                ;;
        esac
    fi
}

# Main function
main() {
    local target_version=""

    print_info "GitLab CLI (glab) installation/update script"
    echo

    # Check dependencies
    check_dependencies

    # Determine version to install
    if [ $# -eq 0 ]; then
        print_info "Retrieving latest version..."
        target_version=$(get_latest_version)
        print_info "Latest version available: v${target_version}"
    else
        target_version=$1
        print_info "Requested version: v${target_version}"

        # Validate user-provided version format
        if ! validate_version_format "$target_version"; then
            exit 1
        fi
    fi

    # Check currently installed version
    local current_version=$(check_current_version)

    if [ "$current_version" = "not_installed" ]; then
        print_info "glab is not installed, installing..."
    elif [ "$current_version" = "$target_version" ]; then
        print_success "glab v${target_version} is already installed"
        
        # Check if glab is working correctly
        verify_glab_installation
        
        # Offer configuration if not yet configured
        check_and_offer_configuration
        
        exit 0
    else
        print_info "Current version: v${current_version}"
        print_info "Updating to v${target_version}..."
    fi

    # Install/update
    install_glab "$target_version"

    # Verify installation
    if command -v glab &> /dev/null; then
        local installed_version=$(glab version 2>/dev/null | grep -oP 'glab \K[0-9.]+' || echo "unknown")
        print_success "Installation verified: glab v${installed_version}"
        
        # Verify functionality
        verify_glab_installation
        
        # Offer configuration if not yet configured
        check_and_offer_configuration
        
        echo
        print_info "You can now use 'glab' in your terminal"
        print_info "Start with: 'glab auth login' to authenticate"
    else
        print_error "Problem with installation, glab is not available"
        exit 1
    fi
}

# Signal handling to clean up on interruption
trap cleanup EXIT INT TERM

# Options handling
if [[ "$1" == "-h" || "$1" == "--help" ]]; then
    echo "GitLab CLI (glab) installation/update script"
    echo
    echo "Usage: $0 [OPTIONS] [version]"
    echo
    echo "Options:"
    echo "  --uninstall    Uninstall glab from the system"
    echo "  -h, --help     Display this help"
    echo
    echo "Arguments:"
    echo "  version        Specific version to install in X.Y.Z format (e.g., 1.61.0)"
    echo "                 If not specified, installs the latest version"
    echo
    echo "Dependencies (automatically installed if missing):"
    echo "  - wget         : file downloading"
    echo "  - dpkg         : .deb package installation"
    echo "  - jq           : JSON parsing of GitLab API responses"
    echo "  - git          : for glab Git features"
    echo "  - ssh          : for SSH authentication with GitLab"
    echo "  - gpg          : for signature verification"
    echo
    echo "Examples:"
    echo "  $0                # Installs the latest version"
    echo "  $0 1.61.0         # Installs version 1.61.0"
    echo "  $0 --uninstall    # Uninstalls glab"
    echo
    echo "Expected version format: X.Y.Z where X, Y, Z are numbers"
    echo
    echo "After installation, use 'glab auth login' to authenticate"
    exit 0
fi

# Check if --uninstall option is passed
if [[ "$1" == "--uninstall" ]]; then
    uninstall_glab
    exit 0
fi

# Execute main script
main "$@"
