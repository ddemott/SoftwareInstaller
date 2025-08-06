# GitHub Repository Availability Test
# Tests all GitHub repositories in the catalog

$scriptDirectory = Split-Path -Parent $MyInvocation.MyCommand.Path
$parentDirectory = Split-Path -Parent $scriptDirectory
$jsonPath = Join-Path $parentDirectory "software-categories.json"

Write-Host "GitHub Repository Availability Test" -ForegroundColor Cyan
Write-Host "===================================" -ForegroundColor Cyan

# Load the software categories
try {
    $jsonContent = Get-Content $jsonPath -Raw -Encoding UTF8
    $categories = $jsonContent | ConvertFrom-Json
} catch {
    Write-Host "❌ Failed to load software catalog: $($_.Exception.Message)" -ForegroundColor Red
    exit 1
}

$githubPackages = @()
$testResults = @()

# Collect all GitHub packages
foreach ($categoryName in $categories.PSObject.Properties.Name) {
    $category = $categories.$categoryName
    
    foreach ($subcategoryName in $category.PSObject.Properties.Name) {
        $subcategory = $category.$subcategoryName
        
        foreach ($software in $subcategory) {
            if ($software.Type -eq "GitHub" -or ($software.Type -eq "CustomInstall" -and $software.Repository)) {
                $githubPackages += [PSCustomObject]@{
                    Name = $software.Name
                    Repository = $software.Repository
                    Type = $software.Type
                    Category = $categoryName
                    Subcategory = $subcategoryName
                    AssetPattern = $software.AssetPattern
                    Description = $software.Description
                }
            }
        }
    }
}

Write-Host "Found $($githubPackages.Count) GitHub repositories to test" -ForegroundColor Yellow
Write-Host "Testing repository accessibility and releases..." -ForegroundColor Gray
Write-Host ""

$progressCount = 0
foreach ($package in $githubPackages) {
    $progressCount++
    $progressPercent = [Math]::Round(($progressCount / $githubPackages.Count) * 100, 1)
    
    Write-Host "[$progressPercent%] Testing: $($package.Name)" -ForegroundColor Gray
    Write-Host "  Repository: $($package.Repository)" -ForegroundColor DarkGray
    
    try {
        # Test repository accessibility
        $apiUrl = "https://api.github.com/repos/$($package.Repository)"
        $response = Invoke-RestMethod -Uri $apiUrl -UseBasicParsing -TimeoutSec 15
        
        if ($response.id) {
            # Repository exists, now check for releases
            $releasesUrl = "https://api.github.com/repos/$($package.Repository)/releases"
            
            try {
                $releases = Invoke-RestMethod -Uri $releasesUrl -UseBasicParsing -TimeoutSec 15
                
                if ($releases.Count -gt 0) {
                    $latestRelease = $releases[0]
                    $hasAssets = $latestRelease.assets -and $latestRelease.assets.Count -gt 0
                    
                    # Check if there are matching assets for the pattern
                    $matchingAssets = @()
                    if ($hasAssets -and $package.AssetPattern) {
                        $matchingAssets = $latestRelease.assets | Where-Object { $_.name -match $package.AssetPattern }
                    }
                    
                    $status = "PASS"
                    $message = "Repository accessible with $($releases.Count) releases"
                    
                    if (-not $hasAssets) {
                        $status = "WARN"
                        $message = "Repository found with releases but no assets"
                    } elseif ($package.AssetPattern -and $matchingAssets.Count -eq 0) {
                        $status = "WARN"
                        $message = "Repository found but no assets match pattern: $($package.AssetPattern)"
                    } elseif ($package.AssetPattern -and $matchingAssets.Count -gt 0) {
                        $message = "Repository found with $($matchingAssets.Count) matching assets"
                    }
                    
                    $testResults += [PSCustomObject]@{
                        Name = $package.Name
                        Repository = $package.Repository
                        Type = $package.Type
                        Category = $package.Category
                        Subcategory = $package.Subcategory
                        Status = $status
                        Message = $message
                        ReleaseCount = $releases.Count
                        LatestVersion = $latestRelease.tag_name
                        HasAssets = $hasAssets
                        MatchingAssets = $matchingAssets.Count
                    }
                    
                    Write-Host "  ✅ $message" -ForegroundColor Green
                    if ($package.AssetPattern) {
                        Write-Host "    Pattern: $($package.AssetPattern) → $($matchingAssets.Count) matches" -ForegroundColor DarkGray
                    }
                } else {
                    $testResults += [PSCustomObject]@{
                        Name = $package.Name
                        Repository = $package.Repository
                        Type = $package.Type
                        Category = $package.Category
                        Subcategory = $package.Subcategory
                        Status = "WARN"
                        Message = "Repository found but no releases"
                        ReleaseCount = 0
                        HasAssets = $false
                        MatchingAssets = 0
                    }
                    Write-Host "  ⚠️ No releases found" -ForegroundColor Yellow
                }
            } catch {
                $testResults += [PSCustomObject]@{
                    Name = $package.Name
                    Repository = $package.Repository
                    Type = $package.Type
                    Category = $package.Category
                    Subcategory = $package.Subcategory
                    Status = "WARN"
                    Message = "Repository accessible but releases check failed"
                    ReleaseCount = -1
                    HasAssets = $false
                    MatchingAssets = 0
                }
                Write-Host "  ⚠️ Releases check failed" -ForegroundColor Yellow
            }
        } else {
            $testResults += [PSCustomObject]@{
                Name = $package.Name
                Repository = $package.Repository
                Type = $package.Type
                Category = $package.Category
                Subcategory = $package.Subcategory
                Status = "FAIL"
                Message = "Repository not found or not accessible"
                ReleaseCount = 0
                HasAssets = $false
                MatchingAssets = 0
            }
            Write-Host "  ❌ Repository not accessible" -ForegroundColor Red
        }
    } catch {
        $errorMsg = if ($_.Exception.Message -like "*rate limit*") {
            "GitHub API rate limit exceeded"
        } elseif ($_.Exception.Message -like "*404*") {
            "Repository not found (404)"
        } else {
            "API error: $($_.Exception.Message)"
        }
        
        $testResults += [PSCustomObject]@{
            Name = $package.Name
            Repository = $package.Repository
            Type = $package.Type
            Category = $package.Category
            Subcategory = $package.Subcategory
            Status = "ERROR"
            Message = $errorMsg
            ReleaseCount = 0
            HasAssets = $false
            MatchingAssets = 0
        }
        Write-Host "  ⚠️ $errorMsg" -ForegroundColor Red
    }
    
    # Delay to avoid GitHub API rate limiting
    Start-Sleep -Milliseconds 1000
}

# Generate report
Write-Host ""
Write-Host "GITHUB REPOSITORY REPORT" -ForegroundColor Cyan
Write-Host "========================" -ForegroundColor Cyan

$passCount = ($testResults | Where-Object { $_.Status -eq "PASS" }).Count
$warnCount = ($testResults | Where-Object { $_.Status -eq "WARN" }).Count
$failCount = ($testResults | Where-Object { $_.Status -eq "FAIL" }).Count
$errorCount = ($testResults | Where-Object { $_.Status -eq "ERROR" }).Count

Write-Host "Total Tested: $($githubPackages.Count)" -ForegroundColor White
Write-Host "✅ Fully Available: $passCount" -ForegroundColor Green
Write-Host "⚠️ Available (Issues): $warnCount" -ForegroundColor Yellow
Write-Host "❌ Not Found: $failCount" -ForegroundColor Red
Write-Host "⚠️ Errors: $errorCount" -ForegroundColor Red

$accessibleCount = $passCount + $warnCount
$accessRate = [Math]::Round(($accessibleCount / $githubPackages.Count) * 100, 2)
Write-Host "Repository Access Rate: $accessRate%" -ForegroundColor $(if ($accessRate -ge 95) { "Green" } elseif ($accessRate -ge 80) { "Yellow" } else { "Red" })

# Show repositories with issues
if ($failCount -gt 0 -or $errorCount -gt 0 -or $warnCount -gt 0) {
    Write-Host ""
    Write-Host "REPOSITORIES WITH ISSUES:" -ForegroundColor Red
    Write-Host "=========================" -ForegroundColor Red
    
    $issues = $testResults | Where-Object { $_.Status -in @("FAIL", "ERROR", "WARN") } | Sort-Object Status, Category, Name
    
    foreach ($issue in $issues) {
        $statusColor = switch ($issue.Status) {
            "FAIL" { "Red" }
            "ERROR" { "Red" }
            "WARN" { "Yellow" }
        }
        
        Write-Host ""
        Write-Host "$($issue.Status): $($issue.Name)" -ForegroundColor $statusColor
        Write-Host "  Repository: https://github.com/$($issue.Repository)" -ForegroundColor Gray
        Write-Host "  Category: $($issue.Category) → $($issue.Subcategory)" -ForegroundColor Gray
        Write-Host "  Issue: $($issue.Message)" -ForegroundColor DarkGray
        
        if ($issue.ReleaseCount -gt 0) {
            Write-Host "  Releases: $($issue.ReleaseCount)" -ForegroundColor DarkGray
        }
    }
}

# Show asset pattern analysis
Write-Host ""
Write-Host "ASSET PATTERN ANALYSIS:" -ForegroundColor Cyan
Write-Host "=======================" -ForegroundColor Cyan

$withPatterns = $testResults | Where-Object { $_.Type -eq "GitHub" -and $githubPackages | Where-Object { $_.Repository -eq $_.Repository -and $_.AssetPattern } }
$patternsWorking = $withPatterns | Where-Object { $_.MatchingAssets -gt 0 }

Write-Host "Repositories with asset patterns: $($withPatterns.Count)" -ForegroundColor White
Write-Host "Patterns working correctly: $($patternsWorking.Count)" -ForegroundColor Green

if ($withPatterns.Count -gt $patternsWorking.Count) {
    Write-Host ""
    Write-Host "Asset patterns with issues:" -ForegroundColor Yellow
    $patternIssues = $withPatterns | Where-Object { $_.MatchingAssets -eq 0 -and $_.Status -ne "FAIL" }
    foreach ($issue in $patternIssues) {
        $packageInfo = $githubPackages | Where-Object { $_.Repository -eq $issue.Repository }
        Write-Host "  $($issue.Name): $($packageInfo.AssetPattern)" -ForegroundColor Yellow
    }
}

# Export results
$timestamp = Get-Date -Format "yyyyMMdd_HHmmss"
$reportPath = Join-Path $parentDirectory "github_availability_report_$timestamp.json"
$testResults | ConvertTo-Json -Depth 3 | Out-File -FilePath $reportPath -Encoding UTF8

Write-Host ""
Write-Host "Detailed report saved to: $reportPath" -ForegroundColor Cyan
Write-Host ""
Write-Host "GitHub repository test completed!" -ForegroundColor Cyan
