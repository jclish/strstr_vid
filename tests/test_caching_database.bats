#!/usr/bin/env bats

# test_caching_database.bats - Tests for caching database functionality
# Tests: Database creation, schema validation, basic operations, cache versioning

setup() {
    export TEST_DIR="$(mktemp -d)"
    export SCRIPT_DIR="$(cd "$(dirname "$BATS_TEST_FILENAME")/.." && pwd)"
    export SEARCH_SCRIPT="$SCRIPT_DIR/search_metadata.sh"
    export REPORT_SCRIPT="$SCRIPT_DIR/generate_media_report.sh"
    export FIXTURES_DIR="$SCRIPT_DIR/tests/fixtures"
    export CACHE_DB="$TEST_DIR/metadata_cache.db"
    
    # Create test directory structure
    mkdir -p "$TEST_DIR/test_files"
    
    # Copy test files for database testing
    cp "$FIXTURES_DIR/test_canon.jpg" "$TEST_DIR/test_files/file1.jpg"
    cp "$FIXTURES_DIR/test_nikon.jpg" "$TEST_DIR/test_files/file2.jpg"
    cp "$FIXTURES_DIR/test_iphone.mov" "$TEST_DIR/test_files/video1.mov"
    
    chmod +x "$SEARCH_SCRIPT"
    chmod +x "$REPORT_SCRIPT"
}

teardown() {
    rm -rf "$TEST_DIR"
}

@test "cache database creation" {
    CACHE_DB="$CACHE_DB" run "$SEARCH_SCRIPT" "test" "$TEST_DIR/test_files" --cache-init
    [ "$status" -eq 0 ]
    [ -f "$CACHE_DB" ]
}

@test "cache database schema validation" {
    CACHE_DB="$CACHE_DB" run "$SEARCH_SCRIPT" "test" "$TEST_DIR/test_files" --cache-init
    [ "$status" -eq 0 ]
    
    # Check if database has required tables
    run sqlite3 "$CACHE_DB" ".tables"
    [ "$status" -eq 0 ]
    [[ "$output" =~ "metadata" ]]
    [[ "$output" =~ "file_info" ]]
    [[ "$output" =~ "cache_stats" ]]
}

@test "cache database table structure" {
    CACHE_DB="$CACHE_DB" run "$SEARCH_SCRIPT" "test" "$TEST_DIR/test_files" --cache-init
    [ "$status" -eq 0 ]
    
    # Check metadata table structure
    run sqlite3 "$CACHE_DB" "PRAGMA table_info(metadata);"
    [ "$status" -eq 0 ]
    [[ "$output" =~ "file_path" ]]
    [[ "$output" =~ "file_hash" ]]
    [[ "$output" =~ "metadata_json" ]]
    [[ "$output" =~ "created_at" ]]
    [[ "$output" =~ "updated_at" ]]
}

@test "cache database indexes" {
    CACHE_DB="$CACHE_DB" run "$SEARCH_SCRIPT" "test" "$TEST_DIR/test_files" --cache-init
    [ "$status" -eq 0 ]
    
    # Check if indexes exist
    run sqlite3 "$CACHE_DB" "SELECT name FROM sqlite_master WHERE type='index';"
    [ "$status" -eq 0 ]
    [[ "$output" =~ "idx_file_path" ]]
    [[ "$output" =~ "idx_file_hash" ]]
    [[ "$output" =~ "idx_created_at" ]]
}

@test "cache database connection" {
    # Initialize cache first
    CACHE_DB="$CACHE_DB" run "$SEARCH_SCRIPT" "test" "$TEST_DIR/test_files" --cache-init
    [ "$status" -eq 0 ]
    
    # Then test cache status
    CACHE_DB="$CACHE_DB" run "$SEARCH_SCRIPT" "test" "" --cache-status
    [ "$status" -eq 0 ]
    [[ "$output" =~ "Cache Status" ]]
}

@test "cache database versioning" {
    CACHE_DB="$CACHE_DB" run "$SEARCH_SCRIPT" "test" "$TEST_DIR/test_files" --cache-init
    [ "$status" -eq 0 ]
    
    # Check cache version
    run sqlite3 "$CACHE_DB" "SELECT value FROM cache_stats WHERE key='version';"
    [ "$status" -eq 0 ]
    [[ "$output" =~ "1.0" ]]
}

@test "cache database migration" {
    # Create old version database
    sqlite3 "$CACHE_DB" "CREATE TABLE metadata (file_path TEXT);"
    sqlite3 "$CACHE_DB" "CREATE TABLE cache_stats (key TEXT, value TEXT);"
    sqlite3 "$CACHE_DB" "INSERT INTO cache_stats (key, value) VALUES ('version', '0.9');"
    
    # Run migration
    CACHE_DB="$CACHE_DB" run "$SEARCH_SCRIPT" "test" "$TEST_DIR/test_files" --cache-migrate
    [ "$status" -eq 0 ]
    
    # Check if migration was successful
    run sqlite3 "$CACHE_DB" "SELECT value FROM cache_stats WHERE key='version';"
    [ "$status" -eq 0 ]
    [[ "$output" =~ "1.0" ]]
}

@test "cache database basic operations" {
    CACHE_DB="$CACHE_DB" run "$SEARCH_SCRIPT" "test" "$TEST_DIR/test_files" --cache-init
    [ "$status" -eq 0 ]
    
    # Test cache store operation
    CACHE_DB="$CACHE_DB" run "$SEARCH_SCRIPT" "test" "$TEST_DIR/test_files" --cache-store
    [ "$status" -eq 0 ]
    
    # Test cache retrieve operation
    CACHE_DB="$CACHE_DB" run "$SEARCH_SCRIPT" "test" "$TEST_DIR/test_files" --cache-retrieve
    [ "$status" -eq 0 ]
    [[ "$output" =~ "Cache hit" ]]
}

@test "cache database integrity" {
    CACHE_DB="$CACHE_DB" run "$SEARCH_SCRIPT" "test" "$TEST_DIR/test_files" --cache-init
    [ "$status" -eq 0 ]
    
    # Test database integrity
    run sqlite3 "$CACHE_DB" "PRAGMA integrity_check;"
    [ "$status" -eq 0 ]
    [[ "$output" =~ "ok" ]]
}

@test "cache database file info table" {
    CACHE_DB="$CACHE_DB" run "$SEARCH_SCRIPT" "test" "$TEST_DIR/test_files" --cache-init
    [ "$status" -eq 0 ]
    
    # Check file_info table structure
    run sqlite3 "$CACHE_DB" "PRAGMA table_info(file_info);"
    [ "$status" -eq 0 ]
    [[ "$output" =~ "file_path" ]]
    [[ "$output" =~ "file_size" ]]
    [[ "$output" =~ "file_hash" ]]
    [[ "$output" =~ "modified_time" ]]
    [[ "$output" =~ "file_type" ]]
}

@test "cache database cache stats table" {
    CACHE_DB="$CACHE_DB" run "$SEARCH_SCRIPT" "test" "$TEST_DIR/test_files" --cache-init
    [ "$status" -eq 0 ]
    
    # Check cache_stats table structure
    run sqlite3 "$CACHE_DB" "PRAGMA table_info(cache_stats);"
    [ "$status" -eq 0 ]
    [[ "$output" =~ "key" ]]
    [[ "$output" =~ "value" ]]
    [[ "$output" =~ "updated_at" ]]
}

@test "cache database initialization with existing database" {
    # Create initial database
    CACHE_DB="$CACHE_DB" run "$SEARCH_SCRIPT" "test" "$TEST_DIR/test_files" --cache-init
    [ "$status" -eq 0 ]
    
    # Try to initialize again (should not fail)
    CACHE_DB="$CACHE_DB" run "$SEARCH_SCRIPT" "test" "$TEST_DIR/test_files" --cache-init
    [ "$status" -eq 0 ]
}

@test "cache database with invalid path" {
    # Initialize cache first
    CACHE_DB="$CACHE_DB" run "$SEARCH_SCRIPT" "test" "$TEST_DIR/test_files" --cache-init
    [ "$status" -eq 0 ]
    
    # Try to store metadata from non-existent directory
    CACHE_DB="$CACHE_DB" run "$SEARCH_SCRIPT" "test" "/nonexistent/path" --cache-store
    [ "$status" -eq 1 ]
    [[ "$output" =~ "Error" ]]
}

@test "cache database permissions" {
    # Create database in read-only directory
    mkdir -p "$TEST_DIR/readonly"
    chmod 444 "$TEST_DIR/readonly"
    
    CACHE_DB="$TEST_DIR/readonly/cache.db" run "$SEARCH_SCRIPT" "test" "$TEST_DIR/readonly" --cache-init
    [ "$status" -eq 1 ]
    [[ "$output" =~ "Error" ]]
    
    chmod 755 "$TEST_DIR/readonly"
}

@test "cache database concurrent access" {
    CACHE_DB="$CACHE_DB" run "$SEARCH_SCRIPT" "test" "$TEST_DIR/test_files" --cache-init
    [ "$status" -eq 0 ]
    
    # Test concurrent access (should not fail)
    CACHE_DB="$CACHE_DB" run "$SEARCH_SCRIPT" "test" "$TEST_DIR/test_files" --cache-status &
    CACHE_DB="$CACHE_DB" run "$SEARCH_SCRIPT" "test" "$TEST_DIR/test_files" --cache-status
    [ "$status" -eq 0 ]
}

@test "cache database cleanup" {
    CACHE_DB="$CACHE_DB" run "$SEARCH_SCRIPT" "test" "$TEST_DIR/test_files" --cache-init
    [ "$status" -eq 0 ]
    [ -f "$CACHE_DB" ]
    
    # Test cache cleanup
    CACHE_DB="$CACHE_DB" run "$SEARCH_SCRIPT" "test" "$TEST_DIR/test_files" --cache-clear
    [ "$status" -eq 0 ]
    
    # Database should still exist but be empty
    [ -f "$CACHE_DB" ]
    run sqlite3 "$CACHE_DB" "SELECT COUNT(*) FROM metadata;"
    [ "$status" -eq 0 ]
    [ "$output" -eq "0" ]
}

@test "cache database backup and restore" {
    CACHE_DB="$CACHE_DB" run "$SEARCH_SCRIPT" "test" "$TEST_DIR/test_files" --cache-init
    [ "$status" -eq 0 ]
    
    # Add some test data
    CACHE_DB="$CACHE_DB" run "$SEARCH_SCRIPT" "test" "$TEST_DIR/test_files" --cache-store
    [ "$status" -eq 0 ]
    
    # Test backup
    CACHE_DB="$CACHE_DB" run "$SEARCH_SCRIPT" "test" "$TEST_DIR/test_files" --cache-backup "$TEST_DIR/backup.db"
    [ "$status" -eq 0 ]
    [ -f "$TEST_DIR/backup.db" ]
    
    # Test restore
    CACHE_DB="$CACHE_DB" run "$SEARCH_SCRIPT" "test" "$TEST_DIR/test_files" --cache-restore "$TEST_DIR/backup.db"
    [ "$status" -eq 0 ]
}

@test "cache database size limits" {
    CACHE_DB="$CACHE_DB" run "$SEARCH_SCRIPT" "test" "$TEST_DIR/test_files" --cache-init --cache-size-limit "1MB"
    [ "$status" -eq 0 ]
    
    # Check if size limit is set
    run sqlite3 "$CACHE_DB" "SELECT value FROM cache_stats WHERE key='size_limit';"
    [ "$status" -eq 0 ]
    [[ "$output" =~ "1048576" ]]
}

@test "cache database compression" {
    CACHE_DB="$CACHE_DB" run "$SEARCH_SCRIPT" "test" "$TEST_DIR/test_files" --cache-init --cache-compress
    [ "$status" -eq 0 ]
    
    # Check if compression is enabled
    run sqlite3 "$CACHE_DB" "SELECT value FROM cache_stats WHERE key='compression';"
    [ "$status" -eq 0 ]
    [[ "$output" =~ "enabled" ]]
} 