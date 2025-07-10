#!/bin/bash

# run_all_tests.sh - Run the complete test suite for Media Metadata Tools
# Version: 2.0

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

echo -e "${BLUE}=== Media Metadata Tools - Test Suite ===${NC}"
echo ""

# Check if BATS is installed
if ! command -v bats >/dev/null 2>&1; then
    echo -e "${RED}Error: BATS is not installed. Please install BATS to run tests.${NC}"
    echo "Installation: https://github.com/bats-core/bats-core"
    exit 1
fi

# Get the directory where this script is located
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$SCRIPT_DIR"

echo "Running test suite..."
echo ""

# Run basic tests
echo -e "${YELLOW}Running test_search_basic.bats...${NC}"
if bats test_search_basic.bats; then
    echo -e "${GREEN}✓ test_search_basic.bats passed${NC}"
else
    echo -e "${RED}✗ test_search_basic.bats failed${NC}"
    exit 1
fi
echo ""

# Run advanced tests
echo -e "${YELLOW}Running test_search_advanced.bats...${NC}"
if bats test_search_advanced.bats; then
    echo -e "${GREEN}✓ test_search_advanced.bats passed${NC}"
else
    echo -e "${RED}✗ test_search_advanced.bats failed${NC}"
    exit 1
fi
echo ""

# Run real media search tests
echo -e "${YELLOW}Running test_search_real_media.bats...${NC}"
if bats test_search_real_media.bats; then
    echo -e "${GREEN}✓ test_search_real_media.bats passed${NC}"
else
    echo -e "${RED}✗ test_search_real_media.bats failed${NC}"
    exit 1
fi
echo ""

# Run basic report tests
echo -e "${YELLOW}Running test_report_basic.bats...${NC}"
if bats test_report_basic.bats; then
    echo -e "${GREEN}✓ test_report_basic.bats passed${NC}"
else
    echo -e "${RED}✗ test_report_basic.bats failed${NC}"
    exit 1
fi
echo ""

# Run real media report tests
echo -e "${YELLOW}Running test_report_real_media.bats...${NC}"
if bats test_report_real_media.bats; then
    echo -e "${GREEN}✓ test_report_real_media.bats passed${NC}"
else
    echo -e "${RED}✗ test_report_real_media.bats failed${NC}"
    exit 1
fi
echo ""

# Run incremental foundation tests
echo -e "${YELLOW}Running test_incremental_foundation.bats...${NC}"
if bats test_incremental_foundation.bats; then
    echo -e "${GREEN}✓ test_incremental_foundation.bats passed${NC}"
else
    echo -e "${RED}✗ test_incremental_foundation.bats failed${NC}"
    exit 1
fi
echo ""

echo -e "${GREEN}=== Test Summary ===${NC}"
echo -e "${GREEN}✓ All tests passed!${NC}"
echo ""
echo -e "${BLUE}Test coverage includes:${NC}"
echo "  • Basic search functionality"
echo "  • Advanced search features (boolean, fuzzy, GPS)"
echo "  • Real media file processing"
echo "  • Report generation and export formats"
echo "  • Incremental processing and change detection"
echo "  • Error handling and edge cases"
echo ""
echo -e "${GREEN}Test suite completed successfully!${NC}" 