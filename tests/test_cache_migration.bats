#!/usr/bin/env bats

# test_cache_migration.bats - Tests for cache migration and versioning
# Tests: Schema versioning, automatic migration, backward compatibility, rollback

setup() {
    export TEST_DIR="$(mktemp -d)"
    export SCRIPT_DIR="$(cd "$(dirname "$BATS_TEST_FILENAME")/.." && pwd)"
    export SEARCH_SCRIPT="$SCRIPT_DIR/search_metadata.sh"
    export FIXTURES_DIR="$SCRIPT_DIR/tests/fixtures"
    export CACHE_DB="$TEST_DIR/metadata_cache.db"
    
    # Create test directory structure
    mkdir -p "$TEST_DIR/test_files"
    
    # Copy test files for cache migration testing
    cp "$FIXTURES_DIR/test_canon.jpg" "$TEST_DIR/test_files/file1.jpg"
    cp "$FIXTURES_DIR/test_nikon.jpg" "$TEST_DIR/test_files/file2.jpg"
    cp "$FIXTURES_DIR/test_iphone.mov" "$TEST_DIR/test_files/video1.mov"
    cp "$FIXTURES_DIR/test_android.mp4" "$TEST_DIR/test_files/video2.mp4"
    
    chmod +x "$SEARCH_SCRIPT"
}

teardown() {
    rm -rf "$TEST_DIR"
}

# Phase 1.3.3.1: Cache Schema Versioning

@test "cache version detection" {
    CACHE_DB="$CACHE_DB" run "$SEARCH_SCRIPT" "test" "$TEST_DIR/test_files" --cache-init
    [ "$status" -eq 0 ]
    
    # Check cache version
    CACHE_DB="$CACHE_DB" run "$SEARCH_SCRIPT" "test" "$TEST_DIR/test_files" --cache-version
    [ "$status" -eq 0 ]
    [[ "$output" =~ "Version" ]]
    [[ "$output" =~ "1" ]] || [[ "$output" =~ "2" ]]
}

@test "cache schema validation" {
    CACHE_DB="$CACHE_DB" run "$SEARCH_SCRIPT" "test" "$TEST_DIR/test_files" --cache-init
    [ "$status" -eq 0 ]
    
    # Validate schema
    CACHE_DB="$CACHE_DB" run "$SEARCH_SCRIPT" "test" "$TEST_DIR/test_files" --cache-schema-validate
    [ "$status" -eq 0 ]
    [[ "$output" =~ "Schema" ]]
    [[ "$output" =~ "Valid" ]]
}

@test "cache version compatibility check" {
    CACHE_DB="$CACHE_DB" run "$SEARCH_SCRIPT" "test" "$TEST_DIR/test_files" --cache-init
    [ "$status" -eq 0 ]
    
    # Check compatibility
    CACHE_DB="$CACHE_DB" run "$SEARCH_SCRIPT" "test" "$TEST_DIR/test_files" --cache-compatibility-check
    [ "$status" -eq 0 ]
    [[ "$output" =~ "Compatibility" ]]
    [[ "$output" =~ "Compatible" ]]
}

@test "cache version upgrade" {
    CACHE_DB="$CACHE_DB" run "$SEARCH_SCRIPT" "test" "$TEST_DIR/test_files" --cache-init
    [ "$status" -eq 0 ]
    
    # Store metadata
    CACHE_DB="$CACHE_DB" run "$SEARCH_SCRIPT" "test" "$TEST_DIR/test_files" --cache-store
    [ "$status" -eq 0 ]
    
    # Upgrade cache version
    CACHE_DB="$CACHE_DB" run "$SEARCH_SCRIPT" "test" "$TEST_DIR/test_files" --cache-upgrade
    [ "$status" -eq 0 ]
    [[ "$output" =~ "Upgrade" ]]
    [[ "$output" =~ "completed" ]]
}

# Phase 1.3.3.2: Automatic Cache Migration

@test "automatic cache migration" {
    CACHE_DB="$CACHE_DB" run "$SEARCH_SCRIPT" "test" "$TEST_DIR/test_files" --cache-init
    [ "$status" -eq 0 ]
    
    # Store metadata
    CACHE_DB="$CACHE_DB" run "$SEARCH_SCRIPT" "test" "$TEST_DIR/test_files" --cache-store
    [ "$status" -eq 0 ]
    
    # Auto migration
    CACHE_DB="$CACHE_DB" run "$SEARCH_SCRIPT" "test" "$TEST_DIR/test_files" --cache-auto-migrate
    [ "$status" -eq 0 ]
    [[ "$output" =~ "Migration" ]]
    [[ "$output" =~ "completed" ]]
}

@test "cache migration with backup" {
    CACHE_DB="$CACHE_DB" run "$SEARCH_SCRIPT" "test" "$TEST_DIR/test_files" --cache-init
    [ "$status" -eq 0 ]
    
    # Store metadata
    CACHE_DB="$CACHE_DB" run "$SEARCH_SCRIPT" "test" "$TEST_DIR/test_files" --cache-store
    [ "$status" -eq 0 ]
    
    # Migration with backup
    CACHE_DB="$CACHE_DB" run "$SEARCH_SCRIPT" "test" "$TEST_DIR/test_files" --cache-migrate-backup
    [ "$status" -eq 0 ]
    [[ "$output" =~ "Backup" ]]
    [[ "$output" =~ "Migration" ]]
}

@test "cache migration status" {
    CACHE_DB="$CACHE_DB" run "$SEARCH_SCRIPT" "test" "$TEST_DIR/test_files" --cache-init
    [ "$status" -eq 0 ]
    
    # Check migration status
    CACHE_DB="$CACHE_DB" run "$SEARCH_SCRIPT" "test" "$TEST_DIR/test_files" --cache-migration-status
    [ "$status" -eq 0 ]
    [[ "$output" =~ "Migration" ]]
    [[ "$output" =~ "Status" ]]
}

# Phase 1.3.3.3: Backward Compatibility

@test "backward compatibility check" {
    CACHE_DB="$CACHE_DB" run "$SEARCH_SCRIPT" "test" "$TEST_DIR/test_files" --cache-init
    [ "$status" -eq 0 ]
    
    # Check backward compatibility
    CACHE_DB="$CACHE_DB" run "$SEARCH_SCRIPT" "test" "$TEST_DIR/test_files" --cache-backward-compat
    [ "$status" -eq 0 ]
    [[ "$output" =~ "Backward" ]]
    [[ "$output" =~ "Supported" ]]
}

@test "legacy cache support" {
    CACHE_DB="$CACHE_DB" run "$SEARCH_SCRIPT" "test" "$TEST_DIR/test_files" --cache-init
    [ "$status" -eq 0 ]
    
    # Test legacy support
    CACHE_DB="$CACHE_DB" run "$SEARCH_SCRIPT" "test" "$TEST_DIR/test_files" --cache-legacy-support
    [ "$status" -eq 0 ]
    [[ "$output" =~ "Legacy" ]]
    [[ "$output" =~ "Supported" ]]
}

@test "cache format conversion" {
    CACHE_DB="$CACHE_DB" run "$SEARCH_SCRIPT" "test" "$TEST_DIR/test_files" --cache-init
    [ "$status" -eq 0 ]
    
    # Store metadata
    CACHE_DB="$CACHE_DB" run "$SEARCH_SCRIPT" "test" "$TEST_DIR/test_files" --cache-store
    [ "$status" -eq 0 ]
    
    # Convert format
    CACHE_DB="$CACHE_DB" run "$SEARCH_SCRIPT" "test" "$TEST_DIR/test_files" --cache-convert-format
    [ "$status" -eq 0 ]
    [[ "$output" =~ "Conversion" ]]
    [[ "$output" =~ "completed" ]]
}

# Phase 1.3.3.4: Migration Rollback

@test "cache migration rollback" {
    CACHE_DB="$CACHE_DB" run "$SEARCH_SCRIPT" "test" "$TEST_DIR/test_files" --cache-init
    [ "$status" -eq 0 ]
    
    # Store metadata
    CACHE_DB="$CACHE_DB" run "$SEARCH_SCRIPT" "test" "$TEST_DIR/test_files" --cache-store
    [ "$status" -eq 0 ]
    
    # Rollback migration
    CACHE_DB="$CACHE_DB" run "$SEARCH_SCRIPT" "test" "$TEST_DIR/test_files" --cache-rollback
    [ "$status" -eq 0 ]
    [[ "$output" =~ "Rollback" ]]
    [[ "$output" =~ "completed" ]]
}

@test "cache rollback history" {
    CACHE_DB="$CACHE_DB" run "$SEARCH_SCRIPT" "test" "$TEST_DIR/test_files" --cache-init
    [ "$status" -eq 0 ]
    
    # Check rollback history
    CACHE_DB="$CACHE_DB" run "$SEARCH_SCRIPT" "test" "$TEST_DIR/test_files" --cache-rollback-history
    [ "$status" -eq 0 ]
    [[ "$output" =~ "Rollback" ]]
    [[ "$output" =~ "History" ]]
}

@test "cache rollback to specific version" {
    CACHE_DB="$CACHE_DB" run "$SEARCH_SCRIPT" "test" "$TEST_DIR/test_files" --cache-init
    [ "$status" -eq 0 ]
    
    # Store metadata
    CACHE_DB="$CACHE_DB" run "$SEARCH_SCRIPT" "test" "$TEST_DIR/test_files" --cache-store
    [ "$status" -eq 0 ]
    
    # Rollback to specific version
    CACHE_DB="$CACHE_DB" run "$SEARCH_SCRIPT" "test" "$TEST_DIR/test_files" --cache-rollback-to "1"
    [ "$status" -eq 0 ]
    [[ "$output" =~ "Rollback" ]]
    [[ "$output" =~ "Invalid" ]] || [[ "$output" =~ "version 1" ]]
}

# Phase 1.3.3.5: Version-Specific Optimizations

@test "version-specific optimizations" {
    CACHE_DB="$CACHE_DB" run "$SEARCH_SCRIPT" "test" "$TEST_DIR/test_files" --cache-init
    [ "$status" -eq 0 ]
    
    # Apply version optimizations
    CACHE_DB="$CACHE_DB" run "$SEARCH_SCRIPT" "test" "$TEST_DIR/test_files" --cache-version-optimize
    [ "$status" -eq 0 ]
    [[ "$output" =~ "Optimization" ]]
    [[ "$output" =~ "completed" ]]
}

@test "cache version comparison" {
    CACHE_DB="$CACHE_DB" run "$SEARCH_SCRIPT" "test" "$TEST_DIR/test_files" --cache-init
    [ "$status" -eq 0 ]
    
    # Compare versions
    CACHE_DB="$CACHE_DB" run "$SEARCH_SCRIPT" "test" "$TEST_DIR/test_files" --cache-version-compare
    [ "$status" -eq 0 ]
    [[ "$output" =~ "Version" ]]
    [[ "$output" =~ "Comparison" ]]
}

@test "cache version recommendations" {
    CACHE_DB="$CACHE_DB" run "$SEARCH_SCRIPT" "test" "$TEST_DIR/test_files" --cache-init
    [ "$status" -eq 0 ]
    
    # Get version recommendations
    CACHE_DB="$CACHE_DB" run "$SEARCH_SCRIPT" "test" "$TEST_DIR/test_files" --cache-version-recommend
    [ "$status" -eq 0 ]
    [[ "$output" =~ "Recommendations" ]]
    [[ "$output" =~ "Version" ]]
}

# Phase 1.3.3.6: Cache Compatibility Checks

@test "cache compatibility validation" {
    CACHE_DB="$CACHE_DB" run "$SEARCH_SCRIPT" "test" "$TEST_DIR/test_files" --cache-init
    [ "$status" -eq 0 ]
    
    # Validate compatibility
    CACHE_DB="$CACHE_DB" run "$SEARCH_SCRIPT" "test" "$TEST_DIR/test_files" --cache-compatibility-validate
    [ "$status" -eq 0 ]
    [[ "$output" =~ "Compatibility" ]]
    [[ "$output" =~ "Valid" ]]
}

@test "cache format validation" {
    CACHE_DB="$CACHE_DB" run "$SEARCH_SCRIPT" "test" "$TEST_DIR/test_files" --cache-init
    [ "$status" -eq 0 ]
    
    # Validate format
    CACHE_DB="$CACHE_DB" run "$SEARCH_SCRIPT" "test" "$TEST_DIR/test_files" --cache-format-validate
    [ "$status" -eq 0 ]
    [[ "$output" =~ "Format" ]]
    [[ "$output" =~ "Valid" ]]
}

@test "cache structure validation" {
    CACHE_DB="$CACHE_DB" run "$SEARCH_SCRIPT" "test" "$TEST_DIR/test_files" --cache-init
    [ "$status" -eq 0 ]
    
    # Validate structure
    CACHE_DB="$CACHE_DB" run "$SEARCH_SCRIPT" "test" "$TEST_DIR/test_files" --cache-structure-validate
    [ "$status" -eq 0 ]
    [[ "$output" =~ "Structure" ]]
    [[ "$output" =~ "Valid" ]]
} 