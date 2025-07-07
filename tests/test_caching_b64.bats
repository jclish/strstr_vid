#!/usr/bin/env bats

setup() {
  export TEST_CACHE_DB="test_b64_cache.db"
  rm -f "$TEST_CACHE_DB"
  source ./lib/caching.sh
  init_cache_database "$TEST_CACHE_DB"
}

teardown() {
  rm -f "$TEST_CACHE_DB"
}

@test "store and retrieve metadata with newlines and quotes" {
  local file="/tmp/testfile1.jpg"
  local metadata='Line1
Line2 with "quotes" and special chars: $&*()[]{}'
  store_metadata_in_cache "$file" "$metadata" "$TEST_CACHE_DB"
  local retrieved=$(get_cached_metadata "$file" "$TEST_CACHE_DB")
  [ "$retrieved" = "$metadata" ]
}

@test "store and retrieve metadata with unicode and multi-line" {
  local file="/tmp/testfile2.jpg"
  local metadata='Unicode: café
Emoji: 😀
Multiline
Another line'
  store_metadata_in_cache "$file" "$metadata" "$TEST_CACHE_DB"
  local retrieved=$(get_cached_metadata "$file" "$TEST_CACHE_DB")
  [ "$retrieved" = "$metadata" ]
} 