#!/bin/bash

# Usage: ./media_debug_final.sh <directory>

if [ $# -lt 1 ]; then
  echo "Usage: $0 <directory>"
  exit 1
fi

dir="$1"
count=0
images=0
videos=0
total_size=0
all_keywords=""
all_cameras=""
all_formats=""

echo "=== COMPREHENSIVE MEDIA REPORT ==="
echo "Directory: $dir"
echo "Generated: $(date)"
echo ""

echo "📊 PROCESSING FILES..."
echo "========================"

# Count total files first for progress bar
total_files=$(find "$dir" -maxdepth 1 -type f | wc -l)
processed=0

while read -r file; do
  ((processed++))
  
  # Show progress bar
  if [ $((processed % 10)) -eq 0 ] || [ $processed -eq 1 ] || [ $processed -eq $total_files ]; then
    progress=$((processed * 50 / total_files))
    # Ensure progress doesn't exceed 50
    if [ $progress -gt 50 ]; then
      progress=50
    fi
    printf "\rProcessing: [%-50s] %d/%d files" "$(printf '#%.0s' $(seq 1 $progress))" "$processed" "$total_files"
  fi
  ((count++))
  
  # Get file extension
  ext="${file##*.}"
  ext=$(echo "$ext" | tr '[:upper:]' '[:lower:]')
  
  # Get file size
  size=$(stat -f%z "$file" 2>/dev/null || stat -c%s "$file" 2>/dev/null)
  total_size=$((total_size + size))
  
  # Determine file type and extract metadata
  case "$ext" in
    jpg|jpeg|png|gif|bmp|tiff|tif|webp|heic|heif)
      ((images++))
      all_formats="$all_formats $ext"
      
      # Extract metadata from images
      metadata=$(exiftool "$file" 2>/dev/null)
      
      # Collect camera info
      camera=$(echo "$metadata" | grep -E "(Make|Model)" | head -2)
      if [ -n "$camera" ]; then
        all_cameras="$all_cameras $camera"
      fi
      
      # Collect keywords - be more selective
      keywords=$(echo "$metadata" | grep -E "(Keywords|Subject|Description|Caption|Title)" | grep -v -E "(Make|Model|Date|Time|Format|File|Size|Bytes|Camera|Image)" | head -5)
      if [ -n "$keywords" ]; then
        all_keywords="$all_keywords $keywords"
      fi
      ;;
    mp4|avi|mov|mkv|wmv|flv|webm|m4v|3gp|mpg|mpeg)
      ((videos++))
      all_formats="$all_formats $ext"
      
      # Extract metadata from videos
      metadata=$(ffprobe -v quiet -print_format json -show_format -show_streams "$file" 2>/dev/null)
      
      # Collect video tags - be more selective
      tags=$(echo "$metadata" | jq -r '.format.tags // empty' 2>/dev/null | grep -v -E "(com\.apple\.|com\.adobe\.|handler|encoder|creation_time|duration|bitrate)" 2>/dev/null)
      if [ -n "$tags" ] && [ "$tags" != "null" ]; then
        all_keywords="$all_keywords $tags"
      fi
      
      # Also try exiftool for videos - be more selective
      video_metadata=$(exiftool "$file" 2>/dev/null)
      video_keywords=$(echo "$video_metadata" | grep -E "(Keywords|Subject|Description|Caption|Title|Comment)" | grep -v -E "(Make|Model|Date|Time|Format|File|Size|Bytes|Camera|Video|Codec|Duration)" | head -3)
      if [ -n "$video_keywords" ]; then
        all_keywords="$all_keywords $video_keywords"
      fi
      ;;
  esac
done < <(find "$dir" -maxdepth 1 -type f -print)

# Clear the progress bar line
echo ""

echo "📋 SUMMARY REPORT"
echo "========================"
echo "Total files: $count"
echo "Images: $images"
echo "Videos: $videos"
echo "Other: $((count - images - videos))"
echo "Total size: $total_size bytes ($(echo "scale=1; $total_size/1024/1024" | bc) MB)"

echo ""
echo "📷 IMAGE ANALYSIS"
echo "========================"
if [ "$images" -gt 0 ]; then
  echo "Image count: $images"
  
  # Format breakdown
  echo "Formats found:"
  echo "$all_formats" | tr ' ' '\n' | grep -E "(jpg|jpeg|png|gif|bmp|tiff|tif|webp|heic|heif)" | sort | uniq -c | sort -nr
  
  # Camera analysis
  if [ -n "$all_cameras" ]; then
    echo ""
    echo "Cameras found:"
    echo "$all_cameras" | tr ' ' '\n' | grep -v "^$" | sort | uniq -c | sort -nr
  fi
else
  echo "No images found"
fi

echo ""
echo "🎬 VIDEO ANALYSIS"
echo "========================"
if [ "$videos" -gt 0 ]; then
  echo "Video count: $videos"
  
  # Format breakdown
  echo "Formats found:"
  echo "$all_formats" | tr ' ' '\n' | grep -E "(mp4|avi|mov|mkv|wmv|flv|webm|m4v|3gp|mpg|mpeg)" | sort | uniq -c | sort -nr
else
  echo "No videos found"
fi

echo ""
echo "🔍 KEYWORD ANALYSIS"
echo "========================"
if [ -n "$all_keywords" ]; then
  # Clean and process keywords for better readability
  echo "📝 KEYWORDS BY FREQUENCY:"
  echo "$all_keywords" | \
    sed 's/Keywords: //g' | \
    sed 's/Subject: //g' | \
    sed 's/Description: //g' | \
    sed 's/Title: //g' | \
    sed 's/Caption: //g' | \
    sed 's/Comment: //g' | \
    tr '[:upper:]' '[:lower:]' | \
    tr ' ' '\n' | \
    grep -v "^$" | \
    grep -E "[a-z]{4,}" | \
    grep -v -E "(make|model|date|time|original|create|modify|camera|image|video|format|file|size|bytes|adobe|stock|adobestock|handler|encoder|creation|duration|bitrate|minor|major|compatible|brands|isom|avc1|mp42)" | \
    sort | uniq -c | sort -nr | head -15 | \
    while read count word; do
      printf "  %2d: %s\n" "$count" "$word"
    done
  
  echo ""
  echo "📊 TOP THEMES (for podcast transcript matching):"
  echo "$all_keywords" | \
    tr '[:upper:]' '[:lower:]' | \
    tr ' ' '\n' | \
    grep -v "^$" | \
    grep -E "[a-z]{5,}" | \
    grep -v -E "(make|model|date|time|original|create|modify|camera|image|video|format|file|size|bytes|adobe|stock|adobestock|handler|encoder|creation|duration|bitrate|minor|major|compatible|brands|isom|avc1|mp42)" | \
    sort | uniq -c | sort -nr | head -10 | \
    while read count word; do
      printf "  %2d: %s\n" "$count" "$word"
    done
  
  echo ""
  echo "💡 SUGGESTED SEARCH TERMS FOR PODCAST MATCHING:"
  echo "$all_keywords" | \
    tr '[:upper:]' '[:lower:]' | \
    tr ' ' '\n' | \
    grep -v "^$" | \
    grep -E "[a-z]{6,}" | \
    grep -v -E "(make|model|date|time|original|create|modify|camera|image|video|format|file|size|bytes|adobe|stock|adobestock|keywords|subject|description|title|caption|handler|encoder|creation|duration|bitrate|minor|major|compatible|brands|isom|avc1|mp42)" | \
    sort | uniq -c | sort -nr | head -8 | \
    while read count word; do
      printf "  • %s (%d occurrences)\n" "$word" "$count"
    done
else
  echo "No keywords found in metadata"
fi

echo ""
echo "✅ REPORT COMPLETE" 