# Winget Software Availability Test
# Tests all Winget packages in the catalog

$scriptDirectory = Split-Path -Parent $MyInvocation.MyCommand.Path
$parentDirectory = Split-Path -Parent $scriptDirectory
$jsonPath = Join-Path $parentDirectory "software-categories.json"

Write-Host "Winget Software Availability Test" -ForegroundColor Cyan
Write-Host "=================================" -ForegroundColor Cyan

# Check if Winget is available
$wingetAvailable = Get-Command winget -ErrorAction SilentlyContinue
if (-not $wingetAvailable) {
    Write-Host "❌ Winget is not available on this system" -ForegroundColor Red
    Write-Host "Please install Winget to run this test" -ForegroundColor Yellow
    exit 1
}

# Load the software categories
try {
    $jsonContent = Get-Content $jsonPath -Raw -Encoding UTF8
    $categories = $jsonContent | ConvertFrom-Json
} catch {
    Write-Host "❌ Failed to load software catalog: $($_.Exception.Message)" -ForegroundColor Red
    exit 1
}

$wingetPackages = @()
$testResults = @()

# Collect all Winget packages
foreach ($categoryName in $categories.PSObject.Properties.Name) {
    $category = $categories.$categoryName
    
    foreach ($subcategoryName in $category.PSObject.Properties.Name) {
        $subcategory = $category.$subcategoryName
        
        foreach ($software in $subcategory) {
            if ($software.Type -eq "Winget") {
                $wingetPackages += [PSCustomObject]@{
                    Name = $software.Name
                    Id = $software.Id
                    Category = $categoryName
                    Subcategory = $subcategoryName
                    Description = $software.Description
                }
            }
        }
    }
}

Write-Host "Found $($wingetPackages.Count) Winget packages to test" -ForegroundColor Yellow
Write-Host "This may take several minutes..." -ForegroundColor Gray
Write-Host ""

$progressCount = 0
foreach ($package in $wingetPackages) {
    $progressCount++
    $progressPercent = [Math]::Round(($progressCount / $wingetPackages.Count) * 100, 1)
    
    Write-Host "[$progressPercent%] Testing: $($package.Name)" -ForegroundColor Gray
    
    try {
        # Test if package exists
        winget show --id $package.Id --accept-source-agreements 2>$null | Out-Null
        
        if ($LASTEXITCODE -eq 0) {
            $testResults += [PSCustomObject]@{
                Name = $package.Name
                Id = $package.Id
                Category = $package.Category
                Subcategory = $package.Subcategory
                Status = "PASS"
                Message = "Package found"
            }
            Write-Host "  ✅ Found" -ForegroundColor Green
        } else {
            $testResults += [PSCustomObject]@{
                Name = $package.Name
                Id = $package.Id
                Category = $package.Category
                Subcategory = $package.Subcategory
                Status = "FAIL"
                Message = "Package not found"
            }
            Write-Host "  ❌ Not found" -ForegroundColor Red
        }
    } catch {
        $testResults += [PSCustomObject]@{
            Name = $package.Name
            Id = $package.Id
            Category = $package.Category
            Subcategory = $package.Subcategory
            Status = "ERROR"
            Message = $_.Exception.Message
        }
        Write-Host "  ⚠️ Error" -ForegroundColor Yellow
    }
    
    # Small delay to avoid overwhelming Winget
    Start-Sleep -Milliseconds 200
}

# Generate report
Write-Host ""
Write-Host "WINGET AVAILABILITY REPORT" -ForegroundColor Cyan
Write-Host "===========================" -ForegroundColor Cyan

$passCount = ($testResults | Where-Object { $_.Status -eq "PASS" }).Count
$failCount = ($testResults | Where-Object { $_.Status -eq "FAIL" }).Count
$errorCount = ($testResults | Where-Object { $_.Status -eq "ERROR" }).Count

Write-Host "Total Tested: $($wingetPackages.Count)" -ForegroundColor White
Write-Host "✅ Available: $passCount" -ForegroundColor Green
Write-Host "❌ Not Found: $failCount" -ForegroundColor Red
Write-Host "⚠️ Errors: $errorCount" -ForegroundColor Yellow

$successRate = [Math]::Round(($passCount / $wingetPackages.Count) * 100, 2)
Write-Host "Success Rate: $successRate%" -ForegroundColor $(if ($successRate -ge 95) { "Green" } elseif ($successRate -ge 80) { "Yellow" } else { "Red" })

# Show failures
if ($failCount -gt 0 -or $errorCount -gt 0) {
    Write-Host ""
    Write-Host "PACKAGES WITH ISSUES:" -ForegroundColor Red
    Write-Host "=====================" -ForegroundColor Red
    
    $issues = $testResults | Where-Object { $_.Status -in @("FAIL", "ERROR") } | Sort-Object Category, Subcategory, Name
    
    $currentCategory = ""
    foreach ($issue in $issues) {
        if ($issue.Category -ne $currentCategory) {
            $currentCategory = $issue.Category
            Write-Host ""
            Write-Host "$currentCategory" -ForegroundColor Cyan
        }
        
        $statusColor = if ($issue.Status -eq "FAIL") { "Red" } else { "Yellow" }
        Write-Host "  $($issue.Status): $($issue.Name)" -ForegroundColor $statusColor
        Write-Host "    ID: $($issue.Id)" -ForegroundColor Gray
        Write-Host "    Subcategory: $($issue.Subcategory)" -ForegroundColor Gray
        if ($issue.Message -ne "Package not found") {
            Write-Host "    Error: $($issue.Message)" -ForegroundColor DarkGray
        }
    }
}

# Export results
$timestamp = Get-Date -Format "yyyyMMdd_HHmmss"
$reportPath = Join-Path $parentDirectory "winget_availability_report_$timestamp.json"
$testResults | ConvertTo-Json -Depth 3 | Out-File -FilePath $reportPath -Encoding UTF8

Write-Host ""
Write-Host "Detailed report saved to: $reportPath" -ForegroundColor Cyan

# Summary by category
Write-Host ""
Write-Host "SUCCESS RATE BY CATEGORY:" -ForegroundColor Cyan
Write-Host "=========================" -ForegroundColor Cyan

$categoryStats = $testResults | Group-Object Category | ForEach-Object {
    $totalInCategory = $_.Count
    $passInCategory = ($_.Group | Where-Object { $_.Status -eq "PASS" }).Count
    $rate = [Math]::Round(($passInCategory / $totalInCategory) * 100, 1)
    
    [PSCustomObject]@{
        Category = $_.Name
        Total = $totalInCategory
        Available = $passInCategory
        SuccessRate = $rate
    }
} | Sort-Object SuccessRate -Descending

foreach ($stat in $categoryStats) {
    $color = if ($stat.SuccessRate -ge 95) { "Green" } elseif ($stat.SuccessRate -ge 80) { "Yellow" } else { "Red" }
    Write-Host "$($stat.Category): $($stat.Available)/$($stat.Total) ($($stat.SuccessRate)%)" -ForegroundColor $color
}

Write-Host ""
Write-Host "Winget test completed!" -ForegroundColor Cyan
