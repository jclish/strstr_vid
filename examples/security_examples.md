# Security Examples and Best Practices

This document provides examples of the security features implemented in the Media Metadata Tools and best practices for secure usage.

## 🔒 Security Features

### SQL Injection Prevention

All database operations use parameterized queries to prevent SQL injection attacks:

```bash
# Secure: Parameterized query
sqlite3 "$db_path" "SELECT metadata FROM metadata_cache WHERE file_path = ?;" "$file_path"

# Insecure: String interpolation (fixed)
sqlite3 "$db_path" "SELECT metadata FROM metadata_cache WHERE file_path = '$file_path';"
```

### Command Injection Prevention

Input validation prevents command injection through malicious file paths:

```bash
# Secure: Validated input
./search_metadata.sh "test" /path/to/photos

# Blocked: Malicious input
./search_metadata.sh "test" "/path/to/photos; rm -rf /"
```

### Path Traversal Protection

The system prevents path traversal attacks:

```bash
# Secure: Normal path
./search_metadata.sh "test" /path/to/photos

# Blocked: Path traversal attempt
./search_metadata.sh "test" "/path/to/photos/../../../etc/passwd"
```

### Null Byte Detection

Malicious input with null bytes is detected and blocked:

```bash
# Secure: Normal string
./search_metadata.sh "test" /path/to/photos

# Blocked: Null byte injection
./search_metadata.sh "test\x00" /path/to/photos
```

### Shell Metacharacter Filtering

Dangerous shell characters are filtered from input:

```bash
# Secure: Normal input
./search_metadata.sh "test" /path/to/photos

# Blocked: Shell metacharacters
./search_metadata.sh "test" "/path/to/photos; rm -rf /"
```

## 🛡️ Security Best Practices

### Input Validation

Always validate user input before processing:

```bash
# Good: Validate search string
if ! validate_search_string "$search_string"; then
    echo "Error: Invalid search string"
    exit 1
fi

# Good: Validate directory path
if ! validate_directory_path "$directory"; then
    echo "Error: Invalid directory path"
    exit 1
fi
```

### Temporary File Security

Use secure temporary file handling:

```bash
# Secure: Proper cleanup with trap
temp_file=$(mktemp)
trap 'rm -f "$temp_file"' EXIT

# Process file
process_data "$temp_file"

# Cleanup handled by trap
```

### Error Handling

Implement secure error handling without information disclosure:

```bash
# Good: Generic error message
if [ ! -f "$file" ]; then
    echo "Error: File not found" >&2
    exit 1
fi

# Bad: Information disclosure
if [ ! -f "$file" ]; then
    echo "Error: File '$file' not found" >&2
    exit 1
fi
```

## 🔍 Security Testing

### Test Input Validation

Test that malicious input is properly blocked:

```bash
# Test null byte injection
./search_metadata.sh "test\x00" /path/to/photos
# Should fail with "Error: Search string contains null bytes"

# Test shell metacharacters
./search_metadata.sh "test" "/path/to/photos; rm -rf /"
# Should fail with "Error: Directory path contains shell metacharacters"

# Test path traversal
./search_metadata.sh "test" "/path/to/photos/../../../etc/passwd"
# Should fail with appropriate error
```

### Test SQL Injection Prevention

Verify that database queries are secure:

```bash
# Test with malicious file path containing SQL
./search_metadata.sh "test" "/path/to/file'; DROP TABLE metadata_cache; --"
# Should not execute the DROP TABLE command
```

## 📋 Security Checklist

### Before Deployment

- [ ] All SQL queries use parameterized statements
- [ ] Input validation is implemented for all user inputs
- [ ] Path traversal protection is enabled
- [ ] Null byte detection is working
- [ ] Shell metacharacter filtering is active
- [ ] Temporary files are properly cleaned up
- [ ] Error messages don't disclose sensitive information
- [ ] File permissions are set correctly
- [ ] Logging doesn't expose sensitive data

### During Operation

- [ ] Monitor for unusual access patterns
- [ ] Check logs for security-related errors
- [ ] Validate file permissions regularly
- [ ] Update dependencies for security patches
- [ ] Backup data securely
- [ ] Monitor system resources for anomalies

## 🚨 Security Alerts

### Critical Issues

If you encounter any of these issues, stop using the system immediately:

1. **SQL injection attempts** - Check logs for unusual database queries
2. **Command injection attempts** - Look for shell commands in input
3. **Path traversal attempts** - Monitor for attempts to access system files
4. **Null byte injection** - Check for null bytes in user input
5. **Shell metacharacter injection** - Look for dangerous characters in input

### Response Procedures

1. **Immediate**: Stop the affected process
2. **Investigation**: Check logs and identify the source
3. **Containment**: Block the source IP/user if applicable
4. **Recovery**: Restore from secure backup if necessary
5. **Prevention**: Update security measures as needed

## 📚 Additional Resources

- [OWASP SQL Injection Prevention](https://owasp.org/www-community/attacks/SQL_Injection)
- [OWASP Command Injection](https://owasp.org/www-community/attacks/Command_Injection)
- [OWASP Path Traversal](https://owasp.org/www-community/attacks/Path_Traversal)
- [Bash Security Best Practices](https://mywiki.wooledge.org/BashFAQ/048) 