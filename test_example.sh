#!/bin/bash

# test_example.sh - Example usage of the metadata search script
# This script demonstrates various ways to use search_metadata.sh

echo "=== Metadata Search Tool Examples ==="
echo

# Check if the main script exists
if [ ! -f "./search_metadata.sh" ]; then
    echo "Error: search_metadata.sh not found in current directory"
    exit 1
fi

echo "CURRENT FEATURES:"
echo "• GPS coordinate extraction and location-based search"
echo "• Mobile device detection (iPhone, Android, Camera)"
echo "• Advanced boolean search operators (--and, --or, --not)"
echo "• Fuzzy matching for typos and variations"
echo "• Reverse geocoding for GPS coordinates"
echo "• Device clustering and statistics"
echo "• Multiple output formats (text, JSON, CSV)"
echo "• Field-specific search and regex support"
echo

echo "1. Basic search for 'Canon' in current directory:"
echo "   ./search_metadata.sh \"Canon\" ."
echo

echo "2. Search for 'iPhone' recursively (case-insensitive):"
echo "   ./search_metadata.sh \"iPhone\" . -r -i"
echo

echo "3. Verbose search for '2023' with full metadata:"
echo "   ./search_metadata.sh \"2023\" . -v -m"
echo

echo "4. Search for camera model 'EOS' in Pictures directory:"
echo "   ./search_metadata.sh \"EOS\" ~/Pictures -r"
echo

echo "5. Search for video codec 'H.264' in Videos directory:"
echo "   ./search_metadata.sh \"H.264\" ~/Videos -r -v"
echo

echo "6. Search for date '2024' in entire media folder:"
echo "   ./search_metadata.sh \"2024\" ~/Media -r -i -m"
echo

echo "=== ADVANCED SEARCH FEATURES ==="
echo

echo "7. Field-specific search (Make field only):"
echo "   ./search_metadata.sh \"Canon\" ~/Pictures -f Make"
echo

echo "8. Regex search for multiple camera brands:"
echo "   ./search_metadata.sh \"Canon|Nikon|Sony\" ~/Pictures -R -i"
echo

echo "9. Boolean search (Canon AND 2023, NOT iPhone):"
echo "   ./search_metadata.sh \"Canon\" ~/Pictures --and \"2023\" --not \"iPhone\""
echo

echo "10. Fuzzy search for typos and variations:"
echo "    ./search_metadata.sh \"Canon\" ~/Pictures --fuzzy --fuzzy-threshold 75"
echo

echo "11. Location-based search (within 10km of coordinates):"
echo "    ./search_metadata.sh \"2023\" ~/Pictures --within-radius \"37.7749,-122.4194,10\""
echo

echo "12. Location search with reverse geocoding:"
echo "    ./search_metadata.sh \"Canon\" ~/Pictures --within-radius \"37.7749,-122.4194,5\" --reverse-geocode"
echo

echo "13. Device statistics with search results:"
echo "    ./search_metadata.sh \"2023\" ~/Pictures --device-stats"
echo

echo "14. Export results in JSON format:"
echo "    ./search_metadata.sh \"Canon\" ~/Pictures --json"
echo

echo "15. Export results in CSV format:"
echo "    ./search_metadata.sh \"Canon\" ~/Pictures --csv -o results.csv"
echo

echo "=== Common Search Terms ==="
echo "Camera makes: Canon, Nikon, Sony, Fujifilm, Olympus"
echo "Camera models: iPhone, EOS, D850, A7, X-T4"
echo "Years: 2020, 2021, 2022, 2023, 2024"
echo "Software: Photoshop, Lightroom, GIMP, Snapseed"
echo "Video codecs: H.264, H.265, VP9, AV1"
echo "Audio codecs: AAC, MP3, FLAC, Opus"
echo "Device types: iPhone, Android, Camera"
echo

echo "=== GPS and Location Features ==="
echo "• GPS coordinates are automatically extracted from images and videos"
echo "• Use --within-radius for circular area search"
echo "• Use --bounding-box for rectangular area search"
echo "• Use --reverse-geocode to convert coordinates to place names"
echo "• Supports both decimal degrees and DMS coordinate formats"
echo

echo "=== Device Detection Features ==="
echo "• Automatically detects iPhone, Android, and camera devices"
echo "• Use --device-stats to see device clustering and statistics"
echo "• Shows device distribution in search results"
echo "• Extracts OS version information when available"
echo

echo "=== Advanced Search Logic ==="
echo "• Use --and for AND logic (all terms must match)"
echo "• Use --or for OR logic (any term can match)"
echo "• Use --not for NOT logic (exclude matching terms)"
echo "• Use --fuzzy for typo-tolerant search"
echo "• Use --fuzzy-threshold to adjust similarity sensitivity"
echo

echo "=== Tips ==="
echo "- Use quotes around search strings with spaces"
echo "- Use -i flag for case-insensitive searches"
echo "- Use -r flag to search subdirectories"
echo "- Use -v flag to see what files are being processed"
echo "- Use -m flag to see full metadata for matches"
echo "- Use -f flag to search specific metadata fields"
echo "- Use -R flag for regex pattern matching"
echo "- Use --fuzzy for finding matches with typos"
echo "- Use --device-stats to see device distribution"
echo "- Use --reverse-geocode to get place names from GPS"
echo

echo "=== Testing the Script ==="
echo "To test if dependencies are installed:"
echo "   ./search_metadata.sh \"test\" /tmp"
echo

echo "To see help:"
echo "   ./search_metadata.sh --help"
echo

echo "To test GPS features (if you have GPS-tagged photos):"
echo "   ./search_metadata.sh \"2023\" ~/Pictures --reverse-geocode"
echo

echo "To test device detection:"
echo "   ./search_metadata.sh \"iPhone\" ~/Pictures --device-stats" 