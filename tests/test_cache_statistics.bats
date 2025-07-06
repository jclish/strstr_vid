#!/usr/bin/env bats

# test_cache_statistics.bats - Tests for cache statistics and monitoring
# Tests: Cache hit rate analysis, cache size monitoring, performance benchmarking

setup() {
    export TEST_DIR="$(mktemp -d)"
    export SCRIPT_DIR="$(cd "$(dirname "$BATS_TEST_FILENAME")/.." && pwd)"
    export SEARCH_SCRIPT="$SCRIPT_DIR/search_metadata.sh"
    export FIXTURES_DIR="$SCRIPT_DIR/tests/fixtures"
    export CACHE_DB="$TEST_DIR/metadata_cache.db"
    
    # Create test directory structure
    mkdir -p "$TEST_DIR/test_files"
    
    # Copy test files for cache statistics testing
    cp "$FIXTURES_DIR/test_canon.jpg" "$TEST_DIR/test_files/file1.jpg"
    cp "$FIXTURES_DIR/test_nikon.jpg" "$TEST_DIR/test_files/file2.jpg"
    cp "$FIXTURES_DIR/test_iphone.mov" "$TEST_DIR/test_files/video1.mov"
    cp "$FIXTURES_DIR/test_android.mp4" "$TEST_DIR/test_files/video2.mp4"
    
    chmod +x "$SEARCH_SCRIPT"
}

teardown() {
    rm -rf "$TEST_DIR"
}

# Phase 1.3.1.1: Cache Hit Rate Analysis

@test "cache hit rate calculation" {
    CACHE_DB="$CACHE_DB" run "$SEARCH_SCRIPT" "test" "$TEST_DIR/test_files" --cache-init
    [ "$status" -eq 0 ]
    
    # Store metadata in cache
    CACHE_DB="$CACHE_DB" run "$SEARCH_SCRIPT" "test" "$TEST_DIR/test_files" --cache-store
    [ "$status" -eq 0 ]
    
    # First search (cache miss)
    CACHE_DB="$CACHE_DB" run "$SEARCH_SCRIPT" "Canon" "$TEST_DIR/test_files" --cache-enabled
    [ "$status" -eq 0 ]
    
    # Second search (cache hit)
    CACHE_DB="$CACHE_DB" run "$SEARCH_SCRIPT" "Canon" "$TEST_DIR/test_files" --cache-enabled
    [ "$status" -eq 0 ]
    
    # Check cache statistics
    CACHE_DB="$CACHE_DB" run "$SEARCH_SCRIPT" "test" "$TEST_DIR/test_files" --cache-stats
    [ "$status" -eq 0 ]
    [[ "$output" =~ "Hit Rate" ]]
    [[ "$output" =~ "Miss Rate" ]]
}

@test "cache miss rate calculation" {
    CACHE_DB="$CACHE_DB" run "$SEARCH_SCRIPT" "test" "$TEST_DIR/test_files" --cache-init
    [ "$status" -eq 0 ]
    
    # Search without cache (should be miss)
    CACHE_DB="$CACHE_DB" run "$SEARCH_SCRIPT" "Canon" "$TEST_DIR/test_files" --cache-enabled
    [ "$status" -eq 0 ]
    
    # Check cache statistics
    CACHE_DB="$CACHE_DB" run "$SEARCH_SCRIPT" "test" "$TEST_DIR/test_files" --cache-stats
    [ "$status" -eq 0 ]
    [[ "$output" =~ "Miss Rate" ]]
    [[ "$output" =~ "100%" ]] || [[ "$output" =~ "0%" ]]
}

@test "cache performance metrics" {
    CACHE_DB="$CACHE_DB" run "$SEARCH_SCRIPT" "test" "$TEST_DIR/test_files" --cache-init
    [ "$status" -eq 0 ]
    
    # Store metadata
    CACHE_DB="$CACHE_DB" run "$SEARCH_SCRIPT" "test" "$TEST_DIR/test_files" --cache-store
    [ "$status" -eq 0 ]
    
    # Run performance test
    CACHE_DB="$CACHE_DB" run "$SEARCH_SCRIPT" "Canon" "$TEST_DIR/test_files" --cache-benchmark
    [ "$status" -eq 0 ]
    [[ "$output" =~ "Performance" ]]
    [[ "$output" =~ "Cache" ]]
    [[ "$output" =~ "No Cache" ]]
}

@test "cache efficiency reporting" {
    CACHE_DB="$CACHE_DB" run "$SEARCH_SCRIPT" "test" "$TEST_DIR/test_files" --cache-init
    [ "$status" -eq 0 ]
    
    # Store metadata
    CACHE_DB="$CACHE_DB" run "$SEARCH_SCRIPT" "test" "$TEST_DIR/test_files" --cache-store
    [ "$status" -eq 0 ]
    
    # Get efficiency report
    CACHE_DB="$CACHE_DB" run "$SEARCH_SCRIPT" "test" "$TEST_DIR/test_files" --cache-efficiency
    [ "$status" -eq 0 ]
    [[ "$output" =~ "Efficiency" ]]
    [[ "$output" =~ "Recommendations" ]]
}

# Phase 1.3.1.2: Cache Size Monitoring

@test "cache size tracking" {
    CACHE_DB="$CACHE_DB" run "$SEARCH_SCRIPT" "test" "$TEST_DIR/test_files" --cache-init
    [ "$status" -eq 0 ]
    
    # Store metadata
    CACHE_DB="$CACHE_DB" run "$SEARCH_SCRIPT" "test" "$TEST_DIR/test_files" --cache-store
    [ "$status" -eq 0 ]
    
    # Check cache size
    CACHE_DB="$CACHE_DB" run "$SEARCH_SCRIPT" "test" "$TEST_DIR/test_files" --cache-size
    [ "$status" -eq 0 ]
    [[ "$output" =~ "Cache Size" ]]
    [[ "$output" =~ "KB" ]] || [[ "$output" =~ "MB" ]]
}

@test "cache growth rate analysis" {
    CACHE_DB="$CACHE_DB" run "$SEARCH_SCRIPT" "test" "$TEST_DIR/test_files" --cache-init
    [ "$status" -eq 0 ]
    
    # Store metadata multiple times
    CACHE_DB="$CACHE_DB" run "$SEARCH_SCRIPT" "test" "$TEST_DIR/test_files" --cache-store
    [ "$status" -eq 0 ]
    
    # Check growth rate
    CACHE_DB="$CACHE_DB" run "$SEARCH_SCRIPT" "test" "$TEST_DIR/test_files" --cache-growth
    [ "$status" -eq 0 ]
    [[ "$output" =~ "Growth Rate" ]]
}

@test "cache size alerts" {
    CACHE_DB="$CACHE_DB" run "$SEARCH_SCRIPT" "test" "$TEST_DIR/test_files" --cache-init --cache-size-limit "1KB"
    [ "$status" -eq 0 ]
    
    # Store metadata (should trigger size alert)
    CACHE_DB="$CACHE_DB" run "$SEARCH_SCRIPT" "test" "$TEST_DIR/test_files" --cache-store
    [ "$status" -eq 0 ]
    
    # Check for size alerts
    CACHE_DB="$CACHE_DB" run "$SEARCH_SCRIPT" "test" "$TEST_DIR/test_files" --cache-alerts
    [ "$status" -eq 0 ]
    [[ "$output" =~ "Alert" ]] || [[ "$output" =~ "Warning" ]]
}

@test "cache cleanup recommendations" {
    CACHE_DB="$CACHE_DB" run "$SEARCH_SCRIPT" "test" "$TEST_DIR/test_files" --cache-init
    [ "$status" -eq 0 ]
    
    # Store metadata
    CACHE_DB="$CACHE_DB" run "$SEARCH_SCRIPT" "test" "$TEST_DIR/test_files" --cache-store
    [ "$status" -eq 0 ]
    
    # Get cleanup recommendations
    CACHE_DB="$CACHE_DB" run "$SEARCH_SCRIPT" "test" "$TEST_DIR/test_files" --cache-cleanup-suggestions
    [ "$status" -eq 0 ]
    [[ "$output" =~ "Recommendations" ]]
}

# Phase 1.3.1.3: Cache Performance Benchmarking

@test "cache vs no-cache performance comparison" {
    CACHE_DB="$CACHE_DB" run "$SEARCH_SCRIPT" "test" "$TEST_DIR/test_files" --cache-init
    [ "$status" -eq 0 ]
    
    # Store metadata
    CACHE_DB="$CACHE_DB" run "$SEARCH_SCRIPT" "test" "$TEST_DIR/test_files" --cache-store
    [ "$status" -eq 0 ]
    
    # Run performance comparison
    CACHE_DB="$CACHE_DB" run "$SEARCH_SCRIPT" "Canon" "$TEST_DIR/test_files" --cache-performance-compare
    [ "$status" -eq 0 ]
    [[ "$output" =~ "Cache Performance" ]]
    [[ "$output" =~ "No Cache Performance" ]]
    [[ "$output" =~ "Improvement" ]]
}

@test "cache performance regression detection" {
    CACHE_DB="$CACHE_DB" run "$SEARCH_SCRIPT" "test" "$TEST_DIR/test_files" --cache-init
    [ "$status" -eq 0 ]
    
    # Store metadata
    CACHE_DB="$CACHE_DB" run "$SEARCH_SCRIPT" "test" "$TEST_DIR/test_files" --cache-store
    [ "$status" -eq 0 ]
    
    # Check for performance regression
    CACHE_DB="$CACHE_DB" run "$SEARCH_SCRIPT" "test" "$TEST_DIR/test_files" --cache-regression-check
    [ "$status" -eq 0 ]
    [[ "$output" =~ "Performance" ]] || [[ "$output" =~ "No Regression" ]]
}

@test "cache optimization suggestions" {
    CACHE_DB="$CACHE_DB" run "$SEARCH_SCRIPT" "test" "$TEST_DIR/test_files" --cache-init
    [ "$status" -eq 0 ]
    
    # Store metadata
    CACHE_DB="$CACHE_DB" run "$SEARCH_SCRIPT" "test" "$TEST_DIR/test_files" --cache-store
    [ "$status" -eq 0 ]
    
    # Get optimization suggestions
    CACHE_DB="$CACHE_DB" run "$SEARCH_SCRIPT" "test" "$TEST_DIR/test_files" --cache-optimize-suggestions
    [ "$status" -eq 0 ]
    [[ "$output" =~ "Efficiency" ]]
    [[ "$output" =~ "Recommendations" ]]
}

@test "cache performance reporting" {
    CACHE_DB="$CACHE_DB" run "$SEARCH_SCRIPT" "test" "$TEST_DIR/test_files" --cache-init
    [ "$status" -eq 0 ]
    
    # Store metadata
    CACHE_DB="$CACHE_DB" run "$SEARCH_SCRIPT" "test" "$TEST_DIR/test_files" --cache-store
    [ "$status" -eq 0 ]
    
    # Generate performance report
    CACHE_DB="$CACHE_DB" run "$SEARCH_SCRIPT" "test" "$TEST_DIR/test_files" --cache-performance-report
    [ "$status" -eq 0 ]
    [[ "$output" =~ "Performance Report" ]]
    [[ "$output" =~ "Statistics" ]]
} 