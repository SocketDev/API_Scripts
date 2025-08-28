# Contributing to Socket API Test Suite

Thank you for your interest in contributing to the Socket API Test Suite! This document provides guidelines and information for contributors.

## 🤝 How to Contribute

### 1. **Report Issues**
- Use the GitHub issue tracker to report bugs or suggest new features
- Include detailed information about the problem
- Provide steps to reproduce the issue
- Include your environment details (OS, bash version, etc.)

### 2. **Submit Pull Requests**
- Fork the repository
- Create a feature branch: `git checkout -b feature/amazing-feature`
- Make your changes following the coding standards below
- Test your changes thoroughly
- Submit a pull request with a clear description

### 3. **Improve Documentation**
- Update README.md with new features
- Add inline comments to complex test logic
- Create examples for new test scenarios

## 📝 Coding Standards

### **Script Structure**
Each test script should follow this structure:

```bash
#!/bin/bash

# =============================================================================
# Socket API Testing Script: [Script Name]
# =============================================================================
# 
# SCENARIO: [Clear description of what this script tests]
# 
# This script tests [specific functionality] including:
# - [Feature 1]
# - [Feature 2]
# - [Feature 3]
#
# =============================================================================

# Load environment variables
source .env

# [Color definitions and utility functions]

# [Main test functions]

# Main test execution
main() {
    # [Test implementation]
}

# Run main function
main "$@"
```

### **Naming Conventions**
- **Files**: `XX_test_[feature_name].sh` (XX = sequential number)
- **Functions**: `snake_case` for function names
- **Variables**: `UPPER_CASE` for environment variables, `snake_case` for local variables
- **Tests**: `Test N: [Description]` format

### **Error Handling**
- Always use the `make_request` function for API calls
- Include proper error checking and validation
- Provide meaningful error messages
- Handle rate limiting gracefully

### **Documentation**
- Include comprehensive header comments
- Document all test scenarios
- Explain complex logic with inline comments
- Update README.md when adding new features

## 🧪 Testing Guidelines

### **Test Coverage**
Each new test should cover:
- **Happy Path**: Normal operation with valid data
- **Edge Cases**: Boundary conditions and unusual inputs
- **Error Scenarios**: Invalid requests and failure conditions
- **Performance**: Large datasets and rate limiting

### **Test Data**
- Use realistic but non-sensitive test data
- Include various data types and formats
- Test with different ecosystem packages (npm, PyPI, Maven, etc.)
- Validate response formats and content

### **API Best Practices**
- Respect rate limits and quotas
- Use appropriate authentication methods
- Handle pagination correctly
- Validate response status codes

## 🔧 Development Setup

### **Local Environment**
```bash
# Clone the repository
git clone [repository-url]
cd socket_api_tests

# Copy environment template
cp .env.example .env

# Edit environment file with your credentials
nano .env

# Make scripts executable
chmod +x *.sh
```

### **Testing Your Changes**
```bash
# Test individual script
./01_test_package_purl_endpoint.sh

# Run complete test suite
./run_all_tests.sh

# Test with verbose output (add -v to curl commands)
```

## 📋 Pull Request Checklist

Before submitting a pull request, ensure:

- [ ] All tests pass locally
- [ ] New tests are added for new functionality
- [ ] Existing tests are not broken
- [ ] Code follows the established style guide
- [ ] Documentation is updated
- [ ] No sensitive data is included
- [ ] Commit messages are clear and descriptive

## 🚀 Adding New Test Scripts

### **1. Create the Script**
```bash
# Create new test script
touch XX_test_[feature_name].sh
chmod +x XX_test_[feature_name].sh
```

### **2. Follow the Template**
Use the existing scripts as templates and ensure:
- Proper header documentation
- Environment variable loading
- Error handling functions
- Consistent test structure

### **3. Update Master Runner**
Add your new script to `run_all_tests.sh`:
```bash
declare -A test_scripts=(
    ["01_test_package_purl_endpoint.sh"]="Package PURL Endpoint Tests"
    ["XX_test_[feature_name].sh"]="[Feature Name] Tests"  # Add here
    # ... existing scripts
)
```

### **4. Update Documentation**
- Add your script to the README.md
- Document the test scenarios
- Include usage examples

## 🐛 Debugging Tips

### **Enable Verbose Output**
```bash
# Add -v flag to curl commands for debugging
curl -v -s -w "\n%{http_code}" \
    -H "Authorization: Bearer $SOCKET_API_TOKEN" \
    "$SOCKET_API_BASE_URL$endpoint"
```

### **Check Environment Variables**
```bash
# Add debug output to scripts
echo "Debug: API Token length: ${#SOCKET_API_TOKEN}"
echo "Debug: Org Slug: $SOCKET_ORG_SLUG"
```

### **Test Individual Components**
```bash
# Test just the request function
source .env
make_request "/test/endpoint" "GET" "" "Test request"
```

## 📚 Resources

- [Socket.dev API Documentation](https://docs.socket.dev/reference)
- [Bash Scripting Guide](https://www.gnu.org/software/bash/manual/)
- [curl Documentation](https://curl.se/docs/)
- [Git Best Practices](https://git-scm.com/book/en/v2)

## 🆘 Getting Help

If you need help or have questions:

1. **Check existing issues** for similar problems
2. **Review the documentation** in README.md
3. **Create a new issue** with detailed information
4. **Join discussions** in existing pull requests

## 📄 License

By contributing to this project, you agree that your contributions will be licensed under the same license as the project.

---

Thank you for contributing to making the Socket API Test Suite more robust and comprehensive! 🎉
