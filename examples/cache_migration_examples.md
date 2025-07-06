# Cache Migration & Versioning Examples

This document provides comprehensive examples for the cache migration and versioning features in the media metadata search tools.

## 🔄 Cache Migration

### Basic Migration
```bash
# Migrate cache to latest version
./search_metadata.sh "test" /path/to/photos --cache-migrate

# Check migration status
./search_metadata.sh "test" /path/to/photos --cache-migrate --status

# Migrate with backup
./search_metadata.sh "test" /path/to/photos --cache-migrate --backup
```

### Migration with Validation
```bash
# Migrate and validate cache integrity
./search_metadata.sh "test" /path/to/photos --cache-migrate --validate

# Check cache version before migration
./search_metadata.sh "test" /path/to/photos --cache-version

# Migrate specific version
./search_metadata.sh "test" /path/to/photos --cache-migrate --target-version 2.1
```

## 🔙 Cache Rollback

### Basic Rollback
```bash
# Rollback to previous version
./search_metadata.sh "test" /path/to/photos --cache-rollback

# Rollback to specific version
./search_metadata.sh "test" /path/to/photos --cache-rollback --version 2.0

# Check rollback history
./search_metadata.sh "test" /path/to/photos --cache-rollback --history
```

### Rollback with Backup
```bash
# Rollback with automatic backup
./search_metadata.sh "test" /path/to/photos --cache-rollback --backup

# Rollback to specific version with backup
./search_metadata.sh "test" /path/to/photos --cache-rollback --version 2.0 --backup
```

## 📊 Cache Versioning

### Version Information
```bash
# Check current cache version
./search_metadata.sh "test" /path/to/photos --cache-version

# Check version compatibility
./search_metadata.sh "test" /path/to/photos --cache-version --compatibility

# Compare cache versions
./search_metadata.sh "test" /path/to/photos --cache-version --compare
```

### Version Validation
```bash
# Validate cache structure
./search_metadata.sh "test" /path/to/photos --cache-validate

# Validate specific version
./search_metadata.sh "test" /path/to/photos --cache-validate --version 2.1

# Validate with detailed report
./search_metadata.sh "test" /path/to/photos --cache-validate --verbose
```

## 🔧 Advanced Migration Features

### Migration with Options
```bash
# Force migration (skip compatibility checks)
./search_metadata.sh "test" /path/to/photos --cache-migrate --force

# Dry run migration (simulate without changes)
./search_metadata.sh "test" /path/to/photos --cache-migrate --dry-run

# Migrate with progress tracking
./search_metadata.sh "test" /path/to/photos --cache-migrate --progress
```

### Migration Status
```bash
# Check migration status
./search_metadata.sh "test" /path/to/photos --cache-migrate --status

# Get detailed migration info
./search_metadata.sh "test" /path/to/photos --cache-migrate --info

# Check migration history
./search_metadata.sh "test" /path/to/photos --cache-migrate --history
```

## 🛡️ Safety Features

### Backup Before Migration
```bash
# Automatic backup before migration
./search_metadata.sh "test" /path/to/photos --cache-migrate --backup

# Manual backup before migration
./search_metadata.sh "test" /path/to/photos --cache-backup pre_migration.db
./search_metadata.sh "test" /path/to/photos --cache-migrate

# Restore from backup if needed
./search_metadata.sh "test" /path/to/photos --cache-restore pre_migration.db
```

### Validation and Testing
```bash
# Validate cache before migration
./search_metadata.sh "test" /path/to/photos --cache-validate

# Test migration without applying
./search_metadata.sh "test" /path/to/photos --cache-migrate --test

# Validate after migration
./search_metadata.sh "test" /path/to/photos --cache-migrate --validate
```

## 📈 Performance Optimization

### Version-Specific Optimizations
```bash
# Apply version-specific optimizations
./search_metadata.sh "test" /path/to/photos --cache-migrate --optimize

# Check optimization recommendations
./search_metadata.sh "test" /path/to/photos --cache-version --recommendations

# Apply recommended optimizations
./search_metadata.sh "test" /path/to/photos --cache-migrate --apply-recommendations
```

### Migration Performance
```bash
# Monitor migration performance
./search_metadata.sh "test" /path/to/photos --cache-migrate --benchmark

# Compare migration performance
./search_metadata.sh "test" /path/to/photos --cache-migrate --compare-performance

# Get migration performance report
./search_metadata.sh "test" /path/to/photos --cache-migrate --performance-report
```

## 🔍 Troubleshooting

### Migration Issues
```bash
# Check migration logs
./search_metadata.sh "test" /path/to/photos --cache-migrate --logs

# Diagnose migration problems
./search_metadata.sh "test" /path/to/photos --cache-migrate --diagnose

# Repair corrupted cache
./search_metadata.sh "test" /path/to/photos --cache-migrate --repair
```

### Compatibility Issues
```bash
# Check compatibility issues
./search_metadata.sh "test" /path/to/photos --cache-version --compatibility-check

# Resolve compatibility issues
./search_metadata.sh "test" /path/to/photos --cache-migrate --resolve-conflicts

# Force compatibility mode
./search_metadata.sh "test" /path/to/photos --cache-migrate --compatibility-mode
```

## 📋 Complete Workflow Examples

### Standard Migration Workflow
```bash
# 1. Check current version
./search_metadata.sh "test" /path/to/photos --cache-version

# 2. Backup current cache
./search_metadata.sh "test" /path/to/photos --cache-backup pre_migration.db

# 3. Validate cache integrity
./search_metadata.sh "test" /path/to/photos --cache-validate

# 4. Migrate to latest version
./search_metadata.sh "test" /path/to/photos --cache-migrate --backup

# 5. Validate migration
./search_metadata.sh "test" /path/to/photos --cache-validate

# 6. Test functionality
./search_metadata.sh "Canon" /path/to/photos --cache-enabled
```

### Rollback Workflow
```bash
# 1. Check migration history
./search_metadata.sh "test" /path/to/photos --cache-migrate --history

# 2. Backup current state
./search_metadata.sh "test" /path/to/photos --cache-backup before_rollback.db

# 3. Rollback to previous version
./search_metadata.sh "test" /path/to/photos --cache-rollback --backup

# 4. Validate rollback
./search_metadata.sh "test" /path/to/photos --cache-validate

# 5. Test functionality
./search_metadata.sh "Canon" /path/to/photos --cache-enabled
```

### Advanced Migration Workflow
```bash
# 1. Check version compatibility
./search_metadata.sh "test" /path/to/photos --cache-version --compatibility

# 2. Get migration recommendations
./search_metadata.sh "test" /path/to/photos --cache-migrate --recommendations

# 3. Dry run migration
./search_metadata.sh "test" /path/to/photos --cache-migrate --dry-run

# 4. Perform migration with optimizations
./search_metadata.sh "test" /path/to/photos --cache-migrate --optimize --backup

# 5. Apply version-specific optimizations
./search_metadata.sh "test" /path/to/photos --cache-migrate --apply-recommendations

# 6. Validate and test
./search_metadata.sh "test" /path/to/photos --cache-validate
./search_metadata.sh "Canon" /path/to/photos --cache-enabled
```

## 🎯 Best Practices

### Before Migration
- Always backup your cache before migration
- Check version compatibility
- Validate cache integrity
- Test with a small subset of data

### During Migration
- Monitor migration progress
- Check for any errors or warnings
- Validate results after migration
- Test functionality with real searches

### After Migration
- Verify cache integrity
- Test performance improvements
- Monitor for any issues
- Keep backup until confident in migration

### Safety Measures
- Use `--dry-run` to test migrations
- Use `--backup` for automatic backups
- Use `--validate` to check integrity
- Use `--rollback` if issues arise 