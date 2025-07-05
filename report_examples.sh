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
echo "• Enhanced statistics and analytics"
echo "• Advanced keyword analysis for podcast transcript matching"
echo "• Multiple output formats (text, JSON, CSV, HTML, Markdown, XML)"
echo "• Comprehensive filtering options (date, size, file type)"
echo "• Recursive directory analysis"
echo "• Camera and device analysis"
echo "• Storage usage trends and duplicate detection"
echo "• Resolution and aspect ratio analysis"
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

echo "=== FILTERING EXAMPLES ==="
echo

echo "7. Filter by date range (2023 files only):"
echo "   ./generate_media_report.sh ~/Media -D 2023-01-01 -T 2023-12-31"
echo

echo "8. Filter by file size (1MB to 100MB):"
echo "   ./generate_media_report.sh ~/Media -s 1MB -S 100MB"
echo

echo "9. Images only with size filter:"
echo "   ./generate_media_report.sh ~/Media --images-only -s 1MB"
echo

echo "10. Videos only with specific format:"
echo "    ./generate_media_report.sh ~/Media --videos-only --format mov"
echo

echo "11. Specific format filter:"
echo "    ./generate_media_report.sh ~/Media --format jpg"
echo

echo "=== OUTPUT FORMAT EXAMPLES ==="
echo

echo "12. HTML report for web viewing:"
echo "    ./generate_media_report.sh ~/Media --html"
echo

echo "13. Markdown report for documentation:"
echo "    ./generate_media_report.sh ~/Media --markdown"
echo

echo "14. XML report for enterprise systems:"
echo "    ./generate_media_report.sh ~/Media --xml"
echo

echo "15. Multiple format reports simultaneously:"
echo "    ./generate_media_report.sh ~/Media --html --markdown --xml"
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

echo "🗂️ Duplicate Detection:"
echo "   ./generate_media_report.sh ~/Media -r | grep -A 5 'Duplicate files:'"
echo

echo "📐 Resolution Analysis:"
echo "   ./generate_media_report.sh ~/Media -r | grep -A 10 'Resolution analysis:'"
echo

echo "=== Output Formats ==="
echo "Text: Human-readable summary with statistics and keyword analysis"
echo "JSON: Complete structured data for programmatic analysis"
echo "CSV: Simple tabular format for spreadsheet import"
echo "HTML: Web-friendly format with styling"
echo "Markdown: Documentation-friendly format"
echo "XML: Enterprise system integration format"
echo

echo "=== Available Options ==="
echo "File Size: -s (min), -S (max) in bytes or with units (1MB, 100MB)"
echo "Date Range: -D (from), -T (to) in YYYY-MM-DD format"
echo "Recursive: -r to include subdirectories"
echo "Verbose: -v for detailed processing information"
echo "Details: -d for detailed file information"
echo "Format: -f text|json|csv|html|markdown|xml for output format"
echo "JSON Export: -j for JSON output"
echo "CSV Export: -c for CSV output"
echo "HTML Export: --html for HTML output"
echo "Markdown Export: --markdown for Markdown output"
echo "XML Export: --xml for XML output"
echo "File Type Filtering: --images-only, --videos-only, --format <type>"
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

echo "Generate HTML report for web sharing:"
echo "   ./generate_media_report.sh ~/Media -r --html > media_report.html"
echo

echo "Create documentation with Markdown:"
echo "   ./generate_media_report.sh ~/Media -r --markdown > media_documentation.md"
echo

echo "=== Enhanced Statistics Features ==="
echo "• Average file sizes by format (JPEG, PNG, MP4, etc.)"
echo "• Storage usage trends with size distribution analysis"
echo "• Duplicate file detection using SHA-1 hashes"
echo "• Resolution analysis showing most common resolutions"
echo "• Aspect ratio analysis categorizing portrait/landscape/square"
echo "• Size distribution breakdowns (small/medium/large files)"
echo "• Enhanced keyword analysis with theme clustering"
echo "• Device and camera statistics"
echo

echo "=== Advanced Keyword Analysis ==="
echo "• Keyword clustering by semantic themes"
echo "• Theme detection and dominant theme identification"
echo "• Sentiment analysis with emotional categorization"
echo "• Language detection for multilingual content"
echo "• Keyword frequency heatmap visualization"
echo "• Podcast transcript matching suggestions"
echo

echo "=== Tips ==="
echo "- Use -r flag for comprehensive analysis of large directories"
echo "- Progress bar shows processing status automatically"
echo "- Use -v flag to see detailed processing information"
echo "- Use -d flag to see detailed file information"
echo "- Combine multiple format flags to export multiple formats"
echo "- Use jq for advanced JSON processing and filtering"
echo "- Keyword analysis helps match media to podcast content"
echo "- JSON output is perfect for programmatic analysis"
echo "- CSV output works well with spreadsheet applications"
echo "- HTML output is great for web sharing and presentations"
echo "- Markdown output is ideal for documentation"
echo "- XML output integrates well with enterprise systems"
echo "- Use filtering options to focus analysis on specific subsets"
echo "- Enhanced statistics provide deeper insights into media collections"
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
echo

echo "Test filtering:"
echo "   ./generate_media_report.sh ~/Pictures --images-only -s 1MB"
echo

echo "Test multiple formats:"
echo "   ./generate_media_report.sh ~/Media -r --html --markdown --xml"
echo

echo "=== Use Cases ==="
echo "• Storage optimization: Identify large files and duplicates"
echo "• Media organization: Understand resolution and aspect ratio patterns"
echo "• Capacity planning: Analyze storage usage trends"
echo "• Quality assessment: Review resolution and format distributions"
echo "• Archive management: Find duplicate content for cleanup"
echo "• Content analysis: Extract keywords for podcast matching"
echo "• Device analysis: Understand camera and device usage patterns"
echo "• Documentation: Generate reports for media collections"
echo "• Integration: Export data for external analysis tools" 