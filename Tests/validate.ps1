# Simple validation test
$scriptDirectory = Split-Path -Parent $MyInvocation.MyCommand.Path
$parentDirectory = Split-Path -Parent $scriptDirectory
$mainScriptPath = Join-Path $parentDirectory "SoftwareInstaller.ps1"

# Load only the functions, not the main execution
$scriptContent = Get-Content $mainScriptPath -Raw
$functionsOnly = $scriptContent -replace '# Start the navigation menu[\s\S]*', ''
Invoke-Expression $functionsOnly

Write-Host "Validation Results:" -ForegroundColor Cyan
Write-Host "- Script loaded: SUCCESS" -ForegroundColor Green
Write-Host "- Categories count: $($softwareCategories.Count)" -ForegroundColor Green
Write-Host "- Winget available: $(if (Get-Command winget -ErrorAction SilentlyContinue) { 'YES' } else { 'NO' })" -ForegroundColor Green

Write-Host "`nCategories available:" -ForegroundColor Yellow
$softwareCategories.Keys | Sort-Object | ForEach-Object {
    $subCount = $softwareCategories[$_].Keys.Count
    Write-Host "  - $_`: $subCount subcategories" -ForegroundColor White
}

Write-Host "`nCore functions available:" -ForegroundColor Yellow
$functions = @('Get-InstalledSoftware', 'Search-WingetPackage', 'Search-GitHubRepository', 'Install-WingetSoftware')
foreach ($func in $functions) {
    $available = Get-Command $func -ErrorAction SilentlyContinue
    Write-Host "  - $func`: $(if ($available) { 'YES' } else { 'NO' })" -ForegroundColor $(if ($available) { 'Green' } else { 'Red' })
}
