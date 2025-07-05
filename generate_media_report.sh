#!/bin/bash

# generate_media_report.sh - Generate comprehensive media reports for directories
# Usage: ./generate_media_report.sh <directory> [options]

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
PURPLE='\033[0;35m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color

# Default values
OUTPUT_FORMAT="text"
VERBOSE=false
RECURSIVE=false
SHOW_DETAILS=false
EXPORT_JSON=false
EXPORT_CSV=false
MIN_SIZE=0
MAX_SIZE=""
DATE_FROM=""
DATE_TO=""

# Function to print usage
print_usage() {
    cat << EOF
Usage: $0 <directory> [options]

Generate comprehensive media reports for directories.

Arguments:
  directory        The directory to analyze

Options:
  -f, --format <format>    Output format: text, json, csv (default: text)
  -v, --verbose            Show detailed processing information
  -r, --recursive          Analyze recursively in subdirectories
  -d, --details            Show detailed metadata for each file
  -j, --json               Export detailed JSON report
  -c, --csv                Export CSV report
  -s, --min-size <bytes>   Minimum file size to include
  -S, --max-size <bytes>   Maximum file size to include
  -D, --date-from <date>   Include files from this date (YYYY-MM-DD)
  -T, --date-to <date>     Include files up to this date (YYYY-MM-DD)
  -h, --help               Show this help message

Examples:
  $0 /path/to/media
  $0 /path/to/media -r -f json
  $0 /path/to/media -j -c -r
  $0 /path/to/media -s 1048576 -D 2023-01-01

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

# Function to format bytes to human readable
format_bytes() {
    local bytes=$1
    if [ $bytes -gt 1073741824 ]; then
        echo "$(echo "scale=1; $bytes/1073741824" | bc) GB"
    elif [ $bytes -gt 1048576 ]; then
        echo "$(echo "scale=1; $bytes/1048576" | bc) MB"
    elif [ $bytes -gt 1024 ]; then
        echo "$(echo "scale=1; $bytes/1024" | bc) KB"
    else
        echo "${bytes} B"
    fi
}

# Function to extract image metadata
extract_image_metadata() {
    local file="$1"
    local metadata=""
    
    if [ -f "$file" ]; then
        metadata=$(exiftool "$file" 2>/dev/null || echo "")
    fi
    
    echo "$metadata"
}

# Function to extract video metadata
extract_video_metadata() {
    local file="$1"
    local metadata=""
    
    if [ -f "$file" ]; then
        metadata=$(ffprobe -v quiet -print_format json -show_format -show_streams "$file" 2>/dev/null || echo "")
    fi
    
    echo "$metadata"
}

# Function to parse date from metadata
parse_date() {
    local metadata="$1"
    local date=""
    
    # Try to extract date from various fields
    date=$(echo "$metadata" | grep -E "(Date/Time Original|Create Date|Modify Date|Date Time Original)" | head -1 | sed 's/.*: //')
    
    if [ -z "$date" ]; then
        # Try file modification time
        date=$(stat -f "%Sm" -t "%Y:%m:%d %H:%M:%S" "$file" 2>/dev/null || stat -c "%y" "$file" 2>/dev/null)
    fi
    
    echo "$date"
}

# Function to check if file meets filter criteria
meets_criteria() {
    local file="$1"
    local size="$2"
    local date="$3"
    
    # Size filter
    if [ "$MIN_SIZE" -gt 0 ] && [ "$size" -lt "$MIN_SIZE" ]; then
        return 1
    fi
    
    if [ -n "$MAX_SIZE" ] && [ "$size" -gt "$MAX_SIZE" ]; then
        return 1
    fi
    
    # Date filter (basic implementation)
    if [ -n "$DATE_FROM" ] || [ -n "$DATE_TO" ]; then
        # Convert date to timestamp for comparison
        local file_timestamp=$(date -j -f "%Y:%m:%d %H:%M:%S" "$date" +%s 2>/dev/null || echo "0")
        local from_timestamp=$(date -j -f "%Y-%m-%d" "$DATE_FROM" +%s 2>/dev/null || echo "0")
        local to_timestamp=$(date -j -f "%Y-%m-%d" "$DATE_TO" +%s 2>/dev/null || echo "9999999999")
        
        if [ "$file_timestamp" -lt "$from_timestamp" ] || [ "$file_timestamp" -gt "$to_timestamp" ]; then
            return 1
        fi
    fi
    
    return 0
}

# Function to analyze file
analyze_file() {
    local file="$1"
    local size=$(stat -f%z "$file" 2>/dev/null || stat -c%s "$file" 2>/dev/null)
    local ext="${file##*.}"
    ext=$(echo "$ext" | tr '[:upper:]' '[:lower:]')
    
    local result=""
    local metadata=""
    local date=""
    
    case "$ext" in
        jpg|jpeg|png|gif|bmp|tiff|tif|webp|heic|heif)
            metadata=$(extract_image_metadata "$file")
            date=$(parse_date "$metadata")
            
            if meets_criteria "$file" "$size" "$date"; then
                result="{\"file\":\"$file\",\"type\":\"image\",\"format\":\"$ext\",\"size\":$size,\"date\":\"$date\",\"metadata\":\"$metadata\"}"
            fi
            ;;
        mp4|avi|mov|mkv|wmv|flv|webm|m4v|3gp|mpg|mpeg)
            metadata=$(extract_video_metadata "$file")
            date=$(parse_date "$metadata")
            
            if meets_criteria "$file" "$size" "$date"; then
                result="{\"file\":\"$file\",\"type\":\"video\",\"format\":\"$ext\",\"size\":$size,\"date\":\"$date\",\"metadata\":\"$metadata\"}"
            fi
            ;;
    esac
    
    echo "$result"
}

# Function to generate text report
generate_text_report() {
    local report_data="$1"
    local dir="$2"
    
    echo -e "${BLUE}=== Media Report for $dir ===${NC}"
    echo
    
    # Parse JSON data and generate statistics
    local total_files=$(echo "$report_data" | jq -r 'length' 2>/dev/null || echo "0")
    local total_size=$(echo "$report_data" | jq -r 'map(.size) | add' 2>/dev/null || echo "0")
    local images=$(echo "$report_data" | jq -r 'map(select(.type == "image")) | length' 2>/dev/null || echo "0")
    local videos=$(echo "$report_data" | jq -r 'map(select(.type == "video")) | length' 2>/dev/null || echo "0")
    
    echo -e "${CYAN}📊 SUMMARY:${NC}"
    echo -e "  Total files: $total_files"
    echo -e "  Images: $images"
    echo -e "  Videos: $videos"
    echo -e "  Total size: $(format_bytes $total_size)"
    echo
    
    # Image analysis
    if [ "$images" -gt 0 ]; then
        echo -e "${GREEN}📷 IMAGES ($images files):${NC}"
        
        # Format breakdown
        local formats=$(echo "$report_data" | jq -r 'map(select(.type == "image")) | group_by(.format) | map({format: .[0].format, count: length}) | sort_by(.count) | reverse' 2>/dev/null)
        if [ -n "$formats" ] && [ "$formats" != "null" ]; then
            echo -e "  Formats: $(echo "$formats" | jq -r 'map("\(.format) (\(.count))") | join(", ")' 2>/dev/null)"
        fi
        
        # Camera analysis
        local cameras=$(echo "$report_data" | jq -r 'map(select(.type == "image")) | map(.metadata) | map(select(. != "")) | map(select(test("Make|Model"))) | unique' 2>/dev/null)
        if [ -n "$cameras" ] && [ "$cameras" != "null" ] && [ "$cameras" != "[]" ]; then
            echo -e "  Cameras: $(echo "$cameras" | jq -r 'join(", ")' 2>/dev/null)"
        fi
        
        echo
    fi
    
    # Video analysis
    if [ "$videos" -gt 0 ]; then
        echo -e "${PURPLE}🎬 VIDEOS ($videos files):${NC}"
        
        # Format breakdown
        local formats=$(echo "$report_data" | jq -r 'map(select(.type == "video")) | group_by(.format) | map({format: .[0].format, count: length}) | sort_by(.count) | reverse' 2>/dev/null)
        if [ -n "$formats" ] && [ "$formats" != "null" ]; then
            echo -e "  Formats: $(echo "$formats" | jq -r 'map("\(.format) (\(.count))") | join(", ")' 2>/dev/null)"
        fi
        
        # Codec analysis
        local codecs=$(echo "$report_data" | jq -r 'map(select(.type == "video")) | map(.metadata) | map(select(. != "")) | map(select(test("codec"))) | unique' 2>/dev/null)
        if [ -n "$codecs" ] && [ "$codecs" != "null" ] && [ "$codecs" != "[]" ]; then
            echo -e "  Codecs: $(echo "$codecs" | jq -r 'join(", ")' 2>/dev/null)"
        fi
        
        echo
    fi
    
    # Detailed file list if requested
    if [ "$SHOW_DETAILS" = true ]; then
        echo -e "${YELLOW}📋 DETAILED FILE LIST:${NC}"
        echo "$report_data" | jq -r '.[] | "\(.type | ascii_upcase): \(.file) (\(.format)) - \(.size | tostring) bytes"' 2>/dev/null
        echo
    fi
}

# Function to generate JSON report
generate_json_report() {
    local report_data="$1"
    local dir="$2"
    
    local total_files=$(echo "$report_data" | jq -r 'length' 2>/dev/null || echo "0")
    local total_size=$(echo "$report_data" | jq -r 'map(.size) | add' 2>/dev/null || echo "0")
    
    cat << EOF
{
  "directory": "$dir",
  "generated_at": "$(date -u +"%Y-%m-%dT%H:%M:%SZ")",
  "summary": {
    "total_files": $total_files,
    "total_size": $total_size,
    "images": $(echo "$report_data" | jq -r 'map(select(.type == "image")) | length' 2>/dev/null || echo "0"),
    "videos": $(echo "$report_data" | jq -r 'map(select(.type == "video")) | length' 2>/dev/null || echo "0")
  },
  "files": $(echo "$report_data" | jq -c '.' 2>/dev/null || echo "[]")
}
EOF
}

# Function to generate CSV report
generate_csv_report() {
    local report_data="$1"
    
    echo "file,type,format,size,date"
    echo "$report_data" | jq -r '.[] | "\(.file),\(.type),\(.format),\(.size),\(.date)"' 2>/dev/null
}

# Function to analyze directory
analyze_directory() {
    local dir="$1"
    local results=()
    local total_files=0
    
    if [ "$VERBOSE" = true ]; then
        echo -e "${BLUE}Analyzing directory: $dir${NC}"
    fi
    
    # Find all files in directory
    local find_cmd="find \"$dir\" -type f"
    if [ "$RECURSIVE" = false ]; then
        find_cmd="$find_cmd -maxdepth 1"
    fi
    
    while IFS= read -r -d '' file; do
        ((total_files++))
        
        if [ "$VERBOSE" = true ]; then
            echo -e "${YELLOW}Processing: $file${NC}"
        fi
        
        local result=$(analyze_file "$file")
        if [ -n "$result" ]; then
            results+=("$result")
        fi
    done < <(eval "$find_cmd" -print0)
    
    # Combine results into JSON array
    local json_data="["
    local first=true
    for result in "${results[@]}"; do
        if [ "$first" = true ]; then
            first=false
        else
            json_data="$json_data,"
        fi
        json_data="$json_data$result"
    done
    json_data="$json_data]"
    
    echo "$json_data"
}

# Main script
main() {
    # Parse command line arguments
    while [[ $# -gt 0 ]]; do
        case $1 in
            -f|--format)
                OUTPUT_FORMAT="$2"
                shift 2
                ;;
            -v|--verbose)
                VERBOSE=true
                shift
                ;;
            -r|--recursive)
                RECURSIVE=true
                shift
                ;;
            -d|--details)
                SHOW_DETAILS=true
                shift
                ;;
            -j|--json)
                EXPORT_JSON=true
                shift
                ;;
            -c|--csv)
                EXPORT_CSV=true
                shift
                ;;
            -s|--min-size)
                MIN_SIZE="$2"
                shift 2
                ;;
            -S|--max-size)
                MAX_SIZE="$2"
                shift 2
                ;;
            -D|--date-from)
                DATE_FROM="$2"
                shift 2
                ;;
            -T|--date-to)
                DATE_TO="$2"
                shift 2
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
    if [ $# -lt 1 ]; then
        echo -e "${RED}Error: Missing required directory argument${NC}"
        print_usage
        exit 1
    fi
    
    local directory="$1"
    
    # Check if directory exists
    if [ ! -d "$directory" ]; then
        echo -e "${RED}Error: Directory '$directory' does not exist${NC}"
        exit 1
    fi
    
    # Check dependencies
    check_dependencies
    
    # Check if jq is available for JSON processing
    if ! command_exists jq; then
        echo -e "${YELLOW}Warning: jq not found. Install jq for better JSON processing:${NC}"
        echo "  macOS: brew install jq"
        echo "  Ubuntu/Debian: sudo apt-get install jq"
        echo "  CentOS/RHEL: sudo yum install jq"
        echo
    fi
    
    echo -e "${BLUE}Generating media report for: $directory${NC}"
    if [ "$RECURSIVE" = true ]; then
        echo -e "${BLUE}Mode: Recursive${NC}"
    else
        echo -e "${BLUE}Mode: Non-recursive${NC}"
    fi
    echo
    
    # Analyze directory
    local report_data=$(analyze_directory "$directory")
    
    # Generate reports based on format
    case "$OUTPUT_FORMAT" in
        "text")
            generate_text_report "$report_data" "$directory"
            ;;
        "json")
            generate_json_report "$report_data" "$directory"
            ;;
        "csv")
            generate_csv_report "$report_data"
            ;;
        *)
            echo -e "${RED}Error: Unknown output format '$OUTPUT_FORMAT'${NC}"
            exit 1
            ;;
    esac
    
    # Export additional formats if requested
    if [ "$EXPORT_JSON" = true ] && [ "$OUTPUT_FORMAT" != "json" ]; then
        echo
        echo -e "${BLUE}=== JSON Export ===${NC}"
        generate_json_report "$report_data" "$directory"
    fi
    
    if [ "$EXPORT_CSV" = true ] && [ "$OUTPUT_FORMAT" != "csv" ]; then
        echo
        echo -e "${BLUE}=== CSV Export ===${NC}"
        generate_csv_report "$report_data"
    fi
}

# Run main function with all arguments
main "$@" 