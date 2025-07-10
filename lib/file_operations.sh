#!/bin/bash

# lib/file_operations.sh - Shared file system operations
# This library provides common functions for file finding, filtering, and directory operations

# Function to find media files in directory
find_media_files() {
    local directory="$1"
    local recursive="${2:-false}"
    local images_only="${3:-false}"
    local videos_only="${4:-false}"
    
    # Validate directory path to prevent command injection
    if echo "$directory" | grep -q '[;&|`$()]'; then
        echo "Error: Invalid directory path" >&2
        return 1
    fi
    
    # Build find command safely
    local find_args=("$directory" "-type" "f")
    
    if [ "$recursive" = false ]; then
        find_args+=("-maxdepth" "1")
    fi
    
    # Build file type filter
    if [ "$images_only" = true ]; then
        find_args+=("(" "-iname" "*.jpg" "-o" "-iname" "*.jpeg" "-o" "-iname" "*.png" "-o" "-iname" "*.gif" "-o" "-iname" "*.bmp" "-o" "-iname" "*.tiff" "-o" "-iname" "*.tif" "-o" "-iname" "*.webp" "-o" "-iname" "*.heic" "-o" "-iname" "*.heif" ")")
    elif [ "$videos_only" = true ]; then
        find_args+=("(" "-iname" "*.mp4" "-o" "-iname" "*.avi" "-o" "-iname" "*.mov" "-o" "-iname" "*.mkv" "-o" "-iname" "*.wmv" "-o" "-iname" "*.flv" "-o" "-iname" "*.webm" "-o" "-iname" "*.m4v" "-o" "-iname" "*.3gp" "-o" "-iname" "*.mpg" "-o" "-iname" "*.mpeg" ")")
    else
        find_args+=("(" "-iname" "*.jpg" "-o" "-iname" "*.jpeg" "-o" "-iname" "*.png" "-o" "-iname" "*.gif" "-o" "-iname" "*.bmp" "-o" "-iname" "*.tiff" "-o" "-iname" "*.tif" "-o" "-iname" "*.webp" "-o" "-iname" "*.heic" "-o" "-iname" "*.heif" "-o" "-iname" "*.mp4" "-o" "-iname" "*.avi" "-o" "-iname" "*.mov" "-o" "-iname" "*.mkv" "-o" "-iname" "*.wmv" "-o" "-iname" "*.flv" "-o" "-iname" "*.webm" "-o" "-iname" "*.m4v" "-o" "-iname" "*.3gp" "-o" "-iname" "*.mpg" "-o" "-iname" "*.mpeg" ")")
    fi
    
    # Execute find command safely
    find "${find_args[@]}" 2>/dev/null
}

# Function to count media files in directory
count_media_files() {
    local directory="$1"
    local recursive="${2:-false}"
    local images_only="${3:-false}"
    local videos_only="${4:-false}"
    
    find_media_files "$directory" "$recursive" "$images_only" "$videos_only" | wc -l
}

# Function to get file size
get_file_size() {
    local file="$1"
    stat -f%z "$file" 2>/dev/null || stat -c%s "$file" 2>/dev/null || echo "0"
}

# Function to get file modification time
get_file_modified_time() {
    local file="$1"
    stat -f%m "$file" 2>/dev/null || stat -c%Y "$file" 2>/dev/null || echo "0"
}

# Function to get file hash
get_file_hash() {
    local file="$1"
    sha256sum "$file" 2>/dev/null | cut -d' ' -f1 || echo ""
}

# Function to check if file is newer than timestamp
is_file_newer_than() {
    local file="$1"
    local timestamp="$2"
    
    local file_time=$(get_file_modified_time "$file")
    if [ "$file_time" -gt "$timestamp" ]; then
        return 0
    else
        return 1
    fi
}

# Function to create temporary file list
create_temp_file_list() {
    local directory="$1"
    local recursive="${2:-false}"
    local images_only="${3:-false}"
    local videos_only="${4:-false}"
    
    # Create temporary file with proper cleanup
    local temp_file=$(mktemp)
    trap 'rm -f "$temp_file"' EXIT
    
    find_media_files "$directory" "$recursive" "$images_only" "$videos_only" > "$temp_file"
    echo "$temp_file"
}

# Function to get directory size
get_directory_size() {
    local directory="$1"
    local recursive="${2:-false}"
    
    local find_cmd="find \"$directory\" -type f"
    if [ "$recursive" = false ]; then
        find_cmd="$find_cmd -maxdepth 1"
    fi
    
    # Get total size in bytes
    local total_size=$(eval "$find_cmd" -exec stat -f%z {} \; 2>/dev/null | awk '{sum += $1} END {print sum}')
    if [ -z "$total_size" ]; then
        total_size=$(eval "$find_cmd" -exec stat -c%s {} \; 2>/dev/null | awk '{sum += $1} END {print sum}')
    fi
    
    echo "${total_size:-0}"
}

# Function to format file size
format_file_size() {
    local size="$1"
    
    if [ "$size" -ge 1073741824 ]; then
        echo "scale=1; $size / 1073741824" | bc -l 2>/dev/null | sed 's/\.0$//' | sed 's/$/GB/'
    elif [ "$size" -ge 1048576 ]; then
        echo "scale=1; $size / 1048576" | bc -l 2>/dev/null | sed 's/\.0$//' | sed 's/$/MB/'
    elif [ "$size" -ge 1024 ]; then
        echo "scale=1; $size / 1024" | bc -l 2>/dev/null | sed 's/\.0$//' | sed 's/$/KB/'
    else
        echo "${size}B"
    fi
}

# Function to check if directory is empty
is_directory_empty() {
    local directory="$1"
    local recursive="${2:-false}"
    
    local count=$(count_media_files "$directory" "$recursive")
    [ "$count" -eq 0 ]
}

# Function to get file extension
get_file_extension() {
    local file="$1"
    echo "$file" | sed 's/.*\.//' | tr '[:upper:]' '[:lower:]'
}

# Function to check if file is readable
is_file_readable() {
    local file="$1"
    [ -f "$file" ] && [ -r "$file" ]
}

# Function to check if directory is accessible
is_directory_accessible() {
    local directory="$1"
    [ -d "$directory" ] && [ -r "$directory" ]
}

# Function to create backup of file
backup_file() {
    local file="$1"
    local backup_dir="${2:-$(dirname "$file")}"
    
    if [ ! -f "$file" ]; then
        return 1
    fi
    
    local filename=$(basename "$file")
    local timestamp=$(date +%Y%m%d_%H%M%S)
    local backup_path="$backup_dir/${filename}.backup.$timestamp"
    
    cp "$file" "$backup_path" 2>/dev/null
    echo "$backup_path"
}

# Function to restore file from backup
restore_file() {
    local backup_file="$1"
    local target_file="$2"
    
    if [ ! -f "$backup_file" ]; then
        return 1
    fi
    
    cp "$backup_file" "$target_file" 2>/dev/null
    return $?
}

# Function to clean up temporary files
cleanup_temp_files() {
    local temp_files=("$@")
    
    for file in "${temp_files[@]}"; do
        if [ -f "$file" ]; then
            rm -f "$file"
        fi
    done
}

# Function to create directory if it doesn't exist
ensure_directory_exists() {
    local directory="$1"
    
    if [ ! -d "$directory" ]; then
        mkdir -p "$directory" 2>/dev/null
        return $?
    fi
    
    return 0
}

# Function to get relative path
get_relative_path() {
    local base_dir="$1"
    local file_path="$2"
    
    if [[ "$file_path" == "$base_dir"* ]]; then
        echo "${file_path#$base_dir/}"
    else
        echo "$file_path"
    fi
}

# Function to normalize file path
normalize_path() {
    local path="$1"
    readlink -f "$path" 2>/dev/null || echo "$path"
} 