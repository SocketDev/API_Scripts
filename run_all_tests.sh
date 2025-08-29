#!/bin/bash

# =============================================================================
# Socket API Comprehensive Test Suite Runner
# =============================================================================
# 
# SCENARIO: Master script to run all Socket API test scenarios
# 
# This script orchestrates the execution of all test scripts in the proper order:
# 1. Package PURL endpoint tests
# 2. License policy tests
# 3. Alert types tests
# 4. Full scans tests
# 5. Repository management tests
# 6. SBOM export tests
#
# It provides:
# - Sequential execution with proper dependencies
# - Comprehensive error reporting
# - Test result aggregation
# - Performance metrics
# - Cleanup and reporting
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

# Test results tracking
declare -A test_results
declare -A test_durations
total_tests=0
passed_tests=0
failed_tests=0

# Function to print colored output
print_header() {
    echo -e "${PURPLE}================================================================${NC}"
    echo -e "${PURPLE}$1${NC}"
    echo -e "${PURPLE}================================================================${NC}"
}

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

print_section() {
    echo -e "${CYAN}----------------------------------------------------------------${NC}"
    echo -e "${CYAN}$1${NC}"
    echo -e "${CYAN}----------------------------------------------------------------${NC}"
}

# Function to check if required environment variables are set
check_env() {
    print_status "Checking environment configuration..."
    
    local missing_vars=()
    
    if [ -z "$SOCKET_API_TOKEN" ] || [ "$SOCKET_API_TOKEN" = "your_socket_api_token_here" ]; then
        missing_vars+=("SOCKET_API_TOKEN")
    fi
    
    if [ -z "$SOCKET_ORG_SLUG" ] || [ "$SOCKET_ORG_SLUG" = "your_organization_slug_here" ]; then
        missing_vars+=("SOCKET_ORG_SLUG")
    fi
    
    if [ -z "$TEST_REPO_SLUG" ] || [ "$TEST_REPO_SLUG" = "your_test_repository_slug" ]; then
        missing_vars+=("TEST_REPO_SLUG")
    fi
    
    if [ ${#missing_vars[@]} -gt 0 ]; then
        print_error "Missing or invalid environment variables:"
        for var in "${missing_vars[@]}"; do
            echo "  - $var"
        done
        echo ""
        print_error "Please update the .env file with your actual values before running tests."
        exit 1
    fi
    
    print_success "Environment configuration validated"
}

# Function to check if test script exists and is executable
check_test_script() {
    local script_path="$1"
    local script_name="$2"
    
    if [ ! -f "$script_path" ]; then
        print_error "Test script not found: $script_path"
        return 1
    fi
    
    if [ ! -x "$script_path" ]; then
        print_warning "Making test script executable: $script_path"
        chmod +x "$script_path"
    fi
    
    return 0
}

# Function to run a test script and track results
run_test_script() {
    local script_path="$1"
    local script_name="$2"
    local description="$3"
    
    print_section "Running: $description"
    print_status "Script: $script_name"
    print_status "Started at: $(date)"
    
    local start_time=$(date +%s)
    
    # Run the test script
    if "$script_path"; then
        local end_time=$(date +%s)
        local duration=$((end_time - start_time))
        
        test_results["$script_name"]="PASSED"
        test_durations["$script_name"]="$duration"
        ((passed_tests++))
        
        print_success "$description completed successfully in ${duration}s"
    else
        local end_time=$(date +%s)
        local duration=$((end_time - start_time))
        
        test_results["$script_name"]="FAILED"
        test_durations["$script_name"]="$duration"
        ((failed_tests++))
        
        print_error "$description failed after ${duration}s"
    fi
    
    ((total_tests++))
    echo ""
}

# Function to display test results summary
display_results_summary() {
    print_header "Test Results Summary"
    
    echo -e "${CYAN}Overall Results:${NC}"
    echo "  Total Tests: $total_tests"
    echo "  Passed: $passed_tests"
    echo "  Failed: $failed_tests"
    echo "  Success Rate: $(( (passed_tests * 100) / total_tests ))%"
    echo ""
    
    echo -e "${CYAN}Individual Test Results:${NC}"
    for script_name in "${!test_results[@]}"; do
        local result="${test_results[$script_name]}"
        local duration="${test_durations[$script_name]}"
        
        if [ "$result" = "PASSED" ]; then
            echo -e "  ${GREEN}✓${NC} $script_name (${duration}s)"
        else
            echo -e "  ${RED}✗${NC} $script_name (${duration}s)"
        fi
    done
    echo ""
    
    if [ $failed_tests -eq 0 ]; then
        print_success "All tests passed! 🎉"
    else
        print_warning "$failed_tests test(s) failed. Please review the output above."
    fi
}

# Function to create test results directory
setup_test_environment() {
    print_status "Setting up test environment..."
    
    # Create test results directory
    mkdir -p test_results
    
    # Create timestamped results file
    local timestamp=$(date +%Y%m%d_%H%M%S)
    local results_file="test_results/test_run_$timestamp.txt"
    
    # Redirect all output to both console and file
    exec > >(tee "$results_file")
    
    print_status "Test results will be saved to: $results_file"
    echo ""
}

# Function to run pre-flight checks
preflight_checks() {
    print_header "Pre-flight Checks"
    
    # Check environment
    check_env
    
    # Check if curl is available
    if ! command -v curl &> /dev/null; then
        print_error "curl is required but not installed. Please install curl and try again."
        exit 1
    fi
    
    # Check if jq is available (optional but recommended)
    if ! command -v jq &> /dev/null; then
        print_warning "jq is not installed. JSON parsing will be limited."
    fi
    
    # Check network connectivity to Socket API
    print_status "Testing connectivity to Socket API..."
    if curl -s --connect-timeout 10 "$SOCKET_API_BASE_URL" > /dev/null; then
        print_success "Socket API is reachable"
    else
        print_warning "Socket API connectivity check failed. Tests may fail."
    fi
    
    echo ""
}

# Function to run post-test cleanup
post_test_cleanup() {
    print_status "Running post-test cleanup..."
    
    # Remove any temporary test files
    rm -f test_package.json
    
    # Clean up test results older than 7 days
    find test_results -name "test_run_*.txt" -mtime +7 -delete 2>/dev/null || true
    find test_results -name "sbom_exports_*" -mtime +7 -exec rm -rf {} + 2>/dev/null || true
    
    print_success "Cleanup completed"
}

# Main execution
main() {
    print_header "Socket API Comprehensive Test Suite"
    print_status "Starting comprehensive API testing at $(date)"
    print_status "API Base URL: $SOCKET_API_BASE_URL"
    print_status "Organization: $SOCKET_ORG_SLUG"
    echo ""
    
    # Setup test environment
    setup_test_environment
    
    # Run pre-flight checks
    preflight_checks
    
    # Define test scripts in execution order
    declare -A test_scripts=(
        ["01_test_package_purl_endpoint.sh"]="Package PURL Endpoint Tests"
        ["02_test_license_policy.sh"]="License Policy Tests"
        ["03_test_alert_types.sh"]="Alert Types Tests"
        ["04_test_full_scans.sh"]="Full Scans Tests"
        ["05_test_repository_management.sh"]="Repository Management Tests"
        ["06_test_sbom_export.sh"]="SBOM Export Tests"
        ["07_test_cve_dependency_traversal.sh"]="CVE Dependency Traversal Tests"
    )
    
    # Check all test scripts exist
    print_status "Validating test scripts..."
    for script_name in "${!test_scripts[@]}"; do
        if ! check_test_script "$script_name" "$script_name"; then
            print_error "Test script validation failed. Exiting."
            exit 1
        fi
    done
    print_success "All test scripts validated"
    echo ""
    
    # Run tests in sequence
    print_header "Executing Test Suite"
    
    for script_name in "${!test_scripts[@]}"; do
        local description="${test_scripts[$script_name]}"
        run_test_script "$script_name" "$script_name" "$description"
        
        # Add a small delay between tests to avoid overwhelming the API
        if [ $total_tests -lt ${#test_scripts[@]} ]; then
            print_status "Waiting 2 seconds before next test..."
            sleep 2
        fi
    done
    
    # Run post-test cleanup
    post_test_cleanup
    
    # Display results summary
    display_results_summary
    
    print_header "Test Suite Execution Completed"
    print_status "Completed at: $(date)"
    
    # Exit with appropriate code
    if [ $failed_tests -eq 0 ]; then
        exit 0
    else
        exit 1
    fi
}

# Run main function
main "$@"
