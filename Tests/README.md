# Test Scripts Directory

This directory contains all test, validation, and debugging scripts for the PowerShell Software Installation Manager.

## Test Files

### 📋 Main Test Scripts
- **`simple-test.ps1`** - Basic verification script for checking software catalog integrity
- **`test-suite.ps1`** - Comprehensive test suite for all software categories
- **`test-suite-clean.ps1`** - Clean version of the comprehensive test suite
- **`validate.ps1`** - Validation script for JSON structure and data integrity

### 🔍 Search & Debug Scripts
- **`test-search.ps1`** - Test script for search functionality
- **`test-search-clean.ps1`** - Clean version of search functionality tests
- **`debug-search.ps1`** - Debugging script for troubleshooting search issues

### 🌐 Software Availability Tests
- **`test-software-availability.ps1`** - **COMPREHENSIVE** test of ALL software in catalog (takes time)
- **`test-software-validation.ps1`** - **QUICK** validation of software catalog structure
- **`test-winget-availability.ps1`** - Specialized test for all Winget packages
- **`test-github-availability.ps1`** - Specialized test for all GitHub repositories

## Usage

Run any test script from the main SoftwareInstaller directory:

```powershell
# Basic catalog verification
.\Tests\simple-test.ps1

# Comprehensive test suite
.\Tests\test-suite.ps1

# Clean comprehensive test suite (recommended)
.\Tests\test-suite-clean.ps1

# JSON and function validation
.\Tests\validate.ps1

# Search functionality testing
.\Tests\test-search.ps1

# Clean search functionality testing
.\Tests\test-search-clean.ps1

# Debug search issues
.\Tests\debug-search.ps1

# === SOFTWARE AVAILABILITY TESTS ===

# Quick validation (fast - structure only)
.\Tests\test-software-validation.ps1

# Full availability test (comprehensive but slow)
.\Tests\test-software-availability.ps1

# Test only Winget packages (medium speed)
.\Tests\test-winget-availability.ps1

# Test only GitHub repositories (medium speed)
.\Tests\test-github-availability.ps1
```

### 🚀 **Recommended Testing Workflow:**

1. **Daily/Quick Check**: `.\Tests\test-software-validation.ps1`
2. **Before Release**: `.\Tests\test-winget-availability.ps1`
3. **Full Verification**: `.\Tests\test-software-availability.ps1`
4. **GitHub Issues**: `.\Tests\test-github-availability.ps1`

**Note**: All test scripts are designed to be run from the main project directory, not from within the Tests folder. They automatically locate the required files using relative paths.

## Purpose

These scripts help ensure:
- ✅ Software catalog JSON integrity
- ✅ Category structure validation
- ✅ Search functionality verification
- ✅ Installation process testing
- ✅ Error handling validation
- ✅ **Winget package availability** (all 150+ packages tested)
- ✅ **GitHub repository accessibility** (releases, assets, patterns)
- ✅ **PowerShell module availability** (PSGallery verification)
- ✅ **URL accessibility** (Custom/MSI/EXE download links)
- ✅ **Software catalog maintenance** (automated quality assurance)

### 📊 **Test Coverage:**

- **Structure Tests**: JSON validation, required fields, format checking
- **Availability Tests**: Real-time verification that software can be found/downloaded
- **Integration Tests**: Search, installation workflow, error handling
- **Performance Tests**: Large catalog handling, paging, memory usage
- **Quality Assurance**: Broken links, invalid IDs, missing descriptions

### 🎯 **Benefits:**

- **Automated Quality Control**: Catch broken software entries before users encounter them
- **Catalog Maintenance**: Identify outdated or moved software packages
- **Release Confidence**: Verify software catalog integrity before deploying updates
- **Performance Monitoring**: Track availability rates and identify patterns
- **Documentation**: Generate detailed reports for troubleshooting and improvement

All test scripts are designed to be run independently and provide detailed feedback on system health and functionality.
