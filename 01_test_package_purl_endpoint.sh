#!/bin/bash

# =============================================================================
# Socket API Testing Script: Package PURL Endpoint
# =============================================================================
# 
# SCENARIO: Test the core package lookup functionality using PURLs
# 
# This script tests the /purl endpoint which is the main entry point for
# looking up package metadata and security alerts. It covers:
# - Basic package lookup for different ecosystems (npm, PyPI, Maven)
# - Batch package lookup
# - Various query parameters (alerts, actions, compact, fixable)
# - Error handling for invalid requests
# - Rate limiting behavior
# - Authentication requirements
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
    print_status "Starting Socket API Package PURL Endpoint Tests"
    print_status "API Base URL: $SOCKET_API_BASE_URL"
    print_status "Organization: $SOCKET_ORG_SLUG"
    
    # Check environment
    check_env
    
    # Test 1: Basic single package lookup (npm)
    print_status "Test 1: Basic npm package lookup"
    make_request "/purl" "POST" "{\"components\": [{\"purl\": \"$TEST_NPM_PACKAGE\"}]}" "Single npm package lookup"
    
    # Test 2: Basic single package lookup (PyPI)
    print_status "Test 2: Basic PyPI package lookup"
    make_request "/purl" "POST" "{\"components\": [{\"purl\": \"$TEST_PYPI_PACKAGE\"}]}" "Single PyPI package lookup"
    
    # Test 3: Basic single package lookup (Maven)
    print_status "Test 3: Basic Maven package lookup"
    make_request "/purl" "POST" "{\"components\": [{\"purl\": \"$TEST_MAVEN_PACKAGE\"}]}" "Single Maven package lookup"
    
    # Test 4: Batch package lookup
    print_status "Test 4: Batch package lookup"
    make_request "/purl" "POST" "{\"components\": [{\"purl\": \"$TEST_NPM_PACKAGE\"}, {\"purl\": \"$TEST_PYPI_PACKAGE\"}, {\"purl\": \"$TEST_MAVEN_PACKAGE\"}]}" "Batch package lookup"
    
    # Test 5: Package lookup with alerts enabled
    print_status "Test 5: Package lookup with alerts enabled"
    make_request "/purl?alerts=true" "POST" "{\"components\": [{\"purl\": \"$TEST_NPM_PACKAGE\"}]}" "Package lookup with alerts metadata"
    
    # Test 6: Package lookup with specific actions filter
    print_status "Test 6: Package lookup with actions filter"
    make_request "/purl?actions=error,monitor" "POST" "{\"components\": [{\"purl\": \"$TEST_NPM_PACKAGE\"}]}" "Package lookup filtered by actions"
    
    # Test 7: Package lookup with compact metadata
    print_status "Test 7: Package lookup with compact metadata"
    make_request "/purl?compact=true" "POST" "{\"components\": [{\"purl\": \"$TEST_NPM_PACKAGE\"}]}" "Package lookup with compact metadata"
    
    # Test 8: Package lookup with fixable alerts only
    print_status "Test 8: Package lookup with fixable alerts only"
    make_request "/purl?fixable=true" "POST" "{\"components\": [{\"purl\": \"$TEST_NPM_PACKAGE\"}]}" "Package lookup with fixable alerts only"
    
    # Test 9: Package lookup with license details
    print_status "Test 9: Package lookup with license details"
    make_request "/purl?licensedetails=true" "POST" "{\"components\": [{\"purl\": \"$TEST_NPM_PACKAGE\"}]}" "Package lookup with license details"
    
    # Test 10: Package lookup with license attribution
    print_status "Test 10: Package lookup with license attribution"
    make_request "/purl?licenseattrib=true" "POST" "{\"components\": [{\"purl\": \"$TEST_NPM_PACKAGE\"}]}" "Package lookup with license attribution"
    
    # Test 11: Error handling - Invalid PURL
    print_status "Test 11: Error handling - Invalid PURL"
    make_request "/purl" "POST" "{\"components\": [{\"purl\": \"invalid-purl-format\"}]}" "Invalid PURL format test"
    
    # Test 12: Error handling - Empty request body
    print_status "Test 12: Error handling - Empty request body"
    make_request "/purl" "POST" "{}" "Empty request body test"
    
    # Test 13: Error handling - Missing authentication
    print_status "Test 13: Error handling - Missing authentication"
    response=$(curl -s -w "\n%{http_code}" \
        -X POST \
        -H "Content-Type: application/json" \
        -d "{\"components\": [{\"purl\": \"$TEST_NPM_PACKAGE\"}]}" \
        "$SOCKET_API_BASE_URL/purl")
    
    http_code=$(echo "$response" | tail -n1)
    response_body=$(echo "$response" | head -n -1)
    
    if [ "$http_code" -eq 401 ]; then
        print_success "HTTP $http_code - Authentication required (expected)"
    else
        print_error "HTTP $http_code - Unexpected response for missing auth"
    fi
    
    print_status "All Package PURL endpoint tests completed!"
}

# Run main function
main "$@"
