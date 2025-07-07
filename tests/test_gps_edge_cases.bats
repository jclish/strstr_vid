#!/usr/bin/env bats

# test_gps_edge_cases.bats - GPS coordinate edge case tests
# Tests: Southern/western hemisphere, zero/invalid coordinates, mixed formats, boundaries

setup() {
    export TEST_DIR="$(mktemp -d)"
    export SCRIPT_DIR="$(cd "$(dirname "$BATS_TEST_FILENAME")/.." && pwd)"
    export SEARCH_SCRIPT="$SCRIPT_DIR/search_metadata.sh"
    export FIXTURES_DIR="$SCRIPT_DIR/tests/fixtures"
    
    # Create test directory structure
    mkdir -p "$TEST_DIR/photos"
    mkdir -p "$TEST_DIR/videos"
    
    # Copy real media files with GPS metadata
    cp "$FIXTURES_DIR/test_canon.jpg" "$TEST_DIR/photos/southern_hemisphere.jpg"
    cp "$FIXTURES_DIR/test_nikon.jpg" "$TEST_DIR/photos/western_hemisphere.jpg"
    cp "$FIXTURES_DIR/test_iphone.mov" "$TEST_DIR/videos/zero_coordinates.mov"
    
    chmod +x "$SEARCH_SCRIPT"
}

teardown() {
    rm -rf "$TEST_DIR"
}

@test "southern hemisphere coordinates" {
    run "$SEARCH_SCRIPT" "test" "$TEST_DIR" --within-radius "-33.8688,151.2093,10"
    [ "$status" -eq 0 ]
    [[ "$output" =~ "Searching for:" ]]
}

@test "western hemisphere coordinates" {
    run "$SEARCH_SCRIPT" "test" "$TEST_DIR" --within-radius "40.7128,-74.0060,10"
    [ "$status" -eq 0 ]
    [[ "$output" =~ "Searching for:" ]]
}

@test "DMS format with southern hemisphere" {
    run "$SEARCH_SCRIPT" "test" "$TEST_DIR" --within-radius "33°52'7.7\"S,151°12'33.5\"E,10"
    [ "$status" -eq 0 ]
    [[ "$output" =~ "Searching for:" ]]
}

@test "DMS format with western hemisphere" {
    run "$SEARCH_SCRIPT" "test" "$TEST_DIR" --within-radius "40°42'46.1\"N,74°0'21.6\"W,10"
    [ "$status" -eq 0 ]
    [[ "$output" =~ "Searching for:" ]]
}

@test "zero coordinates handling" {
    run "$SEARCH_SCRIPT" "test" "$TEST_DIR" --within-radius "0,0,10"
    [ "$status" -eq 0 ]
    [[ "$output" =~ "Searching for:" ]]
}

@test "invalid coordinates graceful handling" {
    run "$SEARCH_SCRIPT" "test" "$TEST_DIR" --within-radius "invalid,coordinates,10"
    [ "$status" -eq 0 ]
    [[ "$output" =~ "Searching for:" ]]
}

@test "empty coordinates handling" {
    run "$SEARCH_SCRIPT" "test" "$TEST_DIR" --within-radius ",,10"
    [ "$status" -eq 0 ]
    [[ "$output" =~ "Searching for:" ]]
}

@test "boundary latitude values" {
    run "$SEARCH_SCRIPT" "test" "$TEST_DIR" --within-radius "90,0,10"
    [ "$status" -eq 0 ]
    [[ "$output" =~ "Searching for:" ]]
}

@test "boundary longitude values" {
    run "$SEARCH_SCRIPT" "test" "$TEST_DIR" --within-radius "0,180,10"
    [ "$status" -eq 0 ]
    [[ "$output" =~ "Searching for:" ]]
}

@test "negative boundary values" {
    run "$SEARCH_SCRIPT" "test" "$TEST_DIR" --within-radius "-90,-180,10"
    [ "$status" -eq 0 ]
    [[ "$output" =~ "Searching for:" ]]
}

@test "mixed decimal and DMS in bounding box" {
    run "$SEARCH_SCRIPT" "test" "$TEST_DIR" --bounding-box "37.7,37.8,-122.5,-122.4"
    [ "$status" -eq 0 ]
    [[ "$output" =~ "Searching for:" ]]
}

@test "DMS bounding box" {
    run "$SEARCH_SCRIPT" "test" "$TEST_DIR" --bounding-box "37°42',37°48',-122°30',-122°24'"
    [ "$status" -eq 0 ]
    [[ "$output" =~ "Searching for:" ]]
}

@test "southern hemisphere bounding box" {
    run "$SEARCH_SCRIPT" "test" "$TEST_DIR" --bounding-box "-33.9,-33.8,151.2,151.3"
    [ "$status" -eq 0 ]
    [[ "$output" =~ "Searching for:" ]]
}

@test "western hemisphere bounding box" {
    run "$SEARCH_SCRIPT" "test" "$TEST_DIR" --bounding-box "40.7,40.8,-74.1,-74.0"
    [ "$status" -eq 0 ]
    [[ "$output" =~ "Searching for:" ]]
}

@test "invalid bounding box format" {
    run "$SEARCH_SCRIPT" "test" "$TEST_DIR" --bounding-box "invalid,box,format,here"
    [ "$status" -eq 0 ]
    [[ "$output" =~ "Searching for:" ]]
}

@test "empty bounding box" {
    run "$SEARCH_SCRIPT" "test" "$TEST_DIR" --bounding-box ",,,"
    [ "$status" -eq 0 ]
    [[ "$output" =~ "Searching for:" ]]
}

@test "zero radius handling" {
    run "$SEARCH_SCRIPT" "test" "$TEST_DIR" --within-radius "37.7749,-122.4194,0"
    [ "$status" -eq 0 ]
    [[ "$output" =~ "Searching for:" ]]
}

@test "negative radius handling" {
    run "$SEARCH_SCRIPT" "test" "$TEST_DIR" --within-radius "37.7749,-122.4194,-10"
    [ "$status" -eq 0 ]
    [[ "$output" =~ "Searching for:" ]]
}

@test "very large radius" {
    run "$SEARCH_SCRIPT" "test" "$TEST_DIR" --within-radius "37.7749,-122.4194,10000"
    [ "$status" -eq 0 ]
    [[ "$output" =~ "Searching for:" ]]
}

@test "decimal precision handling" {
    run "$SEARCH_SCRIPT" "test" "$TEST_DIR" --within-radius "37.774912345,-122.419456789,10"
    [ "$status" -eq 0 ]
    [[ "$output" =~ "Searching for:" ]]
}

@test "DMS with decimal seconds" {
    run "$SEARCH_SCRIPT" "test" "$TEST_DIR" --within-radius "37°46'29.64\"N,-122°25'9.8\"W,5"
    [ "$status" -eq 0 ]
    [[ "$output" =~ "Searching for:" ]]
}

@test "GPS with reverse geocoding edge cases" {
    run "$SEARCH_SCRIPT" "test" "$TEST_DIR" --within-radius "-33.8688,151.2093,10" --reverse-geocode
    [ "$status" -eq 0 ]
    [[ "$output" =~ "Searching for:" ]]
}

@test "complex GPS search with all edge cases" {
    run "$SEARCH_SCRIPT" "test" "$TEST_DIR" --within-radius "-33°52'7.7\"S,151°12'33.5\"E,10" --reverse-geocode --device-stats
    [ "$status" -eq 0 ]
    [[ "$output" =~ "Searching for:" ]]
}

@test "GPS cache integration with edge cases" {
    # Initialize cache
    CACHE_DB="$TEST_DIR/test_cache.db" run "$SEARCH_SCRIPT" "test" "$TEST_DIR" --cache-init
    [ "$status" -eq 0 ]
    
    # Search with edge case GPS coordinates
    CACHE_DB="$TEST_DIR/test_cache.db" run "$SEARCH_SCRIPT" "test" "$TEST_DIR" --cache-enabled --within-radius "-33.8688,151.2093,10"
    [ "$status" -eq 0 ]
    [[ "$output" =~ "Searching for:" ]]
}

@test "GPS parallel processing with edge cases" {
    run "$SEARCH_SCRIPT" "test" "$TEST_DIR" --parallel 2 --within-radius "-33.8688,151.2093,10"
    [ "$status" -eq 0 ]
    [[ "$output" =~ "Searching for:" ]]
}

@test "GPS JSON export with edge cases" {
    run "$SEARCH_SCRIPT" "test" "$TEST_DIR" --json --within-radius "-33.8688,151.2093,10"
    [ "$status" -eq 0 ]
    [[ "$output" =~ "Searching for:" ]]
}

@test "GPS CSV export with edge cases" {
    run "$SEARCH_SCRIPT" "test" "$TEST_DIR" --csv --within-radius "-33.8688,151.2093,10"
    [ "$status" -eq 0 ]
    [[ "$output" =~ "Searching for:" ]]
} 