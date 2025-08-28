# Socket API Testing Suite

A comprehensive collection of bash scripts designed to test the robustness and reliability of the Socket.dev API endpoints. This test suite covers all major API functionality including package analysis, license policy management, security scanning, and SBOM export capabilities.

## 🎯 Purpose

This testing suite is designed for Socket.dev customers who want to:
- **Validate API robustness** - Test how the API handles various scenarios and edge cases
- **Verify error handling** - Ensure proper responses for invalid requests
- **Test rate limiting** - Understand API behavior under different load conditions
- **Validate data integrity** - Ensure responses are consistent and well-formed
- **Test authentication** - Verify proper security controls are in place

## 🏗️ Architecture

The test suite is organized into focused, single-responsibility scripts that can be run individually or as part of a comprehensive test run:

```
socket_api_tests/
├── .env                           # Environment configuration
├── README.md                      # This documentation
├── run_all_tests.sh              # Master test runner
├── 01_test_package_purl_endpoint.sh    # Core package lookup tests
├── 02_test_license_policy.sh           # License policy validation tests
├── 03_test_alert_types.sh              # Alert metadata tests
├── 04_test_full_scans.sh               # Security scanning tests
├── 05_test_repository_management.sh    # Repository management tests
└── 06_test_sbom_export.sh             # SBOM export functionality tests
```

## 🚀 Quick Start

### 1. Prerequisites

- **Bash shell** (macOS, Linux, or WSL)
- **curl** for HTTP requests
- **jq** (optional but recommended for JSON parsing)
- **Socket.dev API token** with appropriate permissions

### 2. Setup

```bash
# Clone or download the test suite
cd socket_api_tests

# Copy and configure the environment file
cp .env.example .env

# Edit .env with your actual values
nano .env
```

### 3. Configuration

Update the `.env` file with your actual Socket.dev credentials:

```bash
# Socket API Configuration
SOCKET_API_BASE_URL=https://api.socket.dev/v0

# Authentication
SOCKET_API_TOKEN=your_actual_api_token_here

# Organization details
SOCKET_ORG_SLUG=your_actual_org_slug

# Test data
TEST_REPO_SLUG=your_test_repository_slug
TEST_BRANCH=main
TEST_COMMIT_HASH=abc123def456

# Sample PURLs for testing
TEST_NPM_PACKAGE=pkg:npm/express@4.19.2
TEST_PYPI_PACKAGE=pkg:pypi/django@5.0.6
TEST_MAVEN_PACKAGE=pkg:maven/log4j/log4j@1.2.17
```

### 4. Run Tests

```bash
# Make scripts executable
chmod +x *.sh

# Run all tests
./run_all_tests.sh

# Or run individual test suites
./01_test_package_purl_endpoint.sh
./02_test_license_policy.sh
# ... etc
```

## 📋 Test Scenarios

### 1. Package PURL Endpoint Tests (`01_test_package_purl_endpoint.sh`)

**Scenario**: Test the core package lookup functionality using PURLs

**Coverage**:
- Basic package lookup for different ecosystems (npm, PyPI, Maven)
- Batch package lookup with multiple packages
- Query parameter variations (alerts, actions, compact, fixable)
- License details and attribution data
- Error handling for invalid PURLs
- Authentication requirements
- Rate limiting behavior

**Key Tests**:
- Single package lookup across ecosystems
- Batch operations with mixed package types
- Parameter combinations and edge cases
- Invalid input handling
- Missing authentication scenarios

### 2. License Policy Tests (`02_test_license_policy.sh`)

**Scenario**: Test license policy management and validation functionality

**Coverage**:
- License policy validation against packages
- License metadata retrieval
- License policy saturation (legacy)
- License class expansions (permissive, copyleft, etc.)
- PURL-based license policy rules
- File-based and version-based rules
- Registry metadata provenance

**Key Tests**:
- Basic license policy validation
- Complex tier combinations
- PURL-based rule configurations
- License metadata with full text
- Error handling for invalid policies

### 3. Alert Types Tests (`03_test_alert_types.sh`)

**Scenario**: Test alert type metadata and information retrieval

**Coverage**:
- Alert type metadata retrieval
- Multi-language support (English, German, French, Spanish, Italian, Acholi)
- Alert type filtering and search
- Alert type properties and suggestions
- Cross-language consistency

**Key Tests**:
- Multi-language alert descriptions
- Single and multiple alert type queries
- Empty and invalid alert type handling
- Public endpoint accessibility
- Large array handling

### 4. Full Scans Tests (`04_test_full_scans.sh`)

**Scenario**: Test full scan creation, management, and reporting functionality

**Coverage**:
- Creating new full scans from manifest files
- Listing and filtering full scans
- Retrieving scan results and metadata
- Integration with various SCM platforms
- File upload handling and validation

**Key Tests**:
- Scan creation with various parameters
- Repository and branch filtering
- Commit and PR information
- Integration type configurations
- Error handling for invalid requests

### 5. Repository Management Tests (`05_test_repository_management.sh`)

**Scenario**: Test repository creation, management, and labeling functionality

**Coverage**:
- Creating new repositories
- Listing and filtering repositories
- Updating repository settings
- Repository labeling and categorization
- Integration with SCM platforms

**Key Tests**:
- Repository CRUD operations
- Label management and associations
- Repository analytics
- Error handling for invalid operations
- GitHub integration

### 6. SBOM Export Tests (`06_test_sbom_export.sh`)

**Scenario**: Test SBOM export functionality in various formats

**Coverage**:
- CycloneDX SBOM export
- SPDX SBOM export
- Custom project metadata
- Vulnerability information inclusion
- File format validation

**Key Tests**:
- Multiple export formats
- Parameter combinations
- File integrity validation
- Error handling for invalid exports
- Custom metadata handling

## 🔧 Customization

### Adding New Test Cases

Each test script follows a consistent pattern. To add new tests:

1. **Identify the endpoint** and add it to the appropriate script
2. **Follow the naming convention**: `Test N: Description`
3. **Use the `make_request` function** for consistent error handling
4. **Add appropriate assertions** for expected responses

Example:
```bash
# Test N: New test case
print_status "Test N: New test case"
make_request "/new/endpoint" "POST" "{\"data\": \"value\"}" "New endpoint test"
```

### Environment Variables

Add new environment variables to `.env`:
```bash
# New test configuration
NEW_TEST_VAR=value
```

### Test Dependencies

If tests have dependencies, update the execution order in `run_all_tests.sh`:
```bash
declare -A test_scripts=(
    ["01_test_package_purl_endpoint.sh"]="Package PURL Endpoint Tests"
    ["02_test_license_policy.sh"]="License Policy Tests"
    ["new_test_script.sh"]="New Test Suite"  # Add here
    # ... etc
)
```

## 📊 Test Results

### Output Format

Tests provide colored, structured output:
- 🔵 **Blue**: Information and status updates
- 🟢 **Green**: Successful operations
- 🟡 **Yellow**: Warnings and rate limiting
- 🔴 **Red**: Errors and failures

### Results Storage

Test results are automatically saved to:
- `test_results/test_run_YYYYMMDD_HHMMSS.txt` - Complete test run log
- `test_results/sbom_exports_YYYYMMDD_HHMMSS/` - Downloaded SBOM files

### Performance Metrics

Each test tracks:
- Execution time
- HTTP status codes
- Response sizes
- Success/failure rates

## 🚨 Error Handling

### Common Issues

1. **Authentication Errors (401)**
   - Verify `SOCKET_API_TOKEN` is correct
   - Check token permissions and expiration

2. **Rate Limiting (429)**
   - Tests automatically wait and retry
   - Adjust `RETRY_DELAY_SECONDS` if needed

3. **Permission Errors (403)**
   - Verify token has required scopes
   - Check organization access

4. **Not Found Errors (404)**
   - Verify `SOCKET_ORG_SLUG` is correct
   - Check if resources exist

### Debugging

Enable verbose output by modifying scripts:
```bash
# Add -v flag to curl commands for verbose output
curl -v -s -w "\n%{http_code}" \
    -H "Authorization: Bearer $SOCKET_API_TOKEN" \
    "$SOCKET_API_BASE_URL$endpoint"
```

## 🔒 Security Considerations

### API Token Security

- **Never commit** `.env` files to version control
- **Use environment-specific** tokens for different environments
- **Rotate tokens** regularly
- **Limit token scopes** to minimum required permissions

### Test Data

- Use **non-production** repositories and data
- **Clean up** test resources after testing
- **Avoid sensitive data** in test manifests

## 📈 Performance Testing

### Load Testing

To test API performance under load:

1. **Modify test scripts** to run multiple iterations
2. **Adjust delays** between requests
3. **Monitor rate limiting** responses
4. **Track response times** and throughput

### Scalability Testing

- Test with **large package lists**
- Verify **batch operation limits**
- Check **memory usage** for large responses
- Test **concurrent request handling**

## 🤝 Contributing

### Adding New Endpoints

When new Socket API endpoints are added:

1. **Create new test script** following naming convention
2. **Add comprehensive test cases** covering:
   - Happy path scenarios
   - Error conditions
   - Edge cases
   - Parameter validation
3. **Update master runner** to include new tests
4. **Document** new test scenarios

### Improving Existing Tests

- **Add more edge cases**
- **Improve error handling**
- **Enhance validation logic**
- **Optimize performance**

## 📚 Additional Resources

- [Socket.dev API Documentation](https://docs.socket.dev/reference)
- [PURL Specification](https://github.com/package-url/purl-spec)
- [CycloneDX Specification](https://cyclonedx.org/specification/)
- [SPDX Specification](https://spdx.dev/specifications/)

## 🆘 Support

For issues with the test suite:

1. **Check the logs** in `test_results/` directory
2. **Verify environment configuration**
3. **Test individual scripts** to isolate issues
4. **Review Socket API documentation** for endpoint changes

---

**Note**: This test suite is designed for Socket.dev customers to validate API robustness. Always test against non-production environments and follow Socket.dev's terms of service and rate limiting guidelines.
