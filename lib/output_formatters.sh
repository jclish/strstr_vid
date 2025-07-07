#!/bin/bash

# lib/output_formatters.sh - Shared output formatting functions
# This library provides common functions for formatting output in various formats

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

# Function to escape CSV values (alternative name for compatibility)
escape_csv() {
    escape_csv_value "$1"
}

# Function to generate JSON report structure
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

# Function to generate CSV report header
generate_csv_header() {
    echo "file,type,format,size,size_mb,date,camera_make,camera_model,keywords,description"
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
        local metadata=$(extract_image_metadata "$file")
        
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
        local metadata=$(extract_video_metadata_exiftool "$file")
        
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
        local ffprobe_metadata=$(extract_video_metadata "$file")
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

# Function to format file size in human readable format
format_file_size() {
    local bytes="$1"
    local size_mb=$(echo "scale=2; $bytes / 1024 / 1024" | bc 2>/dev/null || echo "0")
    echo "$size_mb"
}

# Function to format timestamp for display
format_timestamp() {
    local timestamp="$1"
    if [ -n "$timestamp" ]; then
        date -d "@$timestamp" 2>/dev/null || date -r "$timestamp" 2>/dev/null || echo "$timestamp"
    else
        echo "Unknown"
    fi
}

# Function to generate progress bar
generate_progress_bar() {
    local current="$1"
    local total="$2"
    local width="${3:-50}"
    
    if [ "$total" -eq 0 ]; then
        return
    fi
    
    local percentage=$((current * 100 / total))
    local filled=$((percentage * width / 100))
    local empty=$((width - filled))
    
    printf "\r["
    printf "%${filled}s" | tr ' ' '#'
    printf "%${empty}s" | tr ' ' '-'
    printf "] %d%%" "$percentage"
    
    if [ "$current" -eq "$total" ]; then
        echo
    fi
}

# Function to clear progress bar line
clear_progress_line() {
    printf "\r%${COLUMNS}s\r"
} 