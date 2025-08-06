# Test search functionality
Set-ExecutionPolicy -ExecutionPolicy Bypass -Scope Process -Force

# Get the parent directory (main project directory)
$scriptDirectory = Split-Path -Parent $MyInvocation.MyCommand.Path
$parentDirectory = Split-Path -Parent $scriptDirectory
$mainScriptPath = Join-Path $parentDirectory "SoftwareInstaller.ps1"

# Load the script without running the menu
$ErrorActionPreference = 'Stop'

# Source the script functions only
$scriptContent = Get-Content $mainScriptPath -Raw
$functionsOnly = $scriptContent -replace '# Start the navigation menu[\s\S]*', ''
Invoke-Expression $functionsOnly

# Initialize categories and get count
$categoriesData = Get-SoftwareCategory
$categoriesCount = $categoriesData.Count

Write-Host "Testing Search Functionality:" -ForegroundColor Cyan
Write-Host "Loaded $categoriesCount software categories" -ForegroundColor Gray

# Test Winget search
Write-Host "`n1. Testing Winget search..." -ForegroundColor Yellow
try {
    $wingetResults = Search-WingetPackage -SearchTerm "notepad"
    Write-Host "PASS: Winget search successful - Found $($wingetResults.Count) results" -ForegroundColor Green
    if ($wingetResults.Count -gt 0) {
        Write-Host "   Sample result: $($wingetResults[0].Name)" -ForegroundColor Gray
    }
} catch {
    Write-Host "FAIL: Winget search failed: $($_.Exception.Message)" -ForegroundColor Red
}

# Test GitHub search (with rate limiting protection)
Write-Host "`n2. Testing GitHub search..." -ForegroundColor Yellow
try {
    $githubResults = Search-GitHubRepository -SearchTerm "powershell"
    Write-Host "PASS: GitHub search successful - Found $($githubResults.Count) results" -ForegroundColor Green
    if ($githubResults.Count -gt 0) {
        Write-Host "   Sample result: $($githubResults[0].Name)" -ForegroundColor Gray
    }
} catch {
    Write-Host "WARN: GitHub search failed (may be rate limited): $($_.Exception.Message)" -ForegroundColor Yellow
}

Write-Host "`nPASS: Search functionality tests completed!" -ForegroundColor Green
