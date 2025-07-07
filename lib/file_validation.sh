#!/bin/bash

# lib/file_validation.sh - Shared file validation and error handling functions
# This library provides common functions for file validation, error handling, and dependency checking

# Function to check if a command exists
command_exists() {
    command -v "$1" >/dev/null 2>&1
}

# Function to check dependencies
check_dependencies() {
    local missing_deps=()
    
    # Check for exiftool (required for image metadata)
    if ! command_exists exiftool; then
        missing_deps+=("exiftool")
    fi
    
    # Check for ffprobe (required for video metadata)
    if ! command_exists ffprobe; then
        missing_deps+=("ffprobe")
    fi
    
    # Check for sqlite3 (required for caching)
    if ! command_exists sqlite3; then
        missing_deps+=("sqlite3")
    fi
    
    # Check for bc (required for calculations)
    if ! command_exists bc; then
        missing_deps+=("bc")
    fi
    
    # Check for base64 (required for caching)
    if ! command_exists base64; then
        missing_deps+=("base64")
    fi
    
    if [ ${#missing_deps[@]} -gt 0 ]; then
        echo -e "${RED}Error: Missing required dependencies:${NC}"
        for dep in "${missing_deps[@]}"; do
            echo -e "  - $dep"
        done
        echo -e "\nPlease install the missing dependencies and try again."
        return 1
    fi
    
    return 0
}

# Function to validate directory
validate_directory() {
    local directory="$1"
    
    if [ -z "$directory" ]; then
        echo -e "${RED}Error: Directory path is required${NC}"
        return 1
    fi
    
    if [ ! -d "$directory" ]; then
        echo -e "${RED}Error: Directory does not exist: $directory${NC}"
        return 1
    fi
    
    if [ ! -r "$directory" ]; then
        echo -e "${RED}Error: Directory is not readable: $directory${NC}"
        return 1
    fi
    
    return 0
}

# Function to validate file
validate_file() {
    local file="$1"
    
    if [ -z "$file" ]; then
        return 1
    fi
    
    if [ ! -f "$file" ]; then
        return 1
    fi
    
    if [ ! -r "$file" ]; then
        return 1
    fi
    
    return 0
}

# Function to check if file is a supported image
is_supported_image() {
    local file="$1"
    local extension=$(echo "$file" | sed 's/.*\.//' | tr '[:upper:]' '[:lower:]')
    
    case "$extension" in
        jpg|jpeg|png|gif|bmp|tiff|tif|webp|heic|heif)
            return 0
            ;;
        *)
            return 1
            ;;
    esac
}

# Function to check if file is a supported video
is_supported_video() {
    local file="$1"
    local extension=$(echo "$file" | sed 's/.*\.//' | tr '[:upper:]' '[:lower:]')
    
    case "$extension" in
        mp4|avi|mov|mkv|wmv|flv|webm|m4v|3gp|mpg|mpeg)
            return 0
            ;;
        *)
            return 1
            ;;
    esac
}

# Function to check if file is a supported media file
is_supported_media() {
    local file="$1"
    
    if is_supported_image "$file" || is_supported_video "$file"; then
        return 0
    else
        return 1
    fi
}

# Function to get file extension
get_file_extension() {
    local file="$1"
    echo "$file" | sed 's/.*\.//' | tr '[:upper:]' '[:lower:]'
}

# Function to get file type (image/video)
get_file_type() {
    local file="$1"
    
    if is_supported_image "$file"; then
        echo "image"
    elif is_supported_video "$file"; then
        echo "video"
    else
        echo "unknown"
    fi
}

# Function to validate search string
validate_search_string() {
    local search_string="$1"
    
    if [ -z "$search_string" ]; then
        echo -e "${RED}Error: Search string is required${NC}"
        return 1
    fi
    
    return 0
}

# Function to validate regex pattern
validate_regex_pattern() {
    local pattern="$1"
    
    if [ -z "$pattern" ]; then
        echo -e "${RED}Error: Regex pattern is required${NC}"
        return 1
    fi
    
    # Test if the regex is valid
    if ! echo "test" | grep -E "$pattern" >/dev/null 2>&1; then
        echo -e "${RED}Error: Invalid regex pattern: $pattern${NC}"
        return 1
    fi
    
    return 0
}

# Function to validate GPS coordinates
validate_gps_coordinates() {
    local coordinates="$1"
    
    if [ -z "$coordinates" ]; then
        echo -e "${RED}Error: GPS coordinates are required${NC}"
        return 1
    fi
    
    # Check for decimal format (lat,lon)
    if [[ "$coordinates" =~ ^-?[0-9]+\.?[0-9]*,-?[0-9]+\.?[0-9]*$ ]]; then
        return 0
    fi
    
    # Check for DMS format (degrees, minutes, seconds)
    if [[ "$coordinates" =~ ^[0-9]+°[0-9]+'[0-9]+\.[0-9]*\"[NS],-?[0-9]+°[0-9]+'[0-9]+\.[0-9]*\"[EW]$ ]]; then
        return 0
    fi
    
    echo -e "${RED}Error: Invalid GPS coordinates format: $coordinates${NC}"
    echo -e "Expected formats:"
    echo -e "  Decimal: 37.7749,-122.4194"
    echo -e "  DMS: 37°46'29.6\"N,-122°25'9.8\"W"
    return 1
}

# Function to validate radius
validate_radius() {
    local radius="$1"
    
    if [ -z "$radius" ]; then
        echo -e "${RED}Error: Radius is required${NC}"
        return 1
    fi
    
    if ! [[ "$radius" =~ ^[0-9]+\.?[0-9]*$ ]]; then
        echo -e "${RED}Error: Invalid radius format: $radius${NC}"
        return 1
    fi
    
    if (( $(echo "$radius <= 0" | bc -l) )); then
        echo -e "${RED}Error: Radius must be greater than 0${NC}"
        return 1
    fi
    
    return 0
}

# Function to validate bounding box
validate_bounding_box() {
    local bbox="$1"
    
    if [ -z "$bbox" ]; then
        echo -e "${RED}Error: Bounding box is required${NC}"
        return 1
    fi
    
    # Check format: min_lat,max_lat,min_lon,max_lon
    if ! [[ "$bbox" =~ ^-?[0-9]+\.?[0-9]*,-?[0-9]+\.?[0-9]*,-?[0-9]+\.?[0-9]*,-?[0-9]+\.?[0-9]*$ ]]; then
        echo -e "${RED}Error: Invalid bounding box format: $bbox${NC}"
        echo -e "Expected format: min_lat,max_lat,min_lon,max_lon"
        return 1
    fi
    
    # Parse coordinates
    IFS=',' read -r min_lat max_lat min_lon max_lon <<< "$bbox"
    
    # Validate latitude range
    if (( $(echo "$min_lat < -90 || $max_lat > 90" | bc -l) )); then
        echo -e "${RED}Error: Latitude must be between -90 and 90${NC}"
        return 1
    fi
    
    # Validate longitude range
    if (( $(echo "$min_lon < -180 || $max_lon > 180" | bc -l) )); then
        echo -e "${RED}Error: Longitude must be between -180 and 180${NC}"
        return 1
    fi
    
    # Validate min < max
    if (( $(echo "$min_lat >= $max_lat" | bc -l) )); then
        echo -e "${RED}Error: min_lat must be less than max_lat${NC}"
        return 1
    fi
    
    if (( $(echo "$min_lon >= $max_lon" | bc -l) )); then
        echo -e "${RED}Error: min_lon must be less than max_lon${NC}"
        return 1
    fi
    
    return 0
}

# Function to validate fuzzy threshold
validate_fuzzy_threshold() {
    local threshold="$1"
    
    if [ -z "$threshold" ]; then
        echo -e "${RED}Error: Fuzzy threshold is required${NC}"
        return 1
    fi
    
    if ! [[ "$threshold" =~ ^[0-9]+$ ]]; then
        echo -e "${RED}Error: Invalid fuzzy threshold: $threshold${NC}"
        return 1
    fi
    
    if [ "$threshold" -lt 0 ] || [ "$threshold" -gt 100 ]; then
        echo -e "${RED}Error: Fuzzy threshold must be between 0 and 100${NC}"
        return 1
    fi
    
    return 0
}

# Function to validate worker count
validate_worker_count() {
    local workers="$1"
    
    if [ -z "$workers" ]; then
        echo -e "${RED}Error: Worker count is required${NC}"
        return 1
    fi
    
    if ! [[ "$workers" =~ ^[0-9]+$ ]]; then
        echo -e "${RED}Error: Invalid worker count: $workers${NC}"
        return 1
    fi
    
    if [ "$workers" -lt 1 ] || [ "$workers" -gt 16 ]; then
        echo -e "${RED}Error: Worker count must be between 1 and 16${NC}"
        return 1
    fi
    
    return 0
}

# Function to validate batch size
validate_batch_size() {
    local batch_size="$1"
    
    if [ -z "$batch_size" ]; then
        echo -e "${RED}Error: Batch size is required${NC}"
        return 1
    fi
    
    if ! [[ "$batch_size" =~ ^[0-9]+$ ]]; then
        echo -e "${RED}Error: Invalid batch size: $batch_size${NC}"
        return 1
    fi
    
    if [ "$batch_size" -lt 1 ] || [ "$batch_size" -gt 1000 ]; then
        echo -e "${RED}Error: Batch size must be between 1 and 1000${NC}"
        return 1
    fi
    
    return 0
}

# Function to validate memory limit
validate_memory_limit() {
    local limit="$1"
    
    if [ -z "$limit" ]; then
        return 0  # Optional parameter
    fi
    
    if ! [[ "$limit" =~ ^[0-9]+(MB|GB)$ ]]; then
        echo -e "${RED}Error: Invalid memory limit format: $limit${NC}"
        echo -e "Expected format: 256MB or 1GB"
        return 1
    fi
    
    local size="${BASH_REMATCH[1]}"
    if [ "$size" -lt 1 ]; then
        echo -e "${RED}Error: Memory limit must be greater than 0${NC}"
        return 1
    fi
    
    return 0
}

# Function to validate cache size limit
validate_cache_size_limit() {
    local limit="$1"
    
    if [ -z "$limit" ]; then
        return 0  # Optional parameter
    fi
    
    if ! [[ "$limit" =~ ^[0-9]+(MB|GB)$ ]]; then
        echo -e "${RED}Error: Invalid cache size limit format: $limit${NC}"
        echo -e "Expected format: 100MB or 1GB"
        return 1
    fi
    
    local size="${BASH_REMATCH[1]}"
    if [ "$size" -lt 1 ]; then
        echo -e "${RED}Error: Cache size limit must be greater than 0${NC}"
        return 1
    fi
    
    return 0
}

# Function to validate output file
validate_output_file() {
    local output_file="$1"
    
    if [ -z "$output_file" ]; then
        echo -e "${RED}Error: Output file path is required${NC}"
        return 1
    fi
    
    local output_dir=$(dirname "$output_file")
    if [ "$output_dir" != "." ] && [ ! -d "$output_dir" ]; then
        echo -e "${RED}Error: Output directory does not exist: $output_dir${NC}"
        return 1
    fi
    
    if [ -f "$output_file" ] && [ ! -w "$output_file" ]; then
        echo -e "${RED}Error: Output file is not writable: $output_file${NC}"
        return 1
    fi
    
    return 0
}

# Function to handle errors gracefully
handle_error() {
    local error_message="$1"
    local exit_code="${2:-1}"
    
    echo -e "${RED}Error: $error_message${NC}" >&2
    exit "$exit_code"
}

# Function to check if running in a terminal
is_terminal() {
    [ -t 1 ]
}

# Function to check if colors are supported
supports_colors() {
    is_terminal && [ -n "$TERM" ] && [ "$TERM" != "dumb" ]
}

# Function to initialize colors
init_colors() {
    if supports_colors; then
        RED='\033[0;31m'
        GREEN='\033[0;32m'
        YELLOW='\033[1;33m'
        BLUE='\033[0;34m'
        CYAN='\033[0;36m'
        NC='\033[0m' # No Color
    else
        RED=''
        GREEN=''
        YELLOW=''
        BLUE=''
        CYAN=''
        NC=''
    fi
} 