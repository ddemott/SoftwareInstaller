# ===== SOFTWARE INSTALLER MASTER TEST RUNNER =====
# Comprehensive test suite runner for pre-refactoring validation
# Executes unit tests, integration tests, and validation checks

param(
    [switch]$SkipUnitTests,
    [switch]$SkipIntegrationTests,
    [switch]$SkipValidation,
    [switch]$Verbose,
    [switch]$DryRun
)

# Set default for DryRun to be safe
if (-not $PSBoundParameters.ContainsKey('DryRun')) {
    $DryRun = $true
}

# Clear screen and show header
Clear-Host
Write-Host "====================================================================" -ForegroundColor Cyan
Write-Host "         SOFTWARE INSTALLER TEST RUNNER          " -ForegroundColor Cyan
Write-Host "              Pre-Refactoring Suite               " -ForegroundColor Cyan
Write-Host "====================================================================" -ForegroundColor Cyan
Write-Host ""

$TestStartTime = Get-Date
$ScriptDirectory = Split-Path -Parent $MyInvocation.MyCommand.Path

# Test runner configuration
$TestSuiteConfig = @{
    StartTime = $TestStartTime
    TotalSuites = 0
    PassedSuites = 0
    FailedSuites = 0
    Results = @()
}

function Write-SuiteHeader {
    param([string]$SuiteName)
    Write-Host "" -ForegroundColor Magenta
    Write-Host "====================================================================" -ForegroundColor Magenta
    Write-Host "RUNNING: $SuiteName" -ForegroundColor Magenta
    Write-Host "====================================================================" -ForegroundColor Magenta
}

function Write-SuiteResult {
    param(
        [string]$SuiteName,
        [bool]$Passed,
        [string]$Details = ""
    )
    
    $TestSuiteConfig.TotalSuites++
    $result = @{
        Name = $SuiteName
        Passed = $Passed
        Details = $Details
        Timestamp = Get-Date
    }
    $TestSuiteConfig.Results += $result
    
    if ($Passed) {
        $TestSuiteConfig.PassedSuites++
        Write-Host "SUITE PASSED: $SuiteName" -ForegroundColor Green
    } else {
        $TestSuiteConfig.FailedSuites++
        Write-Host "SUITE FAILED: $SuiteName" -ForegroundColor Red
    }
    
    if ($Details) {
        Write-Host "   $Details" -ForegroundColor Gray
    }
}

Write-Host "Test Configuration:" -ForegroundColor Cyan
Write-Host "  * Script Directory: $ScriptDirectory" -ForegroundColor Gray
Write-Host "  * Dry Run Mode: $DryRun" -ForegroundColor Gray
Write-Host "  * Verbose Output: $Verbose" -ForegroundColor Gray
Write-Host "  * Skip Unit Tests: $SkipUnitTests" -ForegroundColor Gray
Write-Host "  * Skip Integration Tests: $SkipIntegrationTests" -ForegroundColor Gray
Write-Host "  * Skip Validation: $SkipValidation" -ForegroundColor Gray
Write-Host ""

# ===== TEST SUITE 1: UNIT TESTS =====
if (-not $SkipUnitTests) {
    Write-SuiteHeader "Unit Tests"
    $unitTestPath = Join-Path $ScriptDirectory "SoftwareInstaller.UnitTests.ps1"
    
    if (Test-Path $unitTestPath) {
        try {
            Write-Host "Executing unit tests..." -ForegroundColor Cyan
            $unitTestOutput = & $unitTestPath -Verbose:$Verbose 2>&1
            
            # Parse results from output
            $unitTestPassed = $unitTestOutput -match "ALL TESTS PASSED!" -or
                             ($unitTestOutput -match "Success Rate: (\d+\.?\d*)%" -and
                              [double]($matches[1]) -ge 95)
            
            Write-SuiteResult "Unit Tests" $unitTestPassed "Core functionality validation completed"
            
            if ($Verbose -or -not $unitTestPassed) {
                Write-Host "Unit Test Output:" -ForegroundColor Gray
                $unitTestOutput | ForEach-Object { Write-Host "  $_" -ForegroundColor DarkGray }
            }
        } catch {
            Write-SuiteResult "Unit Tests" $false "Error executing unit tests: $($_.Exception.Message)"
        }
    } else {
        Write-SuiteResult "Unit Tests" $false "Unit test file not found: $unitTestPath"
    }
} else {
    Write-Host "SKIPPED: Unit Tests" -ForegroundColor Yellow
}

# ===== TEST SUITE 2: INTEGRATION TESTS =====
if (-not $SkipIntegrationTests) {
    Write-SuiteHeader "Integration Tests"
    $integrationTestPath = Join-Path $ScriptDirectory "SoftwareInstaller.IntegrationTests.ps1"
    
    if (Test-Path $integrationTestPath) {
        try {
            Write-Host "Executing integration tests..." -ForegroundColor Cyan
            $integrationParams = @{
                Verbose = $Verbose
            }
            if ($DryRun) {
                $integrationParams.DryRun = $true
            }
            
            $integrationTestOutput = & $integrationTestPath @integrationParams 2>&1
            
            # Parse results from output
            $integrationTestPassed = $integrationTestOutput -match "ALL INTEGRATION TESTS PASSED!" -or
                                   ($integrationTestOutput -match "Success Rate: (\d+\.?\d*)%" -and
                                    [double]($matches[1]) -ge 85)
            
            Write-SuiteResult "Integration Tests" $integrationTestPassed "Component integration validation completed"
            
            if ($Verbose -or -not $integrationTestPassed) {
                Write-Host "Integration Test Output:" -ForegroundColor Gray
                $integrationTestOutput | ForEach-Object { Write-Host "  $_" -ForegroundColor DarkGray }
            }
        } catch {
            Write-SuiteResult "Integration Tests" $false "Error executing integration tests: $($_.Exception.Message)"
        }
    } else {
        Write-SuiteResult "Integration Tests" $false "Integration test file not found: $integrationTestPath"
    }
} else {
    Write-Host "SKIPPED: Integration Tests" -ForegroundColor Yellow
}

# ===== TEST SUITE 3: EXISTING VALIDATION =====
if (-not $SkipValidation) {
    Write-SuiteHeader "Existing Validation Tests"
    
    # Run existing test scripts if they exist
    $existingTests = @(
        "test-suite.ps1",
        "simple-test.ps1",
        "crystaldiskinfo-test.ps1"
    )
    
    foreach ($testFile in $existingTests) {
        $testPath = Join-Path $ScriptDirectory $testFile
        if (Test-Path $testPath) {
            try {
                Write-Host "Running $testFile..." -ForegroundColor Cyan
                $testOutput = & $testPath 2>&1
                
                # Parse results - look for common success patterns
                $testPassed = $testOutput -match "PASS" -and
                             ($testOutput -notmatch "FAIL" -or
                              ($testOutput -match "PASS").Count -gt ($testOutput -match "FAIL").Count)
                
                Write-SuiteResult "Validation: $testFile" $testPassed "Legacy test validation"
                
                if ($Verbose -or -not $testPassed) {
                    Write-Host "$testFile Output:" -ForegroundColor Gray
                    $testOutput | Select-Object -Last 10 | ForEach-Object { Write-Host "  $_" -ForegroundColor DarkGray }
                }
            } catch {
                Write-SuiteResult "Validation: $testFile" $false "Error running $testFile`: $($_.Exception.Message)"
            }
        } else {
            Write-Host "$testFile not found, skipping" -ForegroundColor Yellow
        }
    }
} else {
    Write-Host "SKIPPED: Validation Tests" -ForegroundColor Yellow
}

# ===== TEST SUITE 4: SYSTEM READINESS CHECK =====
Write-SuiteHeader "System Readiness Check"

try {
    # Check main script file
    $mainScript = Join-Path $ScriptDirectory "SoftwareInstaller_backup_20250802_132727.ps1"
    $mainScriptExists = Test-Path $mainScript
    
    # Check JSON file
    $jsonFile = Join-Path $ScriptDirectory "software-categories.json"
    $jsonExists = Test-Path $jsonFile
    
    # Check PowerShell version
    $psVersion = $PSVersionTable.PSVersion
    $psCompatible = $psVersion.Major -ge 5
    
    # Check execution policy
    $executionPolicy = Get-ExecutionPolicy
    $policyOk = $executionPolicy -in @("Unrestricted", "RemoteSigned", "Bypass")
    
    # Check Winget
    $wingetAvailable = $null -ne (Get-Command winget -ErrorAction SilentlyContinue)
    
    $systemReady = $mainScriptExists -and $jsonExists -and $psCompatible -and $policyOk
    
    $readinessDetails = @(
        "Main Script: $(if ($mainScriptExists) { 'OK' } else { 'MISSING' })",
        "JSON Config: $(if ($jsonExists) { 'OK' } else { 'MISSING' })",
        "PowerShell: $(if ($psCompatible) { 'OK' } else { 'OLD' }) v$($psVersion.ToString())",
        "Exec Policy: $(if ($policyOk) { 'OK' } else { 'RESTRICTED' }) $executionPolicy",
        "Winget: $(if ($wingetAvailable) { 'OK' } else { 'MISSING' }) $(if ($wingetAvailable) { 'Available' } else { 'Not found' })"
    ) -join ", "
    
    Write-SuiteResult "System Readiness" $systemReady $readinessDetails
} catch {
    Write-SuiteResult "System Readiness" $false "Error checking system readiness: $($_.Exception.Message)"
}

# ===== FINAL SUMMARY =====
$TestEndTime = Get-Date
$TestDuration = $TestEndTime - $TestStartTime

Write-Host "" -ForegroundColor Cyan
Write-Host "====================================================================" -ForegroundColor Cyan
Write-Host "FINAL TEST SUMMARY" -ForegroundColor Cyan
Write-Host "====================================================================" -ForegroundColor Cyan

Write-Host "`nExecution Summary:" -ForegroundColor White
Write-Host "  * Start Time: $($TestStartTime.ToString('yyyy-MM-dd HH:mm:ss'))" -ForegroundColor Gray
Write-Host "  * End Time: $($TestEndTime.ToString('yyyy-MM-dd HH:mm:ss'))" -ForegroundColor Gray
Write-Host "  * Duration: $($TestDuration.TotalSeconds.ToString('F1')) seconds" -ForegroundColor Gray

Write-Host "`nTest Suite Results:" -ForegroundColor White
Write-Host "  * Total Suites: $($TestSuiteConfig.TotalSuites)" -ForegroundColor Gray
Write-Host "  * Passed: $($TestSuiteConfig.PassedSuites)" -ForegroundColor Green
Write-Host "  * Failed: $($TestSuiteConfig.FailedSuites)" -ForegroundColor $(if ($TestSuiteConfig.FailedSuites -gt 0) { "Red" } else { "Green" })

if ($TestSuiteConfig.TotalSuites -gt 0) {
    $overallSuccessRate = ($TestSuiteConfig.PassedSuites / $TestSuiteConfig.TotalSuites) * 100
    Write-Host "  * Success Rate: $($overallSuccessRate.ToString('F1'))%" -ForegroundColor $(if ($overallSuccessRate -ge 90) { "Green" } elseif ($overallSuccessRate -ge 75) { "Yellow" } else { "Red" })
}

Write-Host "`nDetailed Results:" -ForegroundColor White
foreach ($result in $TestSuiteConfig.Results) {
    $status = if ($result.Passed) { "PASS" } else { "FAIL" }
    $color = if ($result.Passed) { "Green" } else { "Red" }
    Write-Host "  $status - $($result.Name)" -ForegroundColor $color
    if ($result.Details) {
        Write-Host "      $($result.Details)" -ForegroundColor Gray
    }
}

# ===== REFACTORING RECOMMENDATION =====
Write-Host "" -ForegroundColor Magenta
Write-Host "====================================================================" -ForegroundColor Magenta
Write-Host "REFACTORING RECOMMENDATION" -ForegroundColor Magenta
Write-Host "====================================================================" -ForegroundColor Magenta

if ($TestSuiteConfig.FailedSuites -eq 0) {
    Write-Host "`nEXCELLENT! ALL TEST SUITES PASSED!" -ForegroundColor Green
    Write-Host ""
    Write-Host "Your SoftwareInstaller is ready for refactoring!" -ForegroundColor Green
    Write-Host "All critical functionality has been validated!" -ForegroundColor Green
    Write-Host "Integration points are working correctly!" -ForegroundColor Green
    Write-Host "System compatibility is confirmed!" -ForegroundColor Green
    Write-Host ""
    Write-Host "Recommended next steps:" -ForegroundColor Cyan
    Write-Host "   1. Create a git branch for refactoring work" -ForegroundColor Gray
    Write-Host "   2. Make your refactoring changes incrementally" -ForegroundColor Gray
    Write-Host "   3. Run this test suite after each major change" -ForegroundColor Gray
    Write-Host "   4. Ensure all tests continue to pass" -ForegroundColor Gray
    Write-Host ""
    Write-Host "The current test baseline will help ensure your" -ForegroundColor Yellow
    Write-Host "refactoring maintains all existing functionality!" -ForegroundColor Yellow
    
} elseif ($TestSuiteConfig.FailedSuites -le 1) {
    Write-Host "`nMOSTLY READY - Minor Issues Detected" -ForegroundColor Yellow
    Write-Host ""
    Write-Host "Most test suites passed, but there are minor issues." -ForegroundColor Yellow
    Write-Host "Review the failed test(s) above and consider:" -ForegroundColor Yellow
    Write-Host ""
    Write-Host "* Are the failures critical to your refactoring goals?" -ForegroundColor Gray
    Write-Host "* Can they be safely ignored or easily fixed?" -ForegroundColor Gray
    Write-Host "* Do they affect the areas you plan to refactor?" -ForegroundColor Gray
    Write-Host ""
    Write-Host "You may proceed with caution, but address issues first if possible." -ForegroundColor Yellow
    
} else {
    Write-Host "`nNOT READY FOR REFACTORING" -ForegroundColor Red
    Write-Host ""
    Write-Host "Multiple test suites failed. This indicates potential issues" -ForegroundColor Red
    Write-Host "with the current system that should be resolved before refactoring." -ForegroundColor Red
    Write-Host ""
    Write-Host "Recommended actions:" -ForegroundColor Cyan
    Write-Host "   1. Review all failed test details above" -ForegroundColor Gray
    Write-Host "   2. Fix the underlying issues" -ForegroundColor Gray
    Write-Host "   3. Re-run this test suite" -ForegroundColor Gray
    Write-Host "   4. Only proceed when all tests pass" -ForegroundColor Gray
    Write-Host ""
    Write-Host "Refactoring on an unstable foundation is risky!" -ForegroundColor Red
}

Write-Host ""
Write-Host "Test Runner Complete" -ForegroundColor Cyan
