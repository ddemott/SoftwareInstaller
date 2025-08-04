# ===== CRYSTALDISKINFO VERIFICATION TEST =====
# Test script to verify CrystalDiskInfo and CrystalDiskInfo Portable are in the software categories

param(
    [switch]$Verbose
)

Write-Host "╔══════════════════════════════════════════════════╗" -ForegroundColor Cyan
Write-Host "║         CrystalDiskInfo Verification Test        ║" -ForegroundColor Cyan
Write-Host "╚══════════════════════════════════════════════════╝" -ForegroundColor Cyan
Write-Host ""

# Get the directory where this script is located
$scriptDirectory = Split-Path -Parent $MyInvocation.MyCommand.Path
$jsonPath = Join-Path $scriptDirectory "software-categories.json"

Write-Host "Testing file: $jsonPath" -ForegroundColor Gray
Write-Host ""

# Test 1: Check if JSON file exists
Write-Host "TEST 1: Checking if software-categories.json exists..." -ForegroundColor Yellow
if (Test-Path $jsonPath) {
    Write-Host "✅ PASS: JSON file exists" -ForegroundColor Green
} else {
    Write-Host "❌ FAIL: JSON file not found" -ForegroundColor Red
    exit 1
}

# Test 2: Load and parse JSON
Write-Host "TEST 2: Loading and parsing JSON..." -ForegroundColor Yellow
try {
    $jsonContent = Get-Content -Path $jsonPath -Raw -Encoding UTF8
    $categories = $jsonContent | ConvertFrom-Json
    Write-Host "✅ PASS: JSON loaded and parsed successfully" -ForegroundColor Green
} catch {
    Write-Host "❌ FAIL: Error loading JSON: $($_.Exception.Message)" -ForegroundColor Red
    exit 1
}

# Test 3: Check if Utilities category exists
Write-Host "TEST 3: Checking if Utilities category exists..." -ForegroundColor Yellow
if ($categories.PSObject.Properties.Name -contains "Utilities") {
    Write-Host "✅ PASS: Utilities category found" -ForegroundColor Green
} else {
    Write-Host "❌ FAIL: Utilities category not found" -ForegroundColor Red
    Write-Host "Available categories:" -ForegroundColor Gray
    $categories.PSObject.Properties.Name | ForEach-Object { Write-Host "  - $_" -ForegroundColor Gray }
    exit 1
}

# Test 4: Check if System Tools subcategory exists
Write-Host "TEST 4: Checking if System Tools subcategory exists..." -ForegroundColor Yellow
if ($categories.Utilities.PSObject.Properties.Name -contains "System Tools") {
    Write-Host "✅ PASS: System Tools subcategory found" -ForegroundColor Green
} else {
    Write-Host "❌ FAIL: System Tools subcategory not found" -ForegroundColor Red
    Write-Host "Available subcategories in Utilities:" -ForegroundColor Gray
    $categories.Utilities.PSObject.Properties.Name | ForEach-Object { Write-Host "  - $_" -ForegroundColor Gray }
    exit 1
}

# Test 5: Check for CrystalDiskInfo regular version
Write-Host "TEST 5: Checking for CrystalDiskInfo regular version..." -ForegroundColor Yellow
$systemTools = $categories.Utilities."System Tools"
$crystalDiskInfo = $systemTools | Where-Object { $_.Name -eq "CrystalDiskInfo" }

if ($crystalDiskInfo) {
    Write-Host "✅ PASS: CrystalDiskInfo found" -ForegroundColor Green
    if ($Verbose) {
        Write-Host "   Name: $($crystalDiskInfo.Name)" -ForegroundColor Gray
        Write-Host "   Type: $($crystalDiskInfo.Type)" -ForegroundColor Gray
        Write-Host "   Id: $($crystalDiskInfo.Id)" -ForegroundColor Gray
        Write-Host "   Description: $($crystalDiskInfo.Description)" -ForegroundColor Gray
    }
} else {
    Write-Host "❌ FAIL: CrystalDiskInfo not found" -ForegroundColor Red
}

# Test 6: Check for CrystalDiskInfo Portable
Write-Host "TEST 6: Checking for CrystalDiskInfo Portable..." -ForegroundColor Yellow
$crystalDiskInfoPortable = $systemTools | Where-Object { $_.Name -eq "CrystalDiskInfo Portable" }

if ($crystalDiskInfoPortable) {
    Write-Host "✅ PASS: CrystalDiskInfo Portable found" -ForegroundColor Green
    if ($Verbose) {
        Write-Host "   Name: $($crystalDiskInfoPortable.Name)" -ForegroundColor Gray
        Write-Host "   Type: $($crystalDiskInfoPortable.Type)" -ForegroundColor Gray
        Write-Host "   Repository: $($crystalDiskInfoPortable.Repository)" -ForegroundColor Gray
        Write-Host "   AssetPattern: $($crystalDiskInfoPortable.AssetPattern)" -ForegroundColor Gray
        Write-Host "   Description: $($crystalDiskInfoPortable.Description)" -ForegroundColor Gray
    }
} else {
    Write-Host "❌ FAIL: CrystalDiskInfo Portable not found" -ForegroundColor Red
}

# Test 7: Show all software in System Tools if verbose
if ($Verbose) {
    Write-Host ""
    Write-Host "ALL SOFTWARE IN SYSTEM TOOLS:" -ForegroundColor Cyan
    Write-Host "==============================" -ForegroundColor Cyan
    for ($i = 0; $i -lt $systemTools.Count; $i++) {
        $software = $systemTools[$i]
        Write-Host "$($i + 1). $($software.Name)" -ForegroundColor White
        Write-Host "   Description: $($software.Description)" -ForegroundColor Gray
        if ($software.Id) { Write-Host "   ID: $($software.Id)" -ForegroundColor Gray }
        if ($software.Repository) { Write-Host "   Repository: $($software.Repository)" -ForegroundColor Gray }
        Write-Host ""
    }
}

# Summary
Write-Host ""
Write-Host "╔═══════════════════════════════════════════════════╗"
Write-Host "║                   TEST SUMMARY                    ║"
Write-Host "╚═══════════════════════════════════════════════════╝"

$foundRegular = $null -ne $crystalDiskInfo
$foundPortable = $null -ne $crystalDiskInfoPortable

if ($foundRegular -and $foundPortable) {
    Write-Host "🎉 SUCCESS: Both CrystalDiskInfo versions found!" -ForegroundColor Green
    Write-Host "   - CrystalDiskInfo (Winget): ✅ FOUND" -ForegroundColor Green
    Write-Host "   - CrystalDiskInfo Portable (GitHub): ✅ FOUND" -ForegroundColor Green
} elseif ($foundRegular -or $foundPortable) {
    Write-Host "⚠️  PARTIAL: Only one CrystalDiskInfo version found!" -ForegroundColor Yellow
    Write-Host "   - CrystalDiskInfo (Winget): $(if ($foundRegular) { '✅ FOUND' } else { '❌ MISSING' })" -ForegroundColor $(if ($foundRegular) { 'Green' } else { 'Red' })
    Write-Host "   - CrystalDiskInfo Portable (GitHub): $(if ($foundPortable) { '✅ FOUND' } else { '❌ MISSING' })" -ForegroundColor $(if ($foundPortable) { 'Green' } else { 'Red' })
} else {
    Write-Host "❌ FAILURE: Neither CrystalDiskInfo version found!" -ForegroundColor Red
    Write-Host "   - CrystalDiskInfo (Winget): ❌ MISSING" -ForegroundColor Red
    Write-Host "   - CrystalDiskInfo Portable (GitHub): ❌ MISSING" -ForegroundColor Red
}

Write-Host "Use -Verbose flag to see detailed information about all System Tools software."
