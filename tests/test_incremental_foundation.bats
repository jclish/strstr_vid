#!/usr/bin/env bats

# Test suite for Phase 9.1: Incremental Updates Foundation
# Tests file change detection, change tracking, and basic incremental processing

setup() {
    # Create test directories and files
    mkdir -p test_incremental/{images,videos,subdir}
    
    # Create test image files with different timestamps
    cp tests/fixtures/test_canon.jpg test_incremental/images/image1.jpg
    cp tests/fixtures/test_nikon.jpg test_incremental/images/image2.jpg
    cp tests/fixtures/test_canon.jpg test_incremental/subdir/image3.jpg
    
    # Create test video files
    cp tests/fixtures/test_android.mp4 test_incremental/videos/video1.mp4
    cp tests/fixtures/test_iphone.mov test_incremental/videos/video2.mp4
    
    # Create change tracking database
    export CACHE_DB="test_incremental.db"
}

teardown() {
    # Clean up test files
    rm -rf test_incremental
    rm -f test_incremental.db
    rm -f test_incremental_changes.db
}

# File Change Detection Tests
@test "incremental flag is recognized" {
    run ./search_metadata.sh "test" test_incremental --incremental
    [ $status -eq 0 ]
    [[ "$output" == *"incremental"* || "$output" == *"Processing"* ]]
}

@test "incremental processing with change detection" {
    # First run - process all files
    run ./search_metadata.sh "test" test_incremental --incremental --cache-enabled
    [ $status -eq 0 ]
    
    # Second run - should detect no changes
    run ./search_metadata.sh "test" test_incremental --incremental --cache-enabled
    [ $status -eq 0 ]
    [[ "$output" == *"No changes detected"* || "$output" == *"0 files processed"* ]]
}

@test "incremental processing detects new files" {
    # First run
    run ./search_metadata.sh "test" test_incremental --incremental --cache-enabled
    [ $status -eq 0 ]
    
    # Add new file
    cp tests/fixtures/test_canon.jpg test_incremental/images/new_image.jpg
    
    # Second run - should detect new file
    run ./search_metadata.sh "test" test_incremental --incremental --cache-enabled
    [ $status -eq 0 ]
    [[ "$output" == *"new_image.jpg"* || "$output" == *"1 file processed"* ]]
}

@test "incremental processing detects modified files" {
    # First run
    run ./search_metadata.sh "test" test_incremental --incremental --cache-enabled
    [ $status -eq 0 ]
    
    # Modify file timestamp with a specific time
    touch -t 202401010000.00 test_incremental/images/image1.jpg
    
    # Second run - should detect modified file
    run ./search_metadata.sh "test" test_incremental --incremental --cache-enabled
    [ $status -eq 0 ]
    [[ "$output" == *"image1.jpg"* || "$output" == *"1 file processed"* ]]
}

@test "incremental processing detects deleted files" {
    # First run
    run ./search_metadata.sh "test" test_incremental --incremental --cache-enabled
    [ $status -eq 0 ]
    
    # Delete file
    rm test_incremental/images/image1.jpg
    
    # Second run - should detect deleted file
    run ./search_metadata.sh "test" test_incremental --incremental --cache-enabled
    [ $status -eq 0 ]
    [[ "$output" == *"deleted"* || "$output" == *"removed"* ]]
}

@test "incremental processing with file hash comparison" {
    # First run
    run ./search_metadata.sh "test" test_incremental --incremental --hash-check --cache-enabled
    [ $status -eq 0 ]
    
    # Modify file content (create new file with same name)
    cp tests/fixtures/test_nikon.jpg test_incremental/images/image1.jpg
    
    # Second run - should detect content change
    run ./search_metadata.sh "test" test_incremental --incremental --hash-check --cache-enabled
    [ $status -eq 0 ]
    [[ "$output" == *"content changed"* || "$output" == *"hash mismatch"* ]]
}

@test "incremental processing with timestamp tracking" {
    # First run
    run ./search_metadata.sh "test" test_incremental --incremental --timestamp-track --cache-enabled
    [ $status -eq 0 ]
    
    # Check timestamp database exists
    [ -f "test_incremental_timestamps.db" ]
    
    # Second run - should use timestamp tracking
    run ./search_metadata.sh "test" test_incremental --incremental --timestamp-track --cache-enabled
    [ $status -eq 0 ]
}

@test "incremental processing with change summary" {
    # First run
    run ./search_metadata.sh "test" test_incremental --incremental --change-summary --cache-enabled
    [ $status -eq 0 ]
    
    # Add new file
    cp tests/fixtures/test_canon.jpg test_incremental/images/new_image.jpg
    
    # Second run - should show change summary
    run ./search_metadata.sh "test" test_incremental --incremental --change-summary --cache-enabled
    [ $status -eq 0 ]
    [[ "$output" == *"Changes detected:"* || "$output" == *"Summary:"* ]]
}

@test "incremental processing with verbose output" {
    # First run
    run ./search_metadata.sh "test" test_incremental --incremental -v --cache-enabled
    [ $status -eq 0 ]
    
    # Second run - should show verbose incremental info
    run ./search_metadata.sh "test" test_incremental --incremental -v --cache-enabled
    [ $status -eq 0 ]
    [[ "$output" == *"incremental"* || "$output" == *"change detection"* ]]
}

@test "incremental processing with performance comparison" {
    # First run
    run ./search_metadata.sh "test" test_incremental --incremental --performance-compare --cache-enabled
    [ $status -eq 0 ]
    
    # Second run - should show performance comparison
    run ./search_metadata.sh "test" test_incremental --incremental --performance-compare --cache-enabled
    [ $status -eq 0 ]
    [[ "$output" == *"Performance:"* || "$output" == *"Time saved:"* ]]
}

@test "incremental processing with batch size" {
    # Test incremental processing with batch size
    run ./search_metadata.sh "test" test_incremental --incremental --batch-size 2 --cache-enabled
    [ $status -eq 0 ]
    [[ "$output" == *"batch"* || "$output" == *"Processing"* ]]
}

@test "incremental processing with memory limit" {
    # Test incremental processing with memory limit
    run ./search_metadata.sh "test" test_incremental --incremental --memory-limit 256MB --cache-enabled
    [ $status -eq 0 ]
    [[ "$output" == *"memory"* || "$output" == *"Processing"* ]]
}

@test "incremental processing with parallel workers" {
    # Test incremental processing with parallel workers
    run ./search_metadata.sh "test" test_incremental --incremental --parallel 2 --cache-enabled
    [ $status -eq 0 ]
    [[ "$output" == *"parallel"* || "$output" == *"Processing"* ]]
}

@test "incremental processing with cache integration" {
    # Test incremental processing with cache integration
    run ./search_metadata.sh "test" test_incremental --incremental --cache-enabled --cache-stats
    [ $status -eq 0 ]
    [[ "$output" == *"cache"* || "$output" == *"hit rate"* ]]
}

@test "incremental processing with different file types" {
    # Test incremental processing with different file types
    run ./search_metadata.sh "test" test_incremental --incremental --images-only --cache-enabled
    [ $status -eq 0 ]
    
    run ./search_metadata.sh "test" test_incremental --incremental --videos-only --cache-enabled
    [ $status -eq 0 ]
}

@test "incremental processing with recursive search" {
    # Test incremental processing with recursive search
    run ./search_metadata.sh "test" test_incremental --incremental -r --cache-enabled
    [ $status -eq 0 ]
    [[ "$output" == *"subdir"* || "$output" == *"Processing"* ]]
}

@test "incremental processing with output formats" {
    # Test incremental processing with output formats
    run ./search_metadata.sh "test" test_incremental --incremental --json --cache-enabled
    [ $status -eq 0 ]
    [[ "$output" == *"incremental"* || "$output" == *"json"* ]]
    
    run ./search_metadata.sh "test" test_incremental --incremental --csv --cache-enabled
    [ $status -eq 0 ]
    [[ "$output" == *"incremental"* || "$output" == *"csv"* ]]
}

@test "incremental processing error handling" {
    # Test incremental processing with invalid directory
    run ./search_metadata.sh "test" /nonexistent/directory --incremental --cache-enabled
    [ $status -ne 0 ]
    [[ "$output" == *"error"* || "$output" == *"not found"* ]]
}

@test "incremental processing with change tracking database" {
    # Test incremental processing with change tracking database
    run ./search_metadata.sh "test" test_incremental --incremental --track-changes --cache-enabled
    [ $status -eq 0 ]
    
    # Check change tracking database exists
    [ -f "test_incremental_changes.db" ]
    
    # Second run - should use change tracking
    run ./search_metadata.sh "test" test_incremental --incremental --track-changes --cache-enabled
    [ $status -eq 0 ]
}

@test "incremental processing with change type detection" {
    # Test incremental processing with change type detection
    run ./search_metadata.sh "test" test_incremental --incremental --change-types --cache-enabled
    [ $status -eq 0 ]
    
    # Add new file
    cp tests/fixtures/test_canon.jpg test_incremental/images/new_image.jpg
    
    # Second run - should detect change type
    run ./search_metadata.sh "test" test_incremental --incremental --change-types --cache-enabled
    [ $status -eq 0 ]
    [[ "$output" == *"new"* || "$output" == *"added"* ]]
} 