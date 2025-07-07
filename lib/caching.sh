#!/bin/bash

# lib/caching.sh - Shared caching functions
# This library provides common functions for metadata caching operations

# Default cache database path
CACHE_DB="${CACHE_DB:-$HOME/.search_metadata_cache.db}"

# Helper: Base64 encode
b64_encode() {
    base64 | tr -d '\n'
}

# Helper: Base64 decode
b64_decode() {
    base64 --decode
}

# Function to initialize cache database
init_cache_database() {
    local cache_db="${1:-$CACHE_DB}"
    
    # Create cache directory if it doesn't exist
    local cache_dir=$(dirname "$cache_db")
    mkdir -p "$cache_dir"
    
    # Initialize SQLite database
    sqlite3 "$cache_db" << 'EOF'
CREATE TABLE IF NOT EXISTS metadata_cache (
    file_path TEXT PRIMARY KEY,
    metadata TEXT,
    file_size INTEGER,
    file_hash TEXT,
    modified_time INTEGER,
    file_type TEXT,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    accessed_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

CREATE TABLE IF NOT EXISTS cache_stats (
    key TEXT PRIMARY KEY,
    value TEXT,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

CREATE INDEX IF NOT EXISTS idx_metadata_cache_file_path ON metadata_cache(file_path);
CREATE INDEX IF NOT EXISTS idx_metadata_cache_file_type ON metadata_cache(file_type);
CREATE INDEX IF NOT EXISTS idx_metadata_cache_created_at ON metadata_cache(created_at);
CREATE INDEX IF NOT EXISTS idx_metadata_cache_accessed_at ON metadata_cache(accessed_at);
EOF
    
    echo "Cache database initialized: $cache_db"
}

# Function to store metadata in cache
store_metadata_in_cache() {
    local file="$1"
    local metadata="$2"
    local cache_db="${3:-$CACHE_DB}"
    
    # Base64 encode metadata to avoid SQL issues
    local metadata_b64=$(echo "$metadata" | b64_encode)
    
    printf "INSERT OR REPLACE INTO metadata_cache (file_path, metadata, accessed_at) VALUES ('%s', '%s', CURRENT_TIMESTAMP);\n" "$file" "$metadata_b64" | sqlite3 "$cache_db"
}

# Function to retrieve metadata from cache
get_cached_metadata() {
    local file="$1"
    local cache_db="${2:-$CACHE_DB}"
    
    local metadata_b64=$(sqlite3 "$cache_db" << EOF
SELECT metadata FROM metadata_cache WHERE file_path = '$file';
EOF
)
    if [ -n "$metadata_b64" ]; then
        echo "$metadata_b64" | b64_decode
    fi
}

# Function to retrieve metadata from legacy cache table
get_legacy_cached_metadata() {
    local file="$1"
    local cache_db="${2:-$CACHE_DB}"
    
    local metadata_json=$(sqlite3 "$cache_db" << EOF
SELECT metadata_json FROM metadata WHERE file_path = '$file';
EOF
)
    if [ -n "$metadata_json" ]; then
        echo "$metadata_json"
    fi
}

# Function to check if file is cached
is_file_cached() {
    local file="$1"
    local cache_db="${2:-$CACHE_DB}"
    
    local result=$(sqlite3 "$cache_db" << EOF
SELECT COUNT(*) FROM metadata_cache WHERE file_path = '$file';
EOF
)
    
    [ "$result" -gt 0 ]
}

# Function to store file info in cache
store_file_info() {
    local file="$1"
    local file_size="$2"
    local file_hash="$3"
    local modified_time="$4"
    local file_type="$5"
    local cache_db="${6:-$CACHE_DB}"
    
    sqlite3 "$cache_db" << EOF
UPDATE metadata_cache 
SET file_size = $file_size, 
    file_hash = '$file_hash', 
    modified_time = $modified_time, 
    file_type = '$file_type'
WHERE file_path = '$file';
EOF
}

# Function to get cached modified time
get_cached_modified_time() {
    local file="$1"
    local cache_db="${2:-$CACHE_DB}"
    
    sqlite3 "$cache_db" << EOF
SELECT modified_time FROM metadata_cache WHERE file_path = '$file';
EOF
}

# Function to invalidate cache entry
invalidate_cache_entry() {
    local file="$1"
    local cache_db="${2:-$CACHE_DB}"
    
    sqlite3 "$cache_db" << EOF
DELETE FROM metadata_cache WHERE file_path = '$file';
EOF
}

# Function to clear all cache
clear_cache() {
    local cache_db="${1:-$CACHE_DB}"
    
    sqlite3 "$cache_db" << EOF
DELETE FROM metadata_cache;
DELETE FROM cache_stats;
EOF
    
    echo "Cache cleared: $cache_db"
}

# Function to get cache statistics
get_cache_stats() {
    local cache_db="${1:-$CACHE_DB}"
    
    local total_entries=$(sqlite3 "$cache_db" << EOF
SELECT COUNT(*) FROM metadata_cache;
EOF
)
    
    local cache_size=$(sqlite3 "$cache_db" << EOF
SELECT SUM(LENGTH(metadata)) FROM metadata_cache;
EOF
)
    
    local oldest_entry=$(sqlite3 "$cache_db" << EOF
SELECT MIN(created_at) FROM metadata_cache;
EOF
)
    
    local newest_entry=$(sqlite3 "$cache_db" << EOF
SELECT MAX(created_at) FROM metadata_cache;
EOF
)
    
    echo "Cache Statistics:"
    echo "  Total entries: $total_entries"
    echo "  Cache size: ${cache_size:-0} bytes"
    echo "  Oldest entry: ${oldest_entry:-N/A}"
    echo "  Newest entry: ${newest_entry:-N/A}"
}

# Function to backup cache
backup_cache() {
    local backup_file="$1"
    local cache_db="${2:-$CACHE_DB}"
    
    if [ -f "$cache_db" ]; then
        cp "$cache_db" "$backup_file"
        echo "Cache backed up to: $backup_file"
    else
        echo "No cache database found to backup"
        return 1
    fi
}

# Function to restore cache
restore_cache() {
    local backup_file="$1"
    local cache_db="${2:-$CACHE_DB}"
    
    if [ -f "$backup_file" ]; then
        cp "$backup_file" "$cache_db"
        echo "Cache restored from: $backup_file"
    else
        echo "Backup file not found: $backup_file"
        return 1
    fi
}

# Function to check cache health
check_cache_health() {
    local cache_db="${1:-$CACHE_DB}"
    
    if [ ! -f "$cache_db" ]; then
        echo "Cache database not found: $cache_db"
        return 1
    fi
    
    # Check database integrity
    local integrity_check=$(sqlite3 "$cache_db" "PRAGMA integrity_check;" 2>/dev/null)
    if [ "$integrity_check" != "ok" ]; then
        echo "Cache database corruption detected"
        return 1
    fi
    
    echo "Cache database is healthy: $cache_db"
    return 0
}

# Function to get cache size in human readable format
get_cache_size_human() {
    local cache_db="${1:-$CACHE_DB}"
    
    if [ ! -f "$cache_db" ]; then
        echo "0B"
        return
    fi
    
    local size_bytes=$(stat -f%z "$cache_db" 2>/dev/null || stat -c%s "$cache_db" 2>/dev/null || echo "0")
    
    if [ "$size_bytes" -gt 1073741824 ]; then
        echo "$(echo "scale=1; $size_bytes / 1073741824" | bc)GB"
    elif [ "$size_bytes" -gt 1048576 ]; then
        echo "$(echo "scale=1; $size_bytes / 1048576" | bc)MB"
    elif [ "$size_bytes" -gt 1024 ]; then
        echo "$(echo "scale=1; $size_bytes / 1024" | bc)KB"
    else
        echo "${size_bytes}B"
    fi
} 