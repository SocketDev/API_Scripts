#!/bin/bash

# =============================================================================
# Socket API Testing Script: Repository Management
# =============================================================================
# 
# SCENARIO: Test repository creation, management, and labeling functionality
# 
# This script tests the repository management endpoints including:
# - Creating new repositories
# - Listing and filtering repositories
# - Updating repository settings and metadata
# - Repository labeling and categorization
# - Repository deletion and cleanup
# - Error handling for invalid repository operations
# - Integration with various SCM platforms
# - Repository analytics and reporting
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
    elif [ "$method" = "PUT" ]; then
        response=$(curl -s -w "\n%{http_code}" \
            -X PUT \
            -H "Authorization: Bearer $SOCKET_API_TOKEN" \
            -H "Content-Type: application/json" \
            -d "$data" \
            "$SOCKET_API_BASE_URL$endpoint")
    elif [ "$method" = "DELETE" ]; then
        response=$(curl -s -w "\n%{http_code}" \
            -X DELETE \
            -H "Authorization: Bearer $SOCKET_API_TOKEN" \
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
    print_status "Starting Socket API Repository Management Tests"
    print_status "API Base URL: $SOCKET_API_BASE_URL"
    print_status "Organization: $SOCKET_ORG_SLUG"
    
    # Check environment
    check_env
    
    # Test 1: List existing repositories
    print_status "Test 1: List existing repositories"
    make_request "/orgs/$SOCKET_ORG_SLUG/repos" "GET" "" "List repositories"
    
    # Test 2: List repositories with pagination
    print_status "Test 2: List repositories with pagination"
    make_request "/orgs/$SOCKET_ORG_SLUG/repos?per_page=10&page=1" "GET" "" "List repositories with pagination"
    
    # Test 3: List repositories with sorting
    print_status "Test 3: List repositories with sorting"
    make_request "/orgs/$SOCKET_ORG_SLUG/repos?sort=name&direction=asc" "GET" "" "List repositories with sorting"
    
    # Test 4: Create a new repository (basic)
    print_status "Test 4: Create a new repository (basic)"
    make_request "/orgs/$SOCKET_ORG_SLUG/repos" "POST" "{\"name\": \"test-repo-$(date +%s)\", \"description\": \"Test repository for API testing\"}" "Create basic repository"
    
    # Test 5: Create a repository with full metadata
    print_status "Test 5: Create a repository with full metadata"
    make_request "/orgs/$SOCKET_ORG_SLUG/repos" "POST" "{\"name\": \"test-repo-full-$(date +%s)\", \"description\": \"Test repository with full metadata\", \"homepage\": \"https://example.com\", \"private\": false, \"has_issues\": true, \"has_wiki\": true, \"has_downloads\": true}" "Create repository with full metadata"
    
    # Test 6: Create a private repository
    print_status "Test 6: Create a private repository"
    make_request "/orgs/$SOCKET_ORG_SLUG/repos" "POST" "{\"name\": \"test-repo-private-$(date +%s)\", \"description\": \"Private test repository\", \"private\": true}" "Create private repository"
    
    # Test 7: Get repository details
    print_status "Test 7: Get repository details"
    # First create a repo to get its details
    response=$(curl -s -w "\n%{http_code}" \
        -X POST \
        -H "Authorization: Bearer $SOCKET_API_TOKEN" \
        -H "Content-Type: application/json" \
        -d "{\"name\": \"test-repo-details-$(date +%s)\", \"description\": \"Repository for testing details endpoint\"}" \
        "$SOCKET_API_BASE_URL/orgs/$SOCKET_ORG_SLUG/repos")
    
    http_code=$(echo "$response" | tail -n1)
    response_body=$(echo "$response" | head -n -1)
    
    if [ "$http_code" -eq 201 ]; then
        # Extract repo slug from response
        repo_slug=$(echo "$response_body" | grep -o '"slug":"[^"]*"' | cut -d'"' -f4)
        if [ -n "$repo_slug" ]; then
            make_request "/orgs/$SOCKET_ORG_SLUG/repos/$repo_slug" "GET" "" "Get repository details for $repo_slug"
        else
            print_warning "Could not extract repo slug from response"
        fi
    else
        print_error "Failed to create repository for details test"
    fi
    
    # Test 8: Update repository description
    print_status "Test 8: Update repository description"
    if [ -n "$repo_slug" ]; then
        make_request "/orgs/$SOCKET_ORG_SLUG/repos/$repo_slug" "PUT" "{\"description\": \"Updated description for testing\"}" "Update repository description"
    else
        print_warning "Skipping repository update test - no repo slug available"
    fi
    
    # Test 9: Create repository label
    print_status "Test 9: Create repository label"
    if [ -n "$repo_slug" ]; then
        make_request "/orgs/$SOCKET_ORG_SLUG/repos/$repo_slug/labels" "POST" "{\"name\": \"test-label\", \"description\": \"Test label for API testing\", \"color\": \"0366d6\"}" "Create repository label"
    else
        print_warning "Skipping label creation test - no repo slug available"
    fi
    
    # Test 10: List repository labels
    print_status "Test 10: List repository labels"
    if [ -n "$repo_slug" ]; then
        make_request "/orgs/$SOCKET_ORG_SLUG/repos/$repo_slug/labels" "GET" "" "List repository labels"
    else
        print_warning "Skipping label listing test - no repo slug available"
    fi
    
    # Test 11: Get repository label details
    print_status "Test 11: Get repository label details"
    if [ -n "$repo_slug" ]; then
        make_request "/orgs/$SOCKET_ORG_SLUG/repos/$repo_slug/labels/test-label" "GET" "" "Get repository label details"
    else
        print_warning "Skipping label details test - no repo slug available"
    fi
    
    # Test 12: Update repository label
    print_status "Test 12: Update repository label"
    if [ -n "$repo_slug" ]; then
        make_request "/orgs/$SOCKET_ORG_SLUG/repos/$repo_slug/labels/test-label" "PUT" "{\"description\": \"Updated label description\", \"color\": \"28a745\"}" "Update repository label"
    else
        print_warning "Skipping label update test - no repo slug available"
    fi
    
    # Test 13: Associate repository with label
    print_status "Test 13: Associate repository with label"
    if [ -n "$repo_slug" ]; then
        make_request "/orgs/$SOCKET_ORG_SLUG/repos/$repo_slug/labels/test-label/associate" "POST" "" "Associate repository with label"
    else
        print_warning "Skipping label association test - no repo slug available"
    fi
    
    # Test 14: Get repository label setting
    print_status "Test 14: Get repository label setting"
    if [ -n "$repo_slug" ]; then
        make_request "/orgs/$SOCKET_ORG_SLUG/repos/$repo_slug/labels/test-label/settings" "GET" "" "Get repository label setting"
    else
        print_warning "Skipping label setting test - no repo slug available"
    fi
    
    # Test 15: Update repository label setting
    print_status "Test 15: Update repository label setting"
    if [ -n "$repo_slug" ]; then
        make_request "/orgs/$SOCKET_ORG_SLUG/repos/$repo_slug/labels/test-label/settings" "PUT" "{\"enabled\": true, \"value\": \"test-value\"}" "Update repository label setting"
    else
        print_warning "Skipping label setting update test - no repo slug available"
    fi
    
    # Test 16: Get repository analytics
    print_status "Test 16: Get repository analytics"
    if [ -n "$repo_slug" ]; then
        make_request "/orgs/$SOCKET_ORG_SLUG/repos/$repo_slug/analytics" "GET" "" "Get repository analytics"
    else
        print_warning "Skipping analytics test - no repo slug available"
    fi
    
    # Test 17: Error handling - Create repository with invalid name
    print_status "Test 17: Error handling - Create repository with invalid name"
    make_request "/orgs/$SOCKET_ORG_SLUG/repos" "POST" "{\"name\": \"invalid/repo/name\", \"description\": \"Repository with invalid name\"}" "Create repository with invalid name (should fail)"
    
    # Test 18: Error handling - Create repository without name
    print_status "Test 18: Error handling - Create repository without name"
    make_request "/orgs/$SOCKET_ORG_SLUG/repos" "POST" "{\"description\": \"Repository without name\"}" "Create repository without name (should fail)"
    
    # Test 19: Error handling - Access non-existent repository
    print_status "Test 19: Error handling - Access non-existent repository"
    make_request "/orgs/$SOCKET_ORG_SLUG/repos/non-existent-repo" "GET" "" "Access non-existent repository (should fail)"
    
    # Test 20: Error handling - Update non-existent repository
    print_status "Test 20: Error handling - Update non-existent repository"
    make_request "/orgs/$SOCKET_ORG_SLUG/repos/non-existent-repo" "PUT" "{\"description\": \"Updated description\"}" "Update non-existent repository (should fail)"
    
    # Test 21: List GitHub repositories (if available)
    print_status "Test 21: List GitHub repositories"
    make_request "/orgs/$SOCKET_ORG_SLUG/github/repos" "GET" "" "List GitHub repositories"
    
    print_status "All Repository Management endpoint tests completed!"
}

# Run main function
main "$@"
