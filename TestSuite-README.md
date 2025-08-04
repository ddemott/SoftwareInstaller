# 🧪 Software Installer Test Suite

This comprehensive test suite ensures your SoftwareInstaller functionality remains intact during refactoring. Run these tests **before** making any changes to establish a baseline, then run them again after refactoring to verify nothing broke.

## Quick Start

### Run All Tests (Recommended)
```powershell
.\RunAllTests.ps1
```

### Run Specific Test Types
```powershell
# Unit tests only
.\SoftwareInstaller.UnitTests.ps1

# Integration tests only
.\SoftwareInstaller.IntegrationTests.ps1

# Existing validation tests
.\test-suite.ps1
```

## Test Files Overview

| File | Purpose | What It Tests |
|------|---------|---------------|
| `RunAllTests.ps1` | **Master test runner** | Executes all test suites in sequence |
| `SoftwareInstaller.UnitTests.ps1` | **Unit testing** | Individual functions and data structures |
| `SoftwareInstaller.IntegrationTests.ps1` | **Integration testing** | Component interactions and workflows |
| `SoftwareInstaller.Tests.ps1` | **Pester framework tests** | Advanced testing with Pester (optional) |

## Test Coverage

### ✅ Unit Tests Cover:
- **Data Structures**: Software categories, subcategories, and software entries
- **Core Functions**: All installation functions (Winget, MSI, EXE, PowerShell Module, PowerShell Script)
- **Navigation Functions**: Menu display and user interaction functions
- **Global Variables**: LogPath and other configuration
- **Function Signatures**: Parameter validation and required properties

### ✅ Integration Tests Cover:
- **Complete Data Flow**: Category → Subcategory → Software selection workflow
- **Installation Workflow**: End-to-end installation process simulation
- **Software Discovery**: System scanning and software detection
- **Logging Integration**: Log file creation and content validation
- **Navigation Workflow**: Menu system integration
- **Error Handling**: Graceful handling of edge cases
- **Cross-Component Integration**: How different parts work together
- **System Compatibility**: PowerShell version, execution policy, Winget availability

## Safety Features

### 🔒 Dry Run Mode (Default)
- All tests run in **dry run mode** by default
- No actual software installations are performed
- No system modifications are made
- Safe to run on production systems

### 🛡️ Mock Functions
- Critical system operations are mocked during testing
- Prevents accidental installations or downloads
- Validates function behavior without side effects

## Test Results Interpretation

### ✅ All Tests Pass
Your system is **ready for refactoring**! The current functionality is properly preserved and tested.

### ⚠️ Some Tests Fail
Review the specific failures:
- **Data validation errors**: Fix software catalog issues
- **Missing functions**: Ensure all required functions exist
- **Integration issues**: Check component interactions

### ❌ Many Tests Fail
**Do not proceed with refactoring** until issues are resolved. Multiple failures indicate systemic problems.

## Running Tests

### Standard Usage
```powershell
# Run all tests with default safety settings
.\RunAllTests.ps1

# Run with verbose output for debugging
.\RunAllTests.ps1 -Verbose

# Skip specific test categories
.\RunAllTests.ps1 -SkipIntegrationTests

# Run without dry run (⚠️ Use with caution!)
.\RunAllTests.ps1 -DryRun:$false
```

### Individual Test Usage
```powershell
# Unit tests with verbose output
.\SoftwareInstaller.UnitTests.ps1 -Verbose

# Integration tests with verbose output
.\SoftwareInstaller.IntegrationTests.ps1 -Verbose

# Integration tests with actual operations (⚠️ Use carefully!)
.\SoftwareInstaller.IntegrationTests.ps1 -DryRun:$false
```

## Before Refactoring Checklist

1. ✅ Run `.\RunAllTests.ps1` and ensure all tests pass
2. ✅ Review any warnings and determine if they're acceptable
3. ✅ Create a git branch for your refactoring work
4. ✅ Document what you plan to refactor
5. ✅ Set up a development/testing environment

## During Refactoring

1. 🔄 Make incremental changes
2. 🧪 Run tests frequently: `.\RunAllTests.ps1`
3. 🔍 Pay attention to any new test failures
4. 📝 Update tests if you intentionally change behavior

## After Refactoring

1. 🎯 Run the complete test suite: `.\RunAllTests.ps1`
2. ✅ Ensure all tests still pass (or only expected ones changed)
3. 🔍 Run with verbose output to check for warnings
4. 🚀 Test the actual application manually

## Troubleshooting

### "Script execution is disabled on this system"
```powershell
Set-ExecutionPolicy -ExecutionPolicy RemoteSigned -Scope CurrentUser
```

### "Function not found" errors
Ensure you're running tests against the correct script file. The tests expect `SoftwareInstaller_backup_20250802_132727.ps1` in the same directory.

### Tests fail with PowerShell version errors
These tests require PowerShell 5.1 or later. Check your version:
```powershell
$PSVersionTable.PSVersion
```

### Winget-related warnings
Winget warnings are usually safe to ignore in test mode. They indicate Winget isn't available, but won't prevent refactoring of other components.

## Advanced Usage

### Custom Test Configuration
You can modify the test files to focus on specific areas you're refactoring:

1. Edit `$criticalFunctions` arrays to add/remove functions
2. Modify validation rules in unit tests
3. Add new integration test scenarios

### Creating Additional Tests
Follow the patterns in existing test files:
```powershell
function Write-TestResult {
    param([string]$TestName, [bool]$Passed, [string]$Details = "")
    # Your test result handling
}

Write-TestResult "My custom test" $true "Test details"
```

## Support

If you encounter issues with the test suite:
1. Run with `-Verbose` for detailed output
2. Check the specific test file that's failing
3. Verify your PowerShell environment meets requirements
4. Ensure all required files are present in the script directory

---

**Remember**: These tests are your safety net during refactoring. Trust them to catch issues, but also manually test your changes to ensure the user experience remains smooth! 🚀
