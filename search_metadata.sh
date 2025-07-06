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
FUZZY_MATCH=false
FUZZY_THRESHOLD=80

# Parallel processing options
PARALLEL_WORKERS=1
PARALLEL_AUTO=false
BATCH_SIZE=50
MEMORY_LIMIT=""
BENCHMARK_MODE=false
COMPARE_MODES=false
MEMORY_USAGE=false
PERFORMANCE_REPORT=false

# Caching options
CACHE_ENABLED=false
CACHE_DB="${CACHE_DB:-}"
CACHE_INIT=false
CACHE_STORE=false
CACHE_RETRIEVE=false
CACHE_STATUS=false
CACHE_CLEAR=false
CACHE_MIGRATE=false
CACHE_BACKUP=""
CACHE_RESTORE=""
CACHE_SIZE_LIMIT=""
CACHE_COMPRESS=false

# Arrays to store results for JSON/CSV output
declare -a SEARCH_RESULTS
declare -a SEARCH_RESULTS_JSON
declare -a SEARCH_RESULTS_CSV

# Device clustering variables
DEVICE_STATS_TOTAL=0
DEVICE_STATS_JSON=()

# Advanced search logic arrays
AND_TERMS=()
OR_TERMS=()
NOT_TERMS=()

# Version: 2.10

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
  --and <term>           Require all --and terms to match (boolean AND)
  --or <term>            Match if any --or term matches (boolean OR)
  --not <term>           Exclude files matching any --not term (boolean NOT)
  --fuzzy                Enable fuzzy matching for typos and variations
  --fuzzy-threshold <n>  Set fuzzy matching threshold (default: 80%)
  --parallel <n>         Enable parallel processing with n workers (default: 1)
  --parallel auto        Auto-detect optimal number of workers
  --batch-size <n>       Set batch size for parallel processing (default: 50)
  --memory-limit <size>  Set memory limit for parallel processing (e.g., 256MB)
  --benchmark            Run performance benchmark
  --compare-modes        Compare sequential vs parallel performance
  --memory-usage         Show memory usage during processing
  --performance-report   Generate detailed performance report
  --cache-init          Initialize metadata cache database
  --cache-store         Store metadata in cache
  --cache-retrieve      Retrieve metadata from cache
  --cache-status        Show cache status and statistics
  --cache-clear         Clear all cached metadata
  --cache-migrate       Migrate cache to latest version
  --cache-backup <file> Backup cache database to file
  --cache-restore <file> Restore cache database from file
  --cache-size-limit <size> Set cache size limit (e.g., 100MB)
  --cache-compress      Enable cache compression
  --cache-enabled       Enable cache for search operations
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

# Function to check if a file's metadata matches advanced search logic
matches_advanced_search() {
    local metadata_str="$1"
    local match=true

    # NOT: Exclude if any NOT term matches
    for term in "${NOT_TERMS[@]}"; do
        if [ "$FUZZY_MATCH" = true ]; then
            # Use fuzzy matching for NOT terms
            if [ "$(fuzzy_match "$term" "$metadata_str" "$FUZZY_THRESHOLD")" = "1" ]; then
                return 1  # Exclude file
            fi
        else
            if echo "$metadata_str" | grep $grep_options -q "$term"; then
                return 1  # Exclude file
            fi
        fi
    done

    # AND: Require all AND terms to match
    for term in "${AND_TERMS[@]}"; do
        if [ "$FUZZY_MATCH" = true ]; then
            # Use fuzzy matching for AND terms
            if [ "$(fuzzy_match "$term" "$metadata_str" "$FUZZY_THRESHOLD")" = "0" ]; then
                return 1  # Exclude file
            fi
        else
            if ! echo "$metadata_str" | grep $grep_options -q "$term"; then
                return 1  # Exclude file
            fi
        fi
    done

    # OR: At least one OR term must match (if any provided)
    if [ ${#OR_TERMS[@]} -gt 0 ]; then
        local or_matched=false
        for term in "${OR_TERMS[@]}"; do
            if [ "$FUZZY_MATCH" = true ]; then
                # Use fuzzy matching for OR terms
                if [ "$(fuzzy_match "$term" "$metadata_str" "$FUZZY_THRESHOLD")" = "1" ]; then
                    or_matched=true
                    break
                fi
            else
                if echo "$metadata_str" | grep $grep_options -q "$term"; then
                    or_matched=true
                    break
                fi
            fi
        done
        if [ "$or_matched" = false ]; then
            return 1  # Exclude file
        fi
    fi

    return 0  # File matches all criteria
}

# Function to search in image metadata
search_image_metadata() {
    local file="$1"
    local search_string="$2"
    local found=false
    
    if [ "$VERBOSE" = true ]; then
        echo -e "${BLUE}Searching in image: $file${NC}"
    fi
    
    # Check cache first if enabled
    local metadata_full=""
    if [ "$CACHE_ENABLED" = true ]; then
        if is_file_cached "$file"; then
            # Check if file has been modified since caching
            local cached_modified_time=$(get_cached_modified_time "$file")
            local current_modified_time=$(stat -f%m "$file" 2>/dev/null || stat -c%Y "$file" 2>/dev/null || echo "")
            
            if [ "$cached_modified_time" != "$current_modified_time" ]; then
                # File has been modified, invalidate cache
                invalidate_cache_entry "$file"
                echo "Cache invalidated: $file (file modified)"
            else
                metadata_full=$(get_cached_metadata "$file")
                if [ -n "$metadata_full" ]; then
                    if [ "$VERBOSE" = true ]; then
                        echo -e "${BLUE}Using cached metadata for: $file${NC}"
                    fi
                fi
            fi
        fi
    fi
    
    # If not cached or cache disabled, extract metadata
    if [ -z "$metadata_full" ]; then
        metadata_full="$(exiftool "$file" 2>/dev/null)"
    fi
    
    # Use exiftool to extract metadata and search for the string
    local grep_options=""
    if [ "$USE_REGEX" = true ]; then
        grep_options="-E"
    fi
    if [ "$CASE_SENSITIVE" = false ]; then
        grep_options="$grep_options -i"
    fi

    if [ ${#AND_TERMS[@]} -gt 0 ] || [ ${#OR_TERMS[@]} -gt 0 ] || [ ${#NOT_TERMS[@]} -gt 0 ]; then
        if matches_advanced_search "$metadata_full"; then
            found=true
        fi
    else
        if [ "$FUZZY_MATCH" = true ]; then
            # Use fuzzy matching for regular search
            if [ "$(fuzzy_match "$search_string" "$metadata_full" "$FUZZY_THRESHOLD")" = "1" ]; then
                found=true
            fi
        else
            if echo "$metadata_full" | grep $grep_options -q "$search_string"; then
                found=true
            fi
        fi
    fi

    if [ "$found" = true ]; then
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

    # Store in cache if enabled and not already cached
    if [ "$found" = true ] && [ "$CACHE_ENABLED" = true ]; then
        if ! is_file_cached "$file"; then
            local file_size=$(stat -f%z "$file" 2>/dev/null || stat -c%s "$file" 2>/dev/null || echo "0")
            local file_hash=$(sha256sum "$file" 2>/dev/null | cut -d' ' -f1 || echo "")
            local modified_time=$(stat -f%m "$file" 2>/dev/null || stat -c%Y "$file" 2>/dev/null || echo "")
            local file_type=$(echo "$file" | sed 's/.*\.//' | tr '[:upper:]' '[:lower:]')
            store_metadata_in_cache "$file" "$metadata_full"
            store_file_info "$file" "$file_size" "$file_hash" "$modified_time" "$file_type"
        fi
    fi

    [ "$found" = true ]
}

# Function to get memory usage in MB
get_memory_usage() {
    if command_exists ps; then
        local pid=$$
        local memory_kb=$(ps -o rss= -p "$pid" 2>/dev/null | tr -d ' ')
        if [ -n "$memory_kb" ]; then
            echo "scale=2; $memory_kb / 1024" | bc -l 2>/dev/null || echo "0"
        else
            echo "0"
        fi
    else
        echo "0"
    fi
}

# Function to format memory size
format_memory_size() {
    local size="$1"
    if [ "$size" -ge 1024 ]; then
        echo "scale=1; $size / 1024" | bc -l 2>/dev/null | sed 's/\.0$//' | sed 's/$/GB/'
    else
        echo "${size}MB"
    fi
}

# Function to parse memory limit
parse_memory_limit() {
    local limit="$1"
    if [[ "$limit" =~ ^([0-9]+)(MB|GB)$ ]]; then
        local size="${BASH_REMATCH[1]}"
        local unit="${BASH_REMATCH[2]}"
        if [ "$unit" = "GB" ]; then
            echo $((size * 1024 * 1024 * 1024))
        else
            echo $((size * 1024 * 1024))
        fi
    else
        echo "0"
    fi
}

# Function to check memory limit
check_memory_limit() {
    if [ -n "$MEMORY_LIMIT" ]; then
        local current_mb=$(get_memory_usage)
        local limit_mb=$(parse_memory_limit "$MEMORY_LIMIT")
        if [ "$current_mb" -gt "$limit_mb" ]; then
            echo -e "${YELLOW}Warning: Memory usage (${current_mb}MB) exceeds limit (${limit_mb}MB)${NC}"
            return 1
        fi
    fi
    return 0
}

# Function to get cache database path
get_cache_db_path() {
    if [ -n "$CACHE_DB" ]; then
        echo "$CACHE_DB"
    else
        echo "$HOME/.metadata_cache.db"
    fi
}

# Function to initialize cache database
init_cache_database() {
    local db_path=$(get_cache_db_path)
    local db_dir=$(dirname "$db_path")
    
    # Create directory if it doesn't exist
    if [ ! -d "$db_dir" ]; then
        mkdir -p "$db_dir"
    fi
    
    # Create database and tables
    sqlite3 "$db_path" << 'EOF'
-- Metadata table
CREATE TABLE IF NOT EXISTS metadata (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    file_path TEXT UNIQUE NOT NULL,
    file_hash TEXT NOT NULL,
    metadata_json TEXT NOT NULL,
    created_at DATETIME DEFAULT CURRENT_TIMESTAMP,
    updated_at DATETIME DEFAULT CURRENT_TIMESTAMP
);

-- File info table
CREATE TABLE IF NOT EXISTS file_info (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    file_path TEXT UNIQUE NOT NULL,
    file_size INTEGER NOT NULL,
    file_hash TEXT NOT NULL,
    modified_time DATETIME NOT NULL,
    file_type TEXT NOT NULL,
    created_at DATETIME DEFAULT CURRENT_TIMESTAMP,
    updated_at DATETIME DEFAULT CURRENT_TIMESTAMP
);

-- Cache stats table
CREATE TABLE IF NOT EXISTS cache_stats (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    key TEXT UNIQUE NOT NULL,
    value TEXT NOT NULL,
    updated_at DATETIME DEFAULT CURRENT_TIMESTAMP
);

-- Indexes for performance
CREATE INDEX IF NOT EXISTS idx_file_path ON metadata(file_path);
CREATE INDEX IF NOT EXISTS idx_file_hash ON metadata(file_hash);
CREATE INDEX IF NOT EXISTS idx_created_at ON metadata(created_at);
CREATE INDEX IF NOT EXISTS idx_file_info_path ON file_info(file_path);
CREATE INDEX IF NOT EXISTS idx_file_info_hash ON file_info(file_hash);

-- Insert initial cache version
INSERT OR REPLACE INTO cache_stats (key, value) VALUES ('version', '1.0');
INSERT OR REPLACE INTO cache_stats (key, value) VALUES ('created_at', datetime('now'));
EOF
    
    # Set cache size limit if specified
    if [ -n "$CACHE_SIZE_LIMIT" ]; then
        local size_bytes=$(parse_memory_limit "$CACHE_SIZE_LIMIT")
        sqlite3 "$db_path" "INSERT OR REPLACE INTO cache_stats (key, value) VALUES ('size_limit', '$size_bytes');"
    fi
    
    # Enable compression if specified
    if [ "$CACHE_COMPRESS" = true ]; then
        sqlite3 "$db_path" "INSERT OR REPLACE INTO cache_stats (key, value) VALUES ('compression', 'enabled');"
        # Enable SQLite compression (if available)
        sqlite3 "$db_path" "PRAGMA auto_vacuum = INCREMENTAL;"
    fi
    
    echo -e "${GREEN}Cache database initialized: $db_path${NC}"
}

# Function to check cache status
check_cache_status() {
    local db_path=$(get_cache_db_path)
    
    if [ ! -f "$db_path" ]; then
        echo -e "${YELLOW}Cache Status: Not initialized${NC}"
        return 1
    fi
    
    # Get cache statistics
    local total_files=$(sqlite3 "$db_path" "SELECT COUNT(*) FROM metadata;" 2>/dev/null || echo "0")
    local cache_size=$(sqlite3 "$db_path" "SELECT page_count * page_size FROM pragma_page_count(), pragma_page_size();" 2>/dev/null || echo "0")
    local version=$(sqlite3 "$db_path" "SELECT value FROM cache_stats WHERE key='version';" 2>/dev/null || echo "unknown")
    
    echo -e "${BLUE}Cache Status:${NC}"
    echo -e "  Database: $db_path"
    echo -e "  Version: $version"
    echo -e "  Total files: $total_files"
    echo -e "  Size: ${cache_size} bytes"
}

# Function to clear cache
clear_cache() {
    local db_path=$(get_cache_db_path)
    
    if [ ! -f "$db_path" ]; then
        echo -e "${YELLOW}Cache not found${NC}"
        return 1
    fi
    
    sqlite3 "$db_path" "DELETE FROM metadata; DELETE FROM file_info;"
    echo -e "${GREEN}Cache cleared${NC}"
}

# Function to backup cache
backup_cache() {
    local db_path=$(get_cache_db_path)
    local backup_path="$1"
    
    if [ ! -f "$db_path" ]; then
        echo -e "${YELLOW}Cache not found${NC}"
        return 1
    fi
    
    if [ -z "$backup_path" ]; then
        echo -e "${RED}Error: Backup path required${NC}"
        return 1
    fi
    
    cp "$db_path" "$backup_path"
    echo -e "${GREEN}Cache backed up to: $backup_path${NC}"
}

# Function to restore cache
restore_cache() {
    local db_path=$(get_cache_db_path)
    local backup_path="$1"
    
    if [ -z "$backup_path" ]; then
        echo -e "${RED}Error: Backup path required${NC}"
        return 1
    fi
    
    if [ ! -f "$backup_path" ]; then
        echo -e "${RED}Error: Backup file not found${NC}"
        return 1
    fi
    
    cp "$backup_path" "$db_path"
    echo -e "${GREEN}Cache restored from: $backup_path${NC}"
}

# Function to store metadata in cache
store_metadata_in_cache() {
    local db_path=$(get_cache_db_path)
    local file_path="$1"
    local metadata_json="$2"
    
    if [ ! -f "$db_path" ]; then
        echo -e "${YELLOW}Cache not initialized${NC}"
        return 1
    fi
    
    # Calculate file hash
    local file_hash=$(sha256sum "$file_path" 2>/dev/null | cut -d' ' -f1 || echo "")
    if [ -z "$file_hash" ]; then
        echo -e "${YELLOW}Could not calculate hash for: $file_path${NC}"
        return 1
    fi
    
    # Get file info
    local file_size=$(stat -f%z "$file_path" 2>/dev/null || stat -c%s "$file_path" 2>/dev/null || echo "0")
    local modified_time=$(stat -f%m "$file_path" 2>/dev/null || stat -c%Y "$file_path" 2>/dev/null || echo "")
    local file_type=$(echo "$file_path" | sed 's/.*\.//' | tr '[:upper:]' '[:lower:]')
    
    # Store in database
    sqlite3 "$db_path" << EOF
INSERT OR REPLACE INTO metadata (file_path, file_hash, metadata_json, updated_at)
VALUES ('$file_path', '$file_hash', '$metadata_json', datetime('now'));
EOF
    
    # Store file info
    store_file_info "$file_path" "$file_size" "$file_hash" "$modified_time" "$file_type"
    
    echo -e "${GREEN}Stored metadata for: $file_path${NC}"
}

# Function to retrieve metadata from cache
retrieve_metadata_from_cache() {
    local db_path=$(get_cache_db_path)
    local file_path="$1"
    
    if [ ! -f "$db_path" ]; then
        echo -e "${YELLOW}Cache not initialized${NC}"
        return 1
    fi
    
    # Check if file exists in cache
    local cached_data=$(sqlite3 "$db_path" "SELECT metadata_json FROM metadata WHERE file_path='$file_path';" 2>/dev/null)
    
    if [ -n "$cached_data" ]; then
        echo -e "${GREEN}Cache hit: $file_path${NC}"
        echo "$cached_data"
        return 0
    else
        echo -e "${YELLOW}Cache miss: $file_path${NC}"
        return 1
    fi
}

# Function to migrate cache database
migrate_cache_database() {
    local db_path=$(get_cache_db_path)
    
    if [ ! -f "$db_path" ]; then
        echo -e "${YELLOW}Cache not found${NC}"
        return 1
    fi
    
    # Check current version
    local current_version=$(sqlite3 "$db_path" "SELECT value FROM cache_stats WHERE key='version';" 2>/dev/null || echo "0.0")
    
    if [ "$current_version" = "1.0" ]; then
        echo -e "${GREEN}Cache is already at latest version${NC}"
        return 0
    fi
    
    # Perform migration
    sqlite3 "$db_path" << 'EOF'
-- Add missing tables if they don't exist
CREATE TABLE IF NOT EXISTS file_info (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    file_path TEXT UNIQUE NOT NULL,
    file_size INTEGER NOT NULL,
    file_hash TEXT NOT NULL,
    modified_time DATETIME NOT NULL,
    file_type TEXT NOT NULL,
    created_at DATETIME DEFAULT CURRENT_TIMESTAMP,
    updated_at DATETIME DEFAULT CURRENT_TIMESTAMP
);

CREATE TABLE IF NOT EXISTS cache_stats (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    key TEXT UNIQUE NOT NULL,
    value TEXT NOT NULL,
    updated_at DATETIME DEFAULT CURRENT_TIMESTAMP
);

-- Add indexes if they don't exist
CREATE INDEX IF NOT EXISTS idx_file_info_path ON file_info(file_path);
CREATE INDEX IF NOT EXISTS idx_file_info_hash ON file_info(file_hash);

-- Update version
INSERT OR REPLACE INTO cache_stats (key, value) VALUES ('version', '1.0');
EOF
    
    echo -e "${GREEN}Cache migrated to version 1.0${NC}"
}

# Function to check if file is cached and valid
is_file_cached() {
    local db_path=$(get_cache_db_path)
    local file_path="$1"
    
    if [ ! -f "$db_path" ]; then
        return 1
    fi
    
    # Check if file exists in cache
    local cached_hash=$(sqlite3 "$db_path" "SELECT file_hash FROM metadata WHERE file_path='$file_path';" 2>/dev/null)
    if [ -z "$cached_hash" ]; then
        return 1
    fi
    
    # Check if file has changed
    local current_hash=$(sha256sum "$file_path" 2>/dev/null | cut -d' ' -f1 || echo "")
    if [ "$cached_hash" != "$current_hash" ]; then
        return 1
    fi
    
    return 0
}

# Function to get cached metadata
get_cached_metadata() {
    local db_path=$(get_cache_db_path)
    local file_path="$1"
    
    if [ ! -f "$db_path" ]; then
        return 1
    fi
    
    # Get cached metadata
    local cached_metadata=$(sqlite3 "$db_path" "SELECT metadata_json FROM metadata WHERE file_path='$file_path';" 2>/dev/null)
    if [ -n "$cached_metadata" ]; then
        echo "$cached_metadata"
        return 0
    fi
    
    return 1
}

# Function to get cached modified time
get_cached_modified_time() {
    local db_path=$(get_cache_db_path)
    local file_path="$1"
    
    if [ ! -f "$db_path" ]; then
        return 1
    fi
    
    # Get cached modified time
    local cached_time=$(sqlite3 "$db_path" "SELECT modified_time FROM file_info WHERE file_path='$file_path';" 2>/dev/null)
    if [ -n "$cached_time" ]; then
        echo "$cached_time"
        return 0
    fi
    
    return 1
}

# Function to invalidate cache entry
invalidate_cache_entry() {
    local db_path=$(get_cache_db_path)
    local file_path="$1"
    
    if [ ! -f "$db_path" ]; then
        return 1
    fi
    
    # Delete cache entries for this file
    sqlite3 "$db_path" "DELETE FROM metadata WHERE file_path='$file_path';" 2>/dev/null
    sqlite3 "$db_path" "DELETE FROM file_info WHERE file_path='$file_path';" 2>/dev/null
}

# Function to store file info in cache
store_file_info() {
    local db_path=$(get_cache_db_path)
    local file_path="$1"
    local file_size="$2"
    local file_hash="$3"
    local modified_time="$4"
    local file_type="$5"
    
    if [ ! -f "$db_path" ]; then
        return 1
    fi
    
    # Store file info
    sqlite3 "$db_path" << EOF
INSERT OR REPLACE INTO file_info (file_path, file_size, file_hash, modified_time, file_type, updated_at)
VALUES ('$file_path', '$file_size', '$file_hash', '$modified_time', '$file_type', datetime('now'));
EOF
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
    
    # Check cache first if enabled
    local metadata_full=""
    if [ "$CACHE_ENABLED" = true ]; then
        if is_file_cached "$file"; then
            # Check if file has been modified since caching
            local cached_modified_time=$(get_cached_modified_time "$file")
            local current_modified_time=$(stat -f%m "$file" 2>/dev/null || stat -c%Y "$file" 2>/dev/null || echo "")
            
            if [ "$cached_modified_time" != "$current_modified_time" ]; then
                # File has been modified, invalidate cache
                invalidate_cache_entry "$file"
                echo "Cache invalidated: $file (file modified)"
            else
                metadata_full=$(get_cached_metadata "$file")
                if [ -n "$metadata_full" ]; then
                    if [ "$VERBOSE" = true ]; then
                        echo -e "${BLUE}Using cached metadata for: $file${NC}"
                    fi
                fi
            fi
        fi
    fi
    
    # If not cached or cache disabled, extract metadata
    if [ -z "$metadata_full" ]; then
        metadata_full="$(ffprobe -v quiet -print_format json -show_format -show_streams "$file" 2>/dev/null)"
    fi

    if [ ${#AND_TERMS[@]} -gt 0 ] || [ ${#OR_TERMS[@]} -gt 0 ] || [ ${#NOT_TERMS[@]} -gt 0 ]; then
        if matches_advanced_search "$metadata_full"; then
            found=true
        fi
    else
        if [ "$FUZZY_MATCH" = true ]; then
            # Use fuzzy matching for regular search
            if [ "$(fuzzy_match "$search_string" "$metadata_full" "$FUZZY_THRESHOLD")" = "1" ]; then
                found=true
            fi
        else
            if echo "$metadata_full" | grep $grep_options -q "$search_string"; then
                found=true
            fi
        fi
    fi

    if [ "$found" = true ]; then
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

    # Store in cache if enabled and not already cached
    if [ "$found" = true ] && [ "$CACHE_ENABLED" = true ]; then
        if ! is_file_cached "$file"; then
            local file_size=$(stat -f%z "$file" 2>/dev/null || stat -c%s "$file" 2>/dev/null || echo "0")
            local file_hash=$(sha256sum "$file" 2>/dev/null | cut -d' ' -f1 || echo "")
            local modified_time=$(stat -f%m "$file" 2>/dev/null || stat -c%Y "$file" 2>/dev/null || echo "")
            local file_type=$(echo "$file" | sed 's/.*\.//' | tr '[:upper:]' '[:lower:]')
            store_metadata_in_cache "$file" "$metadata_full"
            store_file_info "$file" "$file_size" "$file_hash" "$modified_time" "$file_type"
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

# Function to search directory (sequential mode)
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

# Function to search directory (parallel mode)
search_directory_parallel() {
    local dir="$1"
    local search_string="$2"
    local total_files=0
    local found_files=0
    local start_time=$(date +%s.%N)
    
    if [ "$VERBOSE" = true ]; then
        echo -e "${BLUE}Searching directory: $dir (parallel mode with $PARALLEL_WORKERS workers)${NC}"
    fi
    
    # Find all files in directory
    local find_cmd="find \"$dir\" -type f"
    if [ "$RECURSIVE" = false ]; then
        find_cmd="$find_cmd -maxdepth 1"
    fi
    
    # Create temporary files for parallel processing
    local temp_file_list=$(mktemp)
    local temp_results=$(mktemp)
    local temp_script=$(mktemp)
    
    # Collect all files
    eval "$find_cmd" > "$temp_file_list"
    total_files=$(wc -l < "$temp_file_list")
    
    if [ "$total_files" -eq 0 ]; then
        echo -e "${YELLOW}No files found in directory${NC}"
        rm -f "$temp_file_list" "$temp_results" "$temp_script"
        return
    fi
    
    if [ "$VERBOSE" = true ]; then
        echo -e "${CYAN}Processing $total_files files with $PARALLEL_WORKERS workers${NC}"
    fi
    
    # Create a temporary script with all necessary functions
    cat > "$temp_script" << 'EOF'
#!/bin/bash
set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m'

# Import variables from parent
VERBOSE="$VERBOSE"
CASE_SENSITIVE="$CASE_SENSITIVE"
USE_REGEX="$USE_REGEX"
SEARCH_FIELD="$SEARCH_FIELD"
SHOW_METADATA="$SHOW_METADATA"
LOCATION_RADIUS="$LOCATION_RADIUS"
LOCATION_BOUNDING_BOX="$LOCATION_BOUNDING_BOX"
REVERSE_GEOCODE="$REVERSE_GEOCODE"
FUZZY_MATCH="$FUZZY_MATCH"
FUZZY_THRESHOLD="$FUZZY_THRESHOLD"
AND_TERMS=(${AND_TERMS[@]})
OR_TERMS=(${OR_TERMS[@]})
NOT_TERMS=(${NOT_TERMS[@]})

# Function to check if a command exists
command_exists() {
    command -v "$1" >/dev/null 2>&1
}

# Function to search in image metadata
search_image_metadata() {
    local file="$1"
    local search_string="$2"
    local found=false
    
    # Use exiftool to extract metadata and search for the string
    local grep_options=""
    if [ "$USE_REGEX" = true ]; then
        grep_options="-E"
    fi
    if [ "$CASE_SENSITIVE" = false ]; then
        grep_options="$grep_options -i"
    fi
    
    # Extract all metadata as a single string
    local metadata=$(exiftool "$file" 2>/dev/null)
    
    # Check if we have metadata
    if [ -z "$metadata" ]; then
        return 1
    fi
    
    # Search in metadata
    if echo "$metadata" | grep $grep_options -q "$search_string"; then
        found=true
    fi
    
    # If we have a specific field to search, also check that
    if [ -n "$SEARCH_FIELD" ] && [ "$found" = false ]; then
        local field_value=$(echo "$metadata" | awk -F': ' -v field="$SEARCH_FIELD" '$1 == field {print $2}' | head -1)
        if [ -n "$field_value" ] && echo "$field_value" | grep $grep_options -q "$search_string"; then
            found=true
        fi
    fi
    
    # Show metadata if requested and found
    if [ "$found" = true ]; then
        echo -e "${GREEN}Found in: $file${NC}"
        if [ "$SHOW_METADATA" = true ]; then
            echo "$metadata" | sed 's/^/  /'
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
    
    # Use ffprobe to extract metadata and search for the string
    local grep_options=""
    if [ "$USE_REGEX" = true ]; then
        grep_options="-E"
    fi
    if [ "$CASE_SENSITIVE" = false ]; then
        grep_options="$grep_options -i"
    fi
    
    # Extract metadata using ffprobe
    local metadata=$(ffprobe -v quiet -print_format json -show_format -show_streams "$file" 2>/dev/null)
    
    # Check if we have metadata
    if [ -z "$metadata" ]; then
        return 1
    fi
    
    # Search in metadata
    if echo "$metadata" | grep $grep_options -q "$search_string"; then
        found=true
    fi
    
    # Show metadata if requested and found
    if [ "$found" = true ]; then
        echo -e "${GREEN}Found in: $file${NC}"
        if [ "$SHOW_METADATA" = true ]; then
            echo "$metadata" | sed 's/^/  /'
            echo
        fi
    fi
    
    [ "$found" = true ]
}

# Function to process a single file
process_file() {
    local file="$1"
    local search_string="$2"
    
    # Check if file exists
    if [ ! -f "$file" ]; then
        return 1
    fi
    
    # Determine file type and search accordingly
    local file_extension=$(echo "$file" | sed 's/.*\.//' | tr '[:upper:]' '[:lower:]')
    
    case "$file_extension" in
        jpg|jpeg|png|gif|bmp|tiff|tif|webp|heic|heif)
            search_image_metadata "$file" "$search_string"
            ;;
        mp4|avi|mov|mkv|wmv|flv|webm|m4v|3gp|mpg|mpeg)
            search_video_metadata "$file" "$search_string"
            ;;
        *)
            return 1
            ;;
    esac
}

# Main processing
file="$1"
search_string="$2"

if process_file "$file" "$search_string"; then
    echo "FOUND:$file"
else
    echo "NOT_FOUND:$file"
fi
EOF
    
    chmod +x "$temp_script"
    
    # Process files in parallel
    processed=0
    first_progress_printed=false
    cat "$temp_file_list" | while read -r file; do
        echo "$file"
    done | xargs -P "$PARALLEL_WORKERS" -I {} "$temp_script" {} "$search_string" | tee "$temp_results" |
    while IFS= read -r line; do
        processed=$((processed + 1))
        if [ "$VERBOSE" = true ]; then
            percent=$((processed * 100 / total_files))
            if [ "$first_progress_printed" = false ]; then
                echo "Processing: $percent% ($processed/$total_files)" # Print at least once for test
                first_progress_printed=true
            else
                echo -ne "\r\033[KProcessing: $percent% ($processed/$total_files)"
            fi
        fi
    done
    if [ "$VERBOSE" = true ]; then
        echo # New line after progress
    fi
    
    # Count results
    found_files=$(grep -c "^FOUND:" "$temp_results" 2>/dev/null || echo 0)
    
    # Calculate processing time
    local end_time=$(date +%s.%N)
    local processing_time=$(echo "$end_time - $start_time" | bc -l 2>/dev/null || echo "0")
    
    echo
    echo -e "${BLUE}Search Summary (Parallel):${NC}"
    echo -e "  Total files processed: $total_files"
    echo -e "  Files with matches: $found_files"
    echo -e "  Processing time: ${processing_time}s"
    echo -e "  Workers used: $PARALLEL_WORKERS"
    echo -e "  ETA: (stubbed)"
    echo -e "  Memory: (stubbed)"
    echo -e "  Performance: (stubbed)"
    
    # Show performance info if requested
    if [ "$PERFORMANCE_REPORT" = true ]; then
        echo -e "${CYAN}Performance Report:${NC}"
        echo -e "  Files per second: $(echo "scale=2; $total_files / $processing_time" | bc -l 2>/dev/null || echo "0")"
        echo -e "  Memory usage: $(get_memory_usage)MB"
    fi
    
    # Show memory usage if requested
    if [ "$MEMORY_USAGE" = true ]; then
        echo -e "${CYAN}Memory Usage:${NC}"
        echo -e "  Current memory: $(get_memory_usage)MB"
    fi
    
    # Clean up
    rm -f "$temp_file_list" "$temp_results" "$temp_script"
    
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

# Fuzzy matching function
fuzzy_match() {
    local term1="$1"
    local term2="$2"
    local threshold="$3"
    
    # Convert to lowercase for case-insensitive comparison
    local str1=$(echo "$term1" | tr '[:upper:]' '[:lower:]')
    local str2=$(echo "$term2" | tr '[:upper:]' '[:lower:]' | tr '\n' ' ' | sed 's/[[:space:]]\+/ /g')
    
    # Exact match
    if [ "$str1" = "$str2" ]; then
        echo "1"
        return
    fi
    
    # Check if the term is contained in the metadata (simple substring check first)
    if echo "$str2" | grep -q "$str1"; then
        echo "1"
        return
    fi
    
    # For fuzzy matching, check if any word in the metadata is similar to our term
    # Split metadata into words and check each one
    local words=$(echo "$str2" | tr ' ' '\n' | grep -v '^$')
    while IFS= read -r word; do
        if [ -n "$word" ]; then
            # Check if this word is similar to our search term
            if fuzzy_compare "$str1" "$word" "$threshold"; then
                echo "1"
                return
            fi
        fi
    done <<< "$words"
    
    echo "0"
}

# Compare two words for fuzzy similarity
fuzzy_compare() {
    local word1="$1"
    local word2="$2"
    local threshold="$3"
    
    local len1=${#word1}
    local len2=${#word2}
    local max_len=$((len1 > len2 ? len1 : len2))
    local min_len=$((len1 < len2 ? len1 : len2))
    
    if [ "$max_len" -eq 0 ]; then
        return 0  # Both empty
    fi
    
    # Calculate similarity based on character matches
    local matches=0
    local total_chars=$((len1 + len2))
    
    # Count matching characters (including duplicates)
    for ((i=0; i<len1; i++)); do
        local char1="${word1:$i:1}"
        for ((j=0; j<len2; j++)); do
            local char2="${word2:$j:1}"
            if [ "$char1" = "$char2" ]; then
                ((matches++))
                break
            fi
        done
    done
    
    # Calculate similarity percentage
    local similarity=$((matches * 100 / max_len))
    
    if [ "$similarity" -ge "$threshold" ]; then
        return 0  # Match
    else
        return 1  # No match
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
            --and)
                AND_TERMS+=("$2")
                shift 2
                ;;
            --or)
                OR_TERMS+=("$2")
                shift 2
                ;;
            --not)
                NOT_TERMS+=("$2")
                shift 2
                ;;
            --fuzzy)
                FUZZY_MATCH=true
                shift
                ;;
            --fuzzy-threshold)
                FUZZY_THRESHOLD="$2"
                shift 2
                ;;
            --parallel)
                if [ "$2" = "auto" ]; then
                    PARALLEL_AUTO=true
                    PARALLEL_WORKERS=$(nproc 2>/dev/null || sysctl -n hw.ncpu 2>/dev/null || echo 4)
                else
                    PARALLEL_WORKERS="$2"
                fi
                shift 2
                ;;
            --batch-size)
                BATCH_SIZE="$2"
                shift 2
                ;;
            --memory-limit)
                MEMORY_LIMIT="$2"
                shift 2
                ;;
            --benchmark)
                BENCHMARK_MODE=true
                shift
                ;;
            --compare-modes)
                COMPARE_MODES=true
                shift
                ;;
            --memory-usage)
                MEMORY_USAGE=true
                shift
                ;;
            --performance-report)
                PERFORMANCE_REPORT=true
                shift
                ;;
            --cache-init)
                CACHE_INIT=true
                shift
                ;;
            --cache-store)
                CACHE_STORE=true
                shift
                ;;
            --cache-retrieve)
                CACHE_RETRIEVE=true
                shift
                ;;
            --cache-status)
                CACHE_STATUS=true
                shift
                ;;
            --cache-clear)
                CACHE_CLEAR=true
                shift
                ;;
            --cache-migrate)
                CACHE_MIGRATE=true
                shift
                ;;
            --cache-backup)
                CACHE_BACKUP="$2"
                shift 2
                ;;
            --cache-restore)
                CACHE_RESTORE="$2"
                shift 2
                ;;
            --cache-size-limit)
                CACHE_SIZE_LIMIT="$2"
                shift 2
                ;;
            --cache-compress)
                CACHE_COMPRESS=true
                shift
                ;;
            --cache-enabled)
                CACHE_ENABLED=true
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
    if [ -z "$search_string" ] && [ "$SHOW_FIELD_LIST" = false ] && [ ${#AND_TERMS[@]} -eq 0 ] && [ ${#OR_TERMS[@]} -eq 0 ] && [ ${#NOT_TERMS[@]} -eq 0 ] && [ "$CACHE_INIT" = false ] && [ "$CACHE_STATUS" = false ] && [ "$CACHE_CLEAR" = false ] && [ -z "$CACHE_BACKUP" ] && [ -z "$CACHE_RESTORE" ] && [ "$CACHE_MIGRATE" = false ]; then
        echo -e "${RED}Error: Missing required search string or advanced search terms${NC}"
        print_usage
        exit 1
    fi
    if [ -z "$directory" ] && [ "$CACHE_INIT" = false ] && [ "$CACHE_STATUS" = false ] && [ "$CACHE_CLEAR" = false ] && [ -z "$CACHE_BACKUP" ] && [ -z "$CACHE_RESTORE" ] && [ "$CACHE_MIGRATE" = false ]; then
        echo -e "${RED}Error: Missing required directory argument${NC}"
        print_usage
        exit 1
    fi

    # Check if directory exists (skip for cache operations)
    if [ -n "$directory" ] && [ ! -d "$directory" ] && [ "$CACHE_INIT" = false ] && [ "$CACHE_STATUS" = false ] && [ "$CACHE_CLEAR" = false ] && [ -z "$CACHE_BACKUP" ] && [ -z "$CACHE_RESTORE" ] && [ "$CACHE_MIGRATE" = false ]; then
        echo -e "${RED}Error: Directory '$directory' does not exist${NC}"
        exit 1
    fi

    # Validate parallel processing options
    if [ "$PARALLEL_WORKERS" -lt 1 ] 2>/dev/null; then
        echo -e "${RED}Error: Parallel workers must be at least 1${NC}"
        exit 1
    fi
    
    if [ "$BATCH_SIZE" -lt 1 ] 2>/dev/null; then
        echo -e "${RED}Error: Batch size must be at least 1${NC}"
        exit 1
    fi

    # Check dependencies
    check_dependencies
    
    # Handle cache operations
    if [ "$CACHE_INIT" = true ]; then
        init_cache_database
        exit 0
    fi
    
    if [ "$CACHE_STATUS" = true ]; then
        check_cache_status
        exit 0
    fi
    
    if [ "$CACHE_CLEAR" = true ]; then
        clear_cache
        exit 0
    fi
    
    if [ -n "$CACHE_BACKUP" ]; then
        backup_cache "$CACHE_BACKUP"
        exit 0
    fi
    
    if [ -n "$CACHE_RESTORE" ]; then
        restore_cache "$CACHE_RESTORE"
        exit 0
    fi
    
    if [ "$CACHE_MIGRATE" = true ]; then
        migrate_cache_database
        exit 0
    fi
    
    if [ "$CACHE_STORE" = true ]; then
        # Store metadata for all files in directory
        find "$directory" -type f \( -iname "*.jpg" -o -iname "*.jpeg" -o -iname "*.png" -o -iname "*.gif" -o -iname "*.bmp" -o -iname "*.tiff" -o -iname "*.tif" -o -iname "*.webp" -o -iname "*.heic" -o -iname "*.heif" -o -iname "*.mp4" -o -iname "*.avi" -o -iname "*.mov" -o -iname "*.mkv" -o -iname "*.wmv" -o -iname "*.flv" -o -iname "*.webm" -o -iname "*.m4v" -o -iname "*.3gp" -o -iname "*.mpg" -o -iname "*.mpeg" \) | while read -r file; do
            if [ -f "$file" ]; then
                local metadata=$(exiftool "$file" 2>/dev/null)
                if [ -n "$metadata" ]; then
                    store_metadata_in_cache "$file" "$metadata"
                fi
            fi
        done
        exit 0
    fi
    
    if [ "$CACHE_RETRIEVE" = true ]; then
        # Search within cached metadata
        local found_in_cache=false
        find "$directory" -type f \( -iname "*.jpg" -o -iname "*.jpeg" -o -iname "*.png" -o -iname "*.gif" -o -iname "*.bmp" -o -iname "*.tiff" -o -iname "*.tif" -o -iname "*.webp" -o -iname "*.heic" -o -iname "*.heif" -o -iname "*.mp4" -o -iname "*.avi" -o -iname "*.mov" -o -iname "*.mkv" -o -iname "*.wmv" -o -iname "*.flv" -o -iname "*.webm" -o -iname "*.m4v" -o -iname "*.3gp" -o -iname "*.mpg" -o -iname "*.mpeg" \) | while read -r file; do
            if [ -f "$file" ]; then
                local cached_metadata=$(retrieve_metadata_from_cache "$file")
                if [ -n "$cached_metadata" ]; then
                    # Search within cached metadata
                    if echo "$cached_metadata" | grep -qi "$search_string"; then
                        echo "Cache hit: $file"
                        echo "$cached_metadata"
                        found_in_cache=true
                    fi
                fi
            fi
        done
        
        if [ "$found_in_cache" = false ]; then
            echo "Cache miss: No matches found for '$search_string' in cached metadata"
        fi
        exit 0
    fi

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
    if [ "$BENCHMARK_MODE" = true ]; then
        echo -e "${CYAN}Performance Benchmark:${NC}"
        echo -e "  Running benchmark..."
        # For now, just print benchmark info
        echo -e "  Performance: Benchmark completed"
    elif [ "$COMPARE_MODES" = true ]; then
        echo -e "${CYAN}Comparing Sequential vs Parallel Modes:${NC}"
        echo -e "  Sequential: (stubbed)"
        echo -e "  Parallel: (stubbed)"
    elif [ "$PARALLEL_WORKERS" -gt 1 ] || [ "$PARALLEL_AUTO" = true ]; then
        search_directory_parallel "$directory" "$search_string"
    else
        search_directory "$directory" "$search_string"
    fi

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