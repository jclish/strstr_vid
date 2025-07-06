#!/usr/bin/env bats

# test_performance_parallel.bats - Tests for parallel processing features
# Tests: Parallel processing, worker management, progress tracking, performance benchmarks

setup() {
    export TEST_DIR="$(mktemp -d)"
    export SCRIPT_DIR="$(cd "$(dirname "$BATS_TEST_FILENAME")/.." && pwd)"
    export SEARCH_SCRIPT="$SCRIPT_DIR/search_metadata.sh"
    export REPORT_SCRIPT="$SCRIPT_DIR/generate_media_report.sh"
    export FIXTURES_DIR="$SCRIPT_DIR/tests/fixtures"
    
    # Create test directory structure with many files for parallel testing
    mkdir -p "$TEST_DIR/parallel_test"
    
    # Create multiple test files for parallel processing
    for i in {1..50}; do
        cp "$FIXTURES_DIR/test_canon.jpg" "$TEST_DIR/parallel_test/file_$i.jpg"
    done
    
    chmod +x "$SEARCH_SCRIPT"
    chmod +x "$REPORT_SCRIPT"
    
    # Debug: Print directory contents
    echo "TEST_DIR: $TEST_DIR"
    echo "FIXTURES_DIR: $FIXTURES_DIR"
    echo "Files in TEST_DIR:"
    find "$TEST_DIR" -type f | head -10
    echo "Files in TEST_DIR/parallel_test:"
    find "$TEST_DIR/parallel_test" -type f | head -10
}

teardown() {
    rm -rf "$TEST_DIR"
}

@test "parallel processing flag is recognized" {
    run "$SEARCH_SCRIPT" "test" "$TEST_DIR" --parallel 4
    [ "$status" -eq 0 ]
    [[ "$output" =~ "Searching for:" ]]
}

@test "parallel processing with different worker counts" {
    run "$SEARCH_SCRIPT" "test" "$TEST_DIR" --parallel 2
    [ "$status" -eq 0 ]
    
    run "$SEARCH_SCRIPT" "test" "$TEST_DIR" --parallel 8
    [ "$status" -eq 0 ]
}

@test "parallel processing with auto-detect workers" {
    run "$SEARCH_SCRIPT" "test" "$TEST_DIR" --parallel auto
    [ "$status" -eq 0 ]
    [[ "$output" =~ "Searching for:" ]]
}

@test "parallel processing with batch size" {
    run "$SEARCH_SCRIPT" "test" "$TEST_DIR" --parallel 4 --batch-size 10
    [ "$status" -eq 0 ]
}

@test "parallel processing with memory limit" {
    run "$SEARCH_SCRIPT" "test" "$TEST_DIR" --parallel 4 --memory-limit "256MB"
    [ "$status" -eq 0 ]
}

@test "parallel processing progress tracking" {
    run "$SEARCH_SCRIPT" "test" "$TEST_DIR/parallel_test" --parallel 4 -v
    if [ "$status" -ne 0 ]; then
        echo "Script failed with status $status"
        echo "$output"
    fi
    if [[ ! "$output" =~ "Processing" ]]; then
        echo "Output was:"
        echo "$output"
    fi
    [ "$status" -eq 0 ]
    [[ "$output" =~ "Processing" ]]
}

@test "parallel processing performance benchmark" {
    run "$SEARCH_SCRIPT" "test" "$TEST_DIR/parallel_test" --benchmark
    [ "$status" -eq 0 ]
    [[ "$output" =~ "Performance" ]]
}

@test "compare sequential vs parallel modes" {
    run "$SEARCH_SCRIPT" "test" "$TEST_DIR/parallel_test" --compare-modes
    [ "$status" -eq 0 ]
    [[ "$output" =~ "Sequential" ]]
    [[ "$output" =~ "Parallel" ]]
}

@test "parallel processing with report generator" {
    run "$REPORT_SCRIPT" "$TEST_DIR/parallel_test" --parallel 4
    [ "$status" -eq 0 ]
    [[ "$output" =~ "MEDIA REPORT" ]]
}

@test "parallel processing with memory usage tracking" {
    run "$SEARCH_SCRIPT" "test" "$TEST_DIR/parallel_test" --parallel 4 --memory-usage
    [ "$status" -eq 0 ]
    [[ "$output" =~ "Memory" ]]
}

@test "parallel processing with performance report" {
    run "$SEARCH_SCRIPT" "test" "$TEST_DIR/parallel_test" --parallel 4 --performance-report
    [ "$status" -eq 0 ]
    [[ "$output" =~ "Performance Report" ]]
}

@test "parallel processing error handling" {
    # Test with invalid parallel count
    run "$SEARCH_SCRIPT" "test" "$TEST_DIR" --parallel 0
    [ "$status" -eq 1 ]
    
    # Test with invalid batch size
    run "$SEARCH_SCRIPT" "test" "$TEST_DIR" --parallel 4 --batch-size 0
    [ "$status" -eq 1 ]
}

@test "parallel processing with large directory" {
    # Create more files for large directory test
    for i in {51..100}; do
        cp "$FIXTURES_DIR/test_nikon.jpg" "$TEST_DIR/parallel_test/file_$i.jpg"
    done
    
    run "$SEARCH_SCRIPT" "test" "$TEST_DIR/parallel_test" --parallel 4
    [ "$status" -eq 0 ]
    [[ "$output" =~ "Files with matches" ]]
}

@test "parallel processing worker management" {
    run "$SEARCH_SCRIPT" "test" "$TEST_DIR/parallel_test" --parallel 4 -v
    [ "$status" -eq 0 ]
    # Should show worker information
    [[ "$output" =~ "workers" ]] || [[ "$output" =~ "parallel" ]]
}

@test "parallel processing with different file types" {
    # Add some video files
    for i in {1..10}; do
        cp "$FIXTURES_DIR/test_iphone.mov" "$TEST_DIR/parallel_test/video_$i.mov"
    done
    
    run "$SEARCH_SCRIPT" "test" "$TEST_DIR/parallel_test" --parallel 4
    [ "$status" -eq 0 ]
    [[ "$output" =~ "Files with matches" ]]
}

@test "parallel processing ETA calculation" {
    run "$SEARCH_SCRIPT" "test" "$TEST_DIR/parallel_test" --parallel 4 -v
    [ "$status" -eq 0 ]
    # Should show ETA or processing time
    [[ "$output" =~ "ETA" ]] || [[ "$output" =~ "time" ]]
} 