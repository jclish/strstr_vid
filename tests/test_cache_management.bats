#!/usr/bin/env bats

# test_cache_management.bats - Tests for advanced cache management commands
# Tests: Cache pruning, cache analysis, cache health checks, advanced operations

setup() {
    export TEST_DIR="$(mktemp -d)"
    export SCRIPT_DIR="$(cd "$(dirname "$BATS_TEST_FILENAME")/.." && pwd)"
    export SEARCH_SCRIPT="$SCRIPT_DIR/search_metadata.sh"
    export FIXTURES_DIR="$SCRIPT_DIR/tests/fixtures"
    export CACHE_DB="$TEST_DIR/metadata_cache.db"
    
    # Create test directory structure
    mkdir -p "$TEST_DIR/test_files"
    
    # Copy test files for cache management testing
    cp "$FIXTURES_DIR/test_canon.jpg" "$TEST_DIR/test_files/file1.jpg"
    cp "$FIXTURES_DIR/test_nikon.jpg" "$TEST_DIR/test_files/file2.jpg"
    cp "$FIXTURES_DIR/test_iphone.mov" "$TEST_DIR/test_files/video1.mov"
    cp "$FIXTURES_DIR/test_android.mp4" "$TEST_DIR/test_files/video2.mp4"
    
    chmod +x "$SEARCH_SCRIPT"
}

teardown() {
    rm -rf "$TEST_DIR"
}

# Phase 1.3.2.1: Cache Pruning & Cleanup

@test "cache prune old entries" {
    CACHE_DB="$CACHE_DB" run "$SEARCH_SCRIPT" "test" "$TEST_DIR/test_files" --cache-init
    [ "$status" -eq 0 ]
    
    # Store metadata
    CACHE_DB="$CACHE_DB" run "$SEARCH_SCRIPT" "test" "$TEST_DIR/test_files" --cache-store
    [ "$status" -eq 0 ]
    
    # Prune old entries
    CACHE_DB="$CACHE_DB" run "$SEARCH_SCRIPT" "test" "$TEST_DIR/test_files" --cache-prune-old
    [ "$status" -eq 0 ]
    [[ "$output" =~ "Pruned" ]]
}

@test "cache prune by size" {
    CACHE_DB="$CACHE_DB" run "$SEARCH_SCRIPT" "test" "$TEST_DIR/test_files" --cache-init
    [ "$status" -eq 0 ]
    
    # Store metadata
    CACHE_DB="$CACHE_DB" run "$SEARCH_SCRIPT" "test" "$TEST_DIR/test_files" --cache-store
    [ "$status" -eq 0 ]
    
    # Prune by size
    CACHE_DB="$CACHE_DB" run "$SEARCH_SCRIPT" "test" "$TEST_DIR/test_files" --cache-prune-size "50KB"
    [ "$status" -eq 0 ]
    [[ "$output" =~ "Pruned" ]]
}

@test "cache prune by access time" {
    CACHE_DB="$CACHE_DB" run "$SEARCH_SCRIPT" "test" "$TEST_DIR/test_files" --cache-init
    [ "$status" -eq 0 ]
    
    # Store metadata
    CACHE_DB="$CACHE_DB" run "$SEARCH_SCRIPT" "test" "$TEST_DIR/test_files" --cache-store
    [ "$status" -eq 0 ]
    
    # Prune by access time
    CACHE_DB="$CACHE_DB" run "$SEARCH_SCRIPT" "test" "$TEST_DIR/test_files" --cache-prune-access "7d"
    [ "$status" -eq 0 ]
    [[ "$output" =~ "Pruned" ]]
}

@test "cache smart cleanup" {
    CACHE_DB="$CACHE_DB" run "$SEARCH_SCRIPT" "test" "$TEST_DIR/test_files" --cache-init
    [ "$status" -eq 0 ]
    
    # Store metadata
    CACHE_DB="$CACHE_DB" run "$SEARCH_SCRIPT" "test" "$TEST_DIR/test_files" --cache-store
    [ "$status" -eq 0 ]
    
    # Smart cleanup
    CACHE_DB="$CACHE_DB" run "$SEARCH_SCRIPT" "test" "$TEST_DIR/test_files" --cache-smart-cleanup
    [ "$status" -eq 0 ]
    [[ "$output" =~ "Cleanup" ]]
}

# Phase 1.3.2.2: Cache Analysis & Health Checks

@test "cache health check" {
    CACHE_DB="$CACHE_DB" run "$SEARCH_SCRIPT" "test" "$TEST_DIR/test_files" --cache-init
    [ "$status" -eq 0 ]
    
    # Store metadata
    CACHE_DB="$CACHE_DB" run "$SEARCH_SCRIPT" "test" "$TEST_DIR/test_files" --cache-store
    [ "$status" -eq 0 ]
    
    # Health check
    CACHE_DB="$CACHE_DB" run "$SEARCH_SCRIPT" "test" "$TEST_DIR/test_files" --cache-health-check
    [ "$status" -eq 0 ]
    [[ "$output" =~ "Health" ]]
    [[ "$output" =~ "Status" ]]
}

@test "cache integrity check" {
    CACHE_DB="$CACHE_DB" run "$SEARCH_SCRIPT" "test" "$TEST_DIR/test_files" --cache-init
    [ "$status" -eq 0 ]
    
    # Store metadata
    CACHE_DB="$CACHE_DB" run "$SEARCH_SCRIPT" "test" "$TEST_DIR/test_files" --cache-store
    [ "$status" -eq 0 ]
    
    # Integrity check
    CACHE_DB="$CACHE_DB" run "$SEARCH_SCRIPT" "test" "$TEST_DIR/test_files" --cache-integrity-check
    [ "$status" -eq 0 ]
    [[ "$output" =~ "Integrity" ]]
}

@test "cache corruption detection" {
    CACHE_DB="$CACHE_DB" run "$SEARCH_SCRIPT" "test" "$TEST_DIR/test_files" --cache-init
    [ "$status" -eq 0 ]
    
    # Store metadata
    CACHE_DB="$CACHE_DB" run "$SEARCH_SCRIPT" "test" "$TEST_DIR/test_files" --cache-store
    [ "$status" -eq 0 ]
    
    # Corruption detection
    CACHE_DB="$CACHE_DB" run "$SEARCH_SCRIPT" "test" "$TEST_DIR/test_files" --cache-corruption-check
    [ "$status" -eq 0 ]
    [[ "$output" =~ "Corruption" ]] || [[ "$output" =~ "No corruption" ]]
}

@test "cache performance analysis" {
    CACHE_DB="$CACHE_DB" run "$SEARCH_SCRIPT" "test" "$TEST_DIR/test_files" --cache-init
    [ "$status" -eq 0 ]
    
    # Store metadata
    CACHE_DB="$CACHE_DB" run "$SEARCH_SCRIPT" "test" "$TEST_DIR/test_files" --cache-store
    [ "$status" -eq 0 ]
    
    # Performance analysis
    CACHE_DB="$CACHE_DB" run "$SEARCH_SCRIPT" "test" "$TEST_DIR/test_files" --cache-performance-analysis
    [ "$status" -eq 0 ]
    [[ "$output" =~ "Performance" ]]
    [[ "$output" =~ "Analysis" ]]
}

# Phase 1.3.2.3: Advanced Cache Operations

@test "cache defragmentation" {
    CACHE_DB="$CACHE_DB" run "$SEARCH_SCRIPT" "test" "$TEST_DIR/test_files" --cache-init
    [ "$status" -eq 0 ]
    
    # Store metadata
    CACHE_DB="$CACHE_DB" run "$SEARCH_SCRIPT" "test" "$TEST_DIR/test_files" --cache-store
    [ "$status" -eq 0 ]
    
    # Defragment cache
    CACHE_DB="$CACHE_DB" run "$SEARCH_SCRIPT" "test" "$TEST_DIR/test_files" --cache-defrag
    [ "$status" -eq 0 ]
    [[ "$output" =~ "Defragmentation" ]]
}

@test "cache optimization" {
    CACHE_DB="$CACHE_DB" run "$SEARCH_SCRIPT" "test" "$TEST_DIR/test_files" --cache-init
    [ "$status" -eq 0 ]
    
    # Store metadata
    CACHE_DB="$CACHE_DB" run "$SEARCH_SCRIPT" "test" "$TEST_DIR/test_files" --cache-store
    [ "$status" -eq 0 ]
    
    # Optimize cache
    CACHE_DB="$CACHE_DB" run "$SEARCH_SCRIPT" "test" "$TEST_DIR/test_files" --cache-optimize
    [ "$status" -eq 0 ]
    [[ "$output" =~ "Optimization" ]]
}

@test "cache rebuild" {
    CACHE_DB="$CACHE_DB" run "$SEARCH_SCRIPT" "test" "$TEST_DIR/test_files" --cache-init
    [ "$status" -eq 0 ]
    
    # Store metadata
    CACHE_DB="$CACHE_DB" run "$SEARCH_SCRIPT" "test" "$TEST_DIR/test_files" --cache-store
    [ "$status" -eq 0 ]
    
    # Rebuild cache
    CACHE_DB="$CACHE_DB" run "$SEARCH_SCRIPT" "test" "$TEST_DIR/test_files" --cache-rebuild
    [ "$status" -eq 0 ]
    [[ "$output" =~ "Rebuild" ]]
}

@test "cache maintenance" {
    CACHE_DB="$CACHE_DB" run "$SEARCH_SCRIPT" "test" "$TEST_DIR/test_files" --cache-init
    [ "$status" -eq 0 ]
    
    # Store metadata
    CACHE_DB="$CACHE_DB" run "$SEARCH_SCRIPT" "test" "$TEST_DIR/test_files" --cache-store
    [ "$status" -eq 0 ]
    
    # Maintenance
    CACHE_DB="$CACHE_DB" run "$SEARCH_SCRIPT" "test" "$TEST_DIR/test_files" --cache-maintenance
    [ "$status" -eq 0 ]
    [[ "$output" =~ "Maintenance" ]]
}

# Phase 1.3.2.4: Cache Monitoring & Alerts

@test "cache monitoring" {
    CACHE_DB="$CACHE_DB" run "$SEARCH_SCRIPT" "test" "$TEST_DIR/test_files" --cache-init
    [ "$status" -eq 0 ]
    
    # Store metadata
    CACHE_DB="$CACHE_DB" run "$SEARCH_SCRIPT" "test" "$TEST_DIR/test_files" --cache-store
    [ "$status" -eq 0 ]
    
    # Monitor cache
    CACHE_DB="$CACHE_DB" run "$SEARCH_SCRIPT" "test" "$TEST_DIR/test_files" --cache-monitor
    [ "$status" -eq 0 ]
    [[ "$output" =~ "Monitoring" ]]
}

@test "cache alert configuration" {
    CACHE_DB="$CACHE_DB" run "$SEARCH_SCRIPT" "test" "$TEST_DIR/test_files" --cache-init
    [ "$status" -eq 0 ]
    
    # Configure alerts
    CACHE_DB="$CACHE_DB" run "$SEARCH_SCRIPT" "test" "$TEST_DIR/test_files" --cache-alert-config "size:100KB,age:30d"
    [ "$status" -eq 0 ]
    [[ "$output" =~ "Alert" ]]
    [[ "$output" =~ "Configuration" ]]
}

@test "cache diagnostic report" {
    CACHE_DB="$CACHE_DB" run "$SEARCH_SCRIPT" "test" "$TEST_DIR/test_files" --cache-init
    [ "$status" -eq 0 ]
    
    # Store metadata
    CACHE_DB="$CACHE_DB" run "$SEARCH_SCRIPT" "test" "$TEST_DIR/test_files" --cache-store
    [ "$status" -eq 0 ]
    
    # Diagnostic report
    CACHE_DB="$CACHE_DB" run "$SEARCH_SCRIPT" "test" "$TEST_DIR/test_files" --cache-diagnostic
    [ "$status" -eq 0 ]
    [[ "$output" =~ "Diagnostic" ]]
    [[ "$output" =~ "Report" ]]
}

@test "cache audit trail" {
    CACHE_DB="$CACHE_DB" run "$SEARCH_SCRIPT" "test" "$TEST_DIR/test_files" --cache-init
    [ "$status" -eq 0 ]
    
    # Store metadata
    CACHE_DB="$CACHE_DB" run "$SEARCH_SCRIPT" "test" "$TEST_DIR/test_files" --cache-store
    [ "$status" -eq 0 ]
    
    # Audit trail
    CACHE_DB="$CACHE_DB" run "$SEARCH_SCRIPT" "test" "$TEST_DIR/test_files" --cache-audit
    [ "$status" -eq 0 ]
    [[ "$output" =~ "Audit" ]]
    [[ "$output" =~ "Trail" ]]
} 