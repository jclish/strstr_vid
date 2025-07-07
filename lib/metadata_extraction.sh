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

# Function to convert DMS to decimal degrees
dms_to_decimal() {
    local dms="$1"
    
    # If it's already a decimal number, return it
    if [[ "$dms" =~ ^-?[0-9]+\.?[0-9]*$ ]]; then
        echo "$dms"
        return
    fi
    
    # For DMS format, we'll use a simpler approach
    # For now, just return the input if it's not a simple decimal
    # This avoids the complex regex that's causing issues
    echo "$dms"
}

# Function to calculate distance between two GPS coordinates (Haversine formula)
calculate_distance() {
    local lat1="$1"
    local lon1="$2"
    local lat2="$3"
    local lon2="$4"
    
    # Convert to radians
    local pi=$(echo "4*a(1)" | bc -l)
    local lat1_rad=$(echo "$lat1 * $pi / 180" | bc -l)
    local lon1_rad=$(echo "$lon1 * $pi / 180" | bc -l)
    local lat2_rad=$(echo "$lat2 * $pi / 180" | bc -l)
    local lon2_rad=$(echo "$lon2 * $pi / 180" | bc -l)
    
    # Haversine formula
    local dlat=$(echo "$lat2_rad - $lat1_rad" | bc -l)
    local dlon=$(echo "$lon2_rad - $lon1_rad" | bc -l)
    local a=$(echo "s($dlat/2)^2 + c($lat1_rad) * c($lat2_rad) * s($dlon/2)^2" | bc -l)
    local c=$(echo "2 * a(sqrt($a))" | bc -l)
    local distance=$(echo "6371 * $c" | bc -l)  # Earth radius in km
    
    echo "$distance"
}

# Function to check if coordinates are within radius
is_within_radius() {
    local lat="$1"
    local lon="$2"
    local center_lat="$3"
    local center_lon="$4"
    local radius_km="$5"
    
    # Check if we have valid coordinates
    if [ -z "$lat" ] || [ -z "$lon" ] || [ "$lat" = "0" ] || [ "$lon" = "0" ]; then
        return 1
    fi
    
    local distance=$(calculate_distance "$lat" "$lon" "$center_lat" "$center_lon")
    
    # Check if distance is within radius
    if (( $(echo "$distance <= $radius_km" | bc -l) )); then
        echo "$distance"
        return 0
    else
        return 1
    fi
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