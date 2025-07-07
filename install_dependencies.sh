#!/bin/bash

# install_dependencies.sh - Install required dependencies for metadata search tool

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Function to detect OS
detect_os() {
    if [[ "$OSTYPE" == "linux-gnu"* ]]; then
        if command -v apt-get >/dev/null 2>&1; then
            echo "ubuntu"
        elif command -v yum >/dev/null 2>&1; then
            echo "centos"
        elif command -v dnf >/dev/null 2>&1; then
            echo "fedora"
        else
            echo "linux"
        fi
    elif [[ "$OSTYPE" == "darwin"* ]]; then
        echo "macos"
    else
        echo "unknown"
    fi
}

# Function to check if a command exists
command_exists() {
    command -v "$1" >/dev/null 2>&1
}

# Function to install on macOS
install_macos() {
    echo -e "${BLUE}Detected macOS${NC}"
    
    if ! command_exists brew; then
        echo -e "${RED}Homebrew not found. Please install Homebrew first:${NC}"
        echo "  /bin/bash -c \"\$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)\""
        return 1
    fi
    
    echo -e "${YELLOW}Installing dependencies via Homebrew...${NC}"
    
    if ! command_exists exiftool; then
        echo "Installing exiftool..."
        brew install exiftool
    else
        echo -e "${GREEN}exiftool already installed${NC}"
    fi
    
    if ! command_exists ffprobe; then
        echo "Installing ffmpeg (includes ffprobe)..."
        brew install ffmpeg
    else
        echo -e "${GREEN}ffprobe already installed${NC}"
    fi
}

# Function to install on Ubuntu/Debian
install_ubuntu() {
    echo -e "${BLUE}Detected Ubuntu/Debian${NC}"
    
    echo -e "${YELLOW}Updating package list...${NC}"
    sudo apt-get update
    
    echo -e "${YELLOW}Installing dependencies...${NC}"
    
    if ! command_exists exiftool; then
        echo "Installing exiftool..."
        sudo apt-get install -y exiftool
    else
        echo -e "${GREEN}exiftool already installed${NC}"
    fi
    
    if ! command_exists ffprobe; then
        echo "Installing ffmpeg (includes ffprobe)..."
        sudo apt-get install -y ffmpeg
    else
        echo -e "${GREEN}ffprobe already installed${NC}"
    fi
}

# Function to install on CentOS/RHEL
install_centos() {
    echo -e "${BLUE}Detected CentOS/RHEL${NC}"
    
    echo -e "${YELLOW}Installing dependencies...${NC}"
    
    if ! command_exists exiftool; then
        echo "Installing exiftool..."
        sudo yum install -y perl-Image-ExifTool
    else
        echo -e "${GREEN}exiftool already installed${NC}"
    fi
    
    if ! command_exists ffprobe; then
        echo "Installing ffmpeg (includes ffprobe)..."
        sudo yum install -y ffmpeg
    else
        echo -e "${GREEN}ffprobe already installed${NC}"
    fi
}

# Function to install on Fedora
install_fedora() {
    echo -e "${BLUE}Detected Fedora${NC}"
    
    echo -e "${YELLOW}Installing dependencies...${NC}"
    
    if ! command_exists exiftool; then
        echo "Installing exiftool..."
        sudo dnf install -y perl-Image-ExifTool
    else
        echo -e "${GREEN}exiftool already installed${NC}"
    fi
    
    if ! command_exists ffprobe; then
        echo "Installing ffmpeg (includes ffprobe)..."
        sudo dnf install -y ffmpeg
    else
        echo -e "${GREEN}ffprobe already installed${NC}"
    fi
}

# Function to verify installation
verify_installation() {
    echo
    echo -e "${BLUE}=== Verifying Installation ===${NC}"
    
    local all_good=true
    
    if command_exists exiftool; then
        echo -e "${GREEN}✓ exiftool is installed${NC}"
        echo "  Version: $(exiftool -ver)"
    else
        echo -e "${RED}✗ exiftool is not installed${NC}"
        all_good=false
    fi
    
    if command_exists ffprobe; then
        echo -e "${GREEN}✓ ffprobe is installed${NC}"
        echo "  Version: $(ffprobe -version | head -n1)"
    else
        echo -e "${RED}✗ ffprobe is not installed${NC}"
        all_good=false
    fi
    
    if [ "$all_good" = true ]; then
        echo
        echo -e "${GREEN}=== Installation Complete! ===${NC}"
        echo "You can now use the metadata search tool:"
        echo "  ./search_metadata.sh \"search_string\" /path/to/directory"
        echo
        echo "For examples, run:"
        echo "  ./test_example.sh"
    else
        echo
        echo -e "${RED}=== Installation Failed ===${NC}"
        echo "Please check the error messages above and try again."
        return 1
    fi
}

# Main installation process
main() {
    local os=$(detect_os)
    
    case $os in
        "macos")
            install_macos
            ;;
        "ubuntu")
            install_ubuntu
            ;;
        "centos")
            install_centos
            ;;
        "fedora")
            install_fedora
            ;;
        *)
            echo -e "${RED}Unsupported operating system: $os${NC}"
            echo "Please install the dependencies manually:"
            echo "  - exiftool (for image metadata)"
            echo "  - ffmpeg (for video metadata, includes ffprobe)"
            exit 1
            ;;
    esac
    
    verify_installation
}

# Only run main if script is executed directly
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    echo -e "${BLUE}=== Metadata Search Tool - Dependency Installer ===${NC}"
    echo
    main "$@"
fi 