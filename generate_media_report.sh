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
EXPORT_HTML=false
EXPORT_MARKDOWN=false
EXPORT_XML=false
SAVE_REPORT=""
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
  -f, --format <format>    Output format: text, json, csv, html, markdown, xml (default: text)
  -v, --verbose            Show detailed processing information
  -r, --recursive          Analyze recursively in subdirectories
  -d, --details            Show detailed metadata for each file
  -j, --json               Export detailed JSON report
  -c, --csv                Export CSV report
  --html                   Export HTML report
  --markdown               Export Markdown report
  --xml                    Export XML report
  --save-report <file>     Save text report to file
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
  $0 /path/to/media --html --markdown
  $0 /path/to/media -f html
  $0 /path/to/media --xml --verbose
  $0 /path/to/media --save-report report.txt

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

# Function to generate HTML report
generate_html_report() {
    local dir="$1"
    local count="$2"
    local images="$3"
    local videos="$4"
    local total_size="$5"
    local all_keywords="$6"
    local all_cameras="$7"
    local all_formats="$8"
    
    cat << EOF
<!DOCTYPE html>
<html lang="en">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>Media Report - $(basename "$dir")</title>
    <style>
        body { font-family: Arial, sans-serif; margin: 20px; background-color: #f5f5f5; }
        .container { max-width: 1200px; margin: 0 auto; background: white; padding: 20px; border-radius: 8px; box-shadow: 0 2px 10px rgba(0,0,0,0.1); }
        h1 { color: #2c3e50; border-bottom: 3px solid #3498db; padding-bottom: 10px; }
        h2 { color: #34495e; margin-top: 30px; }
        .summary { background: #ecf0f1; padding: 15px; border-radius: 5px; margin: 20px 0; }
        .stats { display: grid; grid-template-columns: repeat(auto-fit, minmax(200px, 1fr)); gap: 15px; margin: 20px 0; }
        .stat-card { background: #3498db; color: white; padding: 15px; border-radius: 5px; text-align: center; }
        .stat-number { font-size: 2em; font-weight: bold; }
        .stat-label { font-size: 0.9em; opacity: 0.9; }
        .format-list { background: #f8f9fa; padding: 15px; border-radius: 5px; }
        .keyword-cloud { background: #fff3cd; padding: 15px; border-radius: 5px; margin: 20px 0; }
        .keyword { display: inline-block; margin: 2px; padding: 4px 8px; background: #007bff; color: white; border-radius: 3px; font-size: 0.8em; }
        .generated { color: #6c757d; font-size: 0.9em; text-align: center; margin-top: 30px; }
    </style>
</head>
<body>
    <div class="container">
        <h1>📊 Media Report</h1>
        <div class="generated">Generated on $(date) for directory: $dir</div>
        
        <div class="summary">
            <h2>📋 Summary</h2>
            <div class="stats">
                <div class="stat-card">
                    <div class="stat-number">$count</div>
                    <div class="stat-label">Total Files</div>
                </div>
                <div class="stat-card">
                    <div class="stat-number">$images</div>
                    <div class="stat-label">Images</div>
                </div>
                <div class="stat-card">
                    <div class="stat-number">$videos</div>
                    <div class="stat-label">Videos</div>
                </div>
                <div class="stat-card">
                    <div class="stat-number">$(echo "scale=1; $total_size/1024/1024" | bc) MB</div>
                    <div class="stat-label">Total Size</div>
                </div>
            </div>
        </div>
        
        <h2>📷 Image Analysis</h2>
        <div class="format-list">
            <p><strong>Image count:</strong> $images</p>
            <p><strong>Formats found:</strong></p>
            <ul>
EOF
    
    # Add format breakdown
    if [ -n "$all_formats" ]; then
        echo "$all_formats" | tr ' ' '\n' | grep -E "(jpg|jpeg|png|gif|bmp|tiff|tif|webp|heic|heif)" | sort | uniq -c | sort -nr | while read count format; do
            echo "                <li>$format: $count files</li>"
        done
    fi
    
    cat << EOF
            </ul>
        </div>
        
        <h2>🎬 Video Analysis</h2>
        <div class="format-list">
            <p><strong>Video count:</strong> $videos</p>
            <p><strong>Formats found:</strong></p>
            <ul>
EOF
    
    # Add video format breakdown
    if [ -n "$all_formats" ]; then
        echo "$all_formats" | tr ' ' '\n' | grep -E "(mp4|avi|mov|mkv|wmv|flv|webm|m4v|3gp|mpg|mpeg)" | sort | uniq -c | sort -nr | while read count format; do
            echo "                <li>$format: $count files</li>"
        done
    fi
    
    cat << EOF
            </ul>
        </div>
        
        <h2>🔍 Keyword Analysis</h2>
        <div class="keyword-cloud">
EOF
    
    # Add keyword cloud
    if [ -n "$all_keywords" ]; then
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
            sort | uniq -c | sort -nr | head -20 | while read count word; do
                echo "            <span class=\"keyword\">$word ($count)</span>"
            done
    fi
    
    cat << EOF
        </div>
        
        <div class="generated">
            Report generated by generate_media_report.sh v2.9
        </div>
    </div>
</body>
</html>
EOF
}

# Function to generate Markdown report
generate_markdown_report() {
    local dir="$1"
    local count="$2"
    local images="$3"
    local videos="$4"
    local total_size="$5"
    local all_keywords="$6"
    local all_cameras="$7"
    local all_formats="$8"
    
    cat << EOF
# 📊 Media Report

**Generated:** $(date)  
**Directory:** $dir

## 📋 Summary

| Metric | Value |
|--------|-------|
| Total Files | $count |
| Images | $images |
| Videos | $videos |
| Other | $((count - images - videos)) |
| Total Size | $(echo "scale=1; $total_size/1024/1024" | bc) MB |

## 📷 Image Analysis

**Image count:** $images

### Formats Found
EOF
    
    # Add format breakdown
    if [ -n "$all_formats" ]; then
        echo "$all_formats" | tr ' ' '\n' | grep -E "(jpg|jpeg|png|gif|bmp|tiff|tif|webp|heic|heif)" | sort | uniq -c | sort -nr | while read count format; do
            echo "- $format: $count files"
        done
    fi
    
    cat << EOF

## 🎬 Video Analysis

**Video count:** $videos

### Formats Found
EOF
    
    # Add video format breakdown
    if [ -n "$all_formats" ]; then
        echo "$all_formats" | tr ' ' '\n' | grep -E "(mp4|avi|mov|mkv|wmv|flv|webm|m4v|3gp|mpg|mpeg)" | sort | uniq -c | sort -nr | while read count format; do
            echo "- $format: $count files"
        done
    fi
    
    cat << EOF

## 🔍 Keyword Analysis

### Top Keywords
EOF
    
    # Add keyword analysis
    if [ -n "$all_keywords" ]; then
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
            sort | uniq -c | sort -nr | head -15 | while read count word; do
                echo "- **$word**: $count occurrences"
            done
    fi
    
    cat << EOF

---
*Report generated by generate_media_report.sh v2.9*
EOF
}

# Function to generate ASCII bar chart
generate_ascii_chart() {
    local title="$1"
    local data="$2"
    local max_width=40
    
    echo ""
    echo -e "${YELLOW}$title${NC}"
    echo "$(printf '=%.0s' $(seq 1 ${#title}))"
    
    # Find the maximum value for scaling
    local max_value=0
    echo "$data" | while read count label; do
        if [ "$count" -gt "$max_value" ]; then
            max_value="$count"
        fi
    done
    
    # Generate chart bars
    echo "$data" | while read count label; do
        if [ "$max_value" -gt 0 ]; then
            local bar_width=$((count * max_width / max_value))
            # Ensure at least 1 character for non-zero values
            if [ "$count" -gt 0 ] && [ "$bar_width" -eq 0 ]; then
                bar_width=1
            fi
            local bar=""
            for i in $(seq 1 $bar_width); do
                bar="${bar}█"
            done
            printf "  %-15s [%-${max_width}s] %d\n" "$label" "$bar" "$count"
        else
            printf "  %-15s [%-${max_width}s] %d\n" "$label" "" "$count"
        fi
    done
}

# Function to generate XML report
generate_xml_report() {
    local dir="$1"
    local count="$2"
    local images="$3"
    local videos="$4"
    local total_size="$5"
    local all_keywords="$6"
    local all_cameras="$7"
    local all_formats="$8"
    
    cat << EOF
<?xml version="1.0" encoding="UTF-8"?>
<mediaReport>
    <metadata>
        <generated>$(date -u +"%Y-%m-%dT%H:%M:%SZ")</generated>
        <directory>$dir</directory>
        <script>generate_media_report.sh</script>
        <version>2.9</version>
    </metadata>
    
    <summary>
        <totalFiles>$count</totalFiles>
        <images>$images</images>
        <videos>$videos</videos>
        <other>$((count - images - videos))</other>
        <totalSize>$total_size</totalSize>
        <totalSizeMB>$(echo "scale=1; $total_size/1024/1024" | bc)</totalSizeMB>
    </summary>
    
    <imageAnalysis>
        <count>$images</count>
        <formats>
EOF
    
    # Add image format breakdown
    if [ -n "$all_formats" ]; then
        echo "$all_formats" | tr ' ' '\n' | grep -E "(jpg|jpeg|png|gif|bmp|tiff|tif|webp|heic|heif)" | sort | uniq -c | sort -nr | while read count format; do
            echo "            <format name=\"$format\" count=\"$count\"/>"
        done
    fi
    
    cat << EOF
        </formats>
    </imageAnalysis>
    
    <videoAnalysis>
        <count>$videos</count>
        <formats>
EOF
    
    # Add video format breakdown
    if [ -n "$all_formats" ]; then
        echo "$all_formats" | tr ' ' '\n' | grep -E "(mp4|avi|mov|mkv|wmv|flv|webm|m4v|3gp|mpg|mpeg)" | sort | uniq -c | sort -nr | while read count format; do
            echo "            <format name=\"$format\" count=\"$count\"/>"
        done
    fi
    
    cat << EOF
        </formats>
    </videoAnalysis>
    
    <keywordAnalysis>
        <keywords>
EOF
    
    # Add keyword analysis
    if [ -n "$all_keywords" ]; then
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
            sort | uniq -c | sort -nr | head -20 | while read count word; do
                echo "            <keyword name=\"$word\" count=\"$count\"/>"
            done
    fi
    
    cat << EOF
        </keywords>
    </keywordAnalysis>
</mediaReport>
EOF
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

# Advanced Keyword Analysis Functions

# Keyword clustering - group similar keywords together
cluster_keywords() {
    local keywords="$1"
    
    echo ""
    echo "🔗 KEYWORD CLUSTERING"
    echo "====================="
    
    if [ -z "$keywords" ]; then
        echo "No keywords available for clustering"
        return
    fi
    
    # Clean and process keywords
    local clean_keywords=$(echo "$keywords" | \
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
        sed 's/,$//g' | \
        sed 's/,$//g' | \
        sort | uniq -c | sort -nr)
    
    if [ -z "$clean_keywords" ]; then
        echo "No valid keywords found for clustering"
        return
    fi
    
    # Define keyword categories/clusters using simple variables
    local mining_keywords="mine,mining,mineral,ore,extraction,drill,excavation,quarry"
    local nature_keywords="rock,stone,geology,landscape,mountain,outdoor,natural,earth"
    local industrial_keywords="industry,industrial,equipment,machinery,construction,manufacturing,factory"
    local technology_keywords="digital,electronic,computer,device,modern,technology,innovation"
    local business_keywords="business,corporate,office,professional,work,commerce,enterprise"
    local travel_keywords="travel,tourism,landmark,location,place,destination,visit"
    local people_keywords="person,people,worker,human,individual,portrait,face"
    local emotion_keywords="happy,joy,excitement,emotion,feeling,mood,expression"
    local color_keywords="color,colour,bright,dark,light,shade,tone,palette"
    local quality_keywords="high,quality,premium,excellent,superior,professional"
    
    # Analyze keywords and assign to clusters
    echo "📊 KEYWORD CLUSTERS BY THEME:"
    echo "$clean_keywords" | while read count keyword; do
        local found_cluster=""
        
        if echo "$mining_keywords" | grep -q "$keyword"; then
            found_cluster="mining"
        elif echo "$nature_keywords" | grep -q "$keyword"; then
            found_cluster="nature"
        elif echo "$industrial_keywords" | grep -q "$keyword"; then
            found_cluster="industrial"
        elif echo "$technology_keywords" | grep -q "$keyword"; then
            found_cluster="technology"
        elif echo "$business_keywords" | grep -q "$keyword"; then
            found_cluster="business"
        elif echo "$travel_keywords" | grep -q "$keyword"; then
            found_cluster="travel"
        elif echo "$people_keywords" | grep -q "$keyword"; then
            found_cluster="people"
        elif echo "$emotion_keywords" | grep -q "$keyword"; then
            found_cluster="emotion"
        elif echo "$color_keywords" | grep -q "$keyword"; then
            found_cluster="color"
        elif echo "$quality_keywords" | grep -q "$keyword"; then
            found_cluster="quality"
        fi
        
        if [ -n "$found_cluster" ]; then
            printf "  %-12s: %s (%d occurrences)\n" "$found_cluster" "$keyword" "$count"
        else
            printf "  %-12s: %s (%d occurrences)\n" "other" "$keyword" "$count"
        fi
    done | head -20
    
    # Show cluster summary
    echo ""
    echo "📈 CLUSTER SUMMARY:"
    local mining_count=0
    local nature_count=0
    local industrial_count=0
    local technology_count=0
    local business_count=0
    local travel_count=0
    local people_count=0
    local emotion_count=0
    local color_count=0
    local quality_count=0
    local other_count=0
    
    echo "$clean_keywords" | while read count keyword; do
        if echo "$mining_keywords" | grep -q "$keyword"; then
            mining_count=$((mining_count + count))
        elif echo "$nature_keywords" | grep -q "$keyword"; then
            nature_count=$((nature_count + count))
        elif echo "$industrial_keywords" | grep -q "$keyword"; then
            industrial_count=$((industrial_count + count))
        elif echo "$technology_keywords" | grep -q "$keyword"; then
            technology_count=$((technology_count + count))
        elif echo "$business_keywords" | grep -q "$keyword"; then
            business_count=$((business_count + count))
        elif echo "$travel_keywords" | grep -q "$keyword"; then
            travel_count=$((travel_count + count))
        elif echo "$people_keywords" | grep -q "$keyword"; then
            people_count=$((people_count + count))
        elif echo "$emotion_keywords" | grep -q "$keyword"; then
            emotion_count=$((emotion_count + count))
        elif echo "$color_keywords" | grep -q "$keyword"; then
            color_count=$((color_count + count))
        elif echo "$quality_keywords" | grep -q "$keyword"; then
            quality_count=$((quality_count + count))
        else
            other_count=$((other_count + count))
        fi
    done
    
    # Display cluster counts
    if [ "$mining_count" -gt 0 ]; then
        printf "  %-12s: %d keywords\n" "mining" "$mining_count"
    fi
    if [ "$nature_count" -gt 0 ]; then
        printf "  %-12s: %d keywords\n" "nature" "$nature_count"
    fi
    if [ "$industrial_count" -gt 0 ]; then
        printf "  %-12s: %d keywords\n" "industrial" "$industrial_count"
    fi
    if [ "$technology_count" -gt 0 ]; then
        printf "  %-12s: %d keywords\n" "technology" "$technology_count"
    fi
    if [ "$business_count" -gt 0 ]; then
        printf "  %-12s: %d keywords\n" "business" "$business_count"
    fi
    if [ "$travel_count" -gt 0 ]; then
        printf "  %-12s: %d keywords\n" "travel" "$travel_count"
    fi
    if [ "$people_count" -gt 0 ]; then
        printf "  %-12s: %d keywords\n" "people" "$people_count"
    fi
    if [ "$emotion_count" -gt 0 ]; then
        printf "  %-12s: %d keywords\n" "emotion" "$emotion_count"
    fi
    if [ "$color_count" -gt 0 ]; then
        printf "  %-12s: %d keywords\n" "color" "$color_count"
    fi
    if [ "$quality_count" -gt 0 ]; then
        printf "  %-12s: %d keywords\n" "quality" "$quality_count"
    fi
    if [ "$other_count" -gt 0 ]; then
        printf "  %-12s: %d keywords\n" "other" "$other_count"
    fi
}

# Theme detection - identify common themes in descriptions
detect_themes() {
    local keywords="$1"
    
    echo ""
    echo "🎯 THEME DETECTION"
    echo "=================="
    
    if [ -z "$keywords" ]; then
        echo "No keywords available for theme detection"
        return
    fi
    
    # Clean and process keywords
    local clean_keywords=$(echo "$keywords" | \
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
        sed 's/,$//g' | \
        sed 's/,$//g' | \
        sort | uniq -c | sort -nr)
    
    if [ -z "$clean_keywords" ]; then
        echo "No valid keywords found for theme detection"
        return
    fi
    
    # Define theme patterns using simple variables
    local industrial_theme="mining,industry,industrial,equipment,machinery,factory,construction"
    local nature_theme="rock,stone,geology,landscape,mountain,outdoor,natural,earth,mineral"
    local business_theme="business,corporate,office,professional,work,commerce,enterprise"
    local technology_theme="digital,electronic,computer,device,modern,technology,innovation"
    local travel_theme="travel,tourism,landmark,location,place,destination,visit"
    local people_theme="person,people,worker,human,individual,portrait,face"
    local emotion_theme="happy,joy,excitement,emotion,feeling,mood,expression"
    local quality_theme="high,quality,premium,excellent,superior,professional"
    
    # Analyze themes
    echo "🎨 DETECTED THEMES:"
    local industrial_count=0
    local nature_count=0
    local business_count=0
    local technology_count=0
    local travel_count=0
    local people_count=0
    local emotion_count=0
    local quality_count=0
    
    # Use a while read loop with a here-string to update counters in the main shell
    while read count keyword; do
        local matched=""
        if echo "$industrial_theme" | grep -qw "$keyword"; then
            industrial_count=$((industrial_count + count))
            matched="industrial"
        elif echo "$nature_theme" | grep -qw "$keyword"; then
            nature_count=$((nature_count + count))
            matched="nature"
        elif echo "$business_theme" | grep -qw "$keyword"; then
            business_count=$((business_count + count))
            matched="business"
        elif echo "$technology_theme" | grep -qw "$keyword"; then
            technology_count=$((technology_count + count))
            matched="technology"
        elif echo "$travel_theme" | grep -qw "$keyword"; then
            travel_count=$((travel_count + count))
            matched="travel"
        elif echo "$people_theme" | grep -qw "$keyword"; then
            people_count=$((people_count + count))
            matched="people"
        elif echo "$emotion_theme" | grep -qw "$keyword"; then
            emotion_count=$((emotion_count + count))
            matched="emotion"
        elif echo "$quality_theme" | grep -qw "$keyword"; then
            quality_count=$((quality_count + count))
            matched="quality"
        fi
    done <<< "$clean_keywords"
    
    # Display theme counts
    if [ "$industrial_count" -gt 0 ]; then
        printf "  %-12s: %d occurrences\n" "industrial" "$industrial_count"
    fi
    if [ "$nature_count" -gt 0 ]; then
        printf "  %-12s: %d occurrences\n" "nature" "$nature_count"
    fi
    if [ "$business_count" -gt 0 ]; then
        printf "  %-12s: %d occurrences\n" "business" "$business_count"
    fi
    if [ "$technology_count" -gt 0 ]; then
        printf "  %-12s: %d occurrences\n" "technology" "$technology_count"
    fi
    if [ "$travel_count" -gt 0 ]; then
        printf "  %-12s: %d occurrences\n" "travel" "$travel_count"
    fi
    if [ "$people_count" -gt 0 ]; then
        printf "  %-12s: %d occurrences\n" "people" "$people_count"
    fi
    if [ "$emotion_count" -gt 0 ]; then
        printf "  %-12s: %d occurrences\n" "emotion" "$emotion_count"
    fi
    if [ "$quality_count" -gt 0 ]; then
        printf "  %-12s: %d occurrences\n" "quality" "$quality_count"
    fi
    
    # Show dominant theme
    echo ""
    echo "🏆 DOMINANT THEME:"
    local max_count=0
    local dominant_theme=""
    
    if [ "$industrial_count" -gt "$max_count" ]; then
        max_count="$industrial_count"
        dominant_theme="industrial"
    fi
    if [ "$nature_count" -gt "$max_count" ]; then
        max_count="$nature_count"
        dominant_theme="nature"
    fi
    if [ "$business_count" -gt "$max_count" ]; then
        max_count="$business_count"
        dominant_theme="business"
    fi
    if [ "$technology_count" -gt "$max_count" ]; then
        max_count="$technology_count"
        dominant_theme="technology"
    fi
    if [ "$travel_count" -gt "$max_count" ]; then
        max_count="$travel_count"
        dominant_theme="travel"
    fi
    if [ "$people_count" -gt "$max_count" ]; then
        max_count="$people_count"
        dominant_theme="people"
    fi
    if [ "$emotion_count" -gt "$max_count" ]; then
        max_count="$emotion_count"
        dominant_theme="emotion"
    fi
    if [ "$quality_count" -gt "$max_count" ]; then
        max_count="$quality_count"
        dominant_theme="quality"
    fi
    
    if [ -n "$dominant_theme" ] && [ "$max_count" -gt 0 ]; then
        echo "  Primary theme: $dominant_theme ($max_count occurrences)"
    else
        echo "  No dominant theme detected"
    fi
}

# Sentiment analysis - analyze description sentiment
analyze_sentiment() {
    local keywords="$1"
    
    echo ""
    echo "😊 SENTIMENT ANALYSIS"
    echo "====================="
    
    if [ -z "$keywords" ]; then
        echo "No keywords available for sentiment analysis"
        return
    fi
    
    # Define sentiment keywords using simple variables
    local positive_keywords="happy,joy,excitement,beautiful,amazing,wonderful,great,excellent,positive,success,achievement,winning,prosperous,rich,wealthy,precious,valuable"
    local negative_keywords="sad,depressing,dangerous,risky,hazardous,poor,poverty,difficult,hard,challenging,abandoned,ruined,destroyed,damaged"
    local neutral_keywords="neutral,standard,normal,regular,typical,common,ordinary,average,moderate"
    local professional_keywords="professional,business,corporate,industrial,commercial,enterprise,formal,official"
    local creative_keywords="creative,artistic,innovative,unique,original,creative,imaginative,inspirational"
    
    # Clean and process keywords
    local clean_keywords=$(echo "$keywords" | \
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
        sort | uniq -c | sort -nr)
    
    if [ -z "$clean_keywords" ]; then
        echo "No valid keywords found for sentiment analysis"
        return
    fi
    
    # Analyze sentiment
    echo "📊 SENTIMENT BREAKDOWN:"
    local positive_count=0
    local negative_count=0
    local neutral_count=0
    local professional_count=0
    local creative_count=0
    
    echo "$clean_keywords" | while read count keyword; do
        if echo "$positive_keywords" | grep -q "$keyword"; then
            positive_count=$((positive_count + count))
        elif echo "$negative_keywords" | grep -q "$keyword"; then
            negative_count=$((negative_count + count))
        elif echo "$neutral_keywords" | grep -q "$keyword"; then
            neutral_count=$((neutral_count + count))
        elif echo "$professional_keywords" | grep -q "$keyword"; then
            professional_count=$((professional_count + count))
        elif echo "$creative_keywords" | grep -q "$keyword"; then
            creative_count=$((creative_count + count))
        fi
    done
    
    # Display sentiment counts
    if [ "$positive_count" -gt 0 ]; then
        printf "  %-12s: %d occurrences\n" "positive" "$positive_count"
    fi
    if [ "$negative_count" -gt 0 ]; then
        printf "  %-12s: %d occurrences\n" "negative" "$negative_count"
    fi
    if [ "$neutral_count" -gt 0 ]; then
        printf "  %-12s: %d occurrences\n" "neutral" "$neutral_count"
    fi
    if [ "$professional_count" -gt 0 ]; then
        printf "  %-12s: %d occurrences\n" "professional" "$professional_count"
    fi
    if [ "$creative_count" -gt 0 ]; then
        printf "  %-12s: %d occurrences\n" "creative" "$creative_count"
    fi
    
    # Overall sentiment score
    echo ""
    echo "📈 OVERALL SENTIMENT:"
    local total_sentiment=$((positive_count + negative_count + neutral_count))
    if [ "$total_sentiment" -gt 0 ]; then
        local positive_percent=$((positive_count * 100 / total_sentiment))
        local negative_percent=$((negative_count * 100 / total_sentiment))
        local neutral_percent=$((neutral_count * 100 / total_sentiment))
        
        echo "  Positive: $positive_count ($positive_percent%)"
        echo "  Negative: $negative_count ($negative_percent%)"
        echo "  Neutral:  $neutral_count ($neutral_percent%)"
        
        if [ "$positive_count" -gt "$negative_count" ]; then
            echo "  Overall: Positive sentiment"
        elif [ "$negative_count" -gt "$positive_count" ]; then
            echo "  Overall: Negative sentiment"
        else
            echo "  Overall: Neutral sentiment"
        fi
    else
        echo "  No sentiment keywords detected"
    fi
}

# Language detection - detect content language
detect_language() {
    local keywords="$1"
    
    echo ""
    echo "🌍 LANGUAGE DETECTION"
    echo "====================="
    
    if [ -z "$keywords" ]; then
        echo "No keywords available for language detection"
        return
    fi
    
    # Clean and process keywords
    local clean_keywords=$(echo "$keywords" | \
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
        sort | uniq -c | sort -nr)
    
    if [ -z "$clean_keywords" ]; then
        echo "No valid keywords found for language detection"
        return
    fi
    
    # Simple language detection based on common words
    local english_count=0
    local spanish_count=0
    local french_count=0
    local german_count=0
    local other_count=0
    
    # Common words in different languages
    local english_words="the,and,or,but,for,with,by,from,this,that,these,those,is,are,was,were,be,been,have,has,had,do,does,did,will,would,could,should,may,might,can,must,shall"
    local spanish_words="el,la,los,las,un,una,unos,unas,y,o,pero,para,con,por,desde,este,esta,estos,estas,es,son,era,eran,ser,estar,haber,tener,hacer,ir,venir,ver"
    local french_words="le,la,les,un,une,des,et,ou,mais,pour,avec,par,de,ce,cette,ces,est,sont,était,étaient,être,avoir,faire,aller,venir,voir"
    local german_words="der,die,das,ein,eine,einen,einer,und,oder,aber,für,mit,von,aus,bei,seit,ohne,gegen,über,unter,vor,hinter,neben,zwischen"
    
    echo "$clean_keywords" | while read count keyword; do
        if echo "$english_words" | grep -q "$keyword"; then
            english_count=$((english_count + count))
        elif echo "$spanish_words" | grep -q "$keyword"; then
            spanish_count=$((spanish_count + count))
        elif echo "$french_words" | grep -q "$keyword"; then
            french_count=$((french_count + count))
        elif echo "$german_words" | grep -q "$keyword"; then
            german_count=$((german_count + count))
        else
            other_count=$((other_count + count))
        fi
    done
    
    echo "📊 LANGUAGE BREAKDOWN:"
    if [ "$english_count" -gt 0 ]; then
        echo "  English: $english_count occurrences"
    fi
    if [ "$spanish_count" -gt 0 ]; then
        echo "  Spanish: $spanish_count occurrences"
    fi
    if [ "$french_count" -gt 0 ]; then
        echo "  French: $french_count occurrences"
    fi
    if [ "$german_count" -gt 0 ]; then
        echo "  German: $german_count occurrences"
    fi
    if [ "$other_count" -gt 0 ]; then
        echo "  Other: $other_count occurrences"
    fi
    
    # Determine primary language
    local max_count=0
    local primary_language=""
    
    if [ "$english_count" -gt "$max_count" ]; then
        max_count="$english_count"
        primary_language="English"
    fi
    if [ "$spanish_count" -gt "$max_count" ]; then
        max_count="$spanish_count"
        primary_language="Spanish"
    fi
    if [ "$french_count" -gt "$max_count" ]; then
        max_count="$french_count"
        primary_language="French"
    fi
    if [ "$german_count" -gt "$max_count" ]; then
        max_count="$german_count"
        primary_language="German"
    fi
    
    if [ -n "$primary_language" ]; then
        echo ""
        echo "🎯 PRIMARY LANGUAGE: $primary_language"
    else
        echo ""
        echo "🎯 PRIMARY LANGUAGE: Undetermined"
    fi
}

# Keyword frequency heatmap - visualize keyword distribution
generate_keyword_heatmap() {
    local keywords="$1"
    
    echo ""
    echo "🔥 KEYWORD FREQUENCY HEATMAP"
    echo "============================"
    
    if [ -z "$keywords" ]; then
        echo "No keywords available for heatmap generation"
        return
    fi
    
    # Clean and process keywords
    local clean_keywords=$(echo "$keywords" | \
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
        sort | uniq -c | sort -nr)
    
    if [ -z "$clean_keywords" ]; then
        echo "No valid keywords found for heatmap generation"
        return
    fi
    
    # Get top keywords for heatmap
    local top_keywords=$(echo "$clean_keywords" | head -15)
    local max_count=$(echo "$top_keywords" | head -1 | awk '{print $1}')
    
    echo "📊 KEYWORD FREQUENCY VISUALIZATION:"
    echo "$top_keywords" | while read count keyword; do
        # Calculate heatmap intensity (1-10 scale)
        local intensity=$((count * 10 / max_count))
        if [ "$intensity" -eq 0 ]; then
            intensity=1
        fi
        
        # Create visual heatmap bar
        local bar=""
        for i in $(seq 1 $intensity); do
            bar="${bar}█"
        done
        
        # Pad with spaces for alignment
        local padding=""
        for i in $(seq $intensity 10); do
            padding="${padding} "
        done
        
        printf "  %-15s: %s%s (%d)\n" "$keyword" "$bar" "$padding" "$count"
    done
    
    # Show frequency ranges
    echo ""
    echo "📈 FREQUENCY RANGES:"
    local high_count=$(echo "$clean_keywords" | awk '$1 >= 10 {count++} END {print count+0}')
    local medium_count=$(echo "$clean_keywords" | awk '$1 >= 5 && $1 < 10 {count++} END {print count+0}')
    local low_count=$(echo "$clean_keywords" | awk '$1 < 5 {count++} END {print count+0}')
    
    echo "  High frequency (10+): $high_count keywords"
    echo "  Medium frequency (5-9): $medium_count keywords"
    echo "  Low frequency (<5): $low_count keywords"
    
    # Show keyword diversity
    local total_keywords=$(echo "$clean_keywords" | wc -l)
    local unique_keywords=$(echo "$clean_keywords" | awk '{print $2}' | sort -u | wc -l)
    
    echo ""
    echo "🎯 KEYWORD DIVERSITY:"
    echo "  Total occurrences: $total_keywords"
    echo "  Unique keywords: $unique_keywords"
    if [ "$total_keywords" -gt 0 ]; then
        local avg_frequency=$(echo "scale=1; $total_keywords / $unique_keywords" | bc 2>/dev/null || echo "0")
        echo "  Average frequency: $avg_frequency per keyword"
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
    local export_html=false
    local export_markdown=false
    local export_xml=false
    local save_report=""
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
            --html)
                export_html=true
                shift
                ;;
            --markdown)
                export_markdown=true
                shift
                ;;
            --xml)
                export_xml=true
                shift
                ;;
            --save-report)
                save_report="$2"
                shift 2
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
    EXPORT_HTML="$export_html"
    EXPORT_MARKDOWN="$export_markdown"
    EXPORT_XML="$export_xml"
    SAVE_REPORT="$save_report"
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
    
    # Check if we should generate text output (default or explicitly requested)
    local generate_text=false
    if [ "$output_format" = "text" ] || [ "$output_format" = "" ]; then
        generate_text=true
    fi
    
    # Only show progress and text output for text format
    if [ "$generate_text" = true ]; then
        # Set up output redirection if save-report is specified
        local report_output=""
        if [ -n "$SAVE_REPORT" ]; then
            # Create a temporary file to capture output
            report_output=$(mktemp)
            exec 3>&1  # Save stdout
            exec 1>"$report_output"  # Redirect stdout to temp file
        fi
        
        echo "=== COMPREHENSIVE MEDIA REPORT ==="
        echo "Directory: $directory"
        echo "Generated: $(date)"
        echo ""
        
        echo "📊 PROCESSING FILES..."
        echo "========================"
        
        # Enhanced progress tracking
        local start_time=$(date +%s)
        local total_files=$(eval "$find_cmd" | wc -l)
        local processed=0
        local stage="SCANNING"
        
        # Show initial progress
        echo -e "${CYAN}🔍 Stage: $stage${NC}"
        printf "\rProgress: [%-50s] %d/%d files" "$(printf '#%.0s' $(seq 1 0))" "$processed" "$total_files"
        
        while read -r file; do
            ((processed++))
            
            # Enhanced progress bar with stage transitions
            if [ $((processed % 10)) -eq 0 ] || [ $processed -eq 1 ] || [ $processed -eq $total_files ]; then
                local progress=$((processed * 50 / total_files))
                if [ $progress -gt 50 ]; then progress=50; fi
                
                # Calculate ETA
                local current_time=$(date +%s)
                local elapsed=$((current_time - start_time))
                local eta=""
                if [ "$processed" -gt 0 ] && [ "$elapsed" -gt 0 ]; then
                    local rate=$(echo "scale=2; $processed / $elapsed" | bc 2>/dev/null || echo "0")
                    local remaining=$((total_files - processed))
                    local eta_seconds=$(echo "scale=0; $remaining / $rate" | bc 2>/dev/null || echo "0")
                    if [ "$eta_seconds" -gt 0 ]; then
                        eta=" (ETA: ${eta_seconds}s)"
                    fi
                fi
                
                # Update stage based on progress
                if [ "$processed" -eq 0 ]; then
                    stage="SCANNING"
                elif [ "$processed" -lt $((total_files / 3)) ]; then
                    stage="PROCESSING"
                elif [ "$processed" -lt $((total_files * 2 / 3)) ]; then
                    stage="ANALYZING"
                else
                    stage="FINALIZING"
                fi
                
                # Color-coded progress bar
                local progress_bar=""
                for i in $(seq 1 50); do
                    if [ $i -le $progress ]; then
                        progress_bar="${progress_bar}█"
                    else
                        progress_bar="${progress_bar}░"
                    fi
                done
                
                printf "\r${CYAN}🔍 Stage: %-12s${NC} [%s] %d/%d files%s" "$stage" "$progress_bar" "$processed" "$total_files" "$eta"
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
        
        # Generate enhanced text report
        echo ""
        echo -e "${GREEN}📋 SUMMARY REPORT${NC}"
        echo "========================"
        
        # Calculate total time
        local end_time=$(date +%s)
        local total_time=$((end_time - start_time))
        
        # Enhanced summary with color coding
        echo -e "${YELLOW}📊 File Statistics:${NC}"
        echo -e "  ${BLUE}Total files:${NC} $count"
        echo -e "  ${BLUE}Images:${NC} $images"
        echo -e "  ${BLUE}Videos:${NC} $videos"
        echo -e "  ${BLUE}Other:${NC} $((count - images - videos))"
        
        local total_size_mb=$(echo "scale=1; $total_size/1024/1024" | bc)
        echo -e "  ${BLUE}Total size:${NC} $total_size bytes (${GREEN}${total_size_mb} MB${NC})"
        echo -e "  ${BLUE}Processing time:${NC} ${CYAN}${total_time}s${NC}"
        
        # Performance metrics
        if [ "$total_time" -gt 0 ] && [ "$count" -gt 0 ]; then
            local files_per_second=$(echo "scale=1; $count / $total_time" | bc)
            echo -e "  ${BLUE}Processing rate:${NC} ${GREEN}${files_per_second} files/sec${NC}"
        fi
        
        echo ""
        echo -e "${GREEN}📷 IMAGE ANALYSIS${NC}"
        echo "========================"
        if [ "$images" -gt 0 ]; then
            echo -e "${BLUE}Image count:${NC} $images"
            
            # Format breakdown with ASCII chart
            local image_formats=$(echo "$all_formats" | tr ' ' '\n' | grep -E "(jpg|jpeg|png|gif|bmp|tiff|tif|webp|heic|heif)" | sort | uniq -c | sort -nr)
            if [ -n "$image_formats" ]; then
                generate_ascii_chart "📊 Image Format Distribution" "$image_formats"
            fi
            
            # Camera analysis with enhanced display
            if [ -n "$all_cameras" ]; then
                echo ""
                echo -e "${YELLOW}📸 Camera Analysis:${NC}"
                local camera_data=$(echo "$all_cameras" | tr ' ' '\n' | grep -v "^$" | sort | uniq -c | sort -nr | head -5)
                if [ -n "$camera_data" ]; then
                    generate_ascii_chart "📊 Top Camera Models" "$camera_data"
                fi
            fi
        else
            echo -e "${RED}No images found${NC}"
        fi
        
        echo ""
        echo -e "${GREEN}🎬 VIDEO ANALYSIS${NC}"
        echo "========================"
        if [ "$videos" -gt 0 ]; then
            echo -e "${BLUE}Video count:${NC} $videos"
            
            # Format breakdown with ASCII chart
            local video_formats=$(echo "$all_formats" | tr ' ' '\n' | grep -E "(mp4|avi|mov|mkv|wmv|flv|webm|m4v|3gp|mpg|mpeg)" | sort | uniq -c | sort -nr)
            if [ -n "$video_formats" ]; then
                generate_ascii_chart "📊 Video Format Distribution" "$video_formats"
            fi
        else
            echo -e "${RED}No videos found${NC}"
        fi
        
        echo ""
        echo -e "${GREEN}🔍 KEYWORD ANALYSIS${NC}"
        echo "========================"
        if [ -n "$all_keywords" ]; then
            # Clean and process keywords for better readability
            echo -e "${YELLOW}📝 KEYWORDS BY FREQUENCY:${NC}"
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
            echo -e "${YELLOW}📊 TOP THEMES (for podcast transcript matching):${NC}"
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
            echo -e "${YELLOW}💡 SUGGESTED SEARCH TERMS FOR PODCAST MATCHING:${NC}"
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
            
            # Advanced Keyword Analysis
            cluster_keywords "$all_keywords"
            detect_themes "$all_keywords"
            analyze_sentiment "$all_keywords"
            detect_language "$all_keywords"
            generate_keyword_heatmap "$all_keywords"
        else
            echo -e "${RED}No keywords found in metadata${NC}"
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
        
        # Restore output and save report if requested
        if [ -n "$SAVE_REPORT" ]; then
            exec 1>&3  # Restore stdout
            exec 3>&-  # Close file descriptor
            
            # Copy the captured output to the specified file
            if [ -f "$report_output" ]; then
                cp "$report_output" "$SAVE_REPORT"
                rm "$report_output"
                echo -e "${GREEN}📄 Report saved to: $SAVE_REPORT${NC}"
            fi
        fi
        
    fi
    
    # Handle multiple format exports
    if [ "$EXPORT_JSON" = true ] || [ "$EXPORT_CSV" = true ] || [ "$EXPORT_HTML" = true ] || [ "$EXPORT_MARKDOWN" = true ] || [ "$EXPORT_XML" = true ]; then
        # Reset counters for multiple format processing
        count=0
        images=0
        videos=0
        total_size=0
        all_keywords=""
        all_cameras=""
        all_formats=""
        
        # Process files for multiple formats
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
                    all_formats="$all_formats $ext"
                    ;;
                mp4|avi|mov|mkv|wmv|flv|webm|m4v|3gp|mpg|mpeg)
                    ((videos++))
                    all_formats="$all_formats $ext"
                    ;;
            esac
            
            # Extract keywords for reports
            case "$ext" in
                jpg|jpeg|png|gif|bmp|tiff|tif|webp|heic|heif)
                    local metadata=$(exiftool "$file" 2>/dev/null)
                    local keywords=$(echo "$metadata" | grep -E "(Keywords|Subject|Description|Caption|Title)" | grep -v -E "(Make|Model|Date|Time|Format|File|Size|Bytes|Camera|Image)" | head -3)
                    if [ -n "$keywords" ]; then
                        all_keywords="$all_keywords $keywords"
                    fi
                    ;;
                mp4|avi|mov|mkv|wmv|flv|webm|m4v|3gp|mpg|mpeg)
                    local metadata=$(exiftool "$file" 2>/dev/null)
                    local keywords=$(echo "$metadata" | grep -E "(Keywords|Subject|Description|Caption|Title|Comment)" | grep -v -E "(Make|Model|Date|Time|Format|File|Size|Bytes|Camera|Video|Codec|Duration)" | head -3)
                    if [ -n "$keywords" ]; then
                        all_keywords="$all_keywords $keywords"
                    fi
                    ;;
            esac
        done < <(eval "$find_cmd")
        
        # Generate requested formats
        if [ "$EXPORT_JSON" = true ]; then
            generate_json_report "$directory" "$count" "$images" "$videos" "$total_size"
        fi
        
        if [ "$EXPORT_CSV" = true ]; then
            # Process files for CSV output
            local csv_data=""
            while read -r file; do
                # Get file extension
                local ext="${file##*.}"
                ext=$(echo "$ext" | tr '[:upper:]' '[:lower:]')
                
                # Get file size
                local size=$(stat -f%z "$file" 2>/dev/null || stat -c%s "$file" 2>/dev/null)
                local size_mb=$(echo "scale=2; $size/1024/1024" | bc 2>/dev/null || echo "0")
                
                # Determine file type and process for CSV
                local file_type="other"
                local format="$ext"
                
                case "$ext" in
                    jpg|jpeg|png|gif|bmp|tiff|tif|webp|heic|heif)
                        file_type="image"
                        ;;
                    mp4|avi|mov|mkv|wmv|flv|webm|m4v|3gp|mpg|mpeg)
                        file_type="video"
                        ;;
                esac
                
                # Process file for CSV output
                local csv_line=$(process_file_for_csv "$file" "$file_type" "$format" "$size" "$size_mb")
                csv_data="$csv_data$csv_line"$'\n'
            done < <(eval "$find_cmd")
            
            generate_csv_report "$directory" "$csv_data"
        fi
        
        if [ "$EXPORT_HTML" = true ]; then
            generate_html_report "$directory" "$count" "$images" "$videos" "$total_size" "$all_keywords" "$all_cameras" "$all_formats"
        fi
        
        if [ "$EXPORT_MARKDOWN" = true ]; then
            generate_markdown_report "$directory" "$count" "$images" "$videos" "$total_size" "$all_keywords" "$all_cameras" "$all_formats"
        fi
        
        if [ "$EXPORT_XML" = true ]; then
            generate_xml_report "$directory" "$count" "$images" "$videos" "$total_size" "$all_keywords" "$all_cameras" "$all_formats"
        fi
    fi
    
    # Handle single format output
    if [ "$output_format" = "json" ]; then
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