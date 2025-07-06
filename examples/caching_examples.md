# Caching Examples

This document provides comprehensive examples for using the metadata caching features in the search_metadata.sh script.

## 🚀 Quick Start

### Initialize Cache
```bash
# Initialize cache database
./search_metadata.sh "test" /path/to/photos --cache-init

# Initialize with custom database path
CACHE_DB="/custom/path/cache.db" ./search_metadata.sh "test" /path/to/photos --cache-init
```

### Store Metadata in Cache
```bash
# Store metadata for all files in directory
./search_metadata.sh "test" /path/to/photos --cache-store

# Store with parallel processing
./search_metadata.sh "test" /path/to/photos --cache-store --parallel 4

# Store with compression
./search_metadata.sh "test" /path/to/photos --cache-store --cache-compress
```

### Search with Cache Enabled
```bash
# Search using cached metadata (much faster)
./search_metadata.sh "Canon" /path/to/photos --cache-enabled

# Search with cache and parallel processing
./search_metadata.sh "iPhone" /path/to/photos --cache-enabled --parallel 4

# Search with cache and verbose output
./search_metadata.sh "2023" /path/to/photos --cache-enabled -v
```

## 📊 Cache Management

### Check Cache Status
```bash
# View cache statistics
./search_metadata.sh "test" /path/to/photos --cache-status

# Check cache with custom database
CACHE_DB="/custom/path/cache.db" ./search_metadata.sh "test" /path/to/photos --cache-status
```

### Cache Operations
```bash
# Clear all cached data
./search_metadata.sh "test" /path/to/photos --cache-clear

# Backup cache to file
./search_metadata.sh "test" /path/to/photos --cache-backup backup_2024.db

# Restore cache from backup
./search_metadata.sh "test" /path/to/photos --cache-restore backup_2024.db

# Migrate cache to new version
./search_metadata.sh "test" /path/to/photos --cache-migrate
```

### Cache Configuration
```bash
# Set cache size limit
./search_metadata.sh "test" /path/to/photos --cache-init --cache-size-limit "100MB"

# Enable compression
./search_metadata.sh "test" /path/to/photos --cache-init --cache-compress

# Initialize with both size limit and compression
./search_metadata.sh "test" /path/to/photos --cache-init --cache-size-limit "50MB" --cache-compress
```

## 🔍 Advanced Caching Examples

### Cache with Different Search Types
```bash
# Field-specific search with cache
./search_metadata.sh "Canon" /path/to/photos --cache-enabled -f Make

# Regex search with cache
./search_metadata.sh "Canon|Nikon" /path/to/photos --cache-enabled -R

# Boolean search with cache
./search_metadata.sh "Canon" /path/to/photos --cache-enabled --and "EOS"

# Fuzzy search with cache
./search_metadata.sh "canon" /path/to/photos --cache-enabled --fuzzy

# GPS search with cache
./search_metadata.sh "test" /path/to/photos --cache-enabled --within-radius "37.7749,-122.4194,10"
```

### Cache with Output Formats
```bash
# JSON output with cache
./search_metadata.sh "Canon" /path/to/photos --cache-enabled --json

# CSV output with cache
./search_metadata.sh "Canon" /path/to/photos --cache-enabled --csv

# Multiple formats with cache
./search_metadata.sh "Canon" /path/to/photos --cache-enabled --json --csv
```

### Cache Performance Comparison
```bash
# Benchmark cache performance
./search_metadata.sh "Canon" /path/to/photos --cache-enabled --benchmark

# Compare with and without cache
./search_metadata.sh "test" /path/to/photos --benchmark
./search_metadata.sh "test" /path/to/photos --cache-enabled --benchmark
```

## 🎯 Real-World Scenarios

### Large Photo Collection
```bash
# Initialize cache for large collection
./search_metadata.sh "test" /large/photo/collection --cache-init

# Store metadata with parallel processing
./search_metadata.sh "test" /large/photo/collection --cache-store --parallel 8

# Search with cache (much faster)
./search_metadata.sh "iPhone" /large/photo/collection --cache-enabled --parallel 4
```

### Regular Photo Analysis
```bash
# Weekly cache update
./search_metadata.sh "test" /photos/2024 --cache-store

# Daily searches using cache
./search_metadata.sh "Canon" /photos/2024 --cache-enabled
./search_metadata.sh "iPhone" /photos/2024 --cache-enabled
./search_metadata.sh "vacation" /photos/2024 --cache-enabled
```

### Backup and Restore
```bash
# Backup cache before system update
./search_metadata.sh "test" /path/to/photos --cache-backup cache_backup_$(date +%Y%m%d).db

# Restore cache after system update
./search_metadata.sh "test" /path/to/photos --cache-restore cache_backup_20240115.db
```

## 🔧 Cache Troubleshooting

### Check Cache Database
```bash
# View cache contents
sqlite3 /tmp/metadata_cache.db "SELECT COUNT(*) FROM metadata;"

# Check file types in cache
sqlite3 /tmp/metadata_cache.db "SELECT DISTINCT file_type FROM file_info;"

# View cache statistics
sqlite3 /tmp/metadata_cache.db "SELECT * FROM cache_stats;"
```

### Cache Invalidation
```bash
# Files are automatically invalidated when modified
# You can manually clear cache if needed
./search_metadata.sh "test" /path/to/photos --cache-clear
```

### Performance Monitoring
```bash
# Monitor cache performance
./search_metadata.sh "test" /path/to/photos --cache-status

# Check cache hit rates
./search_metadata.sh "Canon" /path/to/photos --cache-enabled -v
```

## 📈 Performance Benefits

### Typical Performance Improvements
- **First search**: Normal speed (extracting metadata)
- **Subsequent searches**: 5-10x faster (using cached metadata)
- **Large directories**: 10-20x faster for repeated searches
- **Parallel processing**: Additional 2-8x speed improvement

### Memory Usage
- **Cache database**: ~1-5MB per 1000 files
- **Compressed cache**: ~50% reduction in size
- **Size limits**: Prevents unlimited growth

### Best Practices
1. **Initialize cache** before first search
2. **Store metadata** for directories you search frequently
3. **Use parallel processing** for large directories
4. **Monitor cache size** and clear when needed
5. **Backup cache** before system changes
6. **Use compression** for large collections 