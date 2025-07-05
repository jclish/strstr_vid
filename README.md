# Media Metadata Tools

A comprehensive suite of shell scripts for analyzing and searching metadata in video and picture files.

## Tools

### 1. Metadata Search Tool (`search_metadata.sh`)
- **Multi-format support**: Works with images (JPG, PNG, GIF, BMP, TIFF, WebP, HEIC) and videos (MP4, AVI, MOV, MKV, WMV, FLV, WebM, etc.)
- **Flexible search options**: Case-sensitive/insensitive, recursive directory search
- **Rich output**: Colored output, verbose mode, full metadata display
- **Dependency checking**: Automatically checks for required tools and provides installation instructions

### 2. Media Report Generator (`generate_media_report.sh`)
- **Comprehensive analysis**: Generates detailed reports about media collections
- **Multiple output formats**: Text, JSON, and CSV reports
- **Advanced filtering**: Filter by file size, date range, and media type
- **Statistical analysis**: File counts, size totals, format breakdowns, camera/device analysis
- **Export capabilities**: Export detailed data for further analysis

## Requirements

The script requires two main tools:

1. **exiftool** - For extracting image metadata
2. **ffprobe** - For extracting video metadata (part of ffmpeg)

### Installation

#### macOS
```bash
brew install exiftool ffmpeg
```

#### Ubuntu/Debian
```bash
sudo apt-get update
sudo apt-get install exiftool ffmpeg
```

#### CentOS/RHEL
```bash
sudo yum install perl-Image-ExifTool ffmpeg
```

## Usage

### Metadata Search Tool

#### Basic Usage
```bash
./search_metadata.sh "search_string" /path/to/directory
```

#### Examples

Search for "Canon" in photos directory:
```bash
./search_metadata.sh "Canon" ~/Pictures
```

Search for "iPhone" in videos recursively (case-insensitive):
```bash
./search_metadata.sh "iPhone" ~/Videos -r -i
```

Search for "2023" with verbose output and show full metadata:
```bash
./search_metadata.sh "2023" ~/Media -v -m
```

### Media Report Generator

#### Basic Usage
```bash
./generate_media_report.sh /path/to/directory
```

#### Examples

Generate a basic text report:
```bash
./generate_media_report.sh ~/Pictures
```

Generate a JSON report with recursive analysis:
```bash
./generate_media_report.sh ~/Media -r -f json
```

Export both JSON and CSV reports:
```bash
./generate_media_report.sh ~/Videos -j -c -r
```

Filter by file size and date range:
```bash
./generate_media_report.sh ~/Photos -s 1048576 -D 2023-01-01 -T 2024-12-31
```

### Command Line Options

#### Metadata Search Tool

| Option | Long Option | Description |
|--------|-------------|-------------|
| `-v` | `--verbose` | Show detailed output including full metadata |
| `-i` | `--case-insensitive` | Case-insensitive search (default: case-sensitive) |
| `-r` | `--recursive` | Search recursively in subdirectories |
| `-m` | `--show-metadata` | Show full metadata for matching files |
| `-h` | `--help` | Show help message |

#### Media Report Generator

| Option | Long Option | Description |
|--------|-------------|-------------|
| `-f` | `--format` | Output format: text, json, csv (default: text) |
| `-v` | `--verbose` | Show detailed processing information |
| `-r` | `--recursive` | Analyze recursively in subdirectories |
| `-d` | `--details` | Show detailed metadata for each file |
| `-j` | `--json` | Export detailed JSON report |
| `-c` | `--csv` | Export CSV report |
| `-s` | `--min-size` | Minimum file size to include (bytes) |
| `-S` | `--max-size` | Maximum file size to include (bytes) |
| `-D` | `--date-from` | Include files from this date (YYYY-MM-DD) |
| `-T` | `--date-to` | Include files up to this date (YYYY-MM-DD) |
| `-h` | `--help` | Show help message |

## Supported File Types

### Images
- JPG/JPEG
- PNG
- GIF
- BMP
- TIFF/TIF
- WebP
- HEIC/HEIF

### Videos
- MP4
- AVI
- MOV
- MKV
- WMV
- FLV
- WebM
- M4V
- 3GP
- MPG/MPEG

## What Metadata is Analyzed

### Image Metadata (via exiftool)
- Camera make and model
- Date/time taken
- GPS coordinates
- Software used
- Copyright information
- Image dimensions
- Color space
- And many more EXIF/IPTC/XMP fields

### Video Metadata (via ffprobe)
- Video codec
- Audio codec
- Duration
- Resolution
- Frame rate
- Bitrate
- Creation date
- Software used
- And other format/stream metadata

## Report Features

### Text Reports
- Summary statistics (file counts, total size)
- Format breakdown by media type
- Camera/device analysis for images
- Codec analysis for videos
- Optional detailed file listings

### JSON Reports
- Complete structured data export
- All metadata preserved
- Easy integration with other tools
- Machine-readable format

### CSV Reports
- Simple tabular format
- Easy import into spreadsheets
- Basic file information (path, type, format, size, date)

## Output Examples

### Metadata Search Results
```
Searching for: 'Canon'
Directory: /Users/user/Pictures
Mode: Non-recursive

✓ Found in image: /Users/user/Pictures/IMG_001.jpg
✓ Found in image: /Users/user/Pictures/IMG_002.jpg

Search Summary:
  Total files processed: 15
  Files with matches: 2
```

### Media Report Example
```
=== Media Report for /Users/user/Media ===

📊 SUMMARY:
  Total files: 1,247
  Images: 892 (71.5%)
  Videos: 355 (28.5%)
  Total size: 45.2 GB

📷 IMAGES (892 files):
  Formats: JPG (456), PNG (234), HEIC (202)
  Cameras: iPhone (234), Canon (189), Nikon (156)
  Years: 2024 (234), 2023 (456), 2022 (202)
  
🎬 VIDEOS (355 files):
  Formats: MP4 (234), MOV (89), AVI (32)
  Codecs: H.264 (189), H.265 (89), VP9 (77)
  Duration: 2.3 hours total
```

### JSON Report Structure
```json
{
  "directory": "/Users/user/Media",
  "generated_at": "2024-01-15T10:30:00Z",
  "summary": {
    "total_files": 1247,
    "total_size": 48523456789,
    "images": 892,
    "videos": 355
  },
  "files": [
    {
      "file": "/Users/user/Media/IMG_001.jpg",
      "type": "image",
      "format": "jpg",
      "size": 2048576,
      "date": "2024:01:15 10:30:00",
      "metadata": "Make: Canon\nModel: EOS R5\n..."
    }
  ]
}
```

## Error Handling

The script includes comprehensive error handling:

- **Missing dependencies**: Automatically detects missing tools and provides installation instructions
- **Invalid directories**: Checks if the specified directory exists
- **Unsupported files**: Gracefully skips unsupported file types
- **Permission errors**: Handles files that can't be read due to permissions

## Performance Considerations

- The script processes files sequentially to avoid overwhelming the system
- Large directories with many files may take some time to process
- Use the `-v` flag sparingly on large directories as it generates more output
- The `-m` flag can produce very verbose output for files with extensive metadata

## Troubleshooting

### "Command not found" errors
Make sure you have installed the required dependencies (exiftool and ffmpeg).

### Permission denied errors
Ensure the script has execute permissions:
```bash
chmod +x search_metadata.sh
```

### No results found
- Check that your search string is correct
- Try using case-insensitive search (`-i` flag)
- Verify that the files contain the expected metadata
- Use verbose mode (`-v`) to see what files are being processed

## License

This script is provided as-is for educational and personal use. 