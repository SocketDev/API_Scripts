#!/bin/bash

# =============================================================================
# Socket API Testing Script: License Policy Endpoints
# =============================================================================
# 
# SCENARIO: Test license policy management and validation functionality
# 
# This script tests the license policy related endpoints including:
# - License policy validation against packages
# - License metadata retrieval
# - License policy saturation (legacy)
# - Various license policy configurations
# - Error handling for invalid license policies
# - License class expansions (permissive, copyleft, etc.)
# - PURL-based license policy rules
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
    local method="${2:-POST}"
    local data="$3"
    local description="$4"
    
    print_status "Testing: $description"
    
    if [ "$method" = "POST" ]; then
        response=$(curl -s -w "\n%{http_code}" \
            -X POST \
            -H "Authorization: Bearer $SOCKET_API_TOKEN" \
            -H "Content-Type: application/json" \
            -d "$data" \
            "$SOCKET_API_BASE_URL$endpoint")
    else
        response=$(curl -s -w "\n%{http_code}" \
            -X GET \
            -H "Authorization: Bearer $SOCKET_API_TOKEN" \
            "$SOCKET_API_BASE_URL$endpoint")
    fi
    
    # Extract HTTP status code (last line)
    http_code=$(echo "$response" | tail -n1)
    # Extract response body (all lines except last)
    response_body=$(echo "$response" | head -n -1)
    
    if [ "$http_code" -eq 200 ] || [ "$http_code" -eq 201 ]; then
        print_success "HTTP $http_code - $description"
        echo "Response: $response_body" | head -c 200
        echo "..."
    elif [ "$http_code" -eq 429 ]; then
        print_warning "HTTP $http_code - Rate limited. Waiting $RETRY_DELAY_SECONDS seconds..."
        sleep $RETRY_DELAY_SECONDS
    else
        print_error "HTTP $http_code - $description"
        echo "Response: $response_body"
    fi
    
    echo "----------------------------------------"
}

# Main test execution
main() {
    print_status "Starting Socket API License Policy Tests"
    print_status "API Base URL: $SOCKET_API_BASE_URL"
    print_status "Organization: $SOCKET_ORG_SLUG"
    
    # Check environment
    check_env
    
    # Test 1: Basic license policy validation
    print_status "Test 1: Basic license policy validation"
    make_request "/license-policy" "POST" "{\"components\": [{\"purl\": \"$TEST_NPM_PACKAGE\"}], \"allow\": [\"$TEST_LICENSE_ALLOW\"], \"warn\": [\"$TEST_LICENSE_WARN\"]}" "Basic license policy validation"
    
    # Test 2: License policy with license classes
    print_status "Test 2: License policy with license classes"
    make_request "/license-policy" "POST" "{\"components\": [{\"purl\": \"$TEST_NPM_PACKAGE\"}], \"allow\": [\"permissive\"], \"warn\": [\"copyleft\"]}" "License policy with license classes"
    
    # Test 3: License policy with PURL-based rules
    print_status "Test 3: License policy with PURL-based rules"
    make_request "/license-policy" "POST" "{\"components\": [{\"purl\": \"$TEST_NPM_PACKAGE\"}], \"allow\": [\"$TEST_NPM_PACKAGE\"], \"warn\": [\"pkg:npm/lodash?version_glob=4.*\"]}" "License policy with PURL-based rules"
    
    # Test 4: License policy with options
    print_status "Test 4: License policy with options"
    make_request "/license-policy" "POST" "{\"components\": [{\"purl\": \"$TEST_NPM_PACKAGE\"}], \"allow\": [\"$TEST_LICENSE_ALLOW\"], \"options\": [\"toplevelOnly\"]}" "License policy with toplevelOnly option"
    
    # Test 5: License policy with multiple packages
    print_status "Test 5: License policy with multiple packages"
    make_request "/license-policy" "POST" "{\"components\": [{\"purl\": \"$TEST_NPM_PACKAGE\"}, {\"purl\": \"$TEST_PYPI_PACKAGE\"}], \"allow\": [\"$TEST_LICENSE_ALLOW\"], \"warn\": [\"$TEST_LICENSE_WARN\"]}" "License policy with multiple packages"
    
    # Test 6: License metadata retrieval
    print_status "Test 6: License metadata retrieval"
    make_request "/license-metadata" "POST" "[\"$TEST_LICENSE_ALLOW\", \"MIT\", \"GPL-3.0\"]" "License metadata retrieval"
    
    # Test 7: License metadata with text inclusion
    print_status "Test 7: License metadata with text inclusion"
    make_request "/license-metadata?includetext=true" "POST" "[\"$TEST_LICENSE_ALLOW\"]" "License metadata with full text"
    
    # Test 8: License policy saturation (legacy endpoint)
    print_status "Test 8: License policy saturation (legacy)"
    make_request "/saturate-license-policy" "POST" "{\"allowedTiers\": [\"permissive (gold)\"], \"allowedFamilies\": [\"permissive\"], \"allowedApprovalSources\": [\"osi\"]}" "License policy saturation"
    
    # Test 9: License policy with complex tier combinations
    print_status "Test 9: License policy with complex tier combinations"
    make_request "/license-policy" "POST" "{\"components\": [{\"purl\": \"$TEST_NPM_PACKAGE\"}], \"allow\": [\"permissive (silver)\", \"weak copyleft\"], \"warn\": [\"strong copyleft\"]}" "License policy with complex tiers"
    
    # Test 10: License policy with file-based rules
    print_status "Test 10: License policy with file-based rules"
    make_request "/license-policy" "POST" "{\"components\": [{\"purl\": \"$TEST_NPM_PACKAGE\"}], \"allow\": [\"pkg:npm/lodash?file_name=src/**/*&version_glob=4.*\"]}" "License policy with file-based rules"
    
    # Test 11: Error handling - Invalid license identifier
    print_status "Test 11: Error handling - Invalid license identifier"
    make_request "/license-metadata" "POST" "[\"INVALID-LICENSE-ID\"]" "Invalid license identifier test"
    
    # Test 12: Error handling - Empty license policy
    print_status "Test 12: Error handling - Empty license policy"
    make_request "/license-policy" "POST" "{\"components\": []}" "Empty components list test"
    
    # Test 13: Error handling - Invalid PURL in policy
    print_status "Test 13: Error handling - Invalid PURL in policy"
    make_request "/license-policy" "POST" "{\"components\": [{\"purl\": \"$TEST_NPM_PACKAGE\"}], \"allow\": [\"invalid-purl-format\"]}" "Invalid PURL in policy test"
    
    # Test 14: License policy with version glob patterns
    print_status "Test 14: License policy with version glob patterns"
    make_request "/license-policy" "POST" "{\"components\": [{\"purl\": \"$TEST_NPM_PACKAGE\"}], \"allow\": [\"pkg:npm/lodash?version_glob=4.17.*\"], \"warn\": [\"pkg:npm/lodash?version_glob=4.14.*\"]}" "License policy with version glob patterns"
    
    # Test 15: License policy with registry metadata provenance
    print_status "Test 15: License policy with registry metadata provenance"
    make_request "/license-policy" "POST" "{\"components\": [{\"purl\": \"$TEST_NPM_PACKAGE\"}], \"allow\": [\"pkg:npm/lodash?license_provenance=registry_metadata\"]}" "License policy with registry metadata provenance"
    
    print_status "All License Policy endpoint tests completed!"
}

# Run main function
main "$@"
