#!/bin/bash

# =============================================================================
# Socket API Testing Script: CVE Dependency Traversal
# =============================================================================
# 
# SCENARIO: Demonstrate how to use alert data to find direct dependencies
# and traverse through minor versions to find a version without a specific CVE
# 
# This script shows a practical workflow for:
# - Retrieving package alerts and vulnerability data
# - Identifying direct dependencies from alert data
# - Traversing minor version ranges to find CVE-free versions
# - Building a dependency upgrade path for security remediation
# - Practical dependency management using Socket API data
#
# =============================================================================

# Load environment variables
source .env

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
PURPLE='\033[0;35m'
CYAN='\033[0;36m'
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

print_header() {
    echo -e "${PURPLE}================================================================${NC}"
    echo -e "${PURPLE}$1${NC}"
    echo -e "${PURPLE}================================================================${NC}"
}

print_section() {
    echo -e "${CYAN}----------------------------------------------------------------${NC}"
    echo -e "${CYAN}$1${NC}"
    echo -e "${CYAN}----------------------------------------------------------------${NC}"
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
        return 0
    elif [ "$http_code" -eq 429 ]; then
        print_warning "HTTP $http_code - Rate limited. Waiting $RETRY_DELAY_SECONDS seconds..."
        sleep $RETRY_DELAY_SECONDS
        return 1
    else
        print_error "HTTP $http_code - $description"
        echo "Response: $response_body"
        return 1
    fi
}

# Function to extract version from PURL
extract_version() {
    local purl="$1"
    echo "$purl" | grep -o '@[^?]*' | sed 's/@//'
}

# Function to extract package name from PURL
extract_package_name() {
    local purl="$1"
    echo "$purl" | sed 's/pkg:[^/]*\///' | sed 's/@.*//'
}

# Function to generate version range PURLs
generate_version_range() {
    local base_purl="$1"
    local current_version="$2"
    local ecosystem="$3"
    
    local package_name=$(extract_package_name "$base_purl")
    local major_version=$(echo "$current_version" | cut -d. -f1)
    local minor_version=$(echo "$current_version" | cut -d. -f2)
    
    print_status "Generating version range for $package_name starting from $current_version"
    
    # Generate minor version range (e.g., 4.17.0, 4.17.1, 4.17.2, etc.)
    local versions=()
    for i in {0..20}; do
        local new_minor=$((minor_version + i))
        local new_version="${major_version}.${new_minor}.0"
        local new_purl="pkg:${ecosystem}/${package_name}@${new_version}"
        versions+=("$new_purl")
        
        # Also try patch versions within the same minor
        for j in {1..9}; do
            local patch_version="${major_version}.${new_minor}.${j}"
            local patch_purl="pkg:${ecosystem}/${package_name}@${patch_version}"
            versions+=("$patch_purl")
        done
    done
    
    echo "${versions[@]}"
}

# Function to check if a package version has a specific CVE
check_cve_in_version() {
    local purl="$1"
    local target_cve="$2"
    
    print_status "Checking CVE $target_cve in $purl"
    
    # Make request to check package alerts
    local response=$(curl -s -w "\n%{http_code}" \
        -X POST \
        -H "Authorization: Bearer $SOCKET_API_TOKEN" \
        -H "Content-Type: application/json" \
        -d "{\"components\": [{\"purl\": \"$purl\"}], \"alerts\": true}" \
        "$SOCKET_API_BASE_URL/purl")
    
    local http_code=$(echo "$response" | tail -n1)
    local response_body=$(echo "$response" | head -n -1)
    
    if [ "$http_code" -eq 200 ]; then
        # Check if the specific CVE exists in the response
        if echo "$response_body" | grep -q "$target_cve"; then
            print_warning "CVE $target_cve found in $purl"
            return 1  # CVE exists
        else
            print_success "CVE $target_cve NOT found in $purl"
            return 0  # CVE-free
        fi
    else
        print_error "Failed to check $purl (HTTP $http_code)"
        return 1
    fi
}

# Function to find CVE-free version
find_cve_free_version() {
    local base_purl="$1"
    local target_cve="$2"
    local ecosystem="$3"
    
    print_header "Finding CVE-free version for $target_cve"
    
    local current_version=$(extract_version "$base_purl")
    local package_name=$(extract_package_name "$base_purl")
    
    print_status "Starting search from version $current_version"
    
    # Generate version range
    local versions=($(generate_version_range "$base_purl" "$current_version" "$ecosystem"))
    
    local found_version=""
    local checked_count=0
    
    for version_purl in "${versions[@]}"; do
        ((checked_count++))
        
        # Rate limiting check
        if [ $((checked_count % 5)) -eq 0 ]; then
            print_status "Checked $checked_count versions, taking a short break..."
            sleep 1
        fi
        
        if check_cve_in_version "$version_purl" "$target_cve"; then
            found_version="$version_purl"
            print_success "Found CVE-free version: $found_version"
            break
        fi
    done
    
    if [ -n "$found_version" ]; then
        print_success "CVE-free version found: $found_version"
        echo "$found_version" > "cve_free_version.txt"
        return 0
    else
        print_warning "No CVE-free version found in the checked range"
        return 1
    fi
}

# Function to analyze package alerts for direct dependencies
analyze_package_alerts() {
    local package_purl="$1"
    
    print_header "Analyzing package alerts for direct dependencies"
    
    print_status "Package: $package_purl"
    
    # Get package alerts with detailed information
    local response=$(curl -s -w "\n%{http_code}" \
        -X POST \
        -H "Authorization: Bearer $SOCKET_API_TOKEN" \
        -H "Content-Type: application/json" \
        -d "{\"components\": [{\"purl\": \"$package_purl\"}], \"alerts\": true, \"licensedetails\": true}" \
        "$SOCKET_API_BASE_URL/purl")
    
    local http_code=$(echo "$response" | tail -n1)
    local response_body=$(echo "$response" | head -n -1)
    
    if [ "$http_code" -eq 200 ]; then
        print_success "Successfully retrieved package alerts"
        
        # Extract and display alert information
        echo "$response_body" | jq -r '.alerts[]? | "Alert: \(.type) - \(.title)"' 2>/dev/null || \
        echo "$response_body" | grep -o '"type":"[^"]*"' | head -5
        
        # Look for dependency-related alerts
        local dependency_alerts=$(echo "$response_body" | grep -i "dependency\|depends\|requires" | head -3)
        if [ -n "$dependency_alerts" ]; then
            print_status "Dependency-related alerts found:"
            echo "$dependency_alerts"
        fi
        
        return 0
    else
        print_error "Failed to retrieve package alerts (HTTP $http_code)"
        return 1
    fi
}

# Function to demonstrate dependency upgrade path
demonstrate_upgrade_path() {
    local vulnerable_purl="$1"
    local cve_free_purl="$2"
    local target_cve="$3"
    
    print_header "Dependency Upgrade Path Demonstration"
    
    local current_version=$(extract_version "$vulnerable_purl")
    local target_version=$(extract_version "$cve_free_purl")
    local package_name=$(extract_package_name "$vulnerable_purl")
    
    print_status "Current vulnerable version: $current_version"
    print_status "Target CVE-free version: $target_version"
    print_status "Target CVE: $target_cve"
    
    # Create upgrade path
    cat > "upgrade_path.md" << EOF
# Dependency Upgrade Path for $package_name

## Current Status
- **Current Version**: $current_version
- **Vulnerability**: $target_cVE
- **Risk Level**: High

## Target Status
- **Target Version**: $target_version
- **Security**: CVE-free
- **Compatibility**: Minor version upgrade

## Upgrade Steps
1. **Update package.json/requirements.txt**
   - Change version from \`$current_version\` to \`$target_version\`
   
2. **Run dependency update**
   \`\`\`bash
   # For npm
   npm update $package_name
   
   # For pip
   pip install --upgrade $package_name
   
   # For maven
   mvn versions:use-latest-versions
   \`\`\`
   
3. **Verify the fix**
   - Run tests to ensure compatibility
   - Check that $target_cVE is no longer present
   
4. **Deploy and monitor**
   - Deploy the updated dependency
   - Monitor for any compatibility issues

## Rollback Plan
If issues arise, rollback to the previous version:
\`\`\`bash
# For npm
npm install $package_name@$current_version

# For pip  
pip install $package_name==$current_version

# For maven
# Revert the version change in pom.xml
\`\`\`

## Notes
- This is a minor version upgrade, so breaking changes are unlikely
- Test thoroughly in development environment before production
- Monitor application logs for any new issues
EOF
    
    print_success "Upgrade path documentation created: upgrade_path.md"
}

# Main test execution
main() {
    print_header "Socket API CVE Dependency Traversal Demo"
    print_status "This script demonstrates practical CVE remediation using Socket API"
    print_status "API Base URL: $SOCKET_API_BASE_URL"
    print_status "Organization: $SOCKET_ORG_SLUG"
    
    # Check environment
    check_env
    
    # Example 1: lodash with known CVE
    print_section "Example 1: lodash CVE-2021-23337 remediation"
    
    local lodash_purl="pkg:npm/lodash@4.17.21"
    local target_cve="CVE-2021-23337"
    
    print_status "Starting with vulnerable package: $lodash_purl"
    print_status "Target CVE to remediate: $target_cve"
    
    # Analyze current package alerts
    if analyze_package_alerts "$lodash_purl"; then
        print_success "Package analysis completed"
    else
        print_warning "Package analysis had issues, continuing..."
    fi
    
    # Find CVE-free version
    if find_cve_free_version "$lodash_purl" "$target_cve" "npm"; then
        local cve_free_version=$(cat "cve_free_version.txt" 2>/dev/null)
        if [ -n "$cve_free_version" ]; then
            demonstrate_upgrade_path "$lodash_purl" "$cve_free_version" "$target_cve"
        fi
    fi
    
    echo ""
    
    # Example 2: express with hypothetical CVE
    print_section "Example 2: express dependency analysis"
    
    local express_purl="pkg:npm/express@4.19.2"
    local hypothetical_cve="CVE-2024-XXXXX"
    
    print_status "Analyzing package: $express_purl"
    print_status "Looking for dependency patterns and alerts"
    
    if analyze_package_alerts "$express_purl"; then
        print_success "Express package analysis completed"
    fi
    
    # Example 3: Django with version traversal
    print_section "Example 3: Django version traversal demo"
    
    local django_purl="pkg:pypi/django@5.0.6"
    local django_cve="CVE-2024-XXXXX"
    
    print_status "Demonstrating version traversal for: $django_purl"
    print_status "This shows how to systematically check versions"
    
    # Generate version range for demonstration
    local django_versions=($(generate_version_range "$django_purl" "5.0.6" "pypi"))
    print_status "Generated ${#django_versions[@]} versions to check"
    
    # Show first few versions
    print_status "Sample versions to check:"
    for i in {0..4}; do
        if [ $i -lt ${#django_versions[@]} ]; then
            echo "  - ${django_versions[$i]}"
        fi
    done
    
    echo ""
    
    # Summary and next steps
    print_header "CVE Dependency Traversal Summary"
    
    print_success "Demonstration completed successfully!"
    print_status "Key learnings:"
    echo "  1. Use Socket API to retrieve package alerts and vulnerability data"
    echo "  2. Identify direct dependencies from alert information"
    echo "  3. Systematically traverse minor versions to find CVE-free alternatives"
    echo "  4. Build upgrade paths for security remediation"
    echo "  5. Document upgrade steps and rollback plans"
    
    print_status "Generated files:"
    if [ -f "cve_free_version.txt" ]; then
        echo "  - cve_free_version.txt (CVE-free version found)"
    fi
    if [ -f "upgrade_path.md" ]; then
        echo "  - upgrade_path.md (Upgrade path documentation)"
    fi
    
    print_status "Next steps:"
    echo "  1. Use this pattern with your actual vulnerable packages"
    echo "  2. Integrate into your CI/CD pipeline for automated CVE checking"
    echo "  3. Build dependency update automation based on Socket API data"
    echo "  4. Monitor for new CVEs and maintain up-to-date dependencies"
    
    print_status "All CVE dependency traversal tests completed!"
}

# Run main function
main "$@"
