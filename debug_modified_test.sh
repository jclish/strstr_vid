#!/bin/bash

# Debug script for modified file detection

echo "=== Debug Modified File Detection ==="

# Clean up any existing tracking files
rm -f .incremental_track_*

# Create test directory
mkdir -p test_debug/{images,videos,subdir}
cp tests/fixtures/test_canon.jpg test_debug/images/image1.jpg
cp tests/fixtures/test_nikon.jpg test_debug/images/image2.jpg
cp tests/fixtures/test_canon.jpg test_debug/subdir/image3.jpg
cp tests/fixtures/test_android.mp4 test_debug/videos/video1.mp4
cp tests/fixtures/test_iphone.mov test_debug/videos/video2.mp4

echo "=== First run ==="
./search_metadata.sh "test" test_debug --incremental --cache-enabled

echo "=== Checking tracking file ==="
cat .incremental_track_test_debug

echo "=== Modifying file ==="
touch test_debug/images/image1.jpg
sleep 1

echo "=== Second run ==="
./search_metadata.sh "test" test_debug --incremental --cache-enabled

echo "=== Checking tracking file after modification ==="
cat .incremental_track_test_debug

# Clean up
rm -rf test_debug
rm -f .incremental_track_* 