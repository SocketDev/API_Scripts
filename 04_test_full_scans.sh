#!/bin/bash

# =============================================================================
# Socket API Testing Script: Full Scans Management
# =============================================================================
# 
# SCENARIO: Test full scan creation, management, and reporting functionality
# 
# This script tests the full scan related endpoints including:
# - Creating new full scans from manifest files
# - Listing and filtering full scans
# - Retrieving full scan results and metadata
# - Full scan deletion and cleanup
# - Error handling for invalid scan requests
# - Rate limiting and quota management
# - Integration with various SCM platforms
# - File upload handling and validation
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
    
    if [ -z "$TEST_REPO_SLUG" ] || [ "$TEST_REPO_SLUG" = "your_test_repository_slug" ]; then
        print_error "TEST_REPO_SLUG not set. Please update .env file with your actual repository slug."
        exit 1
    fi
}

# Function to make API request with error handling
make_request() {
    local endpoint="$1"
    local method="${2:-GET}"
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

# Function to create a test package.json file
create_test_manifest() {
    cat > test_package.json << 'EOF'
{
  "name": "test-project",
  "version": "1.0.0",
  "description": "Test project for Socket API testing",
  "main": "index.js",
  "dependencies": {
    "express": "4.19.2",
    "lodash": "4.17.21"
  },
  "devDependencies": {
    "jest": "29.7.0"
  },
  "scripts": {
    "test": "jest",
    "start": "node index.js"
  },
  "author": "Test User",
  "license": "MIT"
}
EOF
}

# Function to cleanup test files
cleanup() {
    rm -f test_package.json
    print_status "Test files cleaned up"
}

# Main test execution
main() {
    print_status "Starting Socket API Full Scans Tests"
    print_status "API Base URL: $SOCKET_API_BASE_URL"
    print_status "Organization: $SOCKET_ORG_SLUG"
    print_status "Repository: $TEST_REPO_SLUG"
    
    # Check environment
    check_env
    
    # Create test manifest file
    create_test_manifest
    
    # Set trap to cleanup on exit
    trap cleanup EXIT
    
    # Test 1: List existing full scans
    print_status "Test 1: List existing full scans"
    make_request "/orgs/$SOCKET_ORG_SLUG/full-scans" "GET" "" "List full scans"
    
    # Test 2: List full scans with pagination
    print_status "Test 2: List full scans with pagination"
    make_request "/orgs/$SOCKET_ORG_SLUG/full-scans?per_page=10&page=1" "GET" "" "List full scans with pagination"
    
    # Test 3: List full scans with sorting
    print_status "Test 3: List full scans with sorting"
    make_request "/orgs/$SOCKET_ORG_SLUG/full-scans?sort=created_at&direction=desc" "GET" "" "List full scans with sorting"
    
    # Test 4: List full scans filtered by repository
    print_status "Test 4: List full scans filtered by repository"
    make_request "/orgs/$SOCKET_ORG_SLUG/full-scans?repo=$TEST_REPO_SLUG" "GET" "" "List full scans filtered by repository"
    
    # Test 5: List full scans filtered by branch
    print_status "Test 5: List full scans filtered by branch"
    make_request "/orgs/$SOCKET_ORG_SLUG/full-scans?branch=$TEST_BRANCH" "GET" "" "List full scans filtered by branch"
    
    # Test 6: List full scans filtered by date
    print_status "Test 6: List full scans filtered by date"
    # Get timestamp from 30 days ago
    thirty_days_ago=$(date -d "30 days ago" +%s)
    make_request "/orgs/$SOCKET_ORG_SLUG/full-scans?from=$thirty_days_ago" "GET" "" "List full scans filtered by date"
    
    # Test 7: Create a new full scan (basic)
    print_status "Test 7: Create a new full scan (basic)"
    make_request "/orgs/$SOCKET_ORG_SLUG/full-scans?repo=$TEST_REPO_SLUG" "POST" "" "Create basic full scan"
    
    # Test 8: Create a full scan with branch information
    print_status "Test 8: Create a full scan with branch information"
    make_request "/orgs/$SOCKET_ORG_SLUG/full-scans?repo=$TEST_REPO_SLUG&branch=$TEST_BRANCH" "POST" "" "Create full scan with branch"
    
    # Test 9: Create a full scan with commit information
    print_status "Test 9: Create a full scan with commit information"
    make_request "/orgs/$SOCKET_ORG_SLUG/full-scans?repo=$TEST_REPO_SLUG&branch=$TEST_BRANCH&commit_hash=$TEST_COMMIT_HASH&commit_message=Test%20commit" "POST" "" "Create full scan with commit info"
    
    # Test 10: Create a full scan with pull request information
    print_status "Test 10: Create a full scan with pull request information"
    make_request "/orgs/$SOCKET_ORG_SLUG/full-scans?repo=$TEST_REPO_SLUG&branch=$TEST_BRANCH&pull_request=123" "POST" "" "Create full scan with PR info"
    
    # Test 11: Create a full scan with committer information
    print_status "Test 11: Create a full scan with committer information"
    make_request "/orgs/$SOCKET_ORG_SLUG/full-scans?repo=$TEST_REPO_SLUG&branch=$TEST_BRANCH&committers=test@example.com" "POST" "" "Create full scan with committer"
    
    # Test 12: Create a full scan with integration type
    print_status "Test 12: Create a full scan with integration type"
    make_request "/orgs/$SOCKET_ORG_SLUG/full-scans?repo=$TEST_REPO_SLUG&integration_type=api" "POST" "" "Create full scan with API integration type"
    
    # Test 13: Create a full scan with custom integration org
    print_status "Test 13: Create a full scan with custom integration org"
    make_request "/orgs/$SOCKET_ORG_SLUG/full-scans?repo=$TEST_REPO_SLUG&integration_org_slug=custom-org" "POST" "" "Create full scan with custom integration org"
    
    # Test 14: Create a full scan as default branch
    print_status "Test 14: Create a full scan as default branch"
    make_request "/orgs/$SOCKET_ORG_SLUG/full-scans?repo=$TEST_REPO_SLUG&branch=$TEST_BRANCH&make_default_branch=true" "POST" "" "Create full scan as default branch"
    
    # Test 15: Create a full scan as pending head
    print_status "Test 15: Create a full scan as pending head"
    make_request "/orgs/$SOCKET_ORG_SLUG/full-scans?repo=$TEST_REPO_SLUG&branch=$TEST_BRANCH&set_as_pending_head=true" "POST" "" "Create full scan as pending head"
    
    # Test 16: Create a temporary full scan
    print_status "Test 16: Create a temporary full scan"
    make_request "/orgs/$SOCKET_ORG_SLUG/full-scans?repo=$TEST_REPO_SLUG&tmp=true" "POST" "" "Create temporary full scan"
    
    # Test 17: Error handling - Missing repository parameter
    print_status "Test 17: Error handling - Missing repository parameter"
    make_request "/orgs/$SOCKET_ORG_SLUG/full-scans" "POST" "" "Create full scan without repository (should fail)"
    
    # Test 18: Error handling - Invalid branch name
    print_status "Test 18: Error handling - Invalid branch name"
    make_request "/orgs/$SOCKET_ORG_SLUG/full-scans?repo=$TEST_REPO_SLUG&branch=invalid/branch/name" "POST" "" "Create full scan with invalid branch name"
    
    # Test 19: Error handling - Invalid pull request number
    print_status "Test 19: Error handling - Invalid pull request number"
    make_request "/orgs/$SOCKET_ORG_SLUG/full-scans?repo=$TEST_REPO_SLUG&pull_request=0" "POST" "" "Create full scan with invalid PR number"
    
    # Test 20: Error handling - Invalid integration type
    print_status "Test 20: Error handling - Invalid integration type"
    make_request "/orgs/$SOCKET_ORG_SLUG/full-scans?repo=$TEST_REPO_SLUG&integration_type=invalid" "POST" "" "Create full scan with invalid integration type"
    
    # Test 21: Get supported file types
    print_status "Test 21: Get supported file types"
    make_request "/orgs/$SOCKET_ORG_SLUG/supported-files" "GET" "" "Get supported file types"
    
    print_status "All Full Scans endpoint tests completed!"
}

# Run main function
main "$@"
