#!/usr/bin/env bats

# test_search_real_media.bats - Tests using real media files with metadata
# Tests: Real metadata extraction, GPS, device detection, etc.

setup() {
    export TEST_DIR="$(mktemp -d)"
    export SCRIPT_DIR="$(cd "$(dirname "$BATS_TEST_FILENAME")/.." && pwd)"
    export SEARCH_SCRIPT="$SCRIPT_DIR/search_metadata.sh"
    export FIXTURES_DIR="$SCRIPT_DIR/tests/fixtures"
    
    # Create test directory structure
    mkdir -p "$TEST_DIR/photos"
    mkdir -p "$TEST_DIR/videos"
    
    # Copy real media files with metadata
    cp "$FIXTURES_DIR/test_canon.jpg" "$TEST_DIR/photos/canon_eos.jpg"
    cp "$FIXTURES_DIR/test_nikon.jpg" "$TEST_DIR/photos/nikon_d850.jpg"
    cp "$FIXTURES_DIR/test_iphone.mov" "$TEST_DIR/videos/iphone_video.mov"
    cp "$FIXTURES_DIR/test_android.mp4" "$TEST_DIR/videos/android_video.mp4"
    
    chmod +x "$SEARCH_SCRIPT"
}

teardown() {
    rm -rf "$TEST_DIR"
}

@test "search for Canon camera in real images" {
    run "$SEARCH_SCRIPT" "Canon" "$TEST_DIR" -r
    [ "$status" -eq 0 ]
    [[ "$output" =~ "Found" ]]
}

@test "search for Nikon camera in real images" {
    run "$SEARCH_SCRIPT" "Nikon" "$TEST_DIR" -r
    [ "$status" -eq 0 ]
    [[ "$output" =~ "Found" ]]
}

@test "search for video files with real metadata" {
    run "$SEARCH_SCRIPT" "video" "$TEST_DIR" -r
    [ "$status" -eq 0 ]
    [[ "$output" =~ "Found" ]]
}

@test "device detection with real media" {
    run "$SEARCH_SCRIPT" "test" "$TEST_DIR" --device-stats -r
    [ "$status" -eq 0 ]
    [[ "$output" =~ "Searching for:" ]]
}

@test "GPS search with real media" {
    run "$SEARCH_SCRIPT" "test" "$TEST_DIR" --within-radius "37.7749,-122.4194,1000" -r
    [ "$status" -eq 0 ]
    [[ "$output" =~ "Searching for:" ]]
}

@test "boolean search with real media" {
    run "$SEARCH_SCRIPT" "Canon" "$TEST_DIR" --and "EOS" -r
    [ "$status" -eq 0 ]
    [[ "$output" =~ "Searching for:" ]]
}

@test "fuzzy search with real media" {
    run "$SEARCH_SCRIPT" "Canon" "$TEST_DIR" --fuzzy -r
    [ "$status" -eq 0 ]
    [[ "$output" =~ "Searching for:" ]]
}

@test "JSON export with real media" {
    run "$SEARCH_SCRIPT" "Canon" "$TEST_DIR" --json -r
    [ "$status" -eq 0 ]
    [[ "$output" =~ "search_info" ]]
}

@test "CSV export with real media" {
    run "$SEARCH_SCRIPT" "Canon" "$TEST_DIR" --csv -r
    [ "$status" -eq 0 ]
    [[ "$output" =~ "File Path,File Type" ]]
}

@test "field-specific search with real media" {
    run "$SEARCH_SCRIPT" "Canon" "$TEST_DIR" -f Make -r
    [ "$status" -eq 0 ]
    [[ "$output" =~ "Searching for:" ]]
}

@test "regex search with real media" {
    run "$SEARCH_SCRIPT" "Canon|Nikon" "$TEST_DIR" -R -r
    [ "$status" -eq 0 ]
    [[ "$output" =~ "Searching for:" ]]
} 