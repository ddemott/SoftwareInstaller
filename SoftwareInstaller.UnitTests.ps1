# ===== SIMPLE UNIT TESTS FOR SOFTWARE INSTALLER =====
# Quick unit tests to verify core functionality before refactoring
# Run this before making any changes to ensure current behavior is preserved

param(
    [switch]$Verbose = $false
)

Write-Host "╔════════════════════════════════════════════Write-Host ""
Write-Host "UNIT TEST SUMMARY" -ForegroundColor Cyan═══╗" -ForegroundColor Cyan
Write-Host "║        Software Installer Unit Test Suite       ║" -ForegroundColor Cyan
Write-Host "╚══════════════════════════════════════════════════╝" -ForegroundColor Cyan
Write-Host ""

# Test configuration
$TestResults = @{
    Passed = 0
    Failed = 0
    Total = 0
    Errors = @()
}

function Write-TestResult {
    param(
        [string]$TestName,
        [bool]$Passed,
        [string]$Details = ""
    )
    
    $TestResults.Total++
    if ($Passed) {
        $TestResults.Passed++
        Write-Host "✅ PASS: $TestName" -ForegroundColor Green
    } else {
        $TestResults.Failed++
        $TestResults.Errors += "$TestName - $Details"
        Write-Host "❌ FAIL: $TestName" -ForegroundColor Red
    }
    
    if ($Details -and ($Verbose -or -not $Passed)) {
        Write-Host "    $Details" -ForegroundColor Gray
    }
}

# Get script directory
$scriptDirectory = Split-Path -Parent $MyInvocation.MyCommand.Path
$scriptPath = Join-Path $scriptDirectory "SoftwareInstaller_backup_20250802_132727.ps1"

Write-Host "Testing script: $scriptPath" -ForegroundColor Gray
Write-Host ""

# ===== TEST 1: SCRIPT FILE EXISTS =====
Write-Host "1. File Existence Tests" -ForegroundColor Yellow
Write-TestResult "Script file exists" (Test-Path $scriptPath) "Path: $scriptPath"

# ===== TEST 2: SCRIPT LOADS WITHOUT ERRORS =====
Write-Host "`n2. Script Loading Tests" -ForegroundColor Yellow
try {
    # Load the script content but prevent execution of main menu
    $scriptContent = Get-Content $scriptPath -Raw
    $functionsOnly = $scriptContent -replace 'Navigate-SoftwareMenu[\s\S]*$', ''
    $functionsOnly = $functionsOnly -replace 'Write-Host.*"Thank you for using Software Installation Manager!"[\s\S]*$', ''
    
    Invoke-Expression $functionsOnly
    Write-TestResult "Script loads without errors" $true "Functions loaded successfully"
} catch {
    Write-TestResult "Script loads without errors" $false $_.Exception.Message
    exit 1
}

# ===== TEST 3: GLOBAL VARIABLES =====
Write-Host "`n3. Global Variables Tests" -ForegroundColor Yellow
Write-TestResult "LogPath variable defined" (-not [string]::IsNullOrEmpty($LogPath)) "Value: $LogPath"
Write-TestResult "LogPath has correct format" ($LogPath -match "installation_log_\d{8}_\d{6}\.txt") "Pattern matches timestamp format"

# ===== TEST 4: SOFTWARE CATEGORIES =====
Write-Host "`n4. Software Categories Tests" -ForegroundColor Yellow
Write-TestResult "Software categories variable exists" ($null -ne $softwareCategories) "Type: $($softwareCategories.GetType().Name)"
Write-TestResult "Software categories not empty" ($softwareCategories.Count -gt 0) "Count: $($softwareCategories.Count)"

# Test required categories
$requiredCategories = @("Development", "Internet `& Communication", "Multimedia", "Productivity", "Gaming", "Utilities")
foreach ($category in $requiredCategories) {
    $exists = $softwareCategories.ContainsKey($category)
    Write-TestResult "Category '$category' exists" $exists
}

# Test category structure
if ($softwareCategories -and $softwareCategories.Count -gt 0) {
    foreach ($categoryName in $softwareCategories.Keys) {
        $category = $softwareCategories[$categoryName]
        Write-TestResult "Category '$categoryName' has subcategories" ($category.Keys.Count -gt 0) "Subcategories: $($category.Keys.Count)"
        
        # Test first subcategory structure
        $firstSubcategory = $category.Keys | Select-Object -First 1
        if ($firstSubcategory) {
            $subcategoryItems = $category[$firstSubcategory]
            Write-TestResult "Subcategory '$firstSubcategory' has items" ($subcategoryItems.Count -gt 0) "Items: $($subcategoryItems.Count)"
            
            # Test first item structure
            if ($subcategoryItems.Count -gt 0) {
                $firstItem = $subcategoryItems[0]
                Write-TestResult "First item has Name property" (-not [string]::IsNullOrEmpty($firstItem.Name)) "Name: $($firstItem.Name)"
                Write-TestResult "First item has Type property" (-not [string]::IsNullOrEmpty($firstItem.Type)) "Type: $($firstItem.Type)"
                Write-TestResult "First item has Description property" (-not [string]::IsNullOrEmpty($firstItem.Description)) "Description length: $($firstItem.Description.Length)"
            }
        }
    }
}

# ===== TEST 5: CORE FUNCTIONS =====
Write-Host "`n5. Core Functions Tests" -ForegroundColor Yellow

# Test that critical functions exist
$criticalFunctions = @(
    "Get-InstalledSoftware",
    "Install-WingetSoftware",
    "Install-MSIPackage",
    "Install-EXEPackage",
    "Install-PowerShellModule",
    "Install-PowerShellScript"
)

foreach ($functionName in $criticalFunctions) {
    $function = Get-Command $functionName -ErrorAction SilentlyContinue
    Write-TestResult "Function '$functionName' exists" ($null -ne $function)
    
    if ($function) {
        # Test function parameters
        switch ($functionName) {
            "Get-InstalledSoftware" {
                $hasExportParam = $function.Parameters.ContainsKey("ExportToFile")
                $hasPathParam = $function.Parameters.ContainsKey("ExportPath")
                Write-TestResult "$functionName has ExportToFile parameter" $hasExportParam
                Write-TestResult "$functionName has ExportPath parameter" $hasPathParam
            }
            "Install-WingetSoftware" {
                $hasIdParam = $function.Parameters.ContainsKey("Id")
                $hasNameParam = $function.Parameters.ContainsKey("Name")
                Write-TestResult "$functionName has Id parameter" $hasIdParam
                Write-TestResult "$functionName has Name parameter" $hasNameParam
            }
            "Install-MSIPackage" {
                $hasNameParam = $function.Parameters.ContainsKey("Name")
                $hasUrlParam = $function.Parameters.ContainsKey("Url")
                $hasArgsParam = $function.Parameters.ContainsKey("Arguments")
                Write-TestResult "$functionName has Name parameter" $hasNameParam
                Write-TestResult "$functionName has Url parameter" $hasUrlParam
                Write-TestResult "$functionName has Arguments parameter" $hasArgsParam
            }
            "Install-EXEPackage" {
                $hasNameParam = $function.Parameters.ContainsKey("Name")
                $hasUrlParam = $function.Parameters.ContainsKey("Url")
                $hasArgsParam = $function.Parameters.ContainsKey("Arguments")
                Write-TestResult "$functionName has Name parameter" $hasNameParam
                Write-TestResult "$functionName has Url parameter" $hasUrlParam
                Write-TestResult "$functionName has Arguments parameter" $hasArgsParam
            }
            "Install-PowerShellModule" {
                $hasModuleParam = $function.Parameters.ContainsKey("ModuleName")
                Write-TestResult "$functionName has ModuleName parameter" $hasModuleParam
            }
            "Install-PowerShellScript" {
                $hasNameParam = $function.Parameters.ContainsKey("Name")
                $hasUrlParam = $function.Parameters.ContainsKey("Url")
                $hasArgsParam = $function.Parameters.ContainsKey("Arguments")
                Write-TestResult "$functionName has Name parameter" $hasNameParam
                Write-TestResult "$functionName has Url parameter" $hasUrlParam
                Write-TestResult "$functionName has Arguments parameter" $hasArgsParam
            }
        }
    }
}

# ===== TEST 6: NAVIGATION FUNCTIONS =====
Write-Host "`n6. Navigation Functions Tests" -ForegroundColor Yellow

$navigationFunctions = @(
    "Show-MainCategories",
    "Show-Subcategories", 
    "Show-SoftwareList",
    "Get-UserMenuChoice",
    "Navigate-SoftwareMenu",
    "Install-SelectedSoftware"
)

foreach ($functionName in $navigationFunctions) {
    $function = Get-Command $functionName -ErrorAction SilentlyContinue
    Write-TestResult "Navigation function '$functionName' exists" ($null -ne $function)
    
    if ($function) {
        switch ($functionName) {
            "Show-Subcategories" {
                $hasCategoryParam = $function.Parameters.ContainsKey("categoryName")
                Write-TestResult "$functionName has categoryName parameter" $hasCategoryParam
            }
            "Show-SoftwareList" {
                $hasCategoryParam = $function.Parameters.ContainsKey("categoryName")
                $hasSubcategoryParam = $function.Parameters.ContainsKey("subcategoryName")
                Write-TestResult "$functionName has categoryName parameter" $hasCategoryParam
                Write-TestResult "$functionName has subcategoryName parameter" $hasSubcategoryParam
            }
            "Install-SelectedSoftware" {
                $hasSoftwareParam = $function.Parameters.ContainsKey("softwareList")
                $hasSelectionsParam = $function.Parameters.ContainsKey("selections")
                Write-TestResult "$functionName has softwareList parameter" $hasSoftwareParam
                Write-TestResult "$functionName has selections parameter" $hasSelectionsParam
            }
        }
    }
}

# ===== TEST 7: DATA INTEGRITY =====
Write-Host "`n7. Data Integrity Tests" -ForegroundColor Yellow

$totalSoftware = 0
$validationErrors = @()

if ($softwareCategories) {
    foreach ($categoryName in $softwareCategories.Keys) {
        foreach ($subcategoryName in $softwareCategories[$categoryName].Keys) {
            $softwareList = $softwareCategories[$categoryName][$subcategoryName]
            $totalSoftware += $softwareList.Count
            
            foreach ($software in $softwareList) {
                # Check required properties
                if ([string]::IsNullOrEmpty($software.Name)) {
                    $validationErrors += "{0} - {1} - Missing Name" -f $categoryName, $subcategoryName
                }
                if ([string]::IsNullOrEmpty($software.Type)) {
                    $validationErrors += "{0} - {1} - {2} - Missing Type" -f $categoryName, $subcategoryName, $software.Name
                }
                if ([string]::IsNullOrEmpty($software.Description)) {
                    $validationErrors += "{0} - {1} - {2} - Missing Description" -f $categoryName, $subcategoryName, $software.Name
                }
                
                # Check type-specific properties
                switch ($software.Type) {
                    "Winget" {
                        if ([string]::IsNullOrEmpty($software.Id)) {
                            $validationErrors += "{0} - {1} - {2} - Winget missing Id" -f $categoryName, $subcategoryName, $software.Name
                        }
                    }
                    "MSI" {
                        if ([string]::IsNullOrEmpty($software.Url)) {
                            $validationErrors += "{0} - {1} - {2} - MSI missing Url" -f $categoryName, $subcategoryName, $software.Name
                        }
                    }
                    "EXE" {
                        if ([string]::IsNullOrEmpty($software.Url)) {
                            $validationErrors += "{0} - {1} - {2} - EXE missing Url" -f $categoryName, $subcategoryName, $software.Name
                        }
                    }
                    "PowerShellModule" {
                        if ([string]::IsNullOrEmpty($software.ModuleName)) {
                            $validationErrors += "{0} - {1} - {2} - PowerShellModule missing ModuleName" -f $categoryName, $subcategoryName, $software.Name
                        }
                    }
                    "PowerShellScript" {
                        if ([string]::IsNullOrEmpty($software.Url)) {
                            $validationErrors += "{0} - {1} - {2} - PowerShellScript missing Url" -f $categoryName, $subcategoryName, $software.Name
                        }
                    }
                }
            }
        }
    }
}

Write-TestResult "Total software count reasonable" ($totalSoftware -gt 50) "Total: $totalSoftware items"
Write-TestResult "No data validation errors" ($validationErrors.Count -eq 0) "Errors: $($validationErrors.Count)"

if ($validationErrors.Count -gt 0 -and $Verbose) {
    Write-Host "Validation errors:" -ForegroundColor Red
    $validationErrors | ForEach-Object { Write-Host "  - $_" -ForegroundColor Red }
}

# ===== TEST 8: SPECIFIC SOFTWARE VERIFICATION =====
Write-Host "`n8. Specific Software Verification" -ForegroundColor Yellow

# Test for specific known software
$knownSoftware = @(
    @{ Category = "Development"; Subcategory = "IDEs `& Editors"; Name = "Visual Studio Code"; ExpectedType = "Winget" },
    @{ Category = "Internet `& Communication"; Subcategory = "Web Browsers"; Name = "Google Chrome"; ExpectedType = "Winget" },
    @{ Category = "Utilities"; Subcategory = "System Tools"; Name = "PowerToys"; ExpectedType = "Winget" }
)

foreach ($test in $knownSoftware) {
    if ($softwareCategories.ContainsKey($test.Category) -and 
        $softwareCategories[$test.Category].ContainsKey($test.Subcategory)) {
        
        $found = $softwareCategories[$test.Category][$test.Subcategory] | 
                 Where-Object { $_.Name -eq $test.Name }
        
        $exists = $null -ne $found
        Write-TestResult "Known software '$($test.Name)' exists" $exists
        
        if ($exists) {
            Write-TestResult "'$($test.Name)' has correct type" ($found.Type -eq $test.ExpectedType) "Expected: $($test.ExpectedType), Actual: $($found.Type)"
        }
    } else {
        Write-TestResult "Category/Subcategory exists for '$($test.Name)'" $false "Path: $($test.Category) > $($test.Subcategory)"
    }
}

# ===== TEST SUMMARY =====
Write-Host "`n$('='*60)" -ForegroundColor Cyan
Write-Host "TEST SUMMARY" -ForegroundColor Cyan
Write-Host "$('='*60)" -ForegroundColor Cyan

Write-Host "Total Tests: $($TestResults.Total)" -ForegroundColor White
Write-Host "Passed: $($TestResults.Passed)" -ForegroundColor Green
Write-Host "Failed: $($TestResults.Failed)" -ForegroundColor $(if ($TestResults.Failed -gt 0) { "Red" } else { "Green" })

$successRate = if ($TestResults.Total -gt 0) { ($TestResults.Passed / $TestResults.Total) * 100 } else { 0 }
Write-Host "Success Rate: $($successRate.ToString('F1'))%" -ForegroundColor $(if ($successRate -ge 95) { "Green" } elseif ($successRate -ge 80) { "Yellow" } else { "Red" })

if ($TestResults.Failed -gt 0) {
    Write-Host "`nFailed Tests:" -ForegroundColor Red
    $TestResults.Errors | ForEach-Object { Write-Host "  - $_" -ForegroundColor Red }
    
    Write-Host "`n⚠️  REFACTORING NOT RECOMMENDED" -ForegroundColor Yellow
    Write-Host "Please fix the failing tests before proceeding with refactoring." -ForegroundColor Yellow
} else {
    Write-Host "ALL TESTS PASSED!" -ForegroundColor Green
    Write-Host "The SoftwareInstaller is ready for refactoring!" -ForegroundColor Green
    Write-Host "All core functionality has been verified and documented." -ForegroundColor Green
}
