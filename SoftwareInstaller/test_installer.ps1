# Test version without auto-elevation
# ReinstallSoftware.ps1 - Test Version
# Interactive console script to select and reinstall software after Windows 11 fresh install.

# Parameters
param (
    [string]$JsonPath = "apps.json",  # Optional Winget export file
    [string]$DownloadDir = "$env:TEMP\Installers",  # Temp folder for downloads
    [string]$LogPath = "reinstall_log.txt"  # Log file
)

Write-Host "=== TESTING MODE - ADMIN CHECK DISABLED ===" -ForegroundColor Yellow

# Create download directory if needed
if (-not (Test-Path $DownloadDir)) {
    New-Item -ItemType Directory -Path $DownloadDir | Out-Null
}

# Function to get all installed software on the system
function Get-InstalledSoftware {
    param (
        [switch]$ExportToFile,
        [string]$ExportPath = "installed_software.json"
    )
    
    Write-Host "Scanning installed software..." -ForegroundColor Yellow
    $allSoftware = @()
    
    # Get software from Windows Registry (Uninstall keys)
    Write-Host "  - Scanning Windows Registry..." -ForegroundColor Gray
    $registryPaths = @(
        "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall\*",
        "HKLM:\SOFTWARE\WOW6432Node\Microsoft\Windows\CurrentVersion\Uninstall\*",
        "HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall\*"
    )
    
    foreach ($path in $registryPaths) {
        try {
            Get-ItemProperty $path -ErrorAction SilentlyContinue | 
            Where-Object { $_.DisplayName -and $_.DisplayName -notmatch "^(KB|Security Update|Update for)" } |
            ForEach-Object {
                $allSoftware += [PSCustomObject]@{
                    Name = $_.DisplayName
                    Version = $_.DisplayVersion
                    Publisher = $_.Publisher
                    InstallDate = $_.InstallDate
                    Source = "Registry"
                    UninstallString = $_.UninstallString
                }
            }
        } catch {
            Write-Warning "Could not access registry path: $path"
        }
    }
    
    # Test winget without actually running it in test mode
    if (Get-Command winget -ErrorAction SilentlyContinue) {
        Write-Host "  - Winget is available (skipping scan in test mode)" -ForegroundColor Gray
    } else {
        Write-Host "  - Winget not available" -ForegroundColor Gray
    }
    
    # Get PowerShell modules
    Write-Host "  - Scanning PowerShell modules..." -ForegroundColor Gray
    try {
        Get-Module -ListAvailable | Select-Object -First 10 | ForEach-Object {
            $allSoftware += [PSCustomObject]@{
                Name = "PowerShell Module: $($_.Name)"
                Version = $_.Version.ToString()
                Publisher = $_.Author
                InstallDate = $null
                Source = "PowerShell"
                ModulePath = $_.ModuleBase
            }
        }
    } catch {
        Write-Warning "Could not retrieve PowerShell modules: $($_.Exception.Message)"
    }
    
    # Remove duplicates and sort
    $uniqueSoftware = $allSoftware | Sort-Object Name -Unique
    
    Write-Host "Found $($uniqueSoftware.Count) installed software packages" -ForegroundColor Green
    
    if ($ExportToFile) {
        $uniqueSoftware | ConvertTo-Json -Depth 3 | Out-File $ExportPath -Encoding UTF8
        Write-Host "Software list exported to: $ExportPath" -ForegroundColor Green
    }
    
    return $uniqueSoftware
}

# ===== MAIN MENU =====
Write-Host "`n======================================" -ForegroundColor Cyan
Write-Host "   Software Installation Manager (TEST)" -ForegroundColor Cyan  
Write-Host "======================================" -ForegroundColor Cyan

Write-Host "`nChoose an option:" -ForegroundColor Yellow
Write-Host "1. Show currently installed software"
Write-Host "2. Test software definitions"
Write-Host "3. Export software list to file"
Write-Host "q. Quit"

$mainChoice = Read-Host "`nEnter your choice (1, 2, 3, or q)"

switch ($mainChoice) {
    "1" {
        Write-Host "`nScanning your system for installed software..." -ForegroundColor Cyan
        $installedSoftware = Get-InstalledSoftware
        
        Write-Host "`nInstalled Software (showing first 20):" -ForegroundColor Cyan
        $installedSoftware | Select-Object -First 20 | Format-Table Name, Version, Publisher, Source -AutoSize
        
        if ($installedSoftware.Count -gt 20) {
            Write-Host "... and $($installedSoftware.Count - 20) more packages" -ForegroundColor Gray
        }
        exit
    }
    
    "2" {
        Write-Host "`nTesting software definitions..." -ForegroundColor Cyan
        $testList = @(
            @{Name = "Google Chrome"; Type = "Winget"; Id = "Google.Chrome" },
            @{Name = "7-Zip"; Type = "Winget"; Id = "7zip.7zip" },
            @{Name = "Test MSI"; Type = "MSI"; Url = "https://example.com/test.msi"; Arguments = @("/quiet") }
        )
        
        Write-Host "Test software list:" -ForegroundColor Green
        for ($i = 0; $i -lt $testList.Count; $i++) {
            Write-Host "$($i+1). [$($testList[$i].Type)] $($testList[$i].Name)"
        }
        exit
    }
    
    "3" {
        Write-Host "`nExporting software list..." -ForegroundColor Cyan
        $installedSoftware = Get-InstalledSoftware -ExportToFile -ExportPath "test_export_$(Get-Date -Format 'yyyyMMdd_HHmmss').json"
        Write-Host "Export completed!" -ForegroundColor Green
        exit
    }
    
    "q" { 
        Write-Host "Goodbye!" -ForegroundColor Green
        exit 
    }
    
    default {
        Write-Host "Invalid choice." -ForegroundColor Yellow
        exit
    }
}
