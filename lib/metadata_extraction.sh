#!/bin/bash

# lib/metadata_extraction.sh - Shared metadata extraction functions
# This library provides common functions for extracting metadata from media files

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

# Function to extract metadata field from exiftool output
extract_metadata_field() {
    local metadata="$1"
    local field="$2"
    # Use grep and sed for more flexible field matching
    local value=$(echo "$metadata" | LC_ALL=C grep -E "^[[:space:]]*$field[[:space:]]*:" | sed 's/^[[:space:]]*[^:]*:[[:space:]]*//' | head -1)
    echo "$value"
}

# Function to extract GPS coordinates from exiftool
extract_gps_from_exiftool() {
    local file="$1"
    local lat=""
    local lon=""
    local gps_data
    gps_data=$(exiftool -c '%.8f' -GPSLatitude -GPSLongitude "$file" 2>/dev/null)
    lat=$(echo "$gps_data" | awk -F': ' '/GPS Latitude/ {print $2}' | head -1)
    lon=$(echo "$gps_data" | awk -F': ' '/GPS Longitude/ {print $2}' | head -1)
    
    # Handle longitude with direction suffix (W/E)
    if [[ "$lon" =~ W$ ]]; then
        lon="-${lon% W}"
    elif [[ "$lon" =~ E$ ]]; then
        lon="${lon% E}"
    fi
    
    echo "$lat|$lon"
}

# Function to extract GPS coordinates from ffprobe
extract_gps_from_ffprobe() {
    local file="$1"
    local lat=""
    local lon=""
    local ffprobe_json
    ffprobe_json=$(ffprobe -v quiet -print_format json -show_format -show_streams "$file" 2>/dev/null)
    lat=$(echo "$ffprobe_json" | grep -E 'location|latitude' | grep -o '[-0-9.]*' | head -1)
    lon=$(echo "$ffprobe_json" | grep -E 'location|longitude' | grep -o '[-0-9.]*' | tail -1)
    echo "$lat|$lon"
}

# Function to extract image metadata using exiftool
extract_image_metadata() {
    local file="$1"
    exiftool "$file" 2>/dev/null
}

# Function to extract video metadata using ffprobe
extract_video_metadata() {
    local file="$1"
    ffprobe -v quiet -print_format json -show_format -show_streams "$file" 2>/dev/null
}

# Function to extract video metadata using exiftool (fallback)
extract_video_metadata_exiftool() {
    local file="$1"
    exiftool "$file" 2>/dev/null
}

# Function to get file type based on extension
get_file_type() {
    local file="$1"
    local ext="${file##*.}"
    ext=$(echo "$ext" | tr '[:upper:]' '[:lower:]')
    
    case "$ext" in
        jpg|jpeg|png|gif|bmp|tiff|tif|webp|heic|heif)
            echo "image"
            ;;
        mp4|avi|mov|mkv|wmv|flv|webm|m4v|3gp|mpg|mpeg)
            echo "video"
            ;;
        *)
            echo "unknown"
            ;;
    esac
}

# Function to check if file is supported
is_supported_file() {
    local file="$1"
    local file_type=$(get_file_type "$file")
    [ "$file_type" != "unknown" ]
} 