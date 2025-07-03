# Metadata Search Tool

A powerful shell script for searching strings within video and picture file metadata.

## Features

- **Multi-format support**: Works with images (JPG, PNG, GIF, BMP, TIFF, WebP, HEIC) and videos (MP4, AVI, MOV, MKV, WMV, FLV, WebM, etc.)
- **Flexible search options**: Case-sensitive/insensitive, recursive directory search
- **Rich output**: Colored output, verbose mode, full metadata display
- **Dependency checking**: Automatically checks for required tools and provides installation instructions

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

### Basic Usage
```bash
./search_metadata.sh "search_string" /path/to/directory
```

### Examples

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

### Command Line Options

| Option | Long Option | Description |
|--------|-------------|-------------|
| `-v` | `--verbose` | Show detailed output including full metadata |
| `-i` | `--case-insensitive` | Case-insensitive search (default: case-sensitive) |
| `-r` | `--recursive` | Search recursively in subdirectories |
| `-m` | `--show-metadata` | Show full metadata for matching files |
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

## What Metadata is Searched

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

## Output Examples

### Basic Search
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

### Verbose Search with Metadata
```
Searching for: 'iPhone'
Directory: /Users/user/Videos
Mode: Recursive

Searching in video: /Users/user/Videos/vacation.mp4
✓ Found in video: /Users/user/Videos/vacation.mp4
Full metadata:
  {
    "format": {
      "filename": "vacation.mp4",
      "nb_streams": 2,
      "format_name": "mov,mp4,m4a,3gp,3g2,mj2",
      "format_long_name": "QuickTime / MOV",
      "start_time": "0.000000",
      "duration": "120.500000",
      "size": "15728640",
      "bit_rate": "1044480",
      "tags": {
        "com.apple.quicktime.make": "Apple",
        "com.apple.quicktime.model": "iPhone 14 Pro"
      }
    }
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