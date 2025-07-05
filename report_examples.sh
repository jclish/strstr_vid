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

echo "CURRENT FEATURES:"
echo "• Progress bar during processing"
echo "• Keyword analysis for podcast transcript matching"
echo "• Enhanced metadata filtering"
echo "• Multiple output formats (text, JSON, CSV)"
echo "• Recursive directory analysis"
echo "• Camera and format analysis"
echo

echo "1. Basic media report for current directory:"
echo "   ./generate_media_report.sh ."
echo

echo "2. Recursive analysis with JSON output:"
echo "   ./generate_media_report.sh ~/Pictures -r -f json"
echo

echo "3. Export both JSON and CSV reports:"
echo "   ./generate_media_report.sh ~/Videos -j -c -r"
echo

echo "4. Verbose analysis with detailed processing info:"
echo "   ./generate_media_report.sh ~/Media -v"
echo

echo "5. Generate CSV report for spreadsheet analysis:"
echo "   ./generate_media_report.sh ~/Pictures -f csv > media_report.csv"
echo

echo "6. Recursive analysis with all output formats:"
echo "   ./generate_media_report.sh ~/Media -r -j -c"
echo

echo "=== Common Use Cases ==="
echo "📊 Collection Analysis:"
echo "   ./generate_media_report.sh ~/Pictures -r"
echo

echo "📈 Storage Analysis:"
echo "   ./generate_media_report.sh ~/Media -r -f json | jq '.summary'"
echo

echo "📋 Device Analysis (extract camera info from text output):"
echo "   ./generate_media_report.sh ~/Photos -r | grep -A 20 'Cameras found:'"
echo

echo "🔍 Keyword Analysis for Podcast Matching:"
echo "   ./generate_media_report.sh ~/Media -r"
echo

echo "📊 Format Analysis:"
echo "   ./generate_media_report.sh ~/Media -r | grep -A 10 'Formats found:'"
echo

echo "=== Output Formats ==="
echo "Text: Human-readable summary with statistics and keyword analysis"
echo "JSON: Complete structured data for programmatic analysis"
echo "CSV: Simple tabular format for spreadsheet import"
echo

echo "=== Available Options ==="
echo "File Size: -s (min), -S (max) in bytes"
echo "Date Range: -D (from), -T (to) in YYYY-MM-DD format"
echo "Recursive: -r to include subdirectories"
echo "Verbose: -v for detailed processing information"
echo "Details: -d for detailed file information"
echo "Format: -f text|json|csv for output format"
echo "JSON Export: -j for JSON output"
echo "CSV Export: -c for CSV output"
echo

echo "=== Integration Examples ==="
echo "Generate report and save to file:"
echo "   ./generate_media_report.sh ~/Media -r -f json > media_analysis.json"
echo

echo "Pipe to jq for specific analysis:"
echo "   ./generate_media_report.sh ~/Media -r -f json | jq '.summary'"
echo

echo "Create CSV for Excel:"
echo "   ./generate_media_report.sh ~/Media -r -f csv > media_inventory.csv"
echo

echo "Extract just the summary statistics:"
echo "   ./generate_media_report.sh ~/Media -r -f json | jq '.summary.total_files'"
echo

echo "=== Tips ==="
echo "- Use -r flag for comprehensive analysis of large directories"
echo "- Progress bar shows processing status automatically"
echo "- Use -v flag to see detailed processing information"
echo "- Use -d flag to see detailed file information"
echo "- Combine -j and -c flags to export multiple formats"
echo "- Use jq for advanced JSON processing and filtering"
echo "- Keyword analysis helps match media to podcast content"
echo "- JSON output is perfect for programmatic analysis"
echo "- CSV output works well with spreadsheet applications"
echo

echo "=== Testing Examples ==="
echo "Test with a small directory:"
echo "   ./generate_media_report.sh ."
echo

echo "Test JSON output:"
echo "   ./generate_media_report.sh . -f json | jq ."
echo

echo "Test recursive analysis:"
echo "   ./generate_media_report.sh ~/Downloads -r -f json | jq '.summary'" 