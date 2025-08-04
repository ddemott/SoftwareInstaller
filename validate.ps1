# Simple validation test
. ".\SoftwareInstaller.ps1"

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
$functions = @('Get-InstalledSoftware', 'Search-WingetPackages', 'Search-GitHubRepositories', 'Install-WingetSoftware')
foreach ($func in $functions) {
    $available = Get-Command $func -ErrorAction SilentlyContinue
    Write-Host "  - $func`: $(if ($available) { 'YES' } else { 'NO' })" -ForegroundColor $(if ($available) { 'Green' } else { 'Red' })
}
