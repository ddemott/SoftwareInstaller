# Simple test to check JSON content
$scriptDirectory = Split-Path -Parent $MyInvocation.MyCommand.Path
$parentDirectory = Split-Path -Parent $scriptDirectory
$jsonPath = Join-Path $parentDirectory "software-categories.json"

Write-Host "Loading JSON from: $jsonPath"

if (Test-Path $jsonPath) {
    $jsonContent = Get-Content -Path $jsonPath -Raw -Encoding UTF8
    $categories = $jsonContent | ConvertFrom-Json
    
    Write-Host "Found categories:" -ForegroundColor Green
    $categories.PSObject.Properties.Name | ForEach-Object { Write-Host "  - $_" }
    
    if ($categories.Utilities) {
        Write-Host "`nUtilities subcategories:" -ForegroundColor Green
        $categories.Utilities.PSObject.Properties.Name | ForEach-Object { Write-Host "  - $_" }
        
        if ($categories.Utilities."System Tools") {
            Write-Host "`nSystem Tools software count: $($categories.Utilities.'System Tools'.Count)" -ForegroundColor Green
            Write-Host "System Tools software:" -ForegroundColor Green
            $categories.Utilities."System Tools" | ForEach-Object { 
                Write-Host "  - $($_.Name)" -ForegroundColor Yellow
            }
        } else {
            Write-Host "`nSystem Tools category not found!" -ForegroundColor Red
        }
    } else {
        Write-Host "`nUtilities category not found!" -ForegroundColor Red
    }
} else {
    Write-Host "JSON file not found!" -ForegroundColor Red
}
