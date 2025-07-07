#!/usr/bin/env bats

# Test suite for install_dependencies.sh
# Tests OS detection, dependency checking, installation functions, and verification

load 'test_config.bash'

setup() {
    # Create temporary directory for testing
    TEST_DIR=$(mktemp -d)
    cd "$TEST_DIR"
    
    # Backup original PATH
    ORIGINAL_PATH="$PATH"
    
    # Create mock commands directory
    MOCK_BIN="$TEST_DIR/mock_bin"
    mkdir -p "$MOCK_BIN"
    
    # Create mock commands
    create_mock_command "exiftool" "echo 'ExifTool version 12.50'"
    create_mock_command "ffprobe" "echo 'ffprobe version 4.4.2'"
    create_mock_command "brew" "echo 'Homebrew 3.6.0'"
    create_mock_command "apt-get" "echo 'apt-get mock'"
    create_mock_command "yum" "echo 'yum mock'"
    create_mock_command "dnf" "echo 'dnf mock'"
    create_mock_command "sudo" "echo 'sudo mock'"
    
    # Source the script for testing (without running main)
    SCRIPT_DIR="$BATS_TEST_DIRNAME/.."
    # Remove the conditional block that runs main
    awk '/^if \[\[ \"\$\{BASH_SOURCE\[0\]\}\" == \"\$\{0\}\" \]\]; then/{flag=1; next} /fi[ ]*$/ && flag{flag=0; next} !flag' "$SCRIPT_DIR/install_dependencies.sh" > "$TEST_DIR/install_dependencies_test.sh"
    source "$TEST_DIR/install_dependencies_test.sh"
}

teardown() {
    # Restore original PATH
    export PATH="$ORIGINAL_PATH"
    
    # Clean up
    rm -rf "$TEST_DIR"
}

# Helper function to create mock commands
create_mock_command() {
    local cmd="$1"
    local content="$2"
    cat > "$MOCK_BIN/$cmd" << EOF
#!/bin/bash
$content
EOF
    chmod +x "$MOCK_BIN/$cmd"
}

# Helper function to temporarily add mock bin to PATH
add_mock_to_path() {
    export PATH="$MOCK_BIN:$PATH"
}

# Helper function to remove command from mock bin
remove_mock_command() {
    local cmd="$1"
    rm -f "$MOCK_BIN/$cmd"
}

# Test OS detection function
@test "detect_os function exists" {
    run type -t detect_os
    [ "$status" -eq 0 ]
    [ "$output" = "function" ]
}

@test "detect_os returns macos on darwin" {
    # Mock OSTYPE for macOS
    local original_ostype="$OSTYPE"
    export OSTYPE="darwin"
    
    run detect_os
    [ "$status" -eq 0 ]
    [ "$output" = "macos" ]
    
    export OSTYPE="$original_ostype"
}

@test "detect_os returns ubuntu when apt-get exists" {
    # Mock OSTYPE for Linux
    local original_ostype="$OSTYPE"
    export OSTYPE="linux-gnu"
    
    # Add mock apt-get to PATH
    add_mock_to_path
    
    run detect_os
    [ "$status" -eq 0 ]
    [ "$output" = "ubuntu" ]
    
    export OSTYPE="$original_ostype"
}

@test "detect_os returns centos when yum exists" {
    # Mock OSTYPE for Linux
    local original_ostype="$OSTYPE"
    export OSTYPE="linux-gnu"
    
    # Remove apt-get, add yum
    remove_mock_command "apt-get"
    add_mock_to_path
    
    run detect_os
    [ "$status" -eq 0 ]
    [ "$output" = "centos" ]
    
    export OSTYPE="$original_ostype"
}

@test "detect_os returns fedora when dnf exists" {
    # Mock OSTYPE for Linux
    local original_ostype="$OSTYPE"
    export OSTYPE="linux-gnu"
    
    # Remove apt-get and yum, add dnf
    remove_mock_command "apt-get"
    remove_mock_command "yum"
    add_mock_to_path
    
    run detect_os
    [ "$status" -eq 0 ]
    [ "$output" = "fedora" ]
    
    export OSTYPE="$original_ostype"
}

@test "detect_os returns unknown for unsupported OS" {
    # Mock OSTYPE for unknown
    local original_ostype="$OSTYPE"
    export OSTYPE="unknown-os"
    
    run detect_os
    [ "$status" -eq 0 ]
    [ "$output" = "unknown" ]
    
    export OSTYPE="$original_ostype"
}

# Test command_exists function
@test "command_exists function exists" {
    run type -t command_exists
    [ "$status" -eq 0 ]
    [ "$output" = "function" ]
}

@test "command_exists returns true for existing command" {
    add_mock_to_path
    
    run command_exists exiftool
    [ "$status" -eq 0 ]
}

@test "command_exists returns false for non-existing command" {
    run command_exists nonexistent_command
    [ "$status" -eq 1 ]
}

# Test macOS installation function
@test "install_macos function exists" {
    run type -t install_macos
    [ "$status" -eq 0 ]
    [ "$output" = "function" ]
}

@test "install_macos exits when brew not found" {
    remove_mock_command "brew"
    local original_path="$PATH"
    export PATH="$MOCK_BIN"
    
    run install_macos
    [ "$status" -eq 1 ]
    [[ "$output" == *"Homebrew not found"* ]]
    
    export PATH="$original_path"
}

@test "install_macos continues when brew exists" {
    add_mock_to_path
    
    # Mock that exiftool and ffprobe don't exist
    remove_mock_command "exiftool"
    remove_mock_command "ffprobe"
    
    run install_macos
    [ "$status" -eq 0 ]
    [[ "$output" == *"Installing dependencies via Homebrew"* ]]
}

@test "install_macos skips exiftool if already installed" {
    add_mock_to_path
    
    run install_macos
    [ "$status" -eq 0 ]
    [[ "$output" == *"exiftool already installed"* ]]
}

@test "install_macos skips ffprobe if already installed" {
    add_mock_to_path
    
    run install_macos
    [ "$status" -eq 0 ]
    [[ "$output" == *"ffprobe already installed"* ]]
}

# Test Ubuntu installation function
@test "install_ubuntu function exists" {
    run type -t install_ubuntu
    [ "$status" -eq 0 ]
    [ "$output" = "function" ]
}

@test "install_ubuntu runs apt-get update" {
    add_mock_to_path
    
    # Mock that exiftool and ffprobe don't exist
    remove_mock_command "exiftool"
    remove_mock_command "ffprobe"
    
    run install_ubuntu
    [ "$status" -eq 0 ]
    [[ "$output" == *"Updating package list"* ]]
}

# Test CentOS installation function
@test "install_centos function exists" {
    run type -t install_centos
    [ "$status" -eq 0 ]
    [ "$output" = "function" ]
}

@test "install_centos uses yum for installation" {
    add_mock_to_path
    
    # Mock that exiftool and ffprobe don't exist
    remove_mock_command "exiftool"
    remove_mock_command "ffprobe"
    
    run install_centos
    [ "$status" -eq 0 ]
    [[ "$output" == *"Detected CentOS/RHEL"* ]]
}

# Test Fedora installation function
@test "install_fedora function exists" {
    run type -t install_fedora
    [ "$status" -eq 0 ]
    [ "$output" = "function" ]
}

@test "install_fedora uses dnf for installation" {
    add_mock_to_path
    
    # Mock that exiftool and ffprobe don't exist
    remove_mock_command "exiftool"
    remove_mock_command "ffprobe"
    
    run install_fedora
    [ "$status" -eq 0 ]
    [[ "$output" == *"Detected Fedora"* ]]
}

# Test verification function
@test "verify_installation function exists" {
    run type -t verify_installation
    [ "$status" -eq 0 ]
    [ "$output" = "function" ]
}

@test "verify_installation succeeds when both commands exist" {
    add_mock_to_path
    
    run verify_installation
    [ "$status" -eq 0 ]
    [[ "$output" == *"✓ exiftool is installed"* ]]
    [[ "$output" == *"✓ ffprobe is installed"* ]]
    [[ "$output" == *"Installation Complete"* ]]
}

@test "verify_installation fails when exiftool missing" {
    remove_mock_command "exiftool"
    local original_path="$PATH"
    export PATH="$MOCK_BIN"
    
    run verify_installation
    [ "$status" -eq 1 ]
    [[ "$output" == *"✗ exiftool is not installed"* ]]
    [[ "$output" == *"Installation Failed"* ]]
    
    export PATH="$original_path"
}

@test "verify_installation fails when ffprobe missing" {
    remove_mock_command "ffprobe"
    local original_path="$PATH"
    export PATH="$MOCK_BIN"
    
    run verify_installation
    [ "$status" -eq 1 ]
    [[ "$output" == *"✗ ffprobe is not installed"* ]]
    [[ "$output" == *"Installation Failed"* ]]
    
    export PATH="$original_path"
}

# Test main function
@test "main function exists" {
    run type -t main
    [ "$status" -eq 0 ]
    [ "$output" = "function" ]
}

@test "main calls install_macos for macOS" {
    # Mock OSTYPE for macOS
    local original_ostype="$OSTYPE"
    export OSTYPE="darwin"
    
    add_mock_to_path
    
    run main
    [ "$status" -eq 0 ]
    [[ "$output" == *"Detected macOS"* ]]
    
    export OSTYPE="$original_ostype"
}

@test "main calls install_ubuntu for Ubuntu" {
    # Mock OSTYPE for Linux
    local original_ostype="$OSTYPE"
    export OSTYPE="linux-gnu"
    
    add_mock_to_path
    
    run main
    [ "$status" -eq 0 ]
    [[ "$output" == *"Detected Ubuntu/Debian"* ]]
    
    export OSTYPE="$original_ostype"
}

@test "main exits for unsupported OS" {
    # Mock OSTYPE for unknown
    local original_ostype="$OSTYPE"
    export OSTYPE="unknown-os"
    
    run main
    [ "$status" -eq 1 ]
    [[ "$output" == *"Unsupported operating system"* ]]
    
    export OSTYPE="$original_ostype"
}

# Test script execution
@test "script can be sourced without errors" {
    run bash -c "source '$TEST_DIR/install_dependencies_test.sh' && echo 'Script sourced successfully'"
    [ "$status" -eq 0 ]
    [[ "$output" == *"Script sourced successfully" ]]
}

@test "script has proper shebang" {
    run head -n1 "$SCRIPT_DIR/install_dependencies.sh"
    [ "$status" -eq 0 ]
    [ "$output" = "#!/bin/bash" ]
}

@test "script has set -e for error handling" {
    run grep "set -e" "$SCRIPT_DIR/install_dependencies.sh"
    [ "$status" -eq 0 ]
}

# Test color output functions
@test "script defines color variables" {
    run bash -c "source '$SCRIPT_DIR/install_dependencies.sh' && echo \"RED: $RED\""
    [ "$status" -eq 0 ]
    [[ "$output" == *"RED:"* ]]
}

# Test error handling
@test "script handles missing commands gracefully" {
    # Create a minimal mock environment
    local minimal_mock="$TEST_DIR/minimal_mock"
    mkdir -p "$minimal_mock"
    
    # Only create a few mock commands
    create_mock_command "brew" "echo 'Homebrew 3.6.0'"
    create_mock_command "exiftool" "echo 'ExifTool version 12.50'"
    create_mock_command "ffprobe" "echo 'ffprobe version 4.4.2'"
    
    export PATH="$minimal_mock:$PATH"
    
    # Mock OSTYPE for macOS
    local original_ostype="$OSTYPE"
    export OSTYPE="darwin"
    
    run main
    [ "$status" -eq 0 ]
    
    export OSTYPE="$original_ostype"
}

# Test version output
@test "verify_installation shows exiftool version" {
    add_mock_to_path
    
    run verify_installation
    [ "$status" -eq 0 ]
    [[ "$output" == *"ExifTool version 12.50"* ]]
}

@test "verify_installation shows ffprobe version" {
    add_mock_to_path
    
    run verify_installation
    [ "$status" -eq 0 ]
    [[ "$output" == *"ffprobe version 4.4.2"* ]]
} 