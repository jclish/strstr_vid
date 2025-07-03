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

echo "=== Common Search Terms ==="
echo "Camera makes: Canon, Nikon, Sony, Fujifilm, Olympus"
echo "Camera models: iPhone, EOS, D850, A7, X-T4"
echo "Years: 2020, 2021, 2022, 2023, 2024"
echo "Software: Photoshop, Lightroom, GIMP, Snapseed"
echo "Video codecs: H.264, H.265, VP9, AV1"
echo "Audio codecs: AAC, MP3, FLAC, Opus"
echo

echo "=== Tips ==="
echo "- Use quotes around search strings with spaces"
echo "- Use -i flag for case-insensitive searches"
echo "- Use -r flag to search subdirectories"
echo "- Use -v flag to see what files are being processed"
echo "- Use -m flag to see full metadata for matches"
echo

echo "=== Testing the Script ==="
echo "To test if dependencies are installed:"
echo "   ./search_metadata.sh \"test\" /tmp"
echo

echo "To see help:"
echo "   ./search_metadata.sh --help" 