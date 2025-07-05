#!/bin/bash

# report_examples.sh - Example usage of the media report generator
# This script demonstrates various ways to use generate_media_report.sh

echo "=== Media Report Generator Examples ==="
echo

# Check if the main script exists
if [ ! -f "./generate_media_report.sh" ]; then
    echo "Error: generate_media_report.sh not found in current directory"
    exit 1
fi

echo "1. Basic media report for current directory:"
echo "   ./generate_media_report.sh ."
echo

echo "2. Recursive analysis with JSON output:"
echo "   ./generate_media_report.sh ~/Pictures -r -f json"
echo

echo "3. Export both JSON and CSV reports:"
echo "   ./generate_media_report.sh ~/Videos -j -c -r"
echo

echo "4. Filter by file size (files larger than 1MB):"
echo "   ./generate_media_report.sh ~/Media -s 1048576"
echo

echo "5. Filter by date range (2023 files only):"
echo "   ./generate_media_report.sh ~/Photos -D 2023-01-01 -T 2023-12-31"
echo

echo "6. Verbose analysis with detailed file list:"
echo "   ./generate_media_report.sh ~/Media -v -d"
echo

echo "7. Generate CSV report for spreadsheet analysis:"
echo "   ./generate_media_report.sh ~/Pictures -f csv > media_report.csv"
echo

echo "8. Complex analysis with multiple filters:"
echo "   ./generate_media_report.sh ~/Media -r -s 5242880 -D 2022-01-01 -j -c"
echo

echo "=== Common Use Cases ==="
echo "📊 Collection Analysis:"
echo "   ./generate_media_report.sh ~/Pictures -r"
echo

echo "📈 Storage Analysis:"
echo "   ./generate_media_report.sh ~/Media -r -f json | jq '.summary'"
echo

echo "📋 Device Analysis:"
echo "   ./generate_media_report.sh ~/Photos -r -f json | jq '.files[] | select(.type == \"image\") | .metadata' | grep -i 'make\|model'"
echo

echo "📅 Timeline Analysis:"
echo "   ./generate_media_report.sh ~/Media -r -f csv | grep '2024' | wc -l"
echo

echo "=== Output Formats ==="
echo "Text: Human-readable summary with statistics"
echo "JSON: Complete structured data for programmatic analysis"
echo "CSV: Simple tabular format for spreadsheet import"
echo

echo "=== Filtering Options ==="
echo "File Size: -s (min), -S (max) in bytes"
echo "Date Range: -D (from), -T (to) in YYYY-MM-DD format"
echo "Recursive: -r to include subdirectories"
echo "Verbose: -v for detailed processing information"
echo

echo "=== Integration Examples ==="
echo "Generate report and save to file:"
echo "   ./generate_media_report.sh ~/Media -r -f json > media_analysis.json"
echo

echo "Pipe to jq for specific analysis:"
echo "   ./generate_media_report.sh ~/Media -r -f json | jq '.files | group_by(.format) | map({format: .[0].format, count: length})'"
echo

echo "Create CSV for Excel:"
echo "   ./generate_media_report.sh ~/Media -r -f csv > media_inventory.csv"
echo

echo "=== Tips ==="
echo "- Use -r flag for comprehensive analysis of large directories"
echo "- Use -v flag to see processing progress"
echo "- Use -d flag to see detailed file information"
echo "- Combine -j and -c flags to export multiple formats"
echo "- Use jq for advanced JSON processing and filtering"
echo "- Use date filters to analyze specific time periods"
echo "- Use size filters to focus on large files" 