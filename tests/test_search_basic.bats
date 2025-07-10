#!/usr/bin/env bats

# test_search_basic.bats - Basic search functionality tests
# Tests: string search, case sensitivity, recursive search, help, dependencies

setup() {
    # Create test directory structure
    export TEST_DIR="$(mktemp -d)"
    export SCRIPT_DIR="$(cd "$(dirname "$BATS_TEST_FILENAME")/.." && pwd)"
    export SEARCH_SCRIPT="$SCRIPT_DIR/search_metadata.sh"
    
    # Create test files with known metadata
    mkdir -p "$TEST_DIR/photos"
    mkdir -p "$TEST_DIR/videos"
    
    # Create a simple test image (we'll use a placeholder for now)
    echo "test image content" > "$TEST_DIR/photos/test_canon.jpg"
    echo "test video content" > "$TEST_DIR/videos/test_iphone.mp4"
    
    # Make scripts executable
    chmod +x "$SEARCH_SCRIPT"
}

teardown() {
    # Clean up test directory
    rm -rf "$TEST_DIR"
}

@test "script exists and is executable" {
    [ -f "$SEARCH_SCRIPT" ]
    [ -x "$SEARCH_SCRIPT" ]
}

@test "help option works" {
    run "$SEARCH_SCRIPT" --help
    [ "$status" -eq 0 ]
    [[ "$output" =~ "Usage:" ]]
    [[ "$output" =~ "Options:" ]]
}

@test "script checks for dependencies" {
    # This test assumes exiftool and ffprobe are available
    # In a real test environment, we might mock these
    run "$SEARCH_SCRIPT" "test" "$TEST_DIR"
    # Should either work (if deps installed) or show dependency error
    [ "$status" -eq 0 ] || [[ "$output" =~ "Missing required dependencies" ]]
}

@test "basic string search" {
    # Test with empty directory (should not crash)
    run "$SEARCH_SCRIPT" "Canon" "$TEST_DIR"
    [ "$status" -eq 0 ]
    [[ "$output" =~ "Searching for:" ]]
}

@test "case insensitive search" {
    run "$SEARCH_SCRIPT" "canon" "$TEST_DIR" -i
    [ "$status" -eq 0 ]
    [[ "$output" =~ "Searching for:" ]]
}

@test "recursive search" {
    run "$SEARCH_SCRIPT" "test" "$TEST_DIR" -r
    [ "$status" -eq 0 ]
    [[ "$output" =~ "Recursive" ]]
}

@test "verbose output" {
    run "$SEARCH_SCRIPT" "test" "$TEST_DIR" -v
    [ "$status" -eq 0 ]
    [[ "$output" =~ "Searching for:" ]]
}

@test "show metadata option" {
    run "$SEARCH_SCRIPT" "test" "$TEST_DIR" -m
    [ "$status" -eq 0 ]
    [[ "$output" =~ "Searching for:" ]]
}

@test "invalid directory handling" {
    run "$SEARCH_SCRIPT" "test" "/nonexistent/directory"
    [ "$status" -ne 0 ]
    [[ "$output" =~ "Error" ]]
}

@test "missing search string" {
    run "$SEARCH_SCRIPT" "" "$TEST_DIR"
    [ "$status" -ne 0 ]
    [[ "$output" =~ "Error:" ]]
}

@test "regex search flag" {
    run "$SEARCH_SCRIPT" "test.*canon" "$TEST_DIR" -R
    [ "$status" -eq 0 ]
    [[ "$output" =~ "Searching for:" ]]
}

@test "field specific search" {
    run "$SEARCH_SCRIPT" "Canon" "$TEST_DIR" -f Make
    [ "$status" -eq 0 ]
    [[ "$output" =~ "Searching for:" ]]
}

@test "field list option" {
    run "$SEARCH_SCRIPT" "" "$TEST_DIR" -l
    [ "$status" -eq 0 ]
    [[ "$output" =~ "Searching for:" ]]
}

@test "output to file" {
    local output_file="$TEST_DIR/results.txt"
    run "$SEARCH_SCRIPT" "test" "$TEST_DIR" -o "$output_file"
    [ "$status" -eq 0 ]
    [ -f "$output_file" ]
}

@test "JSON output format" {
    run "$SEARCH_SCRIPT" "test" "$TEST_DIR" --json
    [ "$status" -eq 0 ]
    [[ "$output" =~ "search_info" ]]
}

@test "CSV output format" {
    run "$SEARCH_SCRIPT" "test" "$TEST_DIR" --csv
    [ "$status" -eq 0 ]
    [[ "$output" =~ "File Path,File Type" ]]
} 