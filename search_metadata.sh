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

# Arrays to store results for JSON/CSV output
declare -a SEARCH_RESULTS
declare -a SEARCH_RESULTS_JSON
declare -a SEARCH_RESULTS_CSV

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
    echo "File Path,File Type,Search String,Search Field,Match Type,File Size,Last Modified,GPS Latitude,GPS Longitude"
    
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
                json_result="$json_result\n    }"
                SEARCH_RESULTS_JSON+=("$json_result")
            fi
            
            if [ "$CSV_OUTPUT" = true ]; then
                local csv_result="$(escape_csv "$file"),$(escape_csv "$file_type"),$(escape_csv "$search_string"),$(escape_csv "${SEARCH_FIELD:-""}"),$(escape_csv "metadata"),$(escape_csv "$file_size"),$(escape_csv "$last_modified"),$(escape_csv "$gps_lat"),$(escape_csv "$gps_lon")"
                SEARCH_RESULTS_CSV+=("$csv_result")
            fi
        fi
        
        if [ "$SHOW_METADATA" = true ]; then
            echo -e "${YELLOW}Full metadata:${NC}"
            exiftool "$file" 2>/dev/null | sed 's/^/  /'
            if [ -n "$gps_lat" ] && [ -n "$gps_lon" ]; then
                echo -e "${CYAN}  GPS: $gps_lat, $gps_lon${NC}"
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
                json_result="$json_result\n    }"
                SEARCH_RESULTS_JSON+=("$json_result")
            fi
            
            if [ "$CSV_OUTPUT" = true ]; then
                local csv_result="$(escape_csv "$file"),$(escape_csv "$file_type"),$(escape_csv "$search_string"),$(escape_csv "${SEARCH_FIELD:-""}"),$(escape_csv "metadata"),$(escape_csv "$file_size"),$(escape_csv "$last_modified"),$(escape_csv "$gps_lat"),$(escape_csv "$gps_lon")"
                SEARCH_RESULTS_CSV+=("$csv_result")
            fi
        fi
        
        if [ "$SHOW_METADATA" = true ]; then
            echo -e "${YELLOW}Full metadata:${NC}"
            ffprobe -v quiet -print_format json -show_format -show_streams "$file" 2>/dev/null | python3 -m json.tool 2>/dev/null || ffprobe -v quiet -print_format json -show_format -show_streams "$file" 2>/dev/null
            if [ -n "$gps_lat" ] && [ -n "$gps_lon" ]; then
                echo -e "${CYAN}  GPS: $gps_lat, $gps_lon${NC}"
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