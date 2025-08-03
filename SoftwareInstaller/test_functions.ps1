# Test script to isolate function issues
param (
    [string]$DownloadDir = "$env:TEMP\Installers",
    [string]$LogPath = "test_log.txt"
)

# Simple test function
function Test-GetInstalledSoftware {
    Write-Host "Testing Get-InstalledSoftware function..." -ForegroundColor Yellow
    $allSoftware = @()
    
    # Test registry access
    Write-Host "  - Testing registry access..." -ForegroundColor Gray
    try {
        $testPath = "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall\*"
        $items = Get-ItemProperty $testPath -ErrorAction SilentlyContinue | 
                 Where-Object { $_.DisplayName } | 
                 Select-Object -First 3
        
        foreach ($item in $items) {
            $allSoftware += [PSCustomObject]@{
                Name = $item.DisplayName
                Version = $item.DisplayVersion
                Publisher = $item.Publisher
                Source = "Registry"
            }
        }
        Write-Host "Registry access: SUCCESS - Found $($items.Count) items" -ForegroundColor Green
    } catch {
        Write-Host "Registry access: FAILED - $($_.Exception.Message)" -ForegroundColor Red
    }
    
    # Test winget
    Write-Host "  - Testing winget access..." -ForegroundColor Gray
    try {
        if (Get-Command winget -ErrorAction SilentlyContinue) {
            Write-Host "Winget: AVAILABLE" -ForegroundColor Green
        } else {
            Write-Host "Winget: NOT AVAILABLE" -ForegroundColor Yellow
        }
    } catch {
        Write-Host "Winget test: FAILED - $($_.Exception.Message)" -ForegroundColor Red
    }
    
    return $allSoftware
}

# Run the test
$result = Test-GetInstalledSoftware
Write-Host "`nTest completed. Found $($result.Count) software items." -ForegroundColor Cyan
$result | Format-Table -AutoSize
