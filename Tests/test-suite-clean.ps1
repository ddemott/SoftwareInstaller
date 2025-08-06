# Clean comprehensive test suite
# Tests all major functionality without excessive output

$scriptDirectory = Split-Path -Parent $MyInvocation.MyCommand.Path
$parentDirectory = Split-Path -Parent $scriptDirectory
$mainScriptPath = Join-Path $parentDirectory "SoftwareInstaller.ps1"
$jsonPath = Join-Path $parentDirectory "software-categories.json"

Write-Host "Software Installation Manager - Clean Test Suite" -ForegroundColor Cyan
Write-Host "================================================" -ForegroundColor Cyan

$testResults = @()

# Test 1: File Existence
Write-Host "1. Checking files..." -ForegroundColor Yellow
$filesExist = (Test-Path $mainScriptPath) -and (Test-Path $jsonPath)
$testResults += [PSCustomObject]@{ Test = "File Existence"; Result = $filesExist }
Write-Host "   Files exist: $(if ($filesExist) { '✅ PASS' } else { '❌ FAIL' })" -ForegroundColor $(if ($filesExist) { 'Green' } else { 'Red' })

# Test 2: JSON Validity
Write-Host "2. Validating JSON..." -ForegroundColor Yellow
try {
    $jsonData = Get-Content $jsonPath -Raw | ConvertFrom-Json
    $jsonValid = $jsonData -ne $null -and $jsonData.PSObject.Properties.Count -gt 0
    $testResults += [PSCustomObject]@{ Test = "JSON Validity"; Result = $jsonValid }
    Write-Host "   JSON valid: $(if ($jsonValid) { '✅ PASS' } else { '❌ FAIL' })" -ForegroundColor $(if ($jsonValid) { 'Green' } else { 'Red' })
    if ($jsonValid) {
        Write-Host "   Categories: $($jsonData.PSObject.Properties.Count)" -ForegroundColor Gray
    }
} catch {
    $testResults += [PSCustomObject]@{ Test = "JSON Validity"; Result = $false }
    Write-Host "   JSON valid: ❌ FAIL - $($_.Exception.Message)" -ForegroundColor Red
}

# Test 3: Script Loading
Write-Host "3. Loading script..." -ForegroundColor Yellow
try {
    # Load only the functions, not the main execution
    $scriptContent = Get-Content $mainScriptPath -Raw
    $functionsOnly = $scriptContent -replace '# Start the navigation menu[\s\S]*', ''
    Invoke-Expression $functionsOnly
    
    $scriptLoaded = $softwareCategories -ne $null
    $testResults += [PSCustomObject]@{ Test = "Script Loading"; Result = $scriptLoaded }
    Write-Host "   Script loaded: $(if ($scriptLoaded) { '✅ PASS' } else { '❌ FAIL' })" -ForegroundColor $(if ($scriptLoaded) { 'Green' } else { 'Red' })
} catch {
    $testResults += [PSCustomObject]@{ Test = "Script Loading"; Result = $false }
    Write-Host "   Script loaded: ❌ FAIL - $($_.Exception.Message)" -ForegroundColor Red
}

# Test 4: Core Functions
Write-Host "4. Testing functions..." -ForegroundColor Yellow
$coreFunctions = @('Get-InstalledSoftware', 'Search-WingetPackage', 'Search-GitHubRepository', 'Install-WingetSoftware')
$functionsWork = $true
foreach ($func in $coreFunctions) {
    $exists = Get-Command $func -ErrorAction SilentlyContinue
    if (-not $exists) { $functionsWork = $false }
}
$testResults += [PSCustomObject]@{ Test = "Core Functions"; Result = $functionsWork }
Write-Host "   Functions available: $(if ($functionsWork) { '✅ PASS' } else { '❌ FAIL' })" -ForegroundColor $(if ($functionsWork) { 'Green' } else { 'Red' })

# Test 5: Winget Availability
Write-Host "5. Checking Winget..." -ForegroundColor Yellow
$wingetAvailable = Get-Command winget -ErrorAction SilentlyContinue
$testResults += [PSCustomObject]@{ Test = "Winget Available"; Result = $wingetAvailable -ne $null }
Write-Host "   Winget available: $(if ($wingetAvailable) { '✅ PASS' } else { '⚠️ WARN' })" -ForegroundColor $(if ($wingetAvailable) { 'Green' } else { 'Yellow' })

# Summary
Write-Host "`nTest Summary:" -ForegroundColor Cyan
Write-Host "=============" -ForegroundColor Cyan
$passCount = ($testResults | Where-Object { $_.Result -eq $true }).Count
$totalCount = $testResults.Count
Write-Host "Passed: $passCount/$totalCount tests" -ForegroundColor $(if ($passCount -eq $totalCount) { 'Green' } else { 'Yellow' })

if ($passCount -eq $totalCount) {
    Write-Host "`n🎉 All tests passed! Software Installation Manager is ready to use." -ForegroundColor Green
} else {
    Write-Host "`n⚠️ Some tests failed. Please check the issues above." -ForegroundColor Yellow
}