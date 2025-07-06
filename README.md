# Media Metadata Search Tools

A comprehensive suite of command-line tools for searching and analyzing metadata in video and picture files. Features advanced search capabilities, GPS filtering, device clustering, and comprehensive reporting.

## 🚀 Recent Updates

### Version 2.14 - Incremental Foundation
- **File change detection** - Detect new, modified, deleted, and content-changed files
- **Incremental processing** - Process only changed files for faster subsequent runs
- **Change tracking database** - SQLite database for file modification history
- **File hash comparison** - Detect content changes vs metadata-only changes
- **Change summary and metrics** - Track and display processing changes
- **File type filtering** - Support for `--images-only` and `--videos-only` in incremental mode
- **Cache integration** - Cache statistics with incremental processing
- **Comprehensive test suite** with 20/20 incremental foundation tests passing

### Version 2.13 - Cache Migration & Versioning
- **Cache schema versioning** with automatic version detection
- **Automatic cache migration** for seamless format upgrades
- **Backward compatibility** support for older cache versions
- **Migration rollback** to revert to previous cache versions
- **Version-specific optimizations** for performance improvements
- **Cache compatibility validation** across different versions
- **Comprehensive test suite** with 191 total tests

### Version 2.12 - Advanced Cache Management
- **Cache statistics & monitoring** (hit rates, efficiency, growth analysis)
- **Cache health checks** (integrity, corruption detection)
- **Advanced cache pruning** (by size, age, smart cleanup)
- **Cache optimization** (defragmentation, rebuild, maintenance)
- **Cache performance analysis** (benchmarking, regression detection)
- **Cache monitoring & alerts** (real-time monitoring, alert configuration)
- **Cache diagnostic tools** (comprehensive reports, audit trails)
- **Comprehensive test suite** with 172 total tests

### Version 2.11 - Parallel Processing & Caching
- **Parallel processing** with configurable worker pools
- **Metadata caching** with SQLite database
- **Cache management** commands (init, store, retrieve, clear)
- **Performance benchmarking** and comparison tools
- **Comprehensive test suite** with 144 total tests

## 🚀 Features

### Core Search Features
- **Advanced metadata search** in images (jpg, png, gif, etc.) and videos (mp4, mov, avi, etc.)
- **Recursive directory search** with configurable depth
- **Case-sensitive and case-insensitive** search options
- **Regex pattern matching** for complex search patterns
- **Field-specific search** (search specific metadata fields like Make, Model, Date)
- **Boolean search operators** (AND, OR, NOT) for complex queries
- **Fuzzy matching** with configurable threshold for typos and variations

### Location & GPS Features
- **GPS radius filtering** - find files within a specific distance from coordinates
- **Bounding box filtering** - find files within geographic boundaries
- **Reverse geocoding** - convert GPS coordinates to place names
- **Support for both decimal and DMS coordinate formats**

### Device Analysis
- **Device clustering** - group files by camera/device type
- **Mobile device detection** - identify iPhone, Android, and other mobile devices
- **Device statistics** - comprehensive breakdown of devices used
- **OS version detection** - identify operating system versions

### Parallel Processing & Performance ✅
- **Parallel processing** with configurable worker pools (2-8x faster)
- **Auto-detect optimal workers** based on CPU cores
- **Memory management** with configurable limits
- **Batch processing** for large directories
- **Progress tracking** with real-time updates
- **Performance benchmarking** and comparison tools
- **Memory usage monitoring** during processing
- **Performance reporting** with detailed metrics

### Metadata Caching 🆕
- **Intelligent caching** - Cache metadata for repeated searches
- **Cache invalidation** - Automatic cache refresh when files change
- **Cache management** - Initialize, clear, backup, and restore cache
- **Cache performance** - Significant speed improvements for repeated operations
- **Cache statistics** - Monitor cache hit rates and performance
- **Cache compression** - Reduce storage requirements
- **Cache size limits** - Prevent cache from growing too large
- **Cache-enabled search** - Use cached metadata for faster searches

### Incremental Processing 🆕
- **File change detection** - Detect new, modified, deleted, and content-changed files
- **Incremental processing** - Process only changed files for faster subsequent runs
- **Change tracking database** - SQLite database for file modification history
- **File hash comparison** - Detect content changes vs metadata-only changes
- **Change summary and metrics** - Track and display processing changes
- **File type filtering** - Support for `--images-only` and `--videos-only` in incremental mode
- **Cache integration** - Cache statistics with incremental processing
- **Performance optimization** - Dramatically faster repeated operations

### Output Formats
- **Text output** with detailed metadata display
- **JSON export** for programmatic processing
- **CSV export** for spreadsheet analysis
- **HTML reports** with interactive features
- **Markdown reports** for documentation
- **XML export** for structured data

### Report Generation
- **Comprehensive media reports** with statistics and analysis
- **File type breakdown** (images vs videos)
- **Size analysis** and storage statistics
- **Duplicate detection** using file hashes
- **Resolution analysis** for images and videos
- **Aspect ratio clustering** and trends
- **Keyword extraction** and clustering
- **Date range filtering** and analysis

## 📦 Installation

### Prerequisites
- **exiftool** - for image metadata extraction
- **ffprobe** (part of ffmpeg) - for video metadata extraction

### Install Dependencies

**macOS:**
```bash
brew install exiftool ffmpeg
```

**Ubuntu/Debian:**
```bash
sudo apt-get install exiftool ffmpeg
```

**CentOS/RHEL:**
```bash
sudo yum install perl-Image-ExifTool ffmpeg
```

### Download and Setup
```bash
git clone https://github.com/yourusername/media-metadata-tools.git
cd media-metadata-tools
chmod +x search_metadata.sh generate_media_report.sh
```

## 🎯 Quick Start

### Basic Search
```bash
# Search for "iPhone" in photos directory
./search_metadata.sh "iPhone" /path/to/photos

# Search with case-insensitive option
./search_metadata.sh "canon" /path/to/photos -i

# Search recursively in subdirectories
./search_metadata.sh "2023" /path/to/photos -r
```

### Parallel Processing 🆕
```bash
# Use 4 parallel workers for faster processing
./search_metadata.sh "iPhone" /path/to/photos --parallel 4

# Auto-detect optimal number of workers
./search_metadata.sh "Canon" /path/to/photos --parallel auto

# Memory-managed parallel processing
./search_metadata.sh "2023" /path/to/photos --parallel 8 --memory-limit 512MB
```

### Advanced Search
```bash
# Search specific metadata field
./search_metadata.sh "Canon" /path/to/photos -f Make

# Use regex pattern matching
./search_metadata.sh "iPhone.*202[34]" /path/to/photos -R

# Boolean search (must contain both terms)
./search_metadata.sh "iPhone" /path/to/photos --and "2023" --and "vacation"

# GPS radius search
./search_metadata.sh "iPhone" /path/to/photos --within-radius "37.7749,-122.4194,10"
```

### Generate Reports
```bash
# Generate comprehensive media report
./generate_media_report.sh /path/to/photos

# Export to multiple formats
./generate_media_report.sh /path/to/photos -j -c --html

# Generate report with parallel processing
./generate_media_report.sh /path/to/photos --parallel 4
```

## 📖 Usage Examples

### Search Examples
```bash
# Find all Canon photos
./search_metadata.sh "Canon" /path/to/photos

# Find iPhone photos from 2023
./search_metadata.sh "iPhone" /path/to/photos --and "2023"

# Find photos within 5km of San Francisco
./search_metadata.sh "iPhone" /path/to/photos --within-radius "37.7749,-122.4194,5"

# Find photos with fuzzy matching (handles typos)
./search_metadata.sh "iphne" /path/to/photos --fuzzy

# Export results to JSON
./search_metadata.sh "Canon" /path/to/photos --json -o results.json
```

### Parallel Processing Examples ✅
```bash
# Fast processing of large directory
./search_metadata.sh "test" /large/photo/collection --parallel 8

# Memory-managed processing
./search_metadata.sh "iPhone" /path/to/photos --parallel 4 --memory-limit 256MB

# Progress tracking with verbose output
./search_metadata.sh "Canon" /path/to/photos --parallel 4 -v

# Performance benchmarking
./search_metadata.sh "test" /path/to/photos --benchmark

# Compare sequential vs parallel performance
./search_metadata.sh "test" /path/to/photos --compare-modes
```

### Caching Examples 🆕
```bash
# Initialize cache for faster searches
./search_metadata.sh "test" /path/to/photos --cache-init

# Store metadata in cache
./search_metadata.sh "test" /path/to/photos --cache-store

# Search with cache enabled (much faster)
./search_metadata.sh "Canon" /path/to/photos --cache-enabled

# Check cache status
./search_metadata.sh "test" /path/to/photos --cache-status

# Advanced cache management
./search_metadata.sh "test" /path/to/photos --cache-stats
./search_metadata.sh "test" /path/to/photos --cache-health-check
./search_metadata.sh "test" /path/to/photos --cache-prune-old
./search_metadata.sh "test" /path/to/photos --cache-optimize
./search_metadata.sh "test" /path/to/photos --cache-maintenance

# Cache migration and versioning
./search_metadata.sh "test" /path/to/photos --cache-migrate
./search_metadata.sh "test" /path/to/photos --cache-rollback
./search_metadata.sh "test" /path/to/photos --cache-version
./search_metadata.sh "test" /path/to/photos --cache-validate

# Clear cache
./search_metadata.sh "test" /path/to/photos --cache-clear

# Backup cache
./search_metadata.sh "test" /path/to/photos --cache-backup backup.db

# Restore cache
./search_metadata.sh "test" /path/to/photos --cache-restore backup.db

### Incremental Processing Examples 🆕
```bash
# Process only changed files since last run
./search_metadata.sh "test" /path/to/photos --incremental

# Incremental processing with file type filtering
./search_metadata.sh "test" /path/to/photos --incremental --images-only

# Incremental processing with hash checking for content changes
./search_metadata.sh "test" /path/to/photos --incremental --hash-check

# Track changes and show summary
./search_metadata.sh "test" /path/to/photos --incremental --track-changes

# Incremental processing with cache integration
./search_metadata.sh "test" /path/to/photos --incremental --cache-enabled

# Show change types (new, modified, deleted, content-changed)
./search_metadata.sh "test" /path/to/photos --incremental --change-types
```
```

### Report Examples
```bash
# Basic report
./generate_media_report.sh /path/to/photos

# Detailed report with metadata
./generate_media_report.sh /path/to/photos -d

# Export to multiple formats
./generate_media_report.sh /path/to/photos -j -c --html --markdown

# Filter by date range
./generate_media_report.sh /path/to/photos -D 2023-01-01 -T 2023-12-31

# Images only with size filter
./generate_media_report.sh /path/to/photos --images-only -s 1MB -S 100MB
```

## 🔧 Advanced Features

### GPS and Location Features
```bash
# Search within GPS radius (decimal coordinates)
./search_metadata.sh "iPhone" /path/to/photos --within-radius "37.7749,-122.4194,10"

# Search within GPS radius (DMS coordinates)
./search_metadata.sh "iPhone" /path/to/photos --within-radius "37°46'29.6\"N,-122°25'9.8\"W,5"

# Search within bounding box
./search_metadata.sh "iPhone" /path/to/photos --bounding-box "37.7,37.8,-122.5,-122.4"

# Enable reverse geocoding
./search_metadata.sh "iPhone" /path/to/photos --within-radius "37.7749,-122.4194,10" --reverse-geocode
```

### Device Analysis
```bash
# Show device clustering statistics
./search_metadata.sh "iPhone" /path/to/photos --device-stats

# Find files by device type
./search_metadata.sh "iPhone" /path/to/photos -f "Make" --and "Apple"
```

### Performance Features 🆕
```bash
# Performance benchmarking
./search_metadata.sh "test" /path/to/photos --benchmark

# Memory usage tracking
./search_metadata.sh "iPhone" /path/to/photos --parallel 4 --memory-usage

# Performance report with detailed metrics
./search_metadata.sh "Canon" /path/to/photos --parallel 4 --performance-report

# Batch processing for large directories
./search_metadata.sh "2023" /large/collection --parallel 8 --batch-size 200
```

## 📊 Performance

### Parallel Processing Benchmarks 🆕
- **Small directories (50 files)**: 2-3x faster
- **Medium directories (500 files)**: 4-6x faster
- **Large directories (5000+ files)**: 6-8x faster
- **Memory usage**: Configurable limits prevent OOM
- **CPU utilization**: Optimal worker count auto-detection

### System Requirements
- **Multi-core CPU** (2+ cores recommended for parallel processing)
- **Sufficient RAM** (4GB+ for large directories)
- **exiftool and ffprobe** dependencies

## 🧪 Testing

Run the comprehensive test suite:
```bash
# Install BATS testing framework
npm install -g bats

# Run all tests
./run_tests.sh

# Run specific test categories
bats tests/test_basic.bats
bats tests/test_advanced.bats
bats tests/test_performance_parallel.bats
```

## 📝 Output Formats

### Text Output
```
Found in: /path/to/photo.jpg
  Make: Canon
  Model: EOS R5
  Date/Time Original: 2023:06:15 14:30:25
  GPS Latitude: 37.7749
  GPS Longitude: -122.4194
```

### JSON Output
```json
{
  "search_info": {
    "search_string": "Canon",
    "directory": "/path/to/photos",
    "total_files_processed": 150,
    "files_with_matches": 23
  },
  "results": [
    {
      "file": "/path/to/photo.jpg",
      "type": "image",
      "make": "Canon",
      "model": "EOS R5",
      "date": "2023:06:15 14:30:25"
    }
  ]
}
```

### CSV Output
```csv
File Path,File Type,Search String,Search Field,Match Type,File Size,Last Modified,GPS Latitude,GPS Longitude,Distance (km),Device Type,Device Model,OS Version
/path/to/photo.jpg,image,Canon,Make,exact,2048576,2023-06-15 14:30:25,37.7749,-122.4194,0.0,Camera,EOS R5,
```

## 🤝 Contributing

1. Fork the repository
2. Create a feature branch
3. Make your changes
4. Add tests for new features
5. Run the test suite
6. Submit a pull request

## 📄 License

This project is licensed under the MIT License - see the [LICENSE](LICENSE) file for details.

## 🆕 Version History

### Version 2.10 - Parallel Processing Release
- **Parallel processing** with configurable worker pools
- **Auto-detection** of optimal CPU cores
- **Memory management** with limits and tracking
- **Performance benchmarking** and comparison tools
- **Progress tracking** for large directory processing
- **Comprehensive test suite** with 16 parallel processing tests
- **Integration** with existing search and report functionality

### Version 2.0 - Advanced Features
- Advanced boolean search (AND, OR, NOT)
- Fuzzy matching with configurable threshold
- GPS location filtering and reverse geocoding
- Device clustering and statistics
- Comprehensive test suite with BATS
- Multiple output formats (JSON, CSV, HTML, Markdown, XML)

### Version 1.0 - Core Features
- Basic metadata search in images and videos
- Recursive directory search
- Case-sensitive and case-insensitive search
- Regex pattern matching
- Field-specific search
- Multiple output formats

---

*For more examples and advanced usage, see the `examples/` directory.* 