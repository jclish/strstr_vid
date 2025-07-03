#!/bin/bash

# search_metadata.sh - Search for strings in video and picture file metadata
# Usage: ./search_metadata.sh <search_string> <directory> [options]

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Default values
VERBOSE=false
CASE_SENSITIVE=false
RECURSIVE=false
SHOW_METADATA=false

# Function to print usage
print_usage() {
    cat << EOF
Usage: $0 <search_string> <directory> [options]

Search for a string in video and picture file metadata.

Arguments:
  search_string    The string to search for in metadata
  directory        The directory to search in

Options:
  -v, --verbose          Show detailed output including full metadata
  -i, --case-insensitive Case-insensitive search (default: case-sensitive)
  -r, --recursive        Search recursively in subdirectories
  -m, --show-metadata    Show full metadata for matching files
  -h, --help            Show this help message

Examples:
  $0 "Canon" /path/to/photos
  $0 "iPhone" /path/to/videos -r -i
  $0 "2023" /path/to/media -v -m

Supported file types:
  Images: jpg, jpeg, png, gif, bmp, tiff, tif, webp, heic, heif
  Videos: mp4, avi, mov, mkv, wmv, flv, webm, m4v, 3gp, mpg, mpeg

Requirements:
  - exiftool (for image metadata)
  - ffprobe (for video metadata, part of ffmpeg)
EOF
}

# Function to check if a command exists
command_exists() {
    command -v "$1" >/dev/null 2>&1
}

# Function to check dependencies
check_dependencies() {
    local missing_deps=()
    
    if ! command_exists exiftool; then
        missing_deps+=("exiftool")
    fi
    
    if ! command_exists ffprobe; then
        missing_deps+=("ffprobe")
    fi
    
    if [ ${#missing_deps[@]} -ne 0 ]; then
        echo -e "${RED}Error: Missing required dependencies:${NC}"
        for dep in "${missing_deps[@]}"; do
            echo -e "  - ${YELLOW}$dep${NC}"
        done
        echo
        echo "Install instructions:"
        echo "  macOS: brew install exiftool ffmpeg"
        echo "  Ubuntu/Debian: sudo apt-get install exiftool ffmpeg"
        echo "  CentOS/RHEL: sudo yum install perl-Image-ExifTool ffmpeg"
        exit 1
    fi
}

# Function to search in image metadata
search_image_metadata() {
    local file="$1"
    local search_string="$2"
    local found=false
    
    if [ "$VERBOSE" = true ]; then
        echo -e "${BLUE}Searching in image: $file${NC}"
    fi
    
    # Use exiftool to extract metadata and search for the string
    if exiftool "$file" 2>/dev/null | grep -q "$search_string"; then
        found=true
        echo -e "${GREEN}✓ Found in image: $file${NC}"
        
        if [ "$SHOW_METADATA" = true ]; then
            echo -e "${YELLOW}Full metadata:${NC}"
            exiftool "$file" 2>/dev/null | sed 's/^/  /'
            echo
        fi
    fi
    
    [ "$found" = true ]
}

# Function to search in video metadata
search_video_metadata() {
    local file="$1"
    local search_string="$2"
    local found=false
    
    if [ "$VERBOSE" = true ]; then
        echo -e "${BLUE}Searching in video: $file${NC}"
    fi
    
    # Use ffprobe to extract metadata and search for the string
    if ffprobe -v quiet -print_format json -show_format -show_streams "$file" 2>/dev/null | grep -q "$search_string"; then
        found=true
        echo -e "${GREEN}✓ Found in video: $file${NC}"
        
        if [ "$SHOW_METADATA" = true ]; then
            echo -e "${YELLOW}Full metadata:${NC}"
            ffprobe -v quiet -print_format json -show_format -show_streams "$file" 2>/dev/null | python3 -m json.tool 2>/dev/null || ffprobe -v quiet -print_format json -show_format -show_streams "$file" 2>/dev/null
            echo
        fi
    fi
    
    [ "$found" = true ]
}

# Function to process a single file
process_file() {
    local file="$1"
    local search_string="$2"
    local found=false
    
    # Get file extension
    local ext="${file##*.}"
    ext=$(echo "$ext" | tr '[:upper:]' '[:lower:]')
    
    # Check if it's an image file
    case "$ext" in
        jpg|jpeg|png|gif|bmp|tiff|tif|webp|heic|heif)
            if search_image_metadata "$file" "$search_string"; then
                found=true
            fi
            ;;
        mp4|avi|mov|mkv|wmv|flv|webm|m4v|3gp|mpg|mpeg)
            if search_video_metadata "$file" "$search_string"; then
                found=true
            fi
            ;;
        *)
            if [ "$VERBOSE" = true ]; then
                echo -e "${YELLOW}Skipping unsupported file type: $file${NC}"
            fi
            ;;
    esac
    
    [ "$found" = true ]
}

# Function to search directory
search_directory() {
    local dir="$1"
    local search_string="$2"
    local total_files=0
    local found_files=0
    
    if [ "$VERBOSE" = true ]; then
        echo -e "${BLUE}Searching directory: $dir${NC}"
    fi
    
    # Find all files in directory
    local find_cmd="find \"$dir\" -type f"
    if [ "$RECURSIVE" = false ]; then
        find_cmd="$find_cmd -maxdepth 1"
    fi
    
    while IFS= read -r -d '' file; do
        ((total_files++))
        if process_file "$file" "$search_string"; then
            ((found_files++))
        fi
    done < <(eval "$find_cmd" -print0)
    
    echo
    echo -e "${BLUE}Search Summary:${NC}"
    echo -e "  Total files processed: $total_files"
    echo -e "  Files with matches: $found_files"
}

# Main script
main() {
    # Parse command line arguments
    while [[ $# -gt 0 ]]; do
        case $1 in
            -v|--verbose)
                VERBOSE=true
                shift
                ;;
            -i|--case-insensitive)
                CASE_SENSITIVE=false
                shift
                ;;
            -r|--recursive)
                RECURSIVE=true
                shift
                ;;
            -m|--show-metadata)
                SHOW_METADATA=true
                shift
                ;;
            -h|--help)
                print_usage
                exit 0
                ;;
            -*)
                echo -e "${RED}Error: Unknown option $1${NC}"
                print_usage
                exit 1
                ;;
            *)
                break
                ;;
        esac
    done
    
    # Check if we have the required arguments
    if [ $# -lt 2 ]; then
        echo -e "${RED}Error: Missing required arguments${NC}"
        print_usage
        exit 1
    fi
    
    local search_string="$1"
    local directory="$2"
    
    # Check if directory exists
    if [ ! -d "$directory" ]; then
        echo -e "${RED}Error: Directory '$directory' does not exist${NC}"
        exit 1
    fi
    
    # Check dependencies
    check_dependencies
    
    # Handle case sensitivity
    if [ "$CASE_SENSITIVE" = false ]; then
        search_string=$(echo "$search_string" | tr '[:upper:]' '[:lower:]')
    fi
    
    echo -e "${BLUE}Searching for: '$search_string'${NC}"
    echo -e "${BLUE}Directory: $directory${NC}"
    if [ "$RECURSIVE" = true ]; then
        echo -e "${BLUE}Mode: Recursive${NC}"
    else
        echo -e "${BLUE}Mode: Non-recursive${NC}"
    fi
    echo
    
    # Perform the search
    search_directory "$directory" "$search_string"
}

# Run main function with all arguments
main "$@" 