#!/bin/bash

# test_config.bash - Common test configuration and helper functions
# Source this file in test files for common setup

# Test configuration
export TEST_TIMEOUT=30  # seconds
export TEST_VERBOSE=${TEST_VERBOSE:-false}

# Colors for test output
export TEST_RED='\033[0;31m'
export TEST_GREEN='\033[0;32m'
export TEST_YELLOW='\033[1;33m'
export TEST_BLUE='\033[0;34m'
export TEST_NC='\033[0m'

# Helper function to create test media files with metadata
create_test_image() {
    local file="$1"
    local make="${2:-Canon}"
    local model="${3:-EOS R5}"
    local date="${4:-2023:01:15 10:30:00}"
    
    # Create a simple test image
    echo "test image content" > "$file"
    
    # Add EXIF metadata if exiftool is available
    if command -v exiftool >/dev/null 2>&1; then
        exiftool -overwrite_original \
            -Make="$make" \
            -Model="$model" \
            -DateTimeOriginal="$date" \
            "$file" >/dev/null 2>&1 || true
    fi
}

create_test_video() {
    local file="$1"
    local codec="${2:-H.264}"
    local date="${3:-2023:01:15 10:30:00}"
    
    # Create a simple test video
    echo "test video content" > "$file"
    
    # Add metadata if exiftool is available
    if command -v exiftool >/dev/null 2>&1; then
        exiftool -overwrite_original \
            -VideoCodec="$codec" \
            -DateTimeOriginal="$date" \
            "$file" >/dev/null 2>&1 || true
    fi
}

# Helper function to create GPS-tagged test image
create_gps_test_image() {
    local file="$1"
    local lat="${2:-37.7749}"
    local lon="${3:--122.4194}"
    
    create_test_image "$file"
    
    # Add GPS metadata if exiftool is available
    if command -v exiftool >/dev/null 2>&1; then
        exiftool -overwrite_original \
            -GPSLatitude="$lat" \
            -GPSLongitude="$lon" \
            "$file" >/dev/null 2>&1 || true
    fi
}

# Helper function to create mobile device test image
create_mobile_test_image() {
    local file="$1"
    local device_type="${2:-iPhone}"
    local model="${3:-iPhone 14}"
    
    create_test_image "$file"
    
    # Add device-specific metadata if exiftool is available
    if command -v exiftool >/dev/null 2>&1; then
        exiftool -overwrite_original \
            -Make="Apple" \
            -Model="$model" \
            -Software="iOS 16.0" \
            "$file" >/dev/null 2>&1 || true
    fi
}

# Helper function to check if dependencies are available
check_dependencies() {
    local missing_deps=()
    
    if ! command -v exiftool >/dev/null 2>&1; then
        missing_deps+=("exiftool")
    fi
    
    if ! command -v ffprobe >/dev/null 2>&1; then
        missing_deps+=("ffprobe")
    fi
    
    if [ ${#missing_deps[@]} -ne 0 ]; then
        echo "Warning: Missing dependencies: ${missing_deps[*]}"
        echo "Some tests may not work correctly without these tools."
        return 1
    fi
    
    return 0
}

# Helper function to validate JSON output
validate_json() {
    local json_string="$1"
    
    if command -v jq >/dev/null 2>&1; then
        echo "$json_string" | jq . >/dev/null 2>&1
        return $?
    else
        # Basic JSON validation without jq
        [[ "$json_string" =~ ^\{.*\}$ ]] || [[ "$json_string" =~ ^\[.*\]$ ]]
        return $?
    fi
}

# Helper function to validate CSV output
validate_csv() {
    local csv_string="$1"
    
    # Basic CSV validation - should have commas and not be empty
    [[ "$csv_string" =~ , ]] && [[ -n "$csv_string" ]]
    return $?
}

# Helper function to wait for network operations (like reverse geocoding)
wait_for_network() {
    local timeout="${1:-5}"
    sleep "$timeout"
}

# Test timeout handler
timeout_handler() {
    echo "Test timed out after ${TEST_TIMEOUT} seconds"
    exit 124
}

# Set up timeout for tests that might hang
if [ "$TEST_TIMEOUT" -gt 0 ]; then
    trap timeout_handler ALRM
fi 