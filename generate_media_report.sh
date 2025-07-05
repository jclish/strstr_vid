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

# Global variables for main function

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
  -h, --help               Show this help message

Examples:
  $0 /path/to/media
  $0 /path/to/media -r -f json
  $0 /path/to/media -j -c -r

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

# Function to generate JSON report
generate_json_report() {
    local dir="$1"
    local count="$2"
    local images="$3"
    local videos="$4"
    local total_size="$5"
    
    cat << EOF
{
  "directory": "$dir",
  "generated_at": "$(date -u +"%Y-%m-%dT%H:%M:%SZ")",
  "summary": {
    "total_files": $count,
    "total_size": $total_size,
    "images": $images,
    "videos": $videos,
    "other": $((count - images - videos))
  }
}
EOF
}

# Function to generate CSV report
generate_csv_report() {
    echo "file,type,format,size"
    # This would need to be implemented to show individual files
    echo "csv,format,not,implemented"
}

# Main script
main() {
    # Default values
    local output_format="text"
    local verbose=false
    local recursive=false
    local show_details=false
    local export_json=false
    local export_csv=false
    local directory=""
    
    # Parse command line arguments
    while [[ $# -gt 0 ]]; do
        case $1 in
            -f|--format)
                output_format="$2"
                shift 2
                ;;
            -v|--verbose)
                verbose=true
                shift
                ;;
            -r|--recursive)
                recursive=true
                shift
                ;;
            -d|--details)
                show_details=true
                shift
                ;;
            -j|--json)
                export_json=true
                shift
                ;;
            -c|--csv)
                export_csv=true
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
                # This is the directory argument, not an option
                if [ -z "$directory" ]; then
                    directory="$1"
                fi
                shift
                ;;
        esac
    done
    
    # Check if we have the required arguments
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
    
    # Set find command based on recursive flag
    local find_cmd="find \"$directory\""
    if [ "$recursive" = false ]; then
        find_cmd="$find_cmd -maxdepth 1"
    fi
    find_cmd="$find_cmd -type f -print"
    
    # Initialize variables
    local count=0
    local images=0
    local videos=0
    local total_size=0
    local all_keywords=""
    local all_cameras=""
    local all_formats=""
    

    
    # Only show progress and text output for text format
    if [ "$output_format" = "text" ]; then
        echo "=== COMPREHENSIVE MEDIA REPORT ==="
        echo "Directory: $directory"
        echo "Generated: $(date)"
        echo ""
        
        echo "📊 PROCESSING FILES..."
        echo "========================"
        
        # Count total files first for progress bar
        local total_files=$(eval "$find_cmd" | wc -l)
        local processed=0
        
        while read -r file; do
            ((processed++))
            
            # Show progress bar
            if [ $((processed % 10)) -eq 0 ] || [ $processed -eq 1 ] || [ $processed -eq $total_files ]; then
                local progress=$((processed * 50 / total_files))
                # Ensure progress doesn't exceed 50
                if [ $progress -gt 50 ]; then
                    progress=50
                fi
                printf "\rProcessing: [%-50s] %d/%d files" "$(printf '#%.0s' $(seq 1 $progress))" "$processed" "$total_files"
            fi
            
            # Process file
            ((count++))
            
            # Get file extension
            local ext="${file##*.}"
            ext=$(echo "$ext" | tr '[:upper:]' '[:lower:]')
            
            # Get file size
            local size=$(stat -f%z "$file" 2>/dev/null || stat -c%s "$file" 2>/dev/null)
            total_size=$((total_size + size))
            
            # Determine file type and extract metadata
            case "$ext" in
                jpg|jpeg|png|gif|bmp|tiff|tif|webp|heic|heif)
                    ((images++))
                    all_formats="$all_formats $ext"
                    
                    # Extract metadata from images
                    local metadata=$(exiftool "$file" 2>/dev/null)
                    
                    # Collect camera info
                    local camera=$(echo "$metadata" | grep -E "(Make|Model)" | head -2)
                    if [ -n "$camera" ]; then
                        all_cameras="$all_cameras $camera"
                    fi
                    
                    # Collect keywords - be more selective
                    local keywords=$(echo "$metadata" | grep -E "(Keywords|Subject|Description|Caption|Title)" | grep -v -E "(Make|Model|Date|Time|Format|File|Size|Bytes|Camera|Image)" | head -5)
                    if [ -n "$keywords" ]; then
                        all_keywords="$all_keywords $keywords"
                    fi
                    ;;
                mp4|avi|mov|mkv|wmv|flv|webm|m4v|3gp|mpg|mpeg)
                    ((videos++))
                    all_formats="$all_formats $ext"
                    
                    # Extract metadata from videos
                    local metadata=$(ffprobe -v quiet -print_format json -show_format -show_streams "$file" 2>/dev/null)
                    
                    # Collect video tags - be more selective
                    local tags=$(echo "$metadata" | jq -r '.format.tags // empty' 2>/dev/null | grep -v -E "(com\.apple\.|com\.adobe\.|handler|encoder|creation_time|duration|bitrate)" 2>/dev/null)
                    if [ -n "$tags" ] && [ "$tags" != "null" ]; then
                        all_keywords="$all_keywords $tags"
                    fi
                    
                    # Also try exiftool for videos - be more selective
                    local video_metadata=$(exiftool "$file" 2>/dev/null)
                    local video_keywords=$(echo "$video_metadata" | grep -E "(Keywords|Subject|Description|Caption|Title|Comment)" | grep -v -E "(Make|Model|Date|Time|Format|File|Size|Bytes|Camera|Video|Codec|Duration)" | head -3)
                    if [ -n "$video_keywords" ]; then
                        all_keywords="$all_keywords $video_keywords"
                    fi
                    ;;
            esac
        done < <(eval "$find_cmd")
        
        # Clear the progress bar line
        echo ""
        
        # Generate text report
        echo "📋 SUMMARY REPORT"
        echo "========================"
        echo "Total files: $count"
        echo "Images: $images"
        echo "Videos: $videos"
        echo "Other: $((count - images - videos))"
        echo "Total size: $total_size bytes ($(echo "scale=1; $total_size/1024/1024" | bc) MB)"
        
        echo ""
        echo "📷 IMAGE ANALYSIS"
        echo "========================"
        if [ "$images" -gt 0 ]; then
            echo "Image count: $images"
            
            # Format breakdown
            echo "Formats found:"
            echo "$all_formats" | tr ' ' '\n' | grep -E "(jpg|jpeg|png|gif|bmp|tiff|tif|webp|heic|heif)" | sort | uniq -c | sort -nr
            
            # Camera analysis
            if [ -n "$all_cameras" ]; then
                echo ""
                echo "Cameras found:"
                echo "$all_cameras" | tr ' ' '\n' | grep -v "^$" | sort | uniq -c | sort -nr
            fi
        else
            echo "No images found"
        fi
        
        echo ""
        echo "🎬 VIDEO ANALYSIS"
        echo "========================"
        if [ "$videos" -gt 0 ]; then
            echo "Video count: $videos"
            
            # Format breakdown
            echo "Formats found:"
            echo "$all_formats" | tr ' ' '\n' | grep -E "(mp4|avi|mov|mkv|wmv|flv|webm|m4v|3gp|mpg|mpeg)" | sort | uniq -c | sort -nr
        else
            echo "No videos found"
        fi
        
        echo ""
        echo "🔍 KEYWORD ANALYSIS"
        echo "========================"
        if [ -n "$all_keywords" ]; then
            # Clean and process keywords for better readability
            echo "📝 KEYWORDS BY FREQUENCY:"
            echo "$all_keywords" | \
                sed 's/Keywords: //g' | \
                sed 's/Subject: //g' | \
                sed 's/Description: //g' | \
                sed 's/Title: //g' | \
                sed 's/Caption: //g' | \
                sed 's/Comment: //g' | \
                tr '[:upper:]' '[:lower:]' | \
                tr ' ' '\n' | \
                grep -v "^$" | \
                grep -E "[a-z]{4,}" | \
                grep -v -E "(make|model|date|time|original|create|modify|camera|image|video|format|file|size|bytes|adobe|stock|adobestock|handler|encoder|creation|duration|bitrate|minor|major|compatible|brands|isom|avc1|mp42)" | \
                sort | uniq -c | sort -nr | head -15 | \
                while read count word; do
                    printf "  %2d: %s\n" "$count" "$word"
                done
            
            echo ""
            echo "📊 TOP THEMES (for podcast transcript matching):"
            echo "$all_keywords" | \
                tr '[:upper:]' '[:lower:]' | \
                tr ' ' '\n' | \
                grep -v "^$" | \
                grep -E "[a-z]{5,}" | \
                grep -v -E "(make|model|date|time|original|create|modify|camera|image|video|format|file|size|bytes|adobe|stock|adobestock|handler|encoder|creation|duration|bitrate|minor|major|compatible|brands|isom|avc1|mp42)" | \
                sort | uniq -c | sort -nr | head -10 | \
                while read count word; do
                    printf "  %2d: %s\n" "$count" "$word"
                done
            
            echo ""
            echo "💡 SUGGESTED SEARCH TERMS FOR PODCAST MATCHING:"
            echo "$all_keywords" | \
                tr '[:upper:]' '[:lower:]' | \
                tr ' ' '\n' | \
                grep -v "^$" | \
                grep -E "[a-z]{6,}" | \
                grep -v -E "(make|model|date|time|original|create|modify|camera|image|video|format|file|size|bytes|adobe|stock|adobestock|keywords|subject|description|title|caption|handler|encoder|creation|duration|bitrate|minor|major|compatible|brands|isom|avc1|mp42)" | \
                sort | uniq -c | sort -nr | head -8 | \
                while read count word; do
                    printf "  • %s (%d occurrences)\n" "$word" "$count"
                done
        else
            echo "No keywords found in metadata"
        fi
        
        echo ""
        echo "✅ REPORT COMPLETE"
        
    elif [ "$output_format" = "json" ]; then
        # Process files silently for JSON output
        while read -r file; do
            ((count++))
            
            # Get file extension
            local ext="${file##*.}"
            ext=$(echo "$ext" | tr '[:upper:]' '[:lower:]')
            
            # Get file size
            local size=$(stat -f%z "$file" 2>/dev/null || stat -c%s "$file" 2>/dev/null)
            total_size=$((total_size + size))
            
            # Determine file type
            case "$ext" in
                jpg|jpeg|png|gif|bmp|tiff|tif|webp|heic|heif)
                    ((images++))
                    ;;
                mp4|avi|mov|mkv|wmv|flv|webm|m4v|3gp|mpg|mpeg)
                    ((videos++))
                    ;;
            esac
        done < <(eval "$find_cmd")
        
        # Generate JSON report
        generate_json_report "$directory" "$count" "$images" "$videos" "$total_size"
        
    elif [ "$output_format" = "csv" ]; then
        # Generate CSV report
        generate_csv_report
    fi
}

# Run main function with all arguments
main "$@" 