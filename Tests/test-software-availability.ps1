# Comprehensive Software Availability Test
# Tests all software entries in the catalog to verify they can be found

$scriptDirectory = Split-Path -Parent $MyInvocation.MyCommand.Path
$parentDirectory = Split-Path -Parent $scriptDirectory
$jsonPath = Join-Path $parentDirectory "software-categories.json"

# Load the software categories
Write-Host "Loading software catalog..." -ForegroundColor Cyan
try {
    $jsonContent = Get-Content $jsonPath -Raw -Encoding UTF8
    $categories = $jsonContent | ConvertFrom-Json
} catch {
    Write-Host "❌ Failed to load software catalog: $($_.Exception.Message)" -ForegroundColor Red
    exit 1
}

# Test results storage
$testResults = @()
$totalSoftware = 0
$wingetAvailable = Get-Command winget -ErrorAction SilentlyContinue

Write-Host "Starting comprehensive software availability test..." -ForegroundColor Yellow
Write-Host "This may take several minutes due to network calls..." -ForegroundColor Gray
Write-Host "Note: GitHub repositories may be rate-limited, affecting some results." -ForegroundColor Gray
Write-Host ""

# Function to test Winget package
function Test-WingetPackage {
    param([string]$Id, [string]$Name)
    
    if (-not $wingetAvailable) {
        return [PSCustomObject]@{
            Name = $Name
            Type = "Winget"
            Id = $Id
            Status = "SKIP"
            Message = "Winget not available"
        }
    }
    
    try {
        Write-Host "  Testing Winget: $Name..." -ForegroundColor Gray
        winget show --id $Id --accept-source-agreements 2>$null | Out-Null
        
        if ($LASTEXITCODE -eq 0) {
            return [PSCustomObject]@{
                Name = $Name
                Type = "Winget"
                Id = $Id
                Status = "PASS"
                Message = "Package found"
            }
        } else {
            return [PSCustomObject]@{
                Name = $Name
                Type = "Winget"
                Id = $Id
                Status = "FAIL"
                Message = "Package not found in Winget"
            }
        }
    } catch {
        return [PSCustomObject]@{
            Name = $Name
            Type = "Winget"
            Id = $Id
            Status = "ERROR"
            Message = $_.Exception.Message
        }
    }
}

# Function to test GitHub repository
function Test-GitHubRepository {
    param([string]$Repository, [string]$Name)
    
    try {
        Write-Host "  Testing GitHub: $Name..." -ForegroundColor Gray
        $apiUrl = "https://api.github.com/repos/$Repository"
        
        # Add retry logic for rate limiting
        $maxRetries = 3
        $retryDelay = 2
        $response = $null
        
        for ($retry = 1; $retry -le $maxRetries; $retry++) {
            try {
                $response = Invoke-RestMethod -Uri $apiUrl -UseBasicParsing -TimeoutSec 15
                break
            } catch {
                if ($_.Exception.Message -like "*403*" -and $retry -lt $maxRetries) {
                    Write-Host "    Rate limited, retrying in $retryDelay seconds..." -ForegroundColor Yellow
                    Start-Sleep -Seconds $retryDelay
                    $retryDelay *= 2  # Exponential backoff
                    continue
                } else {
                    throw
                }
            }
        }
        
        if ($response -and $response.id) {
            # Check if repository has releases with retry logic
            $releasesUrl = "https://api.github.com/repos/$Repository/releases/latest"
            try {
                $latestRelease = $null
                for ($retry = 1; $retry -le $maxRetries; $retry++) {
                    try {
                        $latestRelease = Invoke-RestMethod -Uri $releasesUrl -UseBasicParsing -TimeoutSec 15
                        break
                    } catch {
                        if ($_.Exception.Message -like "*403*" -and $retry -lt $maxRetries) {
                            Start-Sleep -Seconds 1
                            continue
                        } elseif ($_.Exception.Message -like "*404*") {
                            # No releases found, this is normal
                            break
                        } else {
                            throw
                        }
                    }
                }
                
                $hasReleases = $null -ne $latestRelease.tag_name
                
                return [PSCustomObject]@{
                    Name = $Name
                    Type = "GitHub"
                    Repository = $Repository
                    Status = "PASS"
                    Message = if ($hasReleases) { "Repository found with releases" } else { "Repository found (no releases)" }
                }
            } catch {
                return [PSCustomObject]@{
                    Name = $Name
                    Type = "GitHub"
                    Repository = $Repository
                    Status = "WARN"
                    Message = "Repository found but releases check failed: $($_.Exception.Message)"
                }
            }
        } else {
            return [PSCustomObject]@{
                Name = $Name
                Type = "GitHub"
                Repository = $Repository
                Status = "FAIL"
                Message = "Repository not found"
            }
        }
    } catch {
        # Handle specific error cases
        if ($_.Exception.Message -like "*403*") {
            return [PSCustomObject]@{
                Name = $Name
                Type = "GitHub"
                Repository = $Repository
                Status = "WARN"
                Message = "GitHub API rate limited - repository may be accessible"
            }
        } elseif ($_.Exception.Message -like "*404*") {
            return [PSCustomObject]@{
                Name = $Name
                Type = "GitHub"
                Repository = $Repository
                Status = "FAIL"
                Message = "Repository not found (404)"
            }
        } else {
            return [PSCustomObject]@{
                Name = $Name
                Type = "GitHub"
                Repository = $Repository
                Status = "ERROR"
                Message = "GitHub API error: $($_.Exception.Message)"
            }
        }
    }
}

# Function to test PowerShell module
function Test-PowerShellModule {
    param([string]$ModuleName, [string]$Name)
    
    try {
        Write-Host "  Testing PS Module: $Name..." -ForegroundColor Gray
        $module = Find-Module -Name $ModuleName -Repository PSGallery -ErrorAction Stop
        
        if ($module) {
            return [PSCustomObject]@{
                Name = $Name
                Type = "PowerShellModule"
                ModuleName = $ModuleName
                Status = "PASS"
                Message = "Module found in PowerShell Gallery"
            }
        } else {
            return [PSCustomObject]@{
                Name = $Name
                Type = "PowerShellModule"
                ModuleName = $ModuleName
                Status = "FAIL"
                Message = "Module not found in PowerShell Gallery"
            }
        }
    } catch {
        return [PSCustomObject]@{
            Name = $Name
            Type = "PowerShellModule"
            ModuleName = $ModuleName
            Status = "ERROR"
            Message = $_.Exception.Message
        }
    }
}

# Function to test Custom/MSI/EXE URLs
function Test-CustomUrl {
    param([string]$Url, [string]$Name, [string]$Type)
    
    try {
        Write-Host "  Testing URL: $Name..." -ForegroundColor Gray
        
        # Use longer timeout and add retry logic for custom URLs
        $maxRetries = 2
        $response = $null
        
        for ($retry = 1; $retry -le $maxRetries; $retry++) {
            try {
                $response = Invoke-WebRequest -Uri $Url -Method Head -UseBasicParsing -TimeoutSec 20
                break
            } catch {
                if ($retry -lt $maxRetries -and ($_.Exception.Message -like "*timeout*" -or $_.Exception.Message -like "*connection*")) {
                    Write-Host "    Connection issue, retrying..." -ForegroundColor Yellow
                    Start-Sleep -Seconds 2
                    continue
                } else {
                    throw
                }
            }
        }
        
        if ($response.StatusCode -eq 200) {
            return [PSCustomObject]@{
                Name = $Name
                Type = $Type
                Url = $Url
                Status = "PASS"
                Message = "URL accessible"
            }
        } else {
            return [PSCustomObject]@{
                Name = $Name
                Type = $Type
                Url = $Url
                Status = "FAIL"
                Message = "URL returned status: $($response.StatusCode)"
            }
        }
    } catch {
        # Handle specific error cases
        if ($_.Exception.Message -like "*403*") {
            return [PSCustomObject]@{
                Name = $Name
                Type = $Type
                Url = $Url
                Status = "WARN"
                Message = "URL blocked (403) - may require authentication or be region-restricted"
            }
        } elseif ($_.Exception.Message -like "*timeout*") {
            return [PSCustomObject]@{
                Name = $Name
                Type = $Type
                Url = $Url
                Status = "WARN"
                Message = "URL timeout - server may be slow or temporarily unavailable"
            }
        } else {
            return [PSCustomObject]@{
                Name = $Name
                Type = $Type
                Url = $Url
                Status = "ERROR"
                Message = "URL not accessible: $($_.Exception.Message)"
            }
        }
    }
}

# Test all categories
$currentCount = 0
foreach ($categoryName in $categories.PSObject.Properties.Name) {
    Write-Host "Testing category: $categoryName" -ForegroundColor Cyan
    $category = $categories.$categoryName
    
    foreach ($subcategoryName in $category.PSObject.Properties.Name) {
        Write-Host " Subcategory: $subcategoryName" -ForegroundColor Yellow
        $subcategory = $category.$subcategoryName
        
        foreach ($software in $subcategory) {
            $currentCount++
            $progressPercent = [Math]::Round(($currentCount / 221) * 100, 1)
            Write-Host "  [$progressPercent%] Testing: $($software.Name)" -ForegroundColor Cyan
            $totalSoftware++
            
            switch ($software.Type) {
                "Winget" {
                    $result = Test-WingetPackage -Id $software.Id -Name $software.Name
                    $testResults += $result
                }
                "GitHub" {
                    $result = Test-GitHubRepository -Repository $software.Repository -Name $software.Name
                    $testResults += $result
                }
                "PowerShellModule" {
                    $result = Test-PowerShellModule -ModuleName $software.ModuleName -Name $software.Name
                    $testResults += $result
                }
                "Custom" {
                    $result = Test-CustomUrl -Url $software.Url -Name $software.Name -Type $software.Type
                    $testResults += $result
                }
                "MSI" {
                    $result = Test-CustomUrl -Url $software.Url -Name $software.Name -Type $software.Type
                    $testResults += $result
                }
                "EXE" {
                    $result = Test-CustomUrl -Url $software.Url -Name $software.Name -Type $software.Type
                    $testResults += $result
                }
                "CustomInstall" {
                    # For CustomInstall, test the GitHub repository
                    if ($software.Repository) {
                        $result = Test-GitHubRepository -Repository $software.Repository -Name $software.Name
                        $testResults += $result
                    } else {
                        $testResults += [PSCustomObject]@{
                            Name = $software.Name
                            Type = "CustomInstall"
                            Status = "SKIP"
                            Message = "No repository specified for CustomInstall"
                        }
                    }
                }
                default {
                    $testResults += [PSCustomObject]@{
                        Name = $software.Name
                        Type = $software.Type
                        Status = "SKIP"
                        Message = "Unknown software type"
                    }
                }
            }
            
            # Add delay based on software type to avoid rate limiting
            switch ($software.Type) {
                "GitHub" { Start-Sleep -Milliseconds 500 }  # Longer delay for GitHub API
                "Custom" { Start-Sleep -Milliseconds 200 }  # Moderate delay for custom URLs
                "MSI" { Start-Sleep -Milliseconds 200 }
                "EXE" { Start-Sleep -Milliseconds 200 }
                default { Start-Sleep -Milliseconds 100 }   # Short delay for Winget/PowerShell
            }
        }
    }
}

# Generate summary report
Write-Host ""
Write-Host "=" * 60 -ForegroundColor Cyan
Write-Host "SOFTWARE AVAILABILITY TEST RESULTS" -ForegroundColor Cyan
Write-Host "=" * 60 -ForegroundColor Cyan

$passCount = ($testResults | Where-Object { $_.Status -eq "PASS" }).Count
$failCount = ($testResults | Where-Object { $_.Status -eq "FAIL" }).Count
$errorCount = ($testResults | Where-Object { $_.Status -eq "ERROR" }).Count
$warnCount = ($testResults | Where-Object { $_.Status -eq "WARN" }).Count
$skipCount = ($testResults | Where-Object { $_.Status -eq "SKIP" }).Count

Write-Host "Total Software Tested: $totalSoftware" -ForegroundColor White
Write-Host "✅ PASS: $passCount" -ForegroundColor Green
Write-Host "❌ FAIL: $failCount" -ForegroundColor Red
Write-Host "⚠️ ERROR: $errorCount" -ForegroundColor Red
Write-Host "⚠️ WARN: $warnCount" -ForegroundColor Yellow
Write-Host "⏭️ SKIP: $skipCount" -ForegroundColor Gray
Write-Host ""

# Show failures and errors
if ($failCount -gt 0 -or $errorCount -gt 0) {
    Write-Host "ISSUES FOUND:" -ForegroundColor Red
    Write-Host "=" * 40 -ForegroundColor Red
    
    $issues = $testResults | Where-Object { $_.Status -in @("FAIL", "ERROR") }
    foreach ($issue in $issues) {
        $color = if ($issue.Status -eq "FAIL") { "Red" } else { "DarkRed" }
        Write-Host "$($issue.Status): $($issue.Name) [$($issue.Type)]" -ForegroundColor $color
        Write-Host "    $($issue.Message)" -ForegroundColor Gray
        if ($issue.Id) { Write-Host "    ID: $($issue.Id)" -ForegroundColor DarkGray }
        if ($issue.Repository) { Write-Host "    Repository: $($issue.Repository)" -ForegroundColor DarkGray }
        if ($issue.Url) { Write-Host "    URL: $($issue.Url)" -ForegroundColor DarkGray }
        Write-Host ""
    }
}

# Show warnings
if ($warnCount -gt 0) {
    Write-Host "WARNINGS:" -ForegroundColor Yellow
    Write-Host "=" * 40 -ForegroundColor Yellow
    
    $warnings = $testResults | Where-Object { $_.Status -eq "WARN" }
    foreach ($warning in $warnings) {
        Write-Host "WARN: $($warning.Name) [$($warning.Type)]" -ForegroundColor Yellow
        Write-Host "    $($warning.Message)" -ForegroundColor Gray
        Write-Host ""
    }
}

# Export detailed results
$timestamp = Get-Date -Format "yyyyMMdd_HHmmss"
$reportPath = Join-Path $parentDirectory "software_availability_report_$timestamp.json"
$testResults | ConvertTo-Json -Depth 3 | Out-File -FilePath $reportPath -Encoding UTF8

Write-Host "Detailed report saved to: $reportPath" -ForegroundColor Cyan

# Overall status
$successRate = [Math]::Round(($passCount / $totalSoftware) * 100, 2)
Write-Host ""
if ($successRate -ge 95) {
    Write-Host "🎉 EXCELLENT: $successRate% of software is available!" -ForegroundColor Green
} elseif ($successRate -ge 80) {
    Write-Host "✅ GOOD: $successRate% of software is available." -ForegroundColor Yellow
} else {
    Write-Host "⚠️ NEEDS ATTENTION: Only $successRate% of software is available." -ForegroundColor Red
}

Write-Host ""
Write-Host "Test completed!" -ForegroundColor Cyan
