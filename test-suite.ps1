# Test Script for Software Installation Manager
Set-ExecutionPolicy -ExecutionPolicy Bypass -Scope Process -Force

Write-Host "=================================================" -ForegroundColor Cyan
Write-Host "    Testing Software Installation Manager       " -ForegroundColor Cyan
Write-Host "=================================================" -ForegroundColor Cyan
Write-Host ""

# Test 1: Check if main script exists
Write-Host "Test 1: Checking main script..." -ForegroundColor Yellow
if (Test-Path ".\SoftwareInstaller.ps1") {
    Write-Host "PASS: SoftwareInstaller.ps1 exists" -ForegroundColor Green
} else {
    Write-Host "FAIL: SoftwareInstaller.ps1 not found" -ForegroundColor Red
    exit 1
}

# Test 2: Check if JSON file exists and is valid
Write-Host "Test 2: Checking software categories JSON..." -ForegroundColor Yellow
if (Test-Path ".\software-categories.json") {
    Write-Host "PASS: software-categories.json exists" -ForegroundColor Green
    try {
        $jsonContent = Get-Content ".\software-categories.json" -Raw | ConvertFrom-Json
        $categoryCount = $jsonContent.PSObject.Properties.Count
        Write-Host "PASS: JSON file is valid - $categoryCount categories found" -ForegroundColor Green
    } catch {
        Write-Host "FAIL: JSON file is invalid: $($_.Exception.Message)" -ForegroundColor Red
        exit 1
    }
} else {
    Write-Host "FAIL: software-categories.json not found" -ForegroundColor Red
    exit 1
}

# Test 3: Load the script and check basic functions
Write-Host "Test 3: Loading script and testing functions..." -ForegroundColor Yellow
try {
    . ".\SoftwareInstaller.ps1"
    Write-Host "PASS: Script loaded successfully" -ForegroundColor Green
} catch {
    Write-Host "FAIL: Script failed to load: $($_.Exception.Message)" -ForegroundColor Red
    exit 1
}

# Test 4: Check software categories
Write-Host "Test 4: Checking software categories..." -ForegroundColor Yellow
if ($softwareCategories -and $softwareCategories.Count -gt 0) {
    Write-Host "PASS: Software categories loaded: $($softwareCategories.Count) categories" -ForegroundColor Green
    
    foreach ($categoryName in $softwareCategories.Keys) {
        $subcategoryCount = $softwareCategories[$categoryName].Keys.Count
        Write-Host "   - $categoryName`: $subcategoryCount subcategories" -ForegroundColor Gray
    }
} else {
    Write-Host "FAIL: Software categories not loaded or empty" -ForegroundColor Red
    exit 1
}

# Test 5: Check if Winget is available
Write-Host "Test 5: Checking Winget availability..." -ForegroundColor Yellow
if (Get-Command winget -ErrorAction SilentlyContinue) {
    Write-Host "PASS: Winget is available" -ForegroundColor Green
} else {
    Write-Host "WARN: Winget not available (some features may not work)" -ForegroundColor Yellow
}

# Test 6: Test core functions
Write-Host "Test 6: Testing core functions..." -ForegroundColor Yellow
try {
    $functions = @('Get-InstalledSoftware', 'Search-WingetPackages', 'Search-GitHubRepositories')
    foreach ($func in $functions) {
        if (Get-Command $func -ErrorAction SilentlyContinue) {
            Write-Host "PASS: $func function available" -ForegroundColor Green
        } else {
            Write-Host "FAIL: $func function not found" -ForegroundColor Red
        }
    }
} catch {
    Write-Host "FAIL: Error testing functions: $($_.Exception.Message)" -ForegroundColor Red
}

Write-Host ""
Write-Host "=================================================" -ForegroundColor Green
Write-Host "           All Tests Completed!                " -ForegroundColor Green
Write-Host "=================================================" -ForegroundColor Green
Write-Host ""
Write-Host "Your Software Installation Manager is ready to use!" -ForegroundColor Cyan
Write-Host "Run: .\SoftwareInstaller.ps1" -ForegroundColor White
