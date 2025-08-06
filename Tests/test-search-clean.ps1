# Clean test for search functionality
# Tests search functions without excessive debug output

$scriptDirectory = Split-Path -Parent $MyInvocation.MyCommand.Path
$parentDirectory = Split-Path -Parent $scriptDirectory
$mainScriptPath = Join-Path $parentDirectory "SoftwareInstaller.ps1"

Write-Host "Loading Software Installation Manager..." -ForegroundColor Cyan
try {
    # Load only the functions, not the main execution
    $scriptContent = Get-Content $mainScriptPath -Raw
    $functionsOnly = $scriptContent -replace '# Start the navigation menu[\s\S]*', ''
    Invoke-Expression $functionsOnly
    Write-Host "✅ Script loaded successfully" -ForegroundColor Green
} catch {
    Write-Host "❌ Failed to load script: $($_.Exception.Message)" -ForegroundColor Red
    exit 1
}

Write-Host "`nTesting Search Functions:" -ForegroundColor Yellow

# Test 1: Winget Search
Write-Host "1. Testing Winget search..." -ForegroundColor Cyan
try {
    if (Get-Command winget -ErrorAction SilentlyContinue) {
        $results = Search-WingetPackage -SearchTerm "git"
        Write-Host "   Found $($results.Count) Winget results" -ForegroundColor Green
    } else {
        Write-Host "   Winget not available - skipping test" -ForegroundColor Yellow
    }
} catch {
    Write-Host "   Error: $($_.Exception.Message)" -ForegroundColor Red
}

# Test 2: GitHub Search
Write-Host "2. Testing GitHub search..." -ForegroundColor Cyan
try {
    $results = Search-GitHubRepository -SearchTerm "powershell"
    Write-Host "   Found $($results.Count) GitHub results" -ForegroundColor Green
} catch {
    Write-Host "   Error: $($_.Exception.Message)" -ForegroundColor Red
}

Write-Host "`n✅ Search tests completed!" -ForegroundColor Green