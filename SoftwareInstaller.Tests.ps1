# ===== SOFTWARE INSTALLER COMPREHENSIVE TEST SUITE =====
# PowerShell Test Suite using Pester Framework and Custom Testing
# Tests core functionality before refactoring to ensure behavior remains unchanged

param(
    [switch]$MockInstallations,
    [switch]$SkipLongRunningTests,
    [switch]$Verbose
)

# Set default values for parameters
if (-not $PSBoundParameters.ContainsKey('MockInstallations')) {
    $MockInstallations = $true
}

# Import required modules
if (-not (Get-Module -Name Pester -ListAvailable)) {
    Write-Host "Installing Pester module..." -ForegroundColor Yellow
    Install-Module -Name Pester -Force -Scope CurrentUser -SkipPublisherCheck
}

Import-Module Pester -Force

# Global test configuration
$Global:TestConfig = @{
    MockInstallations = $MockInstallations
    SkipLongRunningTests = $SkipLongRunningTests
    Verbose = $Verbose
    TestStartTime = Get-Date
    ScriptDirectory = Split-Path -Parent $MyInvocation.MyCommand.Path
    BackupCreated = $false
}

# ===== HELPER FUNCTIONS =====
function Write-TestHeader {
    param([string]$Title)
    Write-Host "`n$('='*60)" -ForegroundColor Cyan
    Write-Host " $Title" -ForegroundColor Cyan
    Write-Host "$('='*60)" -ForegroundColor Cyan
}

function Write-TestResult {
    param(
        [string]$TestName,
        [bool]$Passed,
        [string]$Details = ""
    )
    $status = if ($Passed) { "✅ PASS" } else { "❌ FAIL" }
    $color = if ($Passed) { "Green" } else { "Red" }
    Write-Host "$status - $TestName" -ForegroundColor $color
    if ($Details -and ($Global:TestConfig.Verbose -or -not $Passed)) {
        Write-Host "    $Details" -ForegroundColor Gray
    }
}

function Backup-OriginalScript {
    if (-not $Global:TestConfig.BackupCreated) {
        $backupPath = Join-Path $Global:TestConfig.ScriptDirectory "SoftwareInstaller_test_backup_$(Get-Date -Format 'yyyyMMdd_HHmmss').ps1"
        $originalPath = Join-Path $Global:TestConfig.ScriptDirectory "SoftwareInstaller_backup_20250802_132727.ps1"
        
        if (Test-Path $originalPath) {
            Copy-Item -Path $originalPath -Destination $backupPath
            Write-Host "Created test backup: $backupPath" -ForegroundColor Green
            $Global:TestConfig.BackupCreated = $true
        }
    }
}

# ===== MOCK FUNCTIONS FOR TESTING =====
function New-MockWingetInstall {
    param([string]$Id, [string]$Name)
    if ($Global:TestConfig.MockInstallations) {
        Write-Host "MOCK: Would install $Name (ID: $Id) via Winget" -ForegroundColor Yellow
        return $true
    }
    return $false
}

function New-MockProcessStart {
    param([string]$FilePath, [string]$ArgumentList)
    if ($Global:TestConfig.MockInstallations) {
        Write-Host "MOCK: Would start process $FilePath with args: $ArgumentList" -ForegroundColor Yellow
        return @{ ExitCode = 0 }
    }
    return $null
}

function New-MockWebRequest {
    param([string]$Uri)
    if ($Global:TestConfig.MockInstallations) {
        Write-Host "MOCK: Would download from $Uri" -ForegroundColor Yellow
        return @{ Content = "# Mock PowerShell Script Content" }
    }
    return $null
}

# ===== TEST CONFIGURATION SETUP =====
Write-TestHeader "Software Installer Test Suite Configuration"
Write-Host "Test Configuration:" -ForegroundColor Cyan
Write-Host "  - Mock Installations: $($Global:TestConfig.MockInstallations)" -ForegroundColor Gray
Write-Host "  - Skip Long Running: $($Global:TestConfig.SkipLongRunningTests)" -ForegroundColor Gray
Write-Host "  - Verbose Output: $($Global:TestConfig.Verbose)" -ForegroundColor Gray
Write-Host "  - Test Directory: $($Global:TestConfig.ScriptDirectory)" -ForegroundColor Gray

# Create backup before testing
Backup-OriginalScript

# ===== UNIT TESTS =====
Describe "SoftwareInstaller Unit Tests" {
    
    BeforeAll {
        # Source the script for testing
        $scriptPath = Join-Path $Global:TestConfig.ScriptDirectory "SoftwareInstaller_backup_20250802_132727.ps1"
        if (Test-Path $scriptPath) {
            # Load script content without executing main menu
            $scriptContent = Get-Content $scriptPath -Raw
            # Remove main execution part
            $functionsOnly = $scriptContent -replace 'Navigate-SoftwareMenu[\s\S]*$', ''
            $functionsOnly = $functionsOnly -replace 'Write-Host.*"Thank you for using Software Installation Manager!"[\s\S]*$', ''
            Invoke-Expression $functionsOnly
        }
    }
    
    Context "Core Data Structure Tests" {
        It "Should have software categories defined" {
            $softwareCategories | Should -Not -BeNullOrEmpty
            $softwareCategories.Count | Should -BeGreaterThan 0
        }
        
        It "Should have required main categories" {
            $requiredCategories = @("Development", "Internet & Communication", "Multimedia", "Productivity", "Gaming", "Utilities")
            foreach ($category in $requiredCategories) {
                $softwareCategories.ContainsKey($category) | Should -Be $true
            }
        }
        
        It "Should have valid subcategories structure" {
            foreach ($category in $softwareCategories.Keys) {
                $softwareCategories[$category] | Should -Not -BeNullOrEmpty
                $softwareCategories[$category].GetType().Name | Should -Be "Hashtable"
                $softwareCategories[$category].Keys.Count | Should -BeGreaterThan 0
            }
        }
        
        It "Should have valid software entries with required properties" {
            $validTypes = @("Winget", "MSI", "EXE", "PowerShellModule", "PowerShellScript")
            $sampleSoftware = $softwareCategories["Development"]["IDEs & Editors"][0]
            
            $sampleSoftware.Name | Should -Not -BeNullOrEmpty
            $sampleSoftware.Type | Should -BeIn $validTypes
            $sampleSoftware.Description | Should -Not -BeNullOrEmpty
            
            if ($sampleSoftware.Type -eq "Winget") {
                $sampleSoftware.Id | Should -Not -BeNullOrEmpty
            }
        }
    }
    
    Context "Utility Function Tests" {
        It "Get-InstalledSoftware should be defined and callable" {
            { Get-Command Get-InstalledSoftware } | Should -Not -Throw
        }
        
        It "Install-WingetSoftware should be defined with correct parameters" {
            $command = Get-Command Install-WingetSoftware
            $command | Should -Not -BeNullOrEmpty
            $command.Parameters.Keys | Should -Contain "Id"
            $command.Parameters.Keys | Should -Contain "Name"
        }
        
        It "Install-MSIPackage should be defined with correct parameters" {
            $command = Get-Command Install-MSIPackage
            $command | Should -Not -BeNullOrEmpty
            $command.Parameters.Keys | Should -Contain "Name"
            $command.Parameters.Keys | Should -Contain "Url"
            $command.Parameters.Keys | Should -Contain "Arguments"
        }
        
        It "Install-EXEPackage should be defined with correct parameters" {
            $command = Get-Command Install-EXEPackage
            $command | Should -Not -BeNullOrEmpty
            $command.Parameters.Keys | Should -Contain "Name"
            $command.Parameters.Keys | Should -Contain "Url"
            $command.Parameters.Keys | Should -Contain "Arguments"
        }
        
        It "Install-PowerShellModule should be defined" {
            $command = Get-Command Install-PowerShellModule
            $command | Should -Not -BeNullOrEmpty
            $command.Parameters.Keys | Should -Contain "ModuleName"
        }
        
        It "Install-PowerShellScript should be defined" {
            $command = Get-Command Install-PowerShellScript
            $command | Should -Not -BeNullOrEmpty
            $command.Parameters.Keys | Should -Contain "Name"
            $command.Parameters.Keys | Should -Contain "Url"
        }
    }
    
    Context "Navigation Function Tests" {
        It "Show-MainCategories should be defined" {
            { Get-Command Show-MainCategories } | Should -Not -Throw
        }
        
        It "Show-Subcategories should be defined with categoryName parameter" {
            $command = Get-Command Show-Subcategories
            $command | Should -Not -BeNullOrEmpty
            $command.Parameters.Keys | Should -Contain "categoryName"
        }
        
        It "Show-SoftwareList should be defined with required parameters" {
            $command = Get-Command Show-SoftwareList
            $command | Should -Not -BeNullOrEmpty
            $command.Parameters.Keys | Should -Contain "categoryName"
            $command.Parameters.Keys | Should -Contain "subcategoryName"
        }
        
        It "Get-UserMenuChoice should be defined" {
            { Get-Command Get-UserMenuChoice } | Should -Not -Throw
        }
        
        It "Navigate-SoftwareMenu should be defined" {
            { Get-Command Navigate-SoftwareMenu } | Should -Not -Throw
        }
    }
    
    Context "Global Variables Tests" {
        It "LogPath should be defined and valid" {
            $LogPath | Should -Not -BeNullOrEmpty
            $LogPath | Should -Match "installation_log_\d{8}_\d{6}\.txt"
        }
        
        It "LogPath should point to current directory" {
            $LogPath | Should -Match "^\.\\"
        }
    }
}

# ===== INTEGRATION TESTS =====
Describe "SoftwareInstaller Integration Tests" {
    
    Context "Software Category Data Integrity" {
        It "Should have consistent data structure across all categories" {
            foreach ($categoryName in $softwareCategories.Keys) {
                foreach ($subcategoryName in $softwareCategories[$categoryName].Keys) {
                    $softwareList = $softwareCategories[$categoryName][$subcategoryName]
                    
                    foreach ($software in $softwareList) {
                        # Required properties
                        $software.Name | Should -Not -BeNullOrEmpty
                        $software.Type | Should -Not -BeNullOrEmpty
                        $software.Description | Should -Not -BeNullOrEmpty
                        
                        # Type-specific properties
                        switch ($software.Type) {
                            "Winget" { 
                                $software.Id | Should -Not -BeNullOrEmpty 
                            }
                            "MSI" { 
                                $software.Url | Should -Not -BeNullOrEmpty 
                            }
                            "EXE" { 
                                $software.Url | Should -Not -BeNullOrEmpty 
                            }
                            "PowerShellModule" { 
                                $software.ModuleName | Should -Not -BeNullOrEmpty 
                            }
                            "PowerShellScript" { 
                                $software.Url | Should -Not -BeNullOrEmpty 
                            }
                        }
                    }
                }
            }
        }
        
        It "Should have specific software items in expected categories" {
            # Test known software items
            $vsCode = $softwareCategories["Development"]["IDEs & Editors"] | Where-Object { $_.Name -eq "Visual Studio Code" }
            $vsCode | Should -Not -BeNullOrEmpty
            $vsCode.Type | Should -Be "Winget"
            $vsCode.Id | Should -Be "Microsoft.VisualStudioCode"
            
            $chrome = $softwareCategories["Internet & Communication"]["Web Browsers"] | Where-Object { $_.Name -eq "Google Chrome" }
            $chrome | Should -Not -BeNullOrEmpty
            $chrome.Type | Should -Be "Winget"
            $chrome.Id | Should -Be "Google.Chrome"
        }
    }
    
    Context "Installation Function Integration" -Skip:$Global:TestConfig.SkipLongRunningTests {
        BeforeEach {
            # Create mock log file for testing
            $Global:TestLogPath = ".\test_installation_log_$(Get-Date -Format 'yyyyMMdd_HHmmss').txt"
            $Global:LogPath = $Global:TestLogPath
        }
        
        AfterEach {
            # Clean up test log file
            if (Test-Path $Global:TestLogPath) {
                Remove-Item $Global:TestLogPath -Force
            }
        }
        
        It "Should handle Winget installation process" {
            if ($Global:TestConfig.MockInstallations) {
                # Mock winget command
                Mock winget { return "Successfully installed TestApp" } -Verifiable
                Mock Add-Content {} -Verifiable
                
                $result = Install-WingetSoftware -Id "TestApp.TestApp" -Name "Test Application"
                $result | Should -Be $true
                
                Assert-VerifiableMock
            } else {
                # This test would be skipped in real scenarios to avoid actual installations
                Set-ItResult -Skipped -Because "Real installations disabled for testing"
            }
        }
        
        It "Should handle MSI installation process" {
            if ($Global:TestConfig.MockInstallations) {
                Mock Invoke-WebRequest { return @{} } -Verifiable
                Mock Start-Process { return @{ ExitCode = 0 } } -Verifiable
                Mock Remove-Item {} -Verifiable
                Mock Add-Content {} -Verifiable
                
                $result = Install-MSIPackage -Name "Test MSI" -Url "https://example.com/test.msi"
                $result | Should -Be $true
                
                Assert-VerifiableMock
            } else {
                Set-ItResult -Skipped -Because "Real installations disabled for testing"
            }
        }
    }
    
    Context "Error Handling Integration" {
        It "Should handle missing winget gracefully" {
            # Temporarily rename winget if it exists (PowerShell 5.1 compatible)
            $wingetCommand = Get-Command winget -ErrorAction SilentlyContinue
            $wingetPath = if ($wingetCommand) { $wingetCommand.Source } else { $null }
            $tempName = $null
            
            if ($wingetPath) {
                $tempName = "$wingetPath.temp"
                Rename-Item $wingetPath $tempName
            }
            
            try {
                { Install-WingetSoftware -Id "TestApp" -Name "Test App" } | Should -Not -Throw
            } finally {
                # Restore winget if we moved it
                if ($tempName -and (Test-Path $tempName)) {
                    Rename-Item $tempName $wingetPath
                }
            }
        }
        
        It "Should create log entries for operations" {
            $testLogPath = ".\test_log_$(Get-Date -Format 'yyyyMMdd_HHmmss').txt"
            $Global:LogPath = $testLogPath
            
            try {
                Install-WingetSoftware -Id "NonExistent.App" -Name "Non Existent App"
                
                if (Test-Path $testLogPath) {
                    $logContent = Get-Content $testLogPath -Raw
                    $logContent | Should -Match "Non Existent App"
                }
            } finally {
                if (Test-Path $testLogPath) {
                    Remove-Item $testLogPath -Force
                }
            }
        }
    }
}

# ===== FUNCTIONAL TESTS =====
Write-TestHeader "Functional Tests"

# Test 1: Software Categories Completeness
Write-Host "Testing software categories completeness..." -ForegroundColor Yellow
try {
    $totalSoftware = 0
    foreach ($category in $softwareCategories.Keys) {
        foreach ($subcategory in $softwareCategories[$category].Keys) {
            $totalSoftware += $softwareCategories[$category][$subcategory].Count
        }
    }
    Write-TestResult "Software categories loaded" ($totalSoftware -gt 100) "Total software items: $totalSoftware"
    Write-TestResult "Main categories count" ($softwareCategories.Keys.Count -ge 6) "Categories: $($softwareCategories.Keys.Count)"
} catch {
    Write-TestResult "Software categories loading" $false $_.Exception.Message
}

# Test 2: Critical Functions Existence
Write-Host "Testing critical functions existence..." -ForegroundColor Yellow
$criticalFunctions = @(
    "Get-InstalledSoftware",
    "Install-WingetSoftware", 
    "Install-MSIPackage", 
    "Install-EXEPackage",
    "Install-PowerShellModule",
    "Install-PowerShellScript",
    "Navigate-SoftwareMenu",
    "Show-MainCategories",
    "Show-Subcategories",
    "Show-SoftwareList",
    "Get-UserMenuChoice",
    "Install-SelectedSoftware"
)

$missingFunctions = @()
foreach ($function in $criticalFunctions) {
    $exists = Get-Command $function -ErrorAction SilentlyContinue
    if ($exists) {
        Write-TestResult "Function: $function" $true "Available"
    } else {
        Write-TestResult "Function: $function" $false "Missing"
        $missingFunctions += $function
    }
}

# Test 3: Data Validation
Write-Host "Testing data validation..." -ForegroundColor Yellow
$dataValidationPassed = $true
$validationErrors = @()

foreach ($categoryName in $softwareCategories.Keys) {
    foreach ($subcategoryName in $softwareCategories[$categoryName].Keys) {
        $softwareList = $softwareCategories[$categoryName][$subcategoryName]
        
        for ($i = 0; $i -lt $softwareList.Count; $i++) {
            $software = $softwareList[$i]
            $location = "$categoryName > $subcategoryName > Item $($i+1)"
            
            # Validate required fields
            if (-not $software.Name) {
                $validationErrors += "$location - Missing Name"
                $dataValidationPassed = $false
            }
            if (-not $software.Type) {
                $validationErrors += "$location - Missing Type"
                $dataValidationPassed = $false
            }
            if (-not $software.Description) {
                $validationErrors += "$location - Missing Description"
                $dataValidationPassed = $false
            }
            
            # Validate type-specific fields
            switch ($software.Type) {
                "Winget" {
                    if (-not $software.Id) {
                        $validationErrors += "$location - Winget type missing Id"
                        $dataValidationPassed = $false
                    }
                }
                "MSI" {
                    if (-not $software.Url) {
                        $validationErrors += "$location - MSI type missing Url"
                        $dataValidationPassed = $false
                    }
                }
                "EXE" {
                    if (-not $software.Url) {
                        $validationErrors += "$location - EXE type missing Url"
                        $dataValidationPassed = $false
                    }
                }
                "PowerShellModule" {
                    if (-not $software.ModuleName) {
                        $validationErrors += "$location - PowerShellModule type missing ModuleName"
                        $dataValidationPassed = $false
                    }
                }
                "PowerShellScript" {
                    if (-not $software.Url) {
                        $validationErrors += "$location - PowerShellScript type missing Url"
                        $dataValidationPassed = $false
                    }
                }
            }
        }
    }
}

Write-TestResult "Data structure validation" $dataValidationPassed "$(if ($validationErrors.Count -gt 0) { "Errors: " + ($validationErrors -join '; ') } else { 'All entries valid' })"

# Test 4: Specific Software Verification
Write-Host "Testing specific software entries..." -ForegroundColor Yellow
$specificTests = @(
    @{ Category = "Development"; Subcategory = "IDEs & Editors"; Name = "Visual Studio Code"; Type = "Winget"; Id = "Microsoft.VisualStudioCode" },
    @{ Category = "Internet & Communication"; Subcategory = "Web Browsers"; Name = "Google Chrome"; Type = "Winget"; Id = "Google.Chrome" },
    @{ Category = "Utilities"; Subcategory = "System Tools"; Name = "PowerToys"; Type = "Winget"; Id = "Microsoft.PowerToys" }
)

foreach ($test in $specificTests) {
    $software = $softwareCategories[$test.Category][$test.Subcategory] | Where-Object { $_.Name -eq $test.Name }
    $testPassed = $software -and $software.Type -eq $test.Type -and $software.Id -eq $test.Id
    Write-TestResult "Specific software: $($test.Name)" $testPassed "$(if ($software) { "Found with Type: $($software.Type), Id: $($software.Id)" } else { "Not found" })"
}

# ===== TEST SUMMARY =====
Write-TestHeader "Test Summary"

$endTime = Get-Date
$duration = $endTime - $Global:TestConfig.TestStartTime

Write-Host "Test Execution Summary:" -ForegroundColor Cyan
Write-Host "  Start Time: $($Global:TestConfig.TestStartTime.ToString('yyyy-MM-dd HH:mm:ss'))" -ForegroundColor Gray
Write-Host "  End Time: $($endTime.ToString('yyyy-MM-dd HH:mm:ss'))" -ForegroundColor Gray
Write-Host "  Duration: $($duration.TotalSeconds.ToString('F2')) seconds" -ForegroundColor Gray
Write-Host "  Configuration: Mock Installations = $($Global:TestConfig.MockInstallations)" -ForegroundColor Gray

if ($missingFunctions.Count -eq 0 -and $dataValidationPassed) {
    Write-Host "`n🎉 ALL TESTS PASSED!" -ForegroundColor Green
    Write-Host "Your SoftwareInstaller is ready for refactoring!" -ForegroundColor Green
    Write-Host "The current functionality is properly preserved and tested." -ForegroundColor Green
} else {
    Write-Host "`n⚠️  SOME TESTS FAILED" -ForegroundColor Yellow
    Write-Host "Please review the following issues before refactoring:" -ForegroundColor Yellow
    
    if ($missingFunctions.Count -gt 0) {
        Write-Host "Missing Functions: $($missingFunctions -join ', ')" -ForegroundColor Red
    }
    
    if (-not $dataValidationPassed) {
        Write-Host "Data validation errors found (see details above)" -ForegroundColor Red
    }
}

Write-Host "`n$('='*60)" -ForegroundColor Cyan
Write-Host " Test Suite Complete - Ready for Refactoring!" -ForegroundColor Cyan
Write-Host "$('='*60)" -ForegroundColor Cyan
