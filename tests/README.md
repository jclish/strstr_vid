# Media Metadata Tools - Test Suite

This directory contains comprehensive tests for the Media Metadata Tools using BATS (Bash Automated Testing System).

## Prerequisites

- **bats-core**: Install with `brew install bats-core`
- **exiftool**: For creating test media with metadata
- **ffmpeg**: For video metadata testing
- **jq**: For JSON validation (optional but recommended)

## Running Tests

### Run All Tests
```bash
./tests/run_all_tests.sh
```

### Run Individual Test Files
```bash
bats tests/test_search_basic.bats
bats tests/test_search_advanced.bats
bats tests/test_report_basic.bats
```

### Run with Verbose Output
```bash
bats --verbose tests/test_search_basic.bats
```

### Run Specific Test
```bash
bats --filter "test name" tests/test_search_basic.bats
```

## Test Files

### `test_search_basic.bats`
Tests basic search functionality:
- Script existence and executability
- Help option
- Dependency checking
- Basic string search
- Case sensitivity
- Recursive search
- Verbose output
- Show metadata option
- Error handling
- Regex search
- Field-specific search
- Output formats (JSON, CSV)

### `test_search_advanced.bats`
Tests advanced search features:
- Boolean operators (`--and`, `--or`, `--not`)
- Fuzzy matching with configurable threshold
- GPS radius and bounding box search
- Reverse geocoding
- Device detection and clustering
- Complex search combinations
- Invalid input handling

### `test_report_basic.bats`
Tests media report generator:
- Script existence and executability
- Help option
- Basic report generation
- Recursive analysis
- All output formats (text, JSON, CSV, HTML, Markdown, XML)
- Date and size filtering
- File type filtering
- Error handling
- Save to file functionality

## Test Configuration

### `test_config.bash`
Common configuration and helper functions:
- Test timeout settings
- Color output
- Helper functions for creating test media
- GPS and device metadata creation
- JSON/CSV validation
- Dependency checking

## Adding New Tests

### 1. Create a new test file
```bash
touch tests/test_new_feature.bats
chmod +x tests/test_new_feature.bats
```

### 2. Use the standard BATS structure
```bash
#!/usr/bin/env bats

# test_new_feature.bats - Description of what this tests

setup() {
    # Setup test environment
    export TEST_DIR="$(mktemp -d)"
    export SCRIPT_DIR="$(cd "$(dirname "$BATS_TEST_FILENAME")/.." && pwd)"
    export SCRIPT="$SCRIPT_DIR/script_name.sh"
    
    # Create test files
    mkdir -p "$TEST_DIR/test_files"
    
    chmod +x "$SCRIPT"
}

teardown() {
    # Clean up
    rm -rf "$TEST_DIR"
}

@test "test description" {
    run "$SCRIPT" "args"
    [ "$status" -eq 0 ]
    [[ "$output" =~ "expected output" ]]
}
```

### 3. Add to the test runner
Edit `tests/run_all_tests.sh` and add your test file to the `test_files` array.

## Test Best Practices

### 1. Use Temporary Directories
Always use `mktemp -d` for test directories and clean up in `teardown()`.

### 2. Test Both Success and Failure Cases
```bash
@test "valid input works" {
    run "$SCRIPT" "valid args"
    [ "$status" -eq 0 ]
}

@test "invalid input fails gracefully" {
    run "$SCRIPT" "invalid args"
    [ "$status" -ne 0 ]
    [[ "$output" =~ "Error" ]]
}
```

### 3. Test Edge Cases
- Empty input
- Invalid directories
- Missing dependencies
- Network timeouts (for reverse geocoding)
- Large files
- Special characters in filenames

### 4. Use Helper Functions
Source `test_config.bash` for common functions:
```bash
source "$(dirname "$BATS_TEST_FILENAME")/test_config.bash"

@test "GPS search works" {
    create_gps_test_image "$TEST_DIR/test.jpg" "37.7749" "-122.4194"
    run "$SCRIPT" "test" "$TEST_DIR" --within-radius "37.7749,-122.4194,10"
    [ "$status" -eq 0 ]
}
```

### 5. Validate Output Formats
```bash
@test "JSON output is valid" {
    run "$SCRIPT" "test" "$TEST_DIR" --json
    [ "$status" -eq 0 ]
    validate_json "$output"
}

@test "CSV output is valid" {
    run "$SCRIPT" "test" "$TEST_DIR" --csv
    [ "$status" -eq 0 ]
    validate_csv "$output"
}
```

## Continuous Integration

The test suite is designed to work with CI/CD systems:

```yaml
# Example GitHub Actions workflow
- name: Run tests
  run: |
    brew install bats-core
    ./tests/run_all_tests.sh
```

## Troubleshooting

### Tests Fail Due to Missing Dependencies
- Install required tools: `brew install exiftool ffmpeg jq`
- Some tests will skip gracefully if dependencies are missing

### Network-Dependent Tests Fail
- Tests involving reverse geocoding may fail if network is unavailable
- Use `wait_for_network` helper for network operations

### Tests Time Out
- Increase `TEST_TIMEOUT` in `test_config.bash`
- Check for hanging processes or network calls

### Permission Issues
- Ensure test files are executable: `chmod +x tests/*.bats`
- Check that main scripts are executable

## Test Coverage

The test suite covers:
- ✅ Basic search functionality
- ✅ Advanced search features (boolean, fuzzy, GPS)
- ✅ Output formats (text, JSON, CSV)
- ✅ Error handling and edge cases
- ✅ Media report generator
- ✅ Filtering and validation
- ✅ Device detection and clustering

Future additions:
- Performance benchmarks
- Large file handling
- Cross-platform compatibility
- Integration tests with real media files 