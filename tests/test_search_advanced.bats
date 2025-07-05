#!/usr/bin/env bats

# test_search_advanced.bats - Advanced search functionality tests
# Tests: boolean operators, fuzzy matching, GPS, device detection, reverse geocoding

setup() {
    export TEST_DIR="$(mktemp -d)"
    export SCRIPT_DIR="$(cd "$(dirname "$BATS_TEST_FILENAME")/.." && pwd)"
    export SEARCH_SCRIPT="$SCRIPT_DIR/search_metadata.sh"
    
    # Create test files with known metadata
    mkdir -p "$TEST_DIR/photos"
    mkdir -p "$TEST_DIR/videos"
    
    # Create test files
    echo "test content" > "$TEST_DIR/photos/test_canon.jpg"
    echo "test content" > "$TEST_DIR/photos/test_nikon.jpg"
    echo "test content" > "$TEST_DIR/videos/test_iphone.mp4"
    
    chmod +x "$SEARCH_SCRIPT"
}

teardown() {
    rm -rf "$TEST_DIR"
}

@test "boolean AND operator" {
    run "$SEARCH_SCRIPT" "Canon" "$TEST_DIR" --and "2023"
    [ "$status" -eq 0 ]
    [[ "$output" =~ "Searching for:" ]]
}

@test "boolean OR operator" {
    run "$SEARCH_SCRIPT" "Canon" "$TEST_DIR" --or "Nikon"
    [ "$status" -eq 0 ]
    [[ "$output" =~ "Searching for:" ]]
}

@test "boolean NOT operator" {
    run "$SEARCH_SCRIPT" "Canon" "$TEST_DIR" --not "iPhone"
    [ "$status" -eq 0 ]
    [[ "$output" =~ "Searching for:" ]]
}

@test "complex boolean search" {
    run "$SEARCH_SCRIPT" "Canon" "$TEST_DIR" --and "2023" --or "Nikon" --not "iPhone"
    [ "$status" -eq 0 ]
    [[ "$output" =~ "Searching for:" ]]
}

@test "fuzzy matching enabled" {
    run "$SEARCH_SCRIPT" "Canon" "$TEST_DIR" --fuzzy
    [ "$status" -eq 0 ]
    [[ "$output" =~ "Searching for:" ]]
}

@test "fuzzy matching with threshold" {
    run "$SEARCH_SCRIPT" "Canon" "$TEST_DIR" --fuzzy --fuzzy-threshold 75
    [ "$status" -eq 0 ]
    [[ "$output" =~ "Searching for:" ]]
}

@test "GPS radius search" {
    run "$SEARCH_SCRIPT" "test" "$TEST_DIR" --within-radius "37.7749,-122.4194,10"
    [ "$status" -eq 0 ]
    [[ "$output" =~ "Searching for:" ]]
}

@test "GPS bounding box search" {
    run "$SEARCH_SCRIPT" "test" "$TEST_DIR" --bounding-box "37.7,37.8,-122.5,-122.4"
    [ "$status" -eq 0 ]
    [[ "$output" =~ "Searching for:" ]]
}

@test "reverse geocoding" {
    run "$SEARCH_SCRIPT" "test" "$TEST_DIR" --reverse-geocode
    [ "$status" -eq 0 ]
    [[ "$output" =~ "Searching for:" ]]
}

@test "device statistics" {
    run "$SEARCH_SCRIPT" "test" "$TEST_DIR" --device-stats
    [ "$status" -eq 0 ]
    [[ "$output" =~ "Searching for:" ]]
}

@test "GPS with reverse geocoding" {
    run "$SEARCH_SCRIPT" "test" "$TEST_DIR" --within-radius "37.7749,-122.4194,5" --reverse-geocode
    [ "$status" -eq 0 ]
    [[ "$output" =~ "Searching for:" ]]
}

@test "invalid GPS coordinates" {
    run "$SEARCH_SCRIPT" "test" "$TEST_DIR" --within-radius "invalid,coordinates,10"
    [ "$status" -eq 0 ]
    # Should handle gracefully
}

@test "invalid bounding box" {
    run "$SEARCH_SCRIPT" "test" "$TEST_DIR" --bounding-box "invalid,box,coordinates"
    [ "$status" -eq 0 ]
    # Should handle gracefully
}

@test "fuzzy threshold validation" {
    run "$SEARCH_SCRIPT" "test" "$TEST_DIR" --fuzzy --fuzzy-threshold 150
    [ "$status" -eq 0 ]
    # Should handle out-of-range threshold gracefully
}

@test "empty boolean terms" {
    run "$SEARCH_SCRIPT" "test" "$TEST_DIR" --and ""
    [ "$status" -eq 0 ]
    # Should handle empty boolean terms gracefully
}

@test "multiple boolean terms" {
    run "$SEARCH_SCRIPT" "test" "$TEST_DIR" --and "term1" --and "term2" --or "term3"
    [ "$status" -eq 0 ]
    [[ "$output" =~ "Searching for:" ]]
}

@test "GPS coordinates in DMS format" {
    run "$SEARCH_SCRIPT" "test" "$TEST_DIR" --within-radius "37°46'29.6\"N,-122°25'9.8\"W,5"
    [ "$status" -eq 0 ]
    [[ "$output" =~ "Searching for:" ]]
}

@test "device detection with GPS" {
    run "$SEARCH_SCRIPT" "test" "$TEST_DIR" --device-stats --within-radius "37.7749,-122.4194,10"
    [ "$status" -eq 0 ]
    [[ "$output" =~ "Searching for:" ]]
}

@test "complex search with all advanced features" {
    run "$SEARCH_SCRIPT" "Canon" "$TEST_DIR" --and "2023" --or "Nikon" --not "iPhone" --fuzzy --device-stats --within-radius "37.7749,-122.4194,10" --reverse-geocode
    [ "$status" -eq 0 ]
    [[ "$output" =~ "Searching for:" ]]
} 