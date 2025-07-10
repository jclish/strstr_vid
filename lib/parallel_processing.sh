#!/bin/bash

# lib/parallel_processing.sh - Shared parallel processing functions
# This library provides common functions for parallel processing operations

# Function to get optimal number of workers
get_optimal_workers() {
    local cpu_count=$(nproc 2>/dev/null || sysctl -n hw.ncpu 2>/dev/null || echo "4")
    local optimal=$((cpu_count * 2))
    
    # Cap at reasonable limits
    if [ "$optimal" -gt 8 ]; then
        optimal=8
    elif [ "$optimal" -lt 2 ]; then
        optimal=2
    fi
    
    echo "$optimal"
}

# Function to validate worker count
validate_worker_count() {
    local workers="$1"
    
    if [[ "$workers" =~ ^[0-9]+$ ]]; then
        if [ "$workers" -lt 1 ] || [ "$workers" -gt 16 ]; then
            echo "Error: Worker count must be between 1 and 16"
            return 1
        fi
        return 0
    else
        echo "Error: Invalid worker count: $workers"
        return 1
    fi
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

# Function to calculate ETA
calculate_eta() {
    local elapsed="$1"
    local completed="$2"
    local total="$3"
    
    if [ "$completed" -eq 0 ]; then
        echo "Unknown"
        return
    fi
    
    local remaining=$((total - completed))
    local rate=$(echo "scale=2; $completed / $elapsed" | bc -l 2>/dev/null || echo "0")
    local eta_seconds=$(echo "scale=0; $remaining / $rate" | bc -l 2>/dev/null || echo "0")
    
    if [ "$eta_seconds" -lt 60 ]; then
        echo "${eta_seconds}s"
    elif [ "$eta_seconds" -lt 3600 ]; then
        local minutes=$((eta_seconds / 60))
        echo "${minutes}m"
    else
        local hours=$((eta_seconds / 3600))
        local minutes=$(((eta_seconds % 3600) / 60))
        echo "${hours}h${minutes}m"
    fi
}

# Function to create temporary file list
create_temp_file_list() {
    local directory="$1"
    local temp_file=$(mktemp)
    
    if [ "$RECURSIVE" = true ]; then
        find "$directory" -type f \( -iname "*.jpg" -o -iname "*.jpeg" -o -iname "*.png" -o -iname "*.gif" -o -iname "*.bmp" -o -iname "*.tiff" -o -iname "*.tif" -o -iname "*.webp" -o -iname "*.heic" -o -iname "*.heif" -o -iname "*.mp4" -o -iname "*.avi" -o -iname "*.mov" -o -iname "*.mkv" -o -iname "*.wmv" -o -iname "*.flv" -o -iname "*.webm" -o -iname "*.m4v" -o -iname "*.3gp" -o -iname "*.mpg" -o -iname "*.mpeg" \) 2>/dev/null > "$temp_file"
    else
        find "$directory" -maxdepth 1 -type f \( -iname "*.jpg" -o -iname "*.jpeg" -o -iname "*.png" -o -iname "*.gif" -o -iname "*.bmp" -o -iname "*.tiff" -o -iname "*.tif" -o -iname "*.webp" -o -iname "*.heic" -o -iname "*.heif" -o -iname "*.mp4" -o -iname "*.avi" -o -iname "*.mov" -o -iname "*.mkv" -o -iname "*.wmv" -o -iname "*.flv" -o -iname "*.webm" -o -iname "*.m4v" -o -iname "*.3gp" -o -iname "*.mpg" -o -iname "*.mpeg" \) 2>/dev/null > "$temp_file"
    fi
    
    echo "$temp_file"
}

# Function to process files in parallel
process_files_parallel() {
    local file_list="$1"
    local workers="$2"
    local batch_size="${3:-50}"
    local temp_results=$(mktemp)
    local temp_script=$(mktemp)
    
    # Create worker script
    cat > "$temp_script" << 'EOF'
#!/bin/bash
source "$SCRIPT_DIR/lib/metadata_extraction.sh"
source "$SCRIPT_DIR/lib/output_formatters.sh"
source "$SCRIPT_DIR/lib/caching.sh"

process_single_file() {
    local file="$1"
    local search_string="$2"
    # This function will be implemented by the calling script
    echo "PROCESS:$file"
}

# Process files from stdin
while IFS= read -r file; do
    if [ -n "$file" ]; then
        process_single_file "$file" "$SEARCH_STRING"
    fi
done
EOF
    
    chmod +x "$temp_script"
    
    # Process files in parallel
    local total_files=$(wc -l < "$file_list")
    local processed=0
    
    echo -e "${BLUE}Processing $total_files files with $workers workers...${NC}"
    
    # Split file list into batches
    split -l "$batch_size" "$file_list" "${temp_results}_batch_" 2>/dev/null || \
    awk -v batch="$batch_size" 'NR%batch==1{x="'${temp_results}_batch_'++i;}{print > x}' "$file_list"
    
    # Process each batch in parallel
    for batch_file in "${temp_results}_batch_"*; do
        if [ -f "$batch_file" ]; then
            # Process batch with specified number of workers
            cat "$batch_file" | xargs -P "$workers" -I {} bash "$temp_script" {} >> "$temp_results" 2>/dev/null &
            
            # Update progress using the enhanced progress bar function
            processed=$((processed + $(wc -l < "$batch_file")))
            generate_progress_bar "$processed" "$total_files" 50 "unicode" "true" "true"
        fi
    done
    
    # Wait for all background processes
    wait
    
    # Clear progress bar
    clear_progress_line
    
    # Clean up
    rm -f "$temp_script" "${temp_results}_batch_"*
    
    echo "$temp_results"
} 