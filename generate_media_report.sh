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
DATE_FROM=""
DATE_TO=""
MIN_SIZE=""
MAX_SIZE=""
IMAGES_ONLY=false
VIDEOS_ONLY=false
FILTER_FORMAT=""

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
  -D, --date-from <date>   Filter: only files on/after this date (YYYY-MM-DD)
  -T, --date-to <date>     Filter: only files on/before this date (YYYY-MM-DD)
  -s, --min-size <size>    Filter: only files at least this size (e.g. 1MB)
  -S, --max-size <size>    Filter: only files at most this size (e.g. 100MB)
  --images-only            Filter: only include image files
  --videos-only            Filter: only include video files
  --format <format>        Filter: only include files of this format (e.g. jpg, mp4)
  -h, --help               Show this help message

Examples:
  $0 /path/to/media --images-only
  $0 /path/to/media --videos-only --format mov
  $0 /path/to/media -D 2023-01-01 -T 2023-12-31 -s 1MB -S 100MB
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

# Function to escape CSV values
escape_csv_value() {
    local value="$1"
    # Replace double quotes with two double quotes
    value="${value//\"/\"\"}"
    # If value contains comma, newline, or double quote, wrap in quotes
    if [[ "$value" =~ [,\"\n\r] ]]; then
        value="\"$value\""
    fi
    echo "$value"
}

# Function to extract metadata field
extract_metadata_field() {
    local metadata="$1"
    local field="$2"
    # Use grep and sed for more flexible field matching
    local value=$(echo "$metadata" | LC_ALL=C grep -E "^[[:space:]]*$field[[:space:]]*:" | sed 's/^[[:space:]]*[^:]*:[[:space:]]*//' | head -1)
    echo "$value"
}

# Function to generate CSV report
generate_csv_report() {
    local dir="$1"
    local files_data="$2"
    
    # CSV header
    echo "file,type,format,size,size_mb,date,camera_make,camera_model,keywords,description"
    
    # Output file data
    echo "$files_data"
}

# Function to process file for CSV output
process_file_for_csv() {
    local file="$1"
    local file_type="$2"
    local format="$3"
    local size="$4"
    local size_mb="$5"
    
    # Initialize CSV fields
    local date=""
    local camera_make=""
    local camera_model=""
    local keywords=""
    local description=""
    
    # Extract metadata based on file type
    if [ "$file_type" = "image" ]; then
        local metadata=$(exiftool "$file" 2>/dev/null | LC_ALL=C cat)
        
        # Extract date (prefer Date/Time Original, fallback to File Modification Date)
        date=$(extract_metadata_field "$metadata" "Date/Time Original")
        if [ -z "$date" ]; then
            date=$(extract_metadata_field "$metadata" "File Modification Date/Time")
        fi
        
        # Extract camera info
        camera_make=$(extract_metadata_field "$metadata" "Make")
        camera_model=$(extract_metadata_field "$metadata" "Model")
        
        # Extract keywords and description
        keywords=$(extract_metadata_field "$metadata" "Keywords")
        description=$(extract_metadata_field "$metadata" "Image Description")
        if [ -z "$description" ]; then
            description=$(extract_metadata_field "$metadata" "Caption")
        fi
        
    elif [ "$file_type" = "video" ]; then
        # Try exiftool first for video metadata
        local metadata=$(exiftool "$file" 2>/dev/null | LC_ALL=C cat)
        
        # Extract date
        date=$(extract_metadata_field "$metadata" "Date/Time Original")
        if [ -z "$date" ]; then
            date=$(extract_metadata_field "$metadata" "File Modification Date/Time")
        fi
        
        # Extract camera info
        camera_make=$(extract_metadata_field "$metadata" "Make")
        camera_model=$(extract_metadata_field "$metadata" "Model")
        
        # Extract keywords and description
        keywords=$(extract_metadata_field "$metadata" "Keywords")
        description=$(extract_metadata_field "$metadata" "Description")
        if [ -z "$description" ]; then
            description=$(extract_metadata_field "$metadata" "Comment")
        fi
        
        # Also try ffprobe for additional metadata
        local ffprobe_metadata=$(ffprobe -v quiet -print_format json -show_format -show_streams "$file" 2>/dev/null)
        if [ -n "$ffprobe_metadata" ]; then
            # Extract creation time from ffprobe
            local ffprobe_date=$(echo "$ffprobe_metadata" | jq -r '.format.tags.creation_time // empty' 2>/dev/null)
            if [ -n "$ffprobe_date" ] && [ "$ffprobe_date" != "null" ]; then
                date="$ffprobe_date"
            fi
        fi
    fi
    
    # Escape CSV values
    local escaped_file=$(escape_csv_value "$file")
    local escaped_date=$(escape_csv_value "$date")
    local escaped_camera_make=$(escape_csv_value "$camera_make")
    local escaped_camera_model=$(escape_csv_value "$camera_model")
    local escaped_keywords=$(escape_csv_value "$keywords")
    local escaped_description=$(escape_csv_value "$description")
    
    # Output CSV line
    echo "$escaped_file,$file_type,$format,$size,$size_mb,$escaped_date,$escaped_camera_make,$escaped_camera_model,$escaped_keywords,$escaped_description"
}

# Utility: Convert human-readable size (e.g. 1MB, 500KB) to bytes
parse_size_to_bytes() {
    local size_str="$1"
    if [[ "$size_str" =~ ^[0-9]+$ ]]; then
        echo "$size_str"
        return
    fi
    local num=$(echo "$size_str" | grep -o -E '^[0-9]+')
    local unit=$(echo "$size_str" | grep -o -E '[KMGTP]?B$' | tr '[:upper:]' '[:lower:]')
    case "$unit" in
        b)   echo "$num" ;;
        kb)  echo $((num * 1024)) ;;
        mb)  echo $((num * 1024 * 1024)) ;;
        gb)  echo $((num * 1024 * 1024 * 1024)) ;;
        tb)  echo $((num * 1024 * 1024 * 1024 * 1024)) ;;
        pb)  echo $((num * 1024 * 1024 * 1024 * 1024 * 1024)) ;;
        *)   echo "$num" ;;
    esac
}

# Utility: Convert date string to timestamp for comparison
parse_date_to_timestamp() {
    local date_str="$1"
    if [[ "$date_str" =~ ^[0-9]{4}-[0-9]{2}-[0-9]{2}$ ]]; then
        date -j -f "%Y-%m-%d" "$date_str" "+%s" 2>/dev/null || date -d "$date_str" "+%s" 2>/dev/null
    else
        echo ""
    fi
}

# Enhanced Statistics Functions

# Calculate average file sizes by format
calculate_format_averages() {
    local format_sizes="$1"
    echo "📊 AVERAGE FILE SIZES BY FORMAT"
    echo "================================"
    
    if [ -z "$format_sizes" ]; then
        echo "No file size data available"
        return
    fi
    
    # Process format sizes and calculate averages
    echo "$format_sizes" | grep -v "^$" | while IFS=':' read -r format size; do
        if [ -n "$format" ] && [ -n "$size" ]; then
            echo "$format:$size"
        fi
    done | awk -F: '
    {
        format = $1
        size = $2
        if (format in sizes) {
            sizes[format] += size
            counts[format]++
        } else {
            sizes[format] = size
            counts[format] = 1
        }
    }
    END {
        for (format in sizes) {
            avg = sizes[format] / counts[format]
            avg_mb = avg / 1024 / 1024
            printf "  %-8s: %d files, avg %.1f MB (%.0f bytes)\n", 
                   format, counts[format], avg_mb, avg
        }
    }' | sort -k2 -nr
}

# Analyze storage usage trends
analyze_storage_trends() {
    local image_sizes="$1"
    local video_sizes="$2"
    
    echo ""
    echo "📈 STORAGE USAGE TRENDS"
    echo "========================"
    
    if [ -z "$image_sizes" ] && [ -z "$video_sizes" ]; then
        echo "No size data available for trend analysis"
        return
    fi
    
    # Analyze image sizes
    if [ -n "$image_sizes" ]; then
        local image_count=$(echo "$image_sizes" | grep -v "^$" | wc -l)
        if [ "$image_count" -gt 0 ]; then
            local total_image_size=$(echo "$image_sizes" | grep -v "^$" | awk '{sum += $1} END {print sum}')
            local avg_image_size=$(echo "scale=0; $total_image_size / $image_count" | bc 2>/dev/null || echo "0")
            local avg_image_mb=$(echo "scale=1; $avg_image_size / 1024 / 1024" | bc 2>/dev/null || echo "0")
            
            echo "📷 Images: $image_count files"
            echo "  Total size: $(echo "scale=1; $total_image_size / 1024 / 1024" | bc 2>/dev/null || echo "0") MB"
            echo "  Average size: ${avg_image_mb} MB"
            
            # Size distribution
            local small_count=$(echo "$image_sizes" | grep -v "^$" | awk '$1 < 1024*1024 {count++} END {print count+0}')
            local medium_count=$(echo "$image_sizes" | grep -v "^$" | awk '$1 >= 1024*1024 && $1 < 10*1024*1024 {count++} END {print count+0}')
            local large_count=$(echo "$image_sizes" | grep -v "^$" | awk '$1 >= 10*1024*1024 {count++} END {print count+0}')
            
            echo "  Size distribution:"
            echo "    Small (<1MB): $small_count files"
            echo "    Medium (1-10MB): $medium_count files"
            echo "    Large (>10MB): $large_count files"
        fi
    fi
    
    # Analyze video sizes
    if [ -n "$video_sizes" ]; then
        local video_count=$(echo "$video_sizes" | grep -v "^$" | wc -l)
        if [ "$video_count" -gt 0 ]; then
            local total_video_size=$(echo "$video_sizes" | grep -v "^$" | awk '{sum += $1} END {print sum}')
            local avg_video_size=$(echo "scale=0; $total_video_size / $video_count" | bc 2>/dev/null || echo "0")
            local avg_video_mb=$(echo "scale=1; $avg_video_size / 1024 / 1024" | bc 2>/dev/null || echo "0")
            
            echo ""
            echo "🎬 Videos: $video_count files"
            echo "  Total size: $(echo "scale=1; $total_video_size / 1024 / 1024" | bc 2>/dev/null || echo "0") MB"
            echo "  Average size: ${avg_video_mb} MB"
            
            # Size distribution
            local small_count=$(echo "$video_sizes" | grep -v "^$" | awk '$1 < 50*1024*1024 {count++} END {print count+0}')
            local medium_count=$(echo "$video_sizes" | grep -v "^$" | awk '$1 >= 50*1024*1024 && $1 < 500*1024*1024 {count++} END {print count+0}')
            local large_count=$(echo "$video_sizes" | grep -v "^$" | awk '$1 >= 500*1024*1024 {count++} END {print count+0}')
            
            echo "  Size distribution:"
            echo "    Small (<50MB): $small_count files"
            echo "    Medium (50-500MB): $medium_count files"
            echo "    Large (>500MB): $large_count files"
        fi
    fi
}

# Detect duplicate files
detect_duplicates() {
    local file_hashes="$1"
    
    echo ""
    echo "🔍 DUPLICATE DETECTION"
    echo "======================"
    
    if [ -z "$file_hashes" ]; then
        echo "No file hash data available"
        return
    fi
    
    # Find duplicates by hash
    local duplicate_groups=$(echo "$file_hashes" | grep -v "^$" | awk -F: '
    {
        hash = $1
        file = $2
        if (hash in hashes) {
            hashes[hash] = hashes[hash] "\n" file
            counts[hash]++
        } else {
            hashes[hash] = file
            counts[hash] = 1
        }
    }
    END {
        for (hash in hashes) {
            if (counts[hash] > 1) {
                print "Hash: " hash
                print hashes[hash]
                print "---"
            }
        }
    }')
    
    if [ -n "$duplicate_groups" ]; then
        echo "Found duplicate files:"
        echo "$duplicate_groups"
    else
        echo "No duplicate files found"
    fi
}

# Analyze resolutions
analyze_resolutions() {
    local image_resolutions="$1"
    local video_resolutions="$2"
    
    echo ""
    echo "📐 RESOLUTION ANALYSIS"
    echo "======================"
    
    # Analyze image resolutions
    if [ -n "$image_resolutions" ]; then
        local image_res_count=$(echo "$image_resolutions" | grep -v "^$" | wc -l)
        if [ "$image_res_count" -gt 0 ]; then
            echo "📷 Image Resolutions ($image_res_count files):"
            echo "$image_resolutions" | grep -v "^$" | sort | uniq -c | sort -nr | head -10 | \
                while read count resolution; do
                    printf "  %2d: %s\n" "$count" "$resolution"
                done
        fi
    fi
    
    # Analyze video resolutions
    if [ -n "$video_resolutions" ]; then
        local video_res_count=$(echo "$video_resolutions" | grep -v "^$" | wc -l)
        if [ "$video_res_count" -gt 0 ]; then
            echo ""
            echo "🎬 Video Resolutions ($video_res_count files):"
            echo "$video_resolutions" | grep -v "^$" | sort | uniq -c | sort -nr | head -10 | \
                while read count resolution; do
                    printf "  %2d: %s\n" "$count" "$resolution"
                done
        fi
    fi
    
    if [ -z "$image_resolutions" ] && [ -z "$video_resolutions" ]; then
        echo "No resolution data available"
    fi
}

# Analyze aspect ratios
analyze_aspect_ratios() {
    local image_aspects="$1"
    local video_aspects="$2"
    
    echo ""
    echo "📏 ASPECT RATIO ANALYSIS"
    echo "========================"
    
    # Analyze image aspect ratios
    if [ -n "$image_aspects" ]; then
        local image_aspect_count=$(echo "$image_aspects" | grep -v "^$" | wc -l)
        if [ "$image_aspect_count" -gt 0 ]; then
            echo "📷 Image Aspect Ratios ($image_aspect_count files):"
            
            # Categorize aspect ratios
            local portrait_count=$(echo "$image_aspects" | grep -v "^$" | awk '$1 < 0.8 {count++} END {print count+0}')
            local square_count=$(echo "$image_aspects" | grep -v "^$" | awk '$1 >= 0.8 && $1 <= 1.2 {count++} END {print count+0}')
            local landscape_count=$(echo "$image_aspects" | grep -v "^$" | awk '$1 > 1.2 {count++} END {print count+0}')
            
            echo "  Portrait (<0.8): $portrait_count files"
            echo "  Square (0.8-1.2): $square_count files"
            echo "  Landscape (>1.2): $landscape_count files"
            
            # Show most common ratios
            echo ""
            echo "  Most common ratios:"
            echo "$image_aspects" | grep -v "^$" | awk '
            {
                ratio = $1
                if (ratio < 0.8) category = "Portrait"
                else if (ratio <= 1.2) category = "Square"
                else category = "Landscape"
                categories[category]++
            }
            END {
                for (cat in categories) {
                    printf "    %s: %d files\n", cat, categories[cat]
                }
            }'
        fi
    fi
    
    # Analyze video aspect ratios
    if [ -n "$video_aspects" ]; then
        local video_aspect_count=$(echo "$video_aspects" | grep -v "^$" | wc -l)
        if [ "$video_aspect_count" -gt 0 ]; then
            echo ""
            echo "🎬 Video Aspect Ratios ($video_aspect_count files):"
            
            # Categorize aspect ratios
            local portrait_count=$(echo "$video_aspects" | grep -v "^$" | awk '$1 < 0.8 {count++} END {print count+0}')
            local square_count=$(echo "$video_aspects" | grep -v "^$" | awk '$1 >= 0.8 && $1 <= 1.2 {count++} END {print count+0}')
            local landscape_count=$(echo "$video_aspects" | grep -v "^$" | awk '$1 > 1.2 {count++} END {print count+0}')
            
            echo "  Portrait (<0.8): $portrait_count files"
            echo "  Square (0.8-1.2): $square_count files"
            echo "  Landscape (>1.2): $landscape_count files"
            
            # Show most common ratios
            echo ""
            echo "  Most common ratios:"
            echo "$video_aspects" | grep -v "^$" | awk '
            {
                ratio = $1
                if (ratio < 0.8) category = "Portrait"
                else if (ratio <= 1.2) category = "Square"
                else category = "Landscape"
                categories[category]++
            }
            END {
                for (cat in categories) {
                    printf "    %s: %d files\n", cat, categories[cat]
                }
            }'
        fi
    fi
    
    if [ -z "$image_aspects" ] && [ -z "$video_aspects" ]; then
        echo "No aspect ratio data available"
    fi
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
    local date_from=""
    local date_to=""
    local min_size=""
    local max_size=""
    local images_only=false
    local videos_only=false
    local filter_format=""

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
            -D|--date-from)
                date_from="$2"
                shift 2
                ;;
            -T|--date-to)
                date_to="$2"
                shift 2
                ;;
            -s|--min-size)
                min_size="$2"
                shift 2
                ;;
            -S|--max-size)
                max_size="$2"
                shift 2
                ;;
            --images-only)
                images_only=true
                shift
                ;;
            --videos-only)
                videos_only=true
                shift
                ;;
            --format)
                filter_format="$2"
                shift 2
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
                if [ -z "$directory" ]; then
                    directory="$1"
                fi
                shift
                ;;
        esac
    done

    # Export variables for use in the rest of the script
    OUTPUT_FORMAT="$output_format"
    VERBOSE="$verbose"
    RECURSIVE="$recursive"
    SHOW_DETAILS="$show_details"
    EXPORT_JSON="$export_json"
    EXPORT_CSV="$export_csv"
    DATE_FROM="$date_from"
    DATE_TO="$date_to"
    MIN_SIZE="$min_size"
    MAX_SIZE="$max_size"
    IMAGES_ONLY="$images_only"
    VIDEOS_ONLY="$videos_only"
    FILTER_FORMAT="$filter_format"
    DIRECTORY="$directory"
    
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
    
    # Enhanced statistics variables
    local image_sizes=""
    local video_sizes=""
    local image_resolutions=""
    local video_resolutions=""
    local image_aspects=""
    local video_aspects=""
    local file_hashes=""
    local format_sizes=""
    
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
                if [ $progress -gt 50 ]; then progress=50; fi
                printf "\rProcessing: [%-50s] %d/%d files" "$(printf '#%.0s' $(seq 1 $progress))" "$processed" "$total_files"
            fi
            
            # Get file size
            local size=$(stat -f%z "$file" 2>/dev/null || stat -c%s "$file" 2>/dev/null)

            # Min/max size filtering
            local min_bytes=""
            local max_bytes=""
            if [ -n "$MIN_SIZE" ]; then
                min_bytes=$(parse_size_to_bytes "$MIN_SIZE")
                if [ "$size" -lt "$min_bytes" ]; then
                    continue
                fi
            fi
            if [ -n "$MAX_SIZE" ]; then
                max_bytes=$(parse_size_to_bytes "$MAX_SIZE")
                if [ "$size" -gt "$max_bytes" ]; then
                    continue
                fi
            fi

            # Date filtering
            if [ -n "$DATE_FROM" ] || [ -n "$DATE_TO" ]; then
                local file_date=""
                local file_timestamp=""
                
                # Try to get date from metadata first, fallback to file modification date
                local ext="${file##*.}"
                ext=$(echo "$ext" | tr '[:upper:]' '[:lower:]')
                
                case "$ext" in
                    jpg|jpeg|png|gif|bmp|tiff|tif|webp|heic|heif)
                        local metadata=$(exiftool "$file" 2>/dev/null)
                        file_date=$(extract_metadata_field "$metadata" "Date/Time Original")
                        if [ -z "$file_date" ]; then
                            file_date=$(extract_metadata_field "$metadata" "File Modification Date/Time")
                        fi
                        ;;
                    mp4|avi|mov|mkv|wmv|flv|webm|m4v|3gp|mpg|mpeg)
                        local metadata=$(exiftool "$file" 2>/dev/null)
                        file_date=$(extract_metadata_field "$metadata" "Date/Time Original")
                        if [ -z "$file_date" ]; then
                            file_date=$(extract_metadata_field "$metadata" "File Modification Date/Time")
                        fi
                        ;;
                esac
                
                # If no metadata date, use file modification date
                if [ -z "$file_date" ]; then
                    file_date=$(stat -f "%Sm" -t "%Y:%m:%d %H:%M:%S" "$file" 2>/dev/null || stat -c "%y" "$file" 2>/dev/null)
                fi
                
                # Convert file date to timestamp for comparison
                if [ -n "$file_date" ]; then
                    file_timestamp=$(date -j -f "%Y:%m:%d %H:%M:%S" "$file_date" "+%s" 2>/dev/null || date -d "$file_date" "+%s" 2>/dev/null)
                fi
                
                # Apply date filters
                if [ -n "$DATE_FROM" ] && [ -n "$file_timestamp" ]; then
                    local from_timestamp=$(parse_date_to_timestamp "$DATE_FROM")
                    if [ -n "$from_timestamp" ] && [ "$file_timestamp" -lt "$from_timestamp" ]; then
                        continue
                    fi
                fi
                
                if [ -n "$DATE_TO" ] && [ -n "$file_timestamp" ]; then
                    local to_timestamp=$(parse_date_to_timestamp "$DATE_TO")
                    if [ -n "$to_timestamp" ] && [ "$file_timestamp" -gt "$to_timestamp" ]; then
                        continue
                    fi
                fi
            fi
            
            # Get file extension
            local ext="${file##*.}"
            ext=$(echo "$ext" | tr '[:upper:]' '[:lower:]')

            # File type filtering
            local is_image=false
            local is_video=false
            case "$ext" in
                jpg|jpeg|png|gif|bmp|tiff|tif|webp|heic|heif)
                    is_image=true
                    ;;
                mp4|avi|mov|mkv|wmv|flv|webm|m4v|3gp|mpg|mpeg)
                    is_video=true
                    ;;
            esac
            if [ "$IMAGES_ONLY" = true ] && [ "$is_image" != true ]; then
                continue
            fi
            if [ "$VIDEOS_ONLY" = true ] && [ "$is_video" != true ]; then
                continue
            fi
            if [ -n "$FILTER_FORMAT" ] && [ "$ext" != "$FILTER_FORMAT" ]; then
                continue
            fi
            
            # Process file
            ((count++))
            
            # Get file size
            total_size=$((total_size + size))
            
            # Collect format-specific size data
            format_sizes="$format_sizes$ext:$size"$'\n'
            
            # Calculate file hash for duplicate detection
            local file_hash=$(shasum "$file" 2>/dev/null | cut -d' ' -f1)
            if [ -n "$file_hash" ]; then
                file_hashes="$file_hashes$file_hash:$file"$'\n'
            fi
            
            # Determine file type and extract metadata
            case "$ext" in
                jpg|jpeg|png|gif|bmp|tiff|tif|webp|heic|heif)
                    ((images++))
                    all_formats="$all_formats $ext"
                    
                    # Collect image size for statistics
                    image_sizes="$image_sizes$size"$'\n'
                    
                    # Extract metadata from images
                    local metadata=$(exiftool "$file" 2>/dev/null)
                    
                    # Collect camera info
                    local camera=$(echo "$metadata" | grep -E "(Make|Model)" | head -2)
                    if [ -n "$camera" ]; then
                        all_cameras="$all_cameras $camera"
                    fi
                    
                    # Extract resolution and aspect ratio
                    local width=$(echo "$metadata" | grep "Image Width" | head -1 | sed 's/.*: //')
                    local height=$(echo "$metadata" | grep "Image Height" | head -1 | sed 's/.*: //')
                    if [ -n "$width" ] && [ -n "$height" ]; then
                        image_resolutions="$image_resolutions${width}x${height}"$'\n'
                        # Calculate aspect ratio (simplified)
                        local aspect_ratio=$(echo "scale=2; $width / $height" | bc 2>/dev/null || echo "0")
                        if [ "$aspect_ratio" != "0" ]; then
                            image_aspects="$image_aspects$aspect_ratio"$'\n'
                        fi
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
                    
                    # Collect video size for statistics
                    video_sizes="$video_sizes$size"$'\n'
                    
                    # Extract metadata from videos
                    local metadata=$(ffprobe -v quiet -print_format json -show_format -show_streams "$file" 2>/dev/null)
                    
                    # Extract video resolution and aspect ratio
                    local width=$(echo "$metadata" | jq -r '.streams[] | select(.codec_type=="video") | .width // empty' 2>/dev/null | head -1)
                    local height=$(echo "$metadata" | jq -r '.streams[] | select(.codec_type=="video") | .height // empty' 2>/dev/null | head -1)
                    if [ -n "$width" ] && [ -n "$height" ] && [ "$width" != "null" ] && [ "$height" != "null" ]; then
                        video_resolutions="$video_resolutions${width}x${height}"$'\n'
                        # Calculate aspect ratio (simplified)
                        local aspect_ratio=$(echo "scale=2; $width / $height" | bc 2>/dev/null || echo "0")
                        if [ "$aspect_ratio" != "0" ]; then
                            video_aspects="$video_aspects$aspect_ratio"$'\n'
                        fi
                    fi
                    
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
        
        # Enhanced Statistics
        calculate_format_averages "$format_sizes"
        analyze_storage_trends "$image_sizes" "$video_sizes"
        detect_duplicates "$file_hashes"
        analyze_resolutions "$image_resolutions" "$video_resolutions"
        analyze_aspect_ratios "$image_aspects" "$video_aspects"
        
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
        # Process files for CSV output
        local csv_data=""
        
        while read -r file; do
            ((count++))
            
            # Get file extension
            local ext="${file##*.}"
            ext=$(echo "$ext" | tr '[:upper:]' '[:lower:]')
            
            # Get file size
            local size=$(stat -f%z "$file" 2>/dev/null || stat -c%s "$file" 2>/dev/null)
            local size_mb=$(echo "scale=2; $size/1024/1024" | bc 2>/dev/null || echo "0")
            total_size=$((total_size + size))
            
            # Determine file type and process for CSV
            local file_type="other"
            local format="$ext"
            
            case "$ext" in
                jpg|jpeg|png|gif|bmp|tiff|tif|webp|heic|heif)
                    ((images++))
                    file_type="image"
                    ;;
                mp4|avi|mov|mkv|wmv|flv|webm|m4v|3gp|mpg|mpeg)
                    ((videos++))
                    file_type="video"
                    ;;
            esac
            
            # Process file for CSV output
            local csv_line=$(process_file_for_csv "$file" "$file_type" "$format" "$size" "$size_mb")
            csv_data="$csv_data$csv_line"$'\n'
            
        done < <(eval "$find_cmd")
        
        # Generate CSV report
        generate_csv_report "$directory" "$csv_data"
    fi
}

# Run main function with all arguments
main "$@" 