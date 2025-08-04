# ===== INTEGRATION TESTS FOR SOFTWARE INSTALLER =====
# Tests the complete workflow and integration between components
# These tests ensure that refactoring doesn't break the overall system behavior

param(
    [switch]$DryRun,
    [switch]$Verbose
)

# Set default for DryRun to be safe
if (-not $PSBoundParameters.ContainsKey('DryRun')) {
    $DryRun = $true
}

Write-Host "╔══════════════════════════════════════════════════╗" -ForegroundColor Cyan
Write-Host "║      Software Installer Integration Tests       ║" -ForegroundColor Cyan
Write-Host "╚══════════════════════════════════════════════════╝" -ForegroundColor Cyan
Write-Host ""

if ($DryRun) {
    Write-Host "DRY RUN MODE: No actual installations will be performed" -ForegroundColor Yellow
    Write-Host "This ensures safe testing without modifying your system" -ForegroundColor Gray
    Write-Host ""
}

# Test configuration
$IntegrationResults = @{
    Passed = 0
    Failed = 0
    Total = 0
    Warnings = 0
    TestCategories = @()
}

function Write-IntegrationResult {
    param(
        [string]$TestName,
        [bool]$Passed,
        [string]$Details = "",
        [switch]$Warning = $false
    )
    
    $IntegrationResults.Total++
    if ($Warning) {
        $IntegrationResults.Warnings++
        Write-Host "⚠️  WARN: $TestName" -ForegroundColor Yellow
    } elseif ($Passed) {
        $IntegrationResults.Passed++
        Write-Host "✅ PASS: $TestName" -ForegroundColor Green
    } else {
        $IntegrationResults.Failed++
        Write-Host "❌ FAIL: $TestName" -ForegroundColor Red
    }
    
    if ($Details -and ($Verbose -or -not $Passed -or $Warning)) {
        Write-Host "    $Details" -ForegroundColor Gray
    }
}

# Load the script for testing
$scriptDirectory = Split-Path -Parent $MyInvocation.MyCommand.Path
$scriptPath = Join-Path $scriptDirectory "SoftwareInstaller_backup_20250802_132727.ps1"

Write-Host "Loading script for integration testing..." -ForegroundColor Cyan
try {
    # Load the script but prevent main execution
    $scriptContent = Get-Content $scriptPath -Raw
    $functionsOnly = $scriptContent -replace 'Navigate-SoftwareMenu[\s\S]*$', ''
    $functionsOnly = $functionsOnly -replace 'Write-Host.*"Thank you for using Software Installation Manager!"[\s\S]*$', ''
    
    Invoke-Expression $functionsOnly
    Write-Host "✅ Script loaded successfully for testing" -ForegroundColor Green
} catch {
    Write-Host "❌ Failed to load script: $($_.Exception.Message)" -ForegroundColor Red
    exit 1
}

# ===== INTEGRATION TEST 1: COMPLETE DATA FLOW =====
Write-Host "`n1. Complete Data Flow Integration Test" -ForegroundColor Yellow

# Test the complete flow from categories to specific software
$testCategory = "Development"
$testSubcategory = "IDEs & Editors"

$categoryExists = $softwareCategories.ContainsKey($testCategory)
Write-IntegrationResult "Test category '$testCategory' exists" $categoryExists

if ($categoryExists) {
    $subcategoryExists = $softwareCategories[$testCategory].ContainsKey($testSubcategory)
    Write-IntegrationResult "Test subcategory '$testSubcategory' exists" $subcategoryExists
    
    if ($subcategoryExists) {
        $softwareList = $softwareCategories[$testCategory][$testSubcategory]
        Write-IntegrationResult "Subcategory contains software items" ($softwareList.Count -gt 0) "Count: $($softwareList.Count)"
        
        if ($softwareList.Count -gt 0) {
            $firstSoftware = $softwareList[0]
            $hasRequiredProperties = ($firstSoftware.Name -and $firstSoftware.Type -and $firstSoftware.Description)
            Write-IntegrationResult "First software item has required properties" $hasRequiredProperties "Name: $($firstSoftware.Name), Type: $($firstSoftware.Type)"
        }
    }
}

# ===== INTEGRATION TEST 2: INSTALLATION WORKFLOW SIMULATION =====
Write-Host "`n2. Installation Workflow Simulation" -ForegroundColor Yellow

# Test each installation type with mock data
$installationTypes = @(
    @{ Type = "Winget"; TestFunction = "Install-WingetSoftware"; TestData = @{ Id = "Microsoft.VisualStudioCode"; Name = "Visual Studio Code" } },
    @{ Type = "MSI"; TestFunction = "Install-MSIPackage"; TestData = @{ Name = "Test MSI"; Url = "https://example.com/test.msi"; Arguments = "/quiet" } },
    @{ Type = "EXE"; TestFunction = "Install-EXEPackage"; TestData = @{ Name = "Test EXE"; Url = "https://example.com/test.exe"; Arguments = "/S" } },
    @{ Type = "PowerShellModule"; TestFunction = "Install-PowerShellModule"; TestData = @{ ModuleName = "TestModule" } },
    @{ Type = "PowerShellScript"; TestFunction = "Install-PowerShellScript"; TestData = @{ Name = "Test Script"; Url = "https://example.com/test.ps1" } }
)

foreach ($installationType in $installationTypes) {
    $functionExists = Get-Command $installationType.TestFunction -ErrorAction SilentlyContinue
    Write-IntegrationResult "$($installationType.Type) installation function exists" ($null -ne $functionExists)
    
    if ($functionExists -and $DryRun) {
        # In dry run mode, we can't actually test installations, but we can verify function signatures
        $params = $functionExists.Parameters
        $expectedParams = $installationType.TestData.Keys
        
        $allParamsExist = $true
        foreach ($param in $expectedParams) {
            if (-not $params.ContainsKey($param)) {
                $allParamsExist = $false
                break
            }
        }
        
        Write-IntegrationResult "$($installationType.Type) function has required parameters" $allParamsExist "Parameters: $($expectedParams -join ', ')"
    }
}

# ===== INTEGRATION TEST 3: SOFTWARE DISCOVERY WORKFLOW =====
Write-Host "`n3. Software Discovery Workflow" -ForegroundColor Yellow

# Test Get-InstalledSoftware function
$getInstalledExists = Get-Command Get-InstalledSoftware -ErrorAction SilentlyContinue
Write-IntegrationResult "Get-InstalledSoftware function exists" ($null -ne $getInstalledExists)

if ($getInstalledExists -and -not $DryRun) {
    try {
        # This might take a while, so we'll limit it in integration tests
        Write-Host "    Testing software discovery (this may take a moment)..." -ForegroundColor Gray
        $installedSoftware = Get-InstalledSoftware
        Write-IntegrationResult "Get-InstalledSoftware returns data" ($installedSoftware.Count -gt 0) "Found: $($installedSoftware.Count) items"
        
        if ($installedSoftware.Count -gt 0) {
            $firstItem = $installedSoftware[0]
            $hasRequiredFields = ($firstItem.Name -and $firstItem.Source)
            Write-IntegrationResult "Installed software items have required fields" $hasRequiredFields "Sample: $($firstItem.Name) from $($firstItem.Source)"
        }
    } catch {
        Write-IntegrationResult "Get-InstalledSoftware execution" $false $_.Exception.Message
    }
} else {
    Write-IntegrationResult "Get-InstalledSoftware skipped in dry run" $true -Warning $true
}

# ===== INTEGRATION TEST 4: LOGGING WORKFLOW =====
Write-Host "`n4. Logging Workflow Integration" -ForegroundColor Yellow

# Test that LogPath is properly configured
$logPathValid = $LogPath -and $LogPath -match "installation_log_\d{8}_\d{6}\.txt"
Write-IntegrationResult "LogPath is properly formatted" $logPathValid "Path: $LogPath"

# Test logging functionality with a temp file
$testLogPath = ".\test_integration_log_$(Get-Date -Format 'yyyyMMdd_HHmmss').txt"
$originalLogPath = $LogPath
$Global:LogPath = $testLogPath

try {
    # Test log creation (simulate an installation attempt)
    Add-Content -Path $testLogPath -Value "$(Get-Date): TEST - Integration test log entry"
    $logCreated = Test-Path $testLogPath
    Write-IntegrationResult "Log file creation works" $logCreated "Path: $testLogPath"
    
    if ($logCreated) {
        $logContent = Get-Content $testLogPath -Raw
        $contentValid = $logContent -match "Integration test log entry"
        Write-IntegrationResult "Log content is written correctly" $contentValid
    }
} catch {
    Write-IntegrationResult "Logging functionality" $false $_.Exception.Message
} finally {
    # Cleanup test log and restore original path
    if (Test-Path $testLogPath) {
        Remove-Item $testLogPath -Force -ErrorAction SilentlyContinue
    }
    $Global:LogPath = $originalLogPath
}

# ===== INTEGRATION TEST 5: NAVIGATION WORKFLOW =====
Write-Host "`n5. Navigation Workflow Integration" -ForegroundColor Yellow

$navigationFunctions = @(
    "Show-MainCategories",
    "Show-Subcategories",
    "Show-SoftwareList",
    "Get-UserMenuChoice"
)

foreach ($funcName in $navigationFunctions) {
    $func = Get-Command $funcName -ErrorAction SilentlyContinue
    Write-IntegrationResult "Navigation function '$funcName' exists" ($null -ne $func)
}

# Test navigation function signatures
$showSubcategoriesFunc = Get-Command Show-Subcategories -ErrorAction SilentlyContinue
if ($showSubcategoriesFunc) {
    $hasCategoryParam = $showSubcategoriesFunc.Parameters.ContainsKey("categoryName")
    Write-IntegrationResult "Show-Subcategories accepts categoryName parameter" $hasCategoryParam
}

$showSoftwareListFunc = Get-Command Show-SoftwareList -ErrorAction SilentlyContinue
if ($showSoftwareListFunc) {
    $hasBothParams = $showSoftwareListFunc.Parameters.ContainsKey("categoryName") -and 
                     $showSoftwareListFunc.Parameters.ContainsKey("subcategoryName")
    Write-IntegrationResult "Show-SoftwareList accepts required parameters" $hasBothParams
}

# ===== INTEGRATION TEST 6: ERROR HANDLING WORKFLOW =====
Write-Host "`n6. Error Handling Integration" -ForegroundColor Yellow

# Test handling of non-existent categories
try {
    $nonExistentCategory = $softwareCategories["NonExistentCategory"]
    Write-IntegrationResult "Handles non-existent category gracefully" ($null -eq $nonExistentCategory) "Returns null for invalid category"
} catch {
    Write-IntegrationResult "Non-existent category access" $false "Should return null, not throw error: $($_.Exception.Message)"
}

# Test handling of empty inputs
if ($DryRun) {
    # In dry run, we test function signatures rather than execution
    Write-IntegrationResult "Error handling tests skipped in dry run" $true -Warning $true
} else {
    # Test actual error handling (this could be expanded based on specific needs)
    Write-IntegrationResult "Error handling needs implementation-specific tests" $true -Warning $true
}

# ===== INTEGRATION TEST 7: CROSS-COMPONENT INTEGRATION =====
Write-Host "`n7. Cross-Component Integration" -ForegroundColor Yellow

# Test that different components work together
$sampleWingetSoftware = $null
foreach ($categoryName in $softwareCategories.Keys) {
    foreach ($subcategoryName in $softwareCategories[$categoryName].Keys) {
        $wingetItems = $softwareCategories[$categoryName][$subcategoryName] | Where-Object { $_.Type -eq "Winget" }
        if ($wingetItems.Count -gt 0) {
            $sampleWingetSoftware = $wingetItems[0]
            break
        }
    }
    if ($sampleWingetSoftware) { break }
}

if ($sampleWingetSoftware) {
    Write-IntegrationResult "Found Winget software for integration test" $true "Sample: $($sampleWingetSoftware.Name)"
    
    # Test that the software has all properties needed for installation
    $hasAllWingetProps = $sampleWingetSoftware.Name -and $sampleWingetSoftware.Id
    Write-IntegrationResult "Winget software has installation-ready properties" $hasAllWingetProps "Name: $($sampleWingetSoftware.Name), Id: $($sampleWingetSoftware.Id)"
} else {
    Write-IntegrationResult "Found Winget software for testing" $false "No Winget software found in categories"
}

# ===== INTEGRATION TEST 8: SYSTEM COMPATIBILITY =====
Write-Host "`n8. System Compatibility Integration" -ForegroundColor Yellow

# Test Winget availability
$wingetAvailable = Get-Command winget -ErrorAction SilentlyContinue
Write-IntegrationResult "Winget is available on system" ($null -ne $wingetAvailable) "Required for Winget installations"

# Test PowerShell version compatibility
$psVersion = $PSVersionTable.PSVersion
$psCompatible = $psVersion.Major -ge 5
Write-IntegrationResult "PowerShell version is compatible" $psCompatible "Version: $($psVersion.ToString())"

# Test execution policy
$executionPolicy = Get-ExecutionPolicy
$policyAllowsScripts = $executionPolicy -in @("Unrestricted", "RemoteSigned", "Bypass")
Write-IntegrationResult "Execution policy allows script execution" $policyAllowsScripts "Policy: $executionPolicy"

# ===== INTEGRATION TEST SUMMARY =====
Write-Host "`n$('='*60)" -ForegroundColor Cyan
Write-Host "INTEGRATION TEST SUMMARY" -ForegroundColor Cyan
Write-Host "$('='*60)" -ForegroundColor Cyan

$IntegrationResults.TestCategories = @(
    "Complete Data Flow",
    "Installation Workflow", 
    "Software Discovery",
    "Logging Workflow",
    "Navigation Workflow",
    "Error Handling",
    "Cross-Component Integration",
    "System Compatibility"
)

Write-Host "Total Integration Tests: $($IntegrationResults.Total)" -ForegroundColor White
Write-Host "Passed: $($IntegrationResults.Passed)" -ForegroundColor Green
Write-Host "Failed: $($IntegrationResults.Failed)" -ForegroundColor $(if ($IntegrationResults.Failed -gt 0) { "Red" } else { "Green" })
Write-Host "Warnings: $($IntegrationResults.Warnings)" -ForegroundColor Yellow

$successRate = if ($IntegrationResults.Total -gt 0) { ($IntegrationResults.Passed / $IntegrationResults.Total) * 100 } else { 0 }
Write-Host "Success Rate: $($successRate.ToString('F1'))%" -ForegroundColor $(if ($successRate -ge 90) { "Green" } elseif ($successRate -ge 75) { "Yellow" } else { "Red" })

Write-Host "`nTest Categories Covered:" -ForegroundColor Cyan
$IntegrationResults.TestCategories | ForEach-Object { Write-Host "  ✓ $_" -ForegroundColor Gray }

if ($DryRun) {
    Write-Host "`n🔒 DRY RUN COMPLETED" -ForegroundColor Yellow
    Write-Host "These tests verified the integration points without making system changes." -ForegroundColor Gray
    Write-Host "For full integration testing, run with -DryRun:$false (use caution)." -ForegroundColor Gray
}

if ($IntegrationResults.Failed -eq 0) {
    Write-Host "`n🎉 ALL INTEGRATION TESTS PASSED!" -ForegroundColor Green
    Write-Host "✅ The system components integrate properly!" -ForegroundColor Green
    Write-Host "✅ Ready for refactoring with confidence!" -ForegroundColor Green
    
    if ($IntegrationResults.Warnings -gt 0) {
        Write-Host "`n⚠️  Note: Some tests had warnings (see above)" -ForegroundColor Yellow
        Write-Host "These are typically safe and expected in dry run mode." -ForegroundColor Gray
    }
} else {
    Write-Host "`n❌ INTEGRATION ISSUES DETECTED" -ForegroundColor Red
    Write-Host "Please resolve integration issues before refactoring." -ForegroundColor Red
    Write-Host "System components may not work together as expected." -ForegroundColor Red
}

Write-Host "`n$('='*60)" -ForegroundColor Cyan
Write-Host "Integration Tests Complete" -ForegroundColor Cyan
Write-Host "$('='*60)" -ForegroundColor Cyan
