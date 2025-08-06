# Quick Software Validation Test
# Fast validation of software catalog structure and basic availability

$scriptDirectory = Split-Path -Parent $MyInvocation.MyCommand.Path
$parentDirectory = Split-Path -Parent $scriptDirectory
$jsonPath = Join-Path $parentDirectory "software-categories.json"

Write-Host "Quick Software Catalog Validation" -ForegroundColor Cyan
Write-Host "=================================" -ForegroundColor Cyan

# Load the software categories
try {
    $jsonContent = Get-Content $jsonPath -Raw -Encoding UTF8
    $categories = $jsonContent | ConvertFrom-Json
    Write-Host "✅ JSON loaded successfully" -ForegroundColor Green
} catch {
    Write-Host "❌ Failed to load JSON: $($_.Exception.Message)" -ForegroundColor Red
    exit 1
}

$issues = @()
$totalSoftware = 0
$wingetAvailable = Get-Command winget -ErrorAction SilentlyContinue

Write-Host "Validating software entries..." -ForegroundColor Yellow
Write-Host ""

foreach ($categoryName in $categories.PSObject.Properties.Name) {
    Write-Host "Category: $categoryName" -ForegroundColor Cyan
    $category = $categories.$categoryName
    
    foreach ($subcategoryName in $category.PSObject.Properties.Name) {
        Write-Host "  Subcategory: $subcategoryName" -ForegroundColor Yellow
        $subcategory = $category.$subcategoryName
        
        foreach ($software in $subcategory) {
            $totalSoftware++
            Write-Host "    Testing: $($software.Name)" -ForegroundColor Gray
            
            # Validate required fields based on type
            switch ($software.Type) {
                "Winget" {
                    if (-not $software.Id) {
                        $issues += "❌ Winget software '$($software.Name)' missing Id field"
                    } elseif ($software.Id -notmatch '^[A-Za-z0-9\.\-_]+$') {
                        $issues += "⚠️ Winget ID '$($software.Id)' for '$($software.Name)' may have invalid format"
                    }
                }
                "GitHub" {
                    if (-not $software.Repository) {
                        $issues += "❌ GitHub software '$($software.Name)' missing Repository field"
                    } elseif ($software.Repository -notmatch '^[A-Za-z0-9\.\-_]+/[A-Za-z0-9\.\-_]+$') {
                        $issues += "⚠️ GitHub repository '$($software.Repository)' for '$($software.Name)' may have invalid format"
                    }
                }
                "PowerShellModule" {
                    if (-not $software.ModuleName) {
                        $issues += "❌ PowerShell module '$($software.Name)' missing ModuleName field"
                    }
                }
                "Custom" {
                    if (-not $software.Url) {
                        $issues += "❌ Custom software '$($software.Name)' missing Url field"
                    } elseif ($software.Url -notmatch '^https?://') {
                        $issues += "⚠️ Custom URL for '$($software.Name)' should start with http:// or https://"
                    }
                }
                "MSI" {
                    if (-not $software.Url) {
                        $issues += "❌ MSI software '$($software.Name)' missing Url field"
                    }
                }
                "EXE" {
                    if (-not $software.Url) {
                        $issues += "❌ EXE software '$($software.Name)' missing Url field"
                    }
                }
                "CustomInstall" {
                    if (-not $software.Repository) {
                        $issues += "❌ CustomInstall software '$($software.Name)' missing Repository field"
                    }
                }
                default {
                    $issues += "⚠️ Unknown software type '$($software.Type)' for '$($software.Name)'"
                }
            }
            
            # Check for required common fields
            if (-not $software.Name) {
                $issues += "❌ Software entry missing Name field"
            }
            if (-not $software.Description) {
                $issues += "⚠️ Software '$($software.Name)' missing Description field"
            }
        }
    }
}

Write-Host ""
Write-Host "VALIDATION SUMMARY" -ForegroundColor Cyan
Write-Host "==================" -ForegroundColor Cyan
Write-Host "Total software entries: $totalSoftware" -ForegroundColor White
Write-Host "Issues found: $($issues.Count)" -ForegroundColor $(if ($issues.Count -eq 0) { "Green" } else { "Red" })

if ($issues.Count -gt 0) {
    Write-Host ""
    Write-Host "ISSUES FOUND:" -ForegroundColor Red
    Write-Host "=============" -ForegroundColor Red
    foreach ($issue in $issues) {
        if ($issue.StartsWith("❌")) {
            Write-Host $issue -ForegroundColor Red
        } else {
            Write-Host $issue -ForegroundColor Yellow
        }
    }
} else {
    Write-Host ""
    Write-Host "🎉 All software entries are properly formatted!" -ForegroundColor Green
}

# Quick Winget availability check for a sample
if ($wingetAvailable) {
    Write-Host ""
    Write-Host "QUICK WINGET SAMPLE TEST" -ForegroundColor Cyan
    Write-Host "========================" -ForegroundColor Cyan
    
    # Test a few common Winget packages
    $samplePackages = @(
        @{ Name = "7-Zip"; Id = "7zip.7zip" },
        @{ Name = "Git"; Id = "Git.Git" },
        @{ Name = "Visual Studio Code"; Id = "Microsoft.VisualStudioCode" }
    )
    
    foreach ($package in $samplePackages) {
        Write-Host "Testing: $($package.Name)..." -ForegroundColor Gray
        try {
            winget show --id $package.Id --accept-source-agreements 2>$null | Out-Null
            if ($LASTEXITCODE -eq 0) {
                Write-Host "  ✅ $($package.Name) found" -ForegroundColor Green
            } else {
                Write-Host "  ❌ $($package.Name) not found" -ForegroundColor Red
            }
        } catch {
            Write-Host "  ⚠️ Error testing $($package.Name)" -ForegroundColor Yellow
        }
    }
} else {
    Write-Host ""
    Write-Host "⚠️ Winget not available - skipping sample test" -ForegroundColor Yellow
}

Write-Host ""
Write-Host "Quick validation completed!" -ForegroundColor Cyan
Write-Host "Run 'test-software-availability.ps1' for comprehensive testing." -ForegroundColor Gray
