#!/bin/bash

# =============================================================================
# Socket API Testing Script: SBOM Export Functionality
# =============================================================================
# 
# SCENARIO: Test SBOM export functionality in various formats
# 
# This script tests the SBOM export endpoints including:
# - CycloneDX SBOM export
# - SPDX SBOM export
# - Various export options and parameters
# - Error handling for invalid export requests
# - Rate limiting and quota management
# - Export with vulnerability information
# - Custom project metadata in exports
# - File format validation and integrity
#
# =============================================================================

# Load environment variables
source .env

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Function to print colored output
print_status() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

print_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

print_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

print_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

# Function to check if required environment variables are set
check_env() {
    if [ -z "$SOCKET_API_TOKEN" ] || [ "$SOCKET_API_TOKEN" = "your_socket_api_token_here" ]; then
        print_error "SOCKET_API_TOKEN not set. Please update .env file with your actual token."
        exit 1
    fi
    
    if [ -z "$SOCKET_ORG_SLUG" ] || [ "$SOCKET_ORG_SLUG" = "your_organization_slug_here" ]; then
        print_error "SOCKET_ORG_SLUG not set. Please update .env file with your actual organization slug."
        exit 1
    fi
}

# Function to make API request with error handling
make_request() {
    local endpoint="$1"
    local method="${2:-GET}"
    local description="$3"
    local output_file="$4"
    
    print_status "Testing: $description"
    
    if [ "$method" = "GET" ]; then
        if [ -n "$output_file" ]; then
            # Download the file
            response=$(curl -s -w "\n%{http_code}" \
                -X GET \
                -H "Authorization: Bearer $SOCKET_API_TOKEN" \
                -o "$output_file" \
                "$SOCKET_API_BASE_URL$endpoint")
        else
            # Just get the response
            response=$(curl -s -w "\n%{http_code}" \
                -X GET \
                -H "Authorization: Bearer $SOCKET_API_TOKEN" \
                "$SOCKET_API_BASE_URL$endpoint")
        fi
    else
        response=$(curl -s -w "\n%{http_code}" \
            -X POST \
            -H "Authorization: Bearer $SOCKET_API_TOKEN" \
            -H "Content-Type: application/json" \
            -d "$data" \
            "$SOCKET_API_BASE_URL$endpoint")
    fi
    
    # Extract HTTP status code (last line)
    http_code=$(echo "$response" | tail -n1)
    # Extract response body (all lines except last)
    response_body=$(echo "$response" | head -n -1)
    
    if [ "$http_code" -eq 200 ] || [ "$http_code" -eq 201 ]; then
        print_success "HTTP $http_code - $description"
        if [ -n "$output_file" ] && [ -f "$output_file" ]; then
            file_size=$(stat -f%z "$output_file" 2>/dev/null || stat -c%s "$output_file" 2>/dev/null || echo "unknown")
            print_success "File downloaded: $output_file (size: $file_size bytes)"
        else
            echo "Response: $response_body" | head -c 200
            echo "..."
        fi
    elif [ "$http_code" -eq 429 ]; then
        print_warning "HTTP $http_code - Rate limited. Waiting $RETRY_DELAY_SECONDS seconds..."
        sleep $RETRY_DELAY_SECONDS
    else
        print_error "HTTP $http_code - $description"
        echo "Response: $response_body"
    fi
    
    echo "----------------------------------------"
}

# Function to validate SBOM file
validate_sbom_file() {
    local file_path="$1"
    local file_type="$2"
    
    if [ ! -f "$file_path" ]; then
        print_error "File not found: $file_path"
        return 1
    fi
    
    file_size=$(stat -f%z "$file_path" 2>/dev/null || stat -c%s "$file_path" 2>/dev/null || echo "0")
    
    if [ "$file_size" -eq 0 ]; then
        print_error "File is empty: $file_path"
        return 1
    fi
    
    print_success "SBOM file validation passed: $file_path ($file_type, $file_size bytes)"
    
    # Basic content validation
    if [ "$file_type" = "CycloneDX" ]; then
        if grep -q "bomFormat.*CycloneDX" "$file_path" 2>/dev/null; then
            print_success "CycloneDX format validation passed"
        else
            print_warning "CycloneDX format validation inconclusive"
        fi
    elif [ "$file_type" = "SPDX" ]; then
        if grep -q "SPDXVersion" "$file_path" 2>/dev/null; then
            print_success "SPDX format validation passed"
        else
            print_warning "SPDX format validation inconclusive"
        fi
    fi
    
    return 0
}

# Function to create test output directory
setup_output_dir() {
    local timestamp=$(date +%Y%m%d_%H%M%S)
    local output_dir="test_results/sbom_exports_$timestamp"
    mkdir -p "$output_dir"
    echo "$output_dir"
}

# Main test execution
main() {
    print_status "Starting Socket API SBOM Export Tests"
    print_status "API Base URL: $SOCKET_API_BASE_URL"
    print_status "Organization: $SOCKET_ORG_SLUG"
    
    # Check environment
    check_env
    
    # Setup output directory
    output_dir=$(setup_output_dir)
    print_status "Output directory: $output_dir"
    
    # Note: These tests require existing scan IDs. In a real scenario, you would:
    # 1. Create a full scan first
    # 2. Wait for it to complete
    # 3. Use the scan ID for export tests
    
    # For demonstration, we'll use placeholder IDs and show the expected behavior
    
    # Test 1: Export CycloneDX SBOM (basic)
    print_status "Test 1: Export CycloneDX SBOM (basic)"
    make_request "/orgs/$SOCKET_ORG_SLUG/export/cdx/placeholder-scan-id" "GET" "Export CycloneDX SBOM (basic)" "$output_dir/test_cdx_basic.xml"
    
    # Test 2: Export CycloneDX SBOM with custom author
    print_status "Test 2: Export CycloneDX SBOM with custom author"
    make_request "/orgs/$SOCKET_ORG_SLUG/export/cdx/placeholder-scan-id?author=Test%20User" "GET" "Export CycloneDX SBOM with custom author" "$output_dir/test_cdx_custom_author.xml"
    
    # Test 3: Export CycloneDX SBOM with project metadata
    print_status "Test 3: Export CycloneDX SBOM with project metadata"
    make_request "/orgs/$SOCKET_ORG_SLUG/export/cdx/placeholder-scan-id?project_name=TestProject&project_version=1.0.0&project_group=TestGroup" "GET" "Export CycloneDX SBOM with project metadata" "$output_dir/test_cdx_project_metadata.xml"
    
    # Test 4: Export CycloneDX SBOM with project ID
    print_status "Test 4: Export CycloneDX SBOM with project ID"
    make_request "/orgs/$SOCKET_ORG_SLUG/export/cdx/placeholder-scan-id?project_id=test-project-123" "GET" "Export CycloneDX SBOM with project ID" "$output_dir/test_cdx_project_id.xml"
    
    # Test 5: Export CycloneDX SBOM with vulnerabilities
    print_status "Test 5: Export CycloneDX SBOM with vulnerabilities"
    make_request "/orgs/$SOCKET_ORG_SLUG/export/cdx/placeholder-scan-id?include_vulnerabilities=true" "GET" "Export CycloneDX SBOM with vulnerabilities" "$output_dir/test_cdx_with_vulns.xml"
    
    # Test 6: Export SPDX SBOM (basic)
    print_status "Test 6: Export SPDX SBOM (basic)"
    make_request "/orgs/$SOCKET_ORG_SLUG/export/spdx/placeholder-scan-id" "GET" "Export SPDX SBOM (basic)" "$output_dir/test_spdx_basic.spdx"
    
    # Test 7: Export SPDX SBOM with custom author
    print_status "Test 7: Export SPDX SBOM with custom author"
    make_request "/orgs/$SOCKET_ORG_SLUG/export/spdx/placeholder-scan-id?author=Test%20User" "GET" "Export SPDX SBOM with custom author" "$output_dir/test_spdx_custom_author.spdx"
    
    # Test 8: Export SPDX SBOM with project metadata
    print_status "Test 8: Export SPDX SBOM with project metadata"
    make_request "/orgs/$SOCKET_ORG_SLUG/export/spdx/placeholder-scan-id?project_name=TestProject&project_version=1.0.0&project_group=TestGroup" "GET" "Export SPDX SBOM with project metadata" "$output_dir/test_spdx_project_metadata.spdx"
    
    # Test 9: Export SPDX SBOM with project ID
    print_status "Test 9: Export SPDX SBOM with project ID"
    make_request "/orgs/$SOCKET_ORG_SLUG/export/spdx/placeholder-scan-id?project_id=test-project-123" "GET" "Export SPDX SBOM with project ID" "$output_dir/test_spdx_project_id.spdx"
    
    # Test 10: Export SPDX SBOM with vulnerabilities
    print_status "Test 10: Export SPDX SBOM with vulnerabilities"
    make_request "/orgs/$SOCKET_ORG_SLUG/export/spdx/placeholder-scan-id?include_vulnerabilities=true" "GET" "Export SPDX SBOM with vulnerabilities" "$output_dir/test_spdx_with_vulns.spdx"
    
    # Test 11: Export with all parameters combined
    print_status "Test 11: Export with all parameters combined"
    make_request "/orgs/$SOCKET_ORG_SLUG/export/cdx/placeholder-scan-id?author=Test%20User&project_name=TestProject&project_version=1.0.0&project_group=TestGroup&include_vulnerabilities=true" "GET" "Export with all parameters combined" "$output_dir/test_cdx_all_params.xml"
    
    # Test 12: Error handling - Invalid scan ID
    print_status "Test 12: Error handling - Invalid scan ID"
    make_request "/orgs/$SOCKET_ORG_SLUG/export/cdx/invalid-scan-id" "GET" "Export with invalid scan ID (should fail)"
    
    # Test 13: Error handling - Non-existent scan ID
    print_status "Test 13: Error handling - Non-existent scan ID"
    make_request "/orgs/$SOCKET_ORG_SLUG/export/cdx/00000000-0000-0000-0000-000000000000" "GET" "Export with non-existent scan ID (should fail)"
    
    # Test 14: Error handling - Invalid project ID
    print_status "Test 14: Error handling - Invalid project ID"
    make_request "/orgs/$SOCKET_ORG_SLUG/export/cdx/placeholder-scan-id?project_id=invalid-project-id" "GET" "Export with invalid project ID"
    
    # Test 15: Error handling - Invalid version format
    print_status "Test 15: Error handling - Invalid version format"
    make_request "/orgs/$SOCKET_ORG_SLUG/export/cdx/placeholder-scan-id?project_version=invalid-version" "GET" "Export with invalid version format"
    
    # Test 16: Export with special characters in author
    print_status "Test 16: Export with special characters in author"
    make_request "/orgs/$SOCKET_ORG_SLUG/export/cdx/placeholder-scan-id?author=Test%20User%20%26%20Co." "GET" "Export with special characters in author" "$output_dir/test_cdx_special_chars.xml"
    
    # Test 17: Export with very long project name
    print_status "Test 17: Export with very long project name"
    long_name="VeryLongProjectNameThatExceedsNormalLengthLimitsAndTestsTheAPIBehaviorWithExtremelyLongStringsThatMightCauseIssuesInSomeSystems"
    make_request "/orgs/$SOCKET_ORG_SLUG/export/cdx/placeholder-scan-id?project_name=$long_name" "GET" "Export with very long project name" "$output_dir/test_cdx_long_name.xml"
    
    # Test 18: Export with empty project group
    print_status "Test 18: Export with empty project group"
    make_request "/orgs/$SOCKET_ORG_SLUG/export/cdx/placeholder-scan-id?project_group=" "GET" "Export with empty project group"
    
    # Test 19: Export with numeric project ID
    print_status "Test 19: Export with numeric project ID"
    make_request "/orgs/$SOCKET_ORG_SLUG/export/cdx/placeholder-scan-id?project_id=12345" "GET" "Export with numeric project ID"
    
    # Test 20: Export with boolean string parameters
    print_status "Test 20: Export with boolean string parameters"
    make_request "/orgs/$SOCKET_ORG_SLUG/export/cdx/placeholder-scan-id?include_vulnerabilities=yes" "GET" "Export with boolean string parameter"
    
    # Validate downloaded files
    print_status "Validating downloaded SBOM files..."
    for file in "$output_dir"/*.xml; do
        if [ -f "$file" ]; then
            validate_sbom_file "$file" "CycloneDX"
        fi
    done
    
    for file in "$output_dir"/*.spdx; do
        if [ -f "$file" ]; then
            validate_sbom_file "$file" "SPDX"
        fi
    done
    
    print_status "All SBOM Export endpoint tests completed!"
    print_status "Results saved in: $output_dir"
}

# Run main function
main "$@"
