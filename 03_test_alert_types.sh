#!/bin/bash

# =============================================================================
# Socket API Testing Script: Alert Types and Metadata
# =============================================================================
# 
# SCENARIO: Test alert type metadata and information retrieval
# 
# This script tests the alert types and metadata endpoints including:
# - Alert type metadata retrieval
# - Multi-language support for alert descriptions
# - Alert type filtering and search
# - Alert type properties and suggestions
# - Error handling for invalid alert types
# - Rate limiting behavior for metadata endpoints
# - Cross-language alert type consistency
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
    print_status "Starting Socket API Alert Types Tests"
    print_status "API Base URL: $SOCKET_API_BASE_URL"
    print_status "Organization: $SOCKET_ORG_SLUG"
    
    # Check environment
    check_env
    
    # Test 1: Basic alert types metadata retrieval
    print_status "Test 1: Basic alert types metadata retrieval"
    make_request "/alert-types" "POST" "[\"malicious-code\", \"vulnerability\", \"license\"]" "Basic alert types metadata"
    
    # Test 2: Alert types with English language (default)
    print_status "Test 2: Alert types with English language (default)"
    make_request "/alert-types?language=en-US" "POST" "[\"malicious-code\", \"vulnerability\"]" "Alert types with English language"
    
    # Test 3: Alert types with German language
    print_status "Test 3: Alert types with German language"
    make_request "/alert-types?language=de-DE" "POST" "[\"malicious-code\"]" "Alert types with German language"
    
    # Test 4: Alert types with French language
    print_status "Test 4: Alert types with French language"
    make_request "/alert-types?language=fr-FR" "POST" "[\"malicious-code\"]" "Alert types with French language"
    
    # Test 5: Alert types with Spanish language
    print_status "Test 5: Alert types with Spanish language"
    make_request "/alert-types?language=es-ES" "POST" "[\"malicious-code\"]" "Alert types with Spanish language"
    
    # Test 6: Alert types with Italian language
    print_status "Test 6: Alert types with Italian language"
    make_request "/alert-types?language=it-IT" "POST" "[\"malicious-code\"]" "Alert types with Italian language"
    
    # Test 7: Alert types with Acholi language
    print_status "Test 7: Alert types with Acholi language"
    make_request "/alert-types?language=ach-UG" "POST" "[\"malicious-code\"]" "Alert types with Acholi language"
    
    # Test 8: Single alert type metadata
    print_status "Test 8: Single alert type metadata"
    make_request "/alert-types" "POST" "[\"malicious-code\"]" "Single alert type metadata"
    
    # Test 9: Multiple alert types in different categories
    print_status "Test 9: Multiple alert types in different categories"
    make_request "/alert-types" "POST" "[\"malicious-code\", \"vulnerability\", \"license\", \"maintenance\", \"security\"]" "Multiple alert types across categories"
    
    # Test 10: Alert types with empty array
    print_status "Test 10: Alert types with empty array"
    make_request "/alert-types" "POST" "[]" "Empty alert types array"
    
    # Test 11: Error handling - Invalid alert type
    print_status "Test 11: Error handling - Invalid alert type"
    make_request "/alert-types" "POST" "[\"invalid-alert-type\"]" "Invalid alert type test"
    
    # Test 12: Error handling - Invalid language parameter
    print_status "Test 12: Error handling - Invalid language parameter"
    make_request "/alert-types?language=invalid-lang" "POST" "[\"malicious-code\"]" "Invalid language parameter test"
    
    # Test 13: Alert types without authentication (should work as it's public)
    print_status "Test 13: Alert types without authentication"
    response=$(curl -s -w "\n%{http_code}" \
        -X POST \
        -H "Content-Type: application/json" \
        -d "[\"malicious-code\"]" \
        "$SOCKET_API_BASE_URL/alert-types")
    
    http_code=$(echo "$response" | tail -n1)
    response_body=$(echo "$response" | head -n -1)
    
    if [ "$http_code" -eq 200 ]; then
        print_success "HTTP $http_code - Public endpoint accessible without auth (expected)"
    else
        print_error "HTTP $http_code - Unexpected response for public endpoint"
    fi
    
    # Test 14: Alert types with mixed valid/invalid types
    print_status "Test 14: Alert types with mixed valid/invalid types"
    make_request "/alert-types" "POST" "[\"malicious-code\", \"invalid-type\", \"vulnerability\"]" "Mixed valid/invalid alert types"
    
    # Test 15: Alert types with very long array
    print_status "Test 15: Alert types with very long array"
    long_array="["
    for i in {1..50}; do
        if [ $i -eq 50 ]; then
            long_array="${long_array}\"malicious-code\""
        else
            long_array="${long_array}\"malicious-code\","
        fi
    done
    long_array="${long_array}]"
    
    make_request "/alert-types" "POST" "$long_array" "Very long alert types array"
    
    print_status "All Alert Types endpoint tests completed!"
}

# Run main function
main "$@"
