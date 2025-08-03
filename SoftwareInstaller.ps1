# ===== SOFTWARE INSTALLATION MANAGER =====
# PowerShell Script for Windows 11 Software Installation
# Supports Winget, MSI, EXE, PowerShell Modules, and PowerShell Scripts

# ===== GLOBAL VARIABLES =====
$LogPath = ".\installation_log_$(Get-Date -Format 'yyyyMMdd_HHmmss').txt"

# ===== UTILITY FUNCTIONS =====
function Get-InstalledSoftware {
    param(
        [switch]$ExportToFile,
        [string]$ExportPath = "installed_software.json"
    )
    
    $installedSoftware = @()
    
    try {
        if (Get-Command winget -ErrorAction SilentlyContinue) {
            $wingetList = winget list --accept-source-agreements | Where-Object { $_ -notmatch "^-+$|^Name\s+Id|^$" }
            foreach ($line in $wingetList) {
                if ($line -match "^(.+?)\s+([^\s]+)\s+(.+?)(?:\s+winget)?$") {
                    $installedSoftware += [PSCustomObject]@{
                        Name = $matches[1].Trim()
                        Id = $matches[2].Trim()
                        Version = $matches[3].Trim()
                        Source = "Winget"
                        Publisher = "Unknown"
                    }
                }
            }
        }
    } catch {
        Write-Host "Error retrieving Winget packages: $($_.Exception.Message)" -ForegroundColor Yellow
    }
    
    try {
        $registryPaths = @(
            "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall\*",
            "HKLM:\SOFTWARE\WOW6432Node\Microsoft\Windows\CurrentVersion\Uninstall\*",
            "HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall\*"
        )
        
        foreach ($path in $registryPaths) {
            Get-ItemProperty $path -ErrorAction SilentlyContinue | Where-Object { $_.DisplayName } | ForEach-Object {
                $installedSoftware += [PSCustomObject]@{
                    Name = $_.DisplayName
                    Version = $_.DisplayVersion
                    Publisher = $_.Publisher
                    Source = "Registry"
                    Id = $_.PSChildName
                }
            }
        }
    } catch {
        Write-Host "Error retrieving registry packages: $($_.Exception.Message)" -ForegroundColor Yellow
    }
    
    if ($ExportToFile) {
        $installedSoftware | ConvertTo-Json -Depth 3 | Out-File -FilePath $ExportPath -Encoding UTF8
        Write-Host "Software list exported to: $ExportPath" -ForegroundColor Green
    }
    
    return $installedSoftware | Sort-Object Name -Unique
}

function Install-WingetSoftware {
    param(
        [string]$Id,
        [string]$Name
    )
    
    try {
        Write-Host "Installing $Name via Winget..." -ForegroundColor Cyan
        Add-Content -Path $LogPath -Value "$(Get-Date): Installing $Name (ID: $Id) via Winget"
        
        $result = winget install --id $Id --accept-package-agreements --accept-source-agreements --silent
        
        if ($LASTEXITCODE -eq 0) {
            Write-Host "✅ $Name installed successfully" -ForegroundColor Green
            Add-Content -Path $LogPath -Value "$(Get-Date): SUCCESS - $Name installed"
            return $true
        } else {
            Write-Host "❌ Failed to install $Name. Exit code: $LASTEXITCODE" -ForegroundColor Red
            Add-Content -Path $LogPath -Value "$(Get-Date): FAILED - $Name installation failed with exit code $LASTEXITCODE"
            return $false
        }
    } catch {
        Write-Host "❌ Error installing $Name`: $($_.Exception.Message)" -ForegroundColor Red
        Add-Content -Path $LogPath -Value "$(Get-Date): ERROR - $Name installation error: $($_.Exception.Message)"
        return $false
    }
}

function Install-MSIPackage {
    param(
        [string]$Name,
        [string]$Url,
        [string]$Arguments = "/quiet /norestart"
    )
    
    try {
        Write-Host "Downloading and installing $Name..." -ForegroundColor Cyan
        Add-Content -Path $LogPath -Value "$(Get-Date): Installing $Name via MSI from $Url"
        
        $tempFile = "$env:TEMP\$Name.msi"
        Invoke-WebRequest -Uri $Url -OutFile $tempFile -UseBasicParsing
        
        $process = Start-Process -FilePath "msiexec.exe" -ArgumentList "/i `"$tempFile`" $Arguments" -Wait -PassThru
        
        if ($process.ExitCode -eq 0) {
            Write-Host "✅ $Name installed successfully" -ForegroundColor Green
            Add-Content -Path $LogPath -Value "$(Get-Date): SUCCESS - $Name installed"
            Remove-Item $tempFile -Force -ErrorAction SilentlyContinue
            return $true
        } else {
            Write-Host "❌ Failed to install $Name. Exit code: $($process.ExitCode)" -ForegroundColor Red
            Add-Content -Path $LogPath -Value "$(Get-Date): FAILED - $Name installation failed with exit code $($process.ExitCode)"
            return $false
        }
    } catch {
        Write-Host "❌ Error installing $Name`: $($_.Exception.Message)" -ForegroundColor Red
        Add-Content -Path $LogPath -Value "$(Get-Date): ERROR - $Name installation error: $($_.Exception.Message)"
        return $false
    }
}

function Install-EXEPackage {
    param(
        [string]$Name,
        [string]$Url,
        [string]$Arguments = "/S"
    )
    
    try {
        Write-Host "Downloading and installing $Name..." -ForegroundColor Cyan
        Add-Content -Path $LogPath -Value "$(Get-Date): Installing $Name via EXE from $Url"
        
        $extension = if ($Url -match "\.([^.]+)$") { $matches[1] } else { "exe" }
        $tempFile = "$env:TEMP\$Name.$extension"
        
        Invoke-WebRequest -Uri $Url -OutFile $tempFile -UseBasicParsing
        
        $process = Start-Process -FilePath $tempFile -ArgumentList $Arguments -Wait -PassThru
        
        if ($process.ExitCode -eq 0) {
            Write-Host "✅ $Name installed successfully" -ForegroundColor Green
            Add-Content -Path $LogPath -Value "$(Get-Date): SUCCESS - $Name installed"
            Remove-Item $tempFile -Force -ErrorAction SilentlyContinue
            return $true
        } else {
            Write-Host "❌ Failed to install $Name. Exit code: $($process.ExitCode)" -ForegroundColor Red
            Add-Content -Path $LogPath -Value "$(Get-Date): FAILED - $Name installation failed with exit code $($process.ExitCode)"
            return $false
        }
    } catch {
        Write-Host "❌ Error installing $Name`: $($_.Exception.Message)" -ForegroundColor Red
        Add-Content -Path $LogPath -Value "$(Get-Date): ERROR - $Name installation error: $($_.Exception.Message)"
        return $false
    }
}

function Install-PowerShellModule {
    param([string]$ModuleName)
    
    try {
        Write-Host "Installing PowerShell module: $ModuleName..." -ForegroundColor Cyan
        Add-Content -Path $LogPath -Value "$(Get-Date): Installing PowerShell module $ModuleName"
        
        Install-Module -Name $ModuleName -Force -AllowClobber -Scope CurrentUser
        
        if (Get-Module -ListAvailable -Name $ModuleName) {
            Write-Host "✅ $ModuleName module installed successfully" -ForegroundColor Green
            Add-Content -Path $LogPath -Value "$(Get-Date): SUCCESS - $ModuleName module installed"
            return $true
        } else {
            Write-Host "❌ Failed to install $ModuleName module" -ForegroundColor Red
            Add-Content -Path $LogPath -Value "$(Get-Date): FAILED - $ModuleName module installation failed"
            return $false
        }
    } catch {
        Write-Host "❌ Error installing $ModuleName module: $($_.Exception.Message)" -ForegroundColor Red
        Add-Content -Path $LogPath -Value "$(Get-Date): ERROR - $ModuleName module installation error: $($_.Exception.Message)"
        return $false
    }
}

function Install-PowerShellScript {
    param(
        [string]$Name,
        [string]$Url,
        [string]$Arguments = ""
    )
    
    try {
        Write-Host "Downloading and executing PowerShell script: $Name..." -ForegroundColor Cyan
        Add-Content -Path $LogPath -Value "$(Get-Date): Executing PowerShell script $Name from $Url"
        
        $scriptContent = Invoke-WebRequest -Uri $Url -UseBasicParsing | Select-Object -ExpandProperty Content
        $scriptBlock = [ScriptBlock]::Create($scriptContent)
        
        if ($Arguments) {
            Invoke-Command -ScriptBlock $scriptBlock -ArgumentList $Arguments.Split(' ')
        } else {
            Invoke-Command -ScriptBlock $scriptBlock
        }
        
        Write-Host "✅ $Name script executed successfully" -ForegroundColor Green
        Add-Content -Path $LogPath -Value "$(Get-Date): SUCCESS - $Name script executed"
        return $true
    } catch {
        Write-Host "❌ Error executing $Name script: $($_.Exception.Message)" -ForegroundColor Red
        Add-Content -Path $LogPath -Value "$(Get-Date): ERROR - $Name script execution error: $($_.Exception.Message)"
        return $false
    }
}

function Install-StableDiffusionWebUI {
    param([string]$Name)
    
    try {
        Write-Host "Installing Stable Diffusion WebUI (Automatic1111)..." -ForegroundColor Cyan
        Add-Content -Path $LogPath -Value "$(Get-Date): Installing Stable Diffusion WebUI"
        
        # Check for Git
        if (-not (Get-Command git -ErrorAction SilentlyContinue)) {
            Write-Host "❌ Git is required but not found. Please install Git first." -ForegroundColor Red
            Add-Content -Path $LogPath -Value "$(Get-Date): FAILED - Git not found"
            return $false
        }
        
        # Check for Python
        if (-not (Get-Command python -ErrorAction SilentlyContinue)) {
            Write-Host "❌ Python is required but not found. Please install Python 3.10+ first." -ForegroundColor Red
            Add-Content -Path $LogPath -Value "$(Get-Date): FAILED - Python not found"
            return $false
        }
        
        # Create installation directory
        $installPath = "$env:USERPROFILE\stable-diffusion-webui"
        if (Test-Path $installPath) {
            Write-Host "⚠️ Stable Diffusion WebUI directory already exists at $installPath" -ForegroundColor Yellow
            Write-Host "Do you want to update it? (y/n): " -ForegroundColor Cyan -NoNewline
            $update = Read-Host
            if ($update -eq 'y' -or $update -eq 'Y') {
                Set-Location $installPath
                git pull
            } else {
                Write-Host "Installation cancelled." -ForegroundColor Yellow
                return $false
            }
        } else {
            Write-Host "Cloning Stable Diffusion WebUI repository..." -ForegroundColor Cyan
            git clone https://github.com/AUTOMATIC1111/stable-diffusion-webui.git $installPath
            if ($LASTEXITCODE -ne 0) {
                Write-Host "❌ Failed to clone repository" -ForegroundColor Red
                Add-Content -Path $LogPath -Value "$(Get-Date): FAILED - Git clone failed"
                return $false
            }
        }
        
        # Create startup script
        $startupScript = @"
@echo off
cd /d "$installPath"
call webui-user.bat
pause
"@
        
        $startupPath = "$env:USERPROFILE\Desktop\Start Stable Diffusion WebUI.bat"
        Set-Content -Path $startupPath -Value $startupScript -Encoding ASCII
        
        Write-Host "✅ Stable Diffusion WebUI installed successfully" -ForegroundColor Green
        Write-Host "📍 Installation location: $installPath" -ForegroundColor Cyan
        Write-Host "🚀 Desktop shortcut created: $startupPath" -ForegroundColor Cyan
        Write-Host ""
        Write-Host "📋 Next steps:" -ForegroundColor Yellow
        Write-Host "   1. Download a Stable Diffusion model (e.g., from Hugging Face)" -ForegroundColor Gray
        Write-Host "   2. Place the model in: $installPath\models\Stable-diffusion\" -ForegroundColor Gray
        Write-Host "   3. Run the desktop shortcut to start the WebUI" -ForegroundColor Gray
        Write-Host "   4. The first run will install additional dependencies" -ForegroundColor Gray
        
        Add-Content -Path $LogPath -Value "$(Get-Date): SUCCESS - Stable Diffusion WebUI installed"
        return $true
    } catch {
        Write-Host "❌ Error installing Stable Diffusion WebUI: $($_.Exception.Message)" -ForegroundColor Red
        Add-Content -Path $LogPath -Value "$(Get-Date): ERROR - Stable Diffusion WebUI installation error: $($_.Exception.Message)"
        return $false
    }
}

function Install-GitHubRelease {
    param(
        [string]$Name,
        [string]$Repository,
        [string]$AssetPattern = "",
        [string]$InstallPath = "",
        [string]$Arguments = "",
        [string]$PostInstallScript = ""
    )
    
    try {
        Write-Host "Installing $Name from GitHub..." -ForegroundColor Cyan
        Add-Content -Path $LogPath -Value "$(Get-Date): Installing $Name from GitHub repository $Repository"
        
        # Get latest release info from GitHub API
        $apiUrl = "https://api.github.com/repos/$Repository/releases/latest"
        Write-Host "Fetching latest release information..." -ForegroundColor Cyan
        
        try {
            $releaseInfo = Invoke-RestMethod -Uri $apiUrl -UseBasicParsing
        } catch {
            Write-Host "❌ Failed to fetch release information from GitHub" -ForegroundColor Red
            Add-Content -Path $LogPath -Value "$(Get-Date): FAILED - GitHub API call failed: $($_.Exception.Message)"
            return $false
        }
        
        if (-not $releaseInfo.assets -or $releaseInfo.assets.Count -eq 0) {
            Write-Host "❌ No release assets found for $Repository" -ForegroundColor Red
            Add-Content -Path $LogPath -Value "$(Get-Date): FAILED - No release assets found"
            return $false
        }
        
        # Find the appropriate asset
        $asset = $null
        if ($AssetPattern) {
            $asset = $releaseInfo.assets | Where-Object { $_.name -match $AssetPattern } | Select-Object -First 1
        } else {
            # Try to find Windows-compatible assets
            $windowsPatterns = @("\.exe$", "\.msi$", "\.zip$", "windows", "win64", "win32")
            foreach ($pattern in $windowsPatterns) {
                $asset = $releaseInfo.assets | Where-Object { $_.name -match $pattern } | Select-Object -First 1
                if ($asset) { break }
            }
        }
        
        if (-not $asset) {
            Write-Host "❌ No suitable asset found. Available assets:" -ForegroundColor Red
            $releaseInfo.assets | ForEach-Object { Write-Host "  - $($_.name)" -ForegroundColor Gray }
            Add-Content -Path $LogPath -Value "$(Get-Date): FAILED - No suitable asset found"
            return $false
        }
        
        Write-Host "Found asset: $($asset.name) ($(($asset.size / 1MB).ToString('F2')) MB)" -ForegroundColor Green
        
        # Download the asset
        $extension = [System.IO.Path]::GetExtension($asset.name)
        $tempFile = "$env:TEMP\$Name$extension"
        
        Write-Host "Downloading $($asset.name)..." -ForegroundColor Cyan
        try {
            Invoke-WebRequest -Uri $asset.browser_download_url -OutFile $tempFile -UseBasicParsing
        } catch {
            Write-Host "❌ Failed to download asset: $($_.Exception.Message)" -ForegroundColor Red
            Add-Content -Path $LogPath -Value "$(Get-Date): FAILED - Download failed: $($_.Exception.Message)"
            return $false
        }
        
        # Install based on file type
        $success = $false
        switch ($extension.ToLower()) {
            ".exe" {
                if ($Arguments) {
                    $success = Install-EXEPackage -Name $Name -Url "file://$tempFile" -Arguments $Arguments
                } else {
                    Write-Host "Installing executable..." -ForegroundColor Cyan
                    $process = Start-Process -FilePath $tempFile -ArgumentList "/S" -Wait -PassThru
                    $success = ($process.ExitCode -eq 0)
                }
            }
            ".msi" {
                if ($Arguments) {
                    $success = Install-MSIPackage -Name $Name -Url "file://$tempFile" -Arguments $Arguments
                } else {
                    Write-Host "Installing MSI package..." -ForegroundColor Cyan
                    $process = Start-Process -FilePath "msiexec.exe" -ArgumentList "/i `"$tempFile`" /quiet /norestart" -Wait -PassThru
                    $success = ($process.ExitCode -eq 0)
                }
            }
            ".zip" {
                $extractPath = if ($InstallPath) { $InstallPath } else { "$env:USERPROFILE\$Name" }
                Write-Host "Extracting to: $extractPath" -ForegroundColor Cyan
                
                if (Test-Path $extractPath) {
                    Write-Host "⚠️ Directory already exists. Remove it? (y/n): " -ForegroundColor Yellow -NoNewline
                    $remove = Read-Host
                    if ($remove -eq 'y' -or $remove -eq 'Y') {
                        Remove-Item $extractPath -Recurse -Force
                    } else {
                        Write-Host "Installation cancelled." -ForegroundColor Yellow
                        return $false
                    }
                }
                
                try {
                    # Create directory
                    New-Item -ItemType Directory -Path $extractPath -Force | Out-Null
                    
                    # Extract using .NET classes (built into PowerShell)
                    Add-Type -AssemblyName System.IO.Compression.FileSystem
                    [System.IO.Compression.ZipFile]::ExtractToDirectory($tempFile, $extractPath)
                    
                    Write-Host "✅ Extracted successfully to: $extractPath" -ForegroundColor Green
                    
                    # Create desktop shortcut if executable found
                    $exeFiles = Get-ChildItem -Path $extractPath -Filter "*.exe" -Recurse | Select-Object -First 1
                    if ($exeFiles) {
                        $shortcutPath = "$env:USERPROFILE\Desktop\$Name.lnk"
                        $shell = New-Object -ComObject WScript.Shell
                        $shortcut = $shell.CreateShortcut($shortcutPath)
                        $shortcut.TargetPath = $exeFiles.FullName
                        $shortcut.WorkingDirectory = $exeFiles.DirectoryName
                        $shortcut.Save()
                        Write-Host "🚀 Desktop shortcut created: $shortcutPath" -ForegroundColor Cyan
                    }
                    
                    $success = $true
                } catch {
                    Write-Host "❌ Failed to extract: $($_.Exception.Message)" -ForegroundColor Red
                    $success = $false
                }
            }
            default {
                Write-Host "❌ Unsupported file type: $extension" -ForegroundColor Red
                $success = $false
            }
        }
        
        # Execute post-install script if provided
        if ($success -and $PostInstallScript) {
            Write-Host "Running post-install script..." -ForegroundColor Cyan
            try {
                $scriptBlock = [ScriptBlock]::Create($PostInstallScript)
                Invoke-Command -ScriptBlock $scriptBlock
            } catch {
                Write-Host "⚠️ Post-install script failed: $($_.Exception.Message)" -ForegroundColor Yellow
            }
        }
        
        # Cleanup
        Remove-Item $tempFile -Force -ErrorAction SilentlyContinue
        
        if ($success) {
            Write-Host "✅ $Name installed successfully from GitHub" -ForegroundColor Green
            Add-Content -Path $LogPath -Value "$(Get-Date): SUCCESS - $Name installed from GitHub"
        } else {
            Write-Host "❌ Failed to install $Name" -ForegroundColor Red
            Add-Content -Path $LogPath -Value "$(Get-Date): FAILED - $Name installation failed"
        }
        
        return $success
    } catch {
        Write-Host "❌ Error installing $Name from GitHub: $($_.Exception.Message)" -ForegroundColor Red
        Add-Content -Path $LogPath -Value "$(Get-Date): ERROR - $Name GitHub installation error: $($_.Exception.Message)"
        return $false
    }
}

function Search-WingetPackages {
    param([string]$SearchTerm)
    
    try {
        if (-not (Get-Command winget -ErrorAction SilentlyContinue)) {
            Write-Host "❌ Winget not available" -ForegroundColor Red
            return @()
        }
        
        Write-Host "Searching Winget for: $SearchTerm..." -ForegroundColor Cyan
        $searchResults = winget search $SearchTerm --accept-source-agreements 2>$null
        
        $packages = @()
        foreach ($line in $searchResults) {
            if ($line -match "^(.+?)\s+([^\s]+)\s+(.+?)(?:\s+winget)?$" -and $line -notmatch "^Name\s+Id|^-+$") {
                $packages += [PSCustomObject]@{
                    Name = $matches[1].Trim()
                    Id = $matches[2].Trim()
                    Version = $matches[3].Trim()
                    Type = "Winget"
                }
            }
        }
        
        return $packages | Select-Object -First 10
    } catch {
        Write-Host "❌ Error searching Winget: $($_.Exception.Message)" -ForegroundColor Red
        return @()
    }
}

function Search-GitHubRepositories {
    param([string]$SearchTerm)
    
    try {
        Write-Host "Searching GitHub for: $SearchTerm..." -ForegroundColor Cyan
        $apiUrl = "https://api.github.com/search/repositories?q=$SearchTerm+language:PowerShell+OR+language:C%23+OR+language:C%2B%2B+OR+language:Rust+OR+language:Go&sort=stars&order=desc&per_page=10"
        
        $searchResults = Invoke-RestMethod -Uri $apiUrl -UseBasicParsing
        
        $repositories = @()
        foreach ($repo in $searchResults.items) {
            # Check if repo has releases
            try {
                $releasesUrl = "https://api.github.com/repos/$($repo.full_name)/releases/latest"
                $latestRelease = Invoke-RestMethod -Uri $releasesUrl -UseBasicParsing -ErrorAction Stop
                
                if ($latestRelease.assets -and $latestRelease.assets.Count -gt 0) {
                    $repositories += [PSCustomObject]@{
                        Name = $repo.name
                        Repository = $repo.full_name
                        Description = $repo.description
                        Stars = $repo.stargazers_count
                        Type = "GitHub"
                        HasReleases = $true
                    }
                }
            } catch {
                # No releases or API limit
                continue
            }
        }
        
        return $repositories
    } catch {
        Write-Host "❌ Error searching GitHub: $($_.Exception.Message)" -ForegroundColor Red
        return @()
    }
}

function Show-SearchResults {
    param(
        [array]$WingetResults,
        [array]$GitHubResults
    )
    
    Clear-Host
    Write-Host "╔══════════════════════════════════════════════════╗" -ForegroundColor Cyan
    Write-Host "║              Search Results                      ║" -ForegroundColor Cyan
    Write-Host "╚══════════════════════════════════════════════════╝" -ForegroundColor Cyan
    Write-Host ""
    
    $allResults = @()
    $index = 1
    
    if ($WingetResults.Count -gt 0) {
        Write-Host "🔍 Winget Packages:" -ForegroundColor Yellow
        foreach ($pkg in $WingetResults) {
            Write-Host "$index. [W] $($pkg.Name)" -ForegroundColor White
            Write-Host "    ID: $($pkg.Id) | Version: $($pkg.Version)" -ForegroundColor Gray
            $allResults += $pkg
            $index++
        }
        Write-Host ""
    }
    
    if ($GitHubResults.Count -gt 0) {
        Write-Host "🔍 GitHub Repositories:" -ForegroundColor Yellow
        foreach ($repo in $GitHubResults) {
            Write-Host "$index. [GH] $($repo.Name)" -ForegroundColor White
            Write-Host "    Repo: $($repo.Repository) | ⭐ $($repo.Stars)" -ForegroundColor Gray
            Write-Host "    $($repo.Description)" -ForegroundColor DarkGray
            $allResults += $repo
            $index++
        }
        Write-Host ""
    }
    
    if ($allResults.Count -eq 0) {
        Write-Host "No results found." -ForegroundColor Yellow
        Write-Host ""
        Write-Host "Press any key to continue..." -ForegroundColor Gray
        $null = $Host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown")
        return @()
    }
    
    Write-Host "Enter numbers (comma-separated) to add to your software collection:" -ForegroundColor Cyan
    Write-Host "B. Back to main menu" -ForegroundColor Gray
    Write-Host ""
    Write-Host "Enter your choice: " -ForegroundColor Cyan -NoNewline
    
    $choice = Read-Host
    
    if ($choice.ToUpper() -eq "B") {
        return @()
    }
    
    $selectedIndexes = @()
    if ($choice -match '^[\d,\s]+$') {
        $selectedIndexes = $choice -split ',' | ForEach-Object { 
            $num = [int]$_.Trim() - 1
            if ($num -ge 0 -and $num -lt $allResults.Count) { $num }
        }
    }
    
    $selectedResults = @()
    foreach ($idx in $selectedIndexes) {
        $selectedResults += $allResults[$idx]
    }
    
    return $selectedResults
}

function Add-SoftwareToCategory {
    param([array]$SelectedSoftware)
    
    if ($SelectedSoftware.Count -eq 0) {
        return
    }
    
    Clear-Host
    Write-Host "╔══════════════════════════════════════════════════╗" -ForegroundColor Cyan
    Write-Host "║          Add Software to Category               ║" -ForegroundColor Cyan
    Write-Host "╚══════════════════════════════════════════════════╝" -ForegroundColor Cyan
    Write-Host ""
    
    Write-Host "Selected software to add:" -ForegroundColor Yellow
    foreach ($sw in $SelectedSoftware) {
        Write-Host "  - $($sw.Name) [$($sw.Type)]" -ForegroundColor White
    }
    Write-Host ""
    
    # Show categories
    $categories = $softwareCategories.Keys | Sort-Object
    for ($i = 0; $i -lt $categories.Count; $i++) {
        Write-Host "$($i + 1). $($categories[$i])" -ForegroundColor Yellow
    }
    Write-Host ""
    Write-Host "Select category (number): " -ForegroundColor Cyan -NoNewline
    $categoryChoice = Read-Host
    
    $categoryIndex = [int]$categoryChoice - 1
    if ($categoryIndex -lt 0 -or $categoryIndex -ge $categories.Count) {
        Write-Host "Invalid category selection." -ForegroundColor Red
        return
    }
    
    $selectedCategory = $categories[$categoryIndex]
    
    # Show subcategories
    Clear-Host
    Write-Host "Selected Category: $selectedCategory" -ForegroundColor Cyan
    Write-Host ""
    
    $subcategories = $softwareCategories[$selectedCategory].Keys | Sort-Object
    for ($i = 0; $i -lt $subcategories.Count; $i++) {
        Write-Host "$($i + 1). $($subcategories[$i])" -ForegroundColor Yellow
    }
    Write-Host ""
    Write-Host "Select subcategory (number): " -ForegroundColor Cyan -NoNewline
    $subcategoryChoice = Read-Host
    
    $subcategoryIndex = [int]$subcategoryChoice - 1
    if ($subcategoryIndex -lt 0 -or $subcategoryIndex -ge $subcategories.Count) {
        Write-Host "Invalid subcategory selection." -ForegroundColor Red
        return
    }
    
    $selectedSubcategory = $subcategories[$subcategoryIndex]
    
    # Add software to the category
    foreach ($software in $SelectedSoftware) {
        $newEntry = @{
            Name = $software.Name
            Type = $software.Type
            Description = if ($software.Description) { $software.Description } else { "User-added software" }
        }
        
        if ($software.Type -eq "Winget") {
            $newEntry.Id = $software.Id
        } elseif ($software.Type -eq "GitHub") {
            $newEntry.Repository = $software.Repository
            $newEntry.AssetPattern = ""
        }
        
        $softwareCategories[$selectedCategory][$selectedSubcategory] += $newEntry
    }
    
    Write-Host ""
    Write-Host "✅ Successfully added $($SelectedSoftware.Count) software item(s) to $selectedCategory > $selectedSubcategory" -ForegroundColor Green
    
    # Ask if user wants to save changes permanently
    Write-Host ""
    Write-Host "Save changes to the script file permanently? (y/n): " -ForegroundColor Cyan -NoNewline
    $saveChoice = Read-Host
    
    if ($saveChoice -eq 'y' -or $saveChoice -eq 'Y') {
        Save-SoftwareCategories
    }
    
    Write-Host ""
    Write-Host "Press any key to continue..." -ForegroundColor Gray
    $null = $Host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown")
}

function Save-SoftwareCategories {
    try {
        Write-Host "Saving changes to JSON file..." -ForegroundColor Cyan
        
        $jsonPath = ".\software-categories.json"
        
        # Create backup of JSON file
        if (Test-Path $jsonPath) {
            $backupPath = ".\software-categories_backup_$(Get-Date -Format 'yyyyMMdd_HHmmss').json"
            Copy-Item -Path $jsonPath -Destination $backupPath
            Write-Host "Backup created: $backupPath" -ForegroundColor Green
        }
        
        # Convert hashtable to JSON and save
        $jsonContent = $softwareCategories | ConvertTo-Json -Depth 10
        Set-Content -Path $jsonPath -Value $jsonContent -Encoding UTF8
        
        Write-Host "✅ Software categories saved successfully to JSON file!" -ForegroundColor Green
        Add-Content -Path $LogPath -Value "$(Get-Date): SUCCESS - Software categories saved to JSON file"
        
    } catch {
        Write-Host "❌ Error saving changes: $($_.Exception.Message)" -ForegroundColor Red
        Add-Content -Path $LogPath -Value "$(Get-Date): ERROR - Failed to save software categories: $($_.Exception.Message)"
    }
}


function Show-SearchMenu {
    Clear-Host
    Write-Host "╔══════════════════════════════════════════════════╗" -ForegroundColor Cyan
    Write-Host "║            Software Search & Discovery           ║" -ForegroundColor Cyan
    Write-Host "╚══════════════════════════════════════════════════╝" -ForegroundColor Cyan
    Write-Host ""
    
    Write-Host "Enter search term (e.g., 'video editor', 'python', 'git'): " -ForegroundColor Cyan -NoNewline
    $searchTerm = Read-Host
    
    if ([string]::IsNullOrWhiteSpace($searchTerm)) {
        Write-Host "Search cancelled." -ForegroundColor Yellow
        Write-Host "Press any key to continue..." -ForegroundColor Gray
        $null = $Host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown")
        return
    }
    
    Write-Host ""
    Write-Host "Searching for '$searchTerm'..." -ForegroundColor Cyan
    Write-Host ""
    
    $wingetResults = Search-WingetPackages -SearchTerm $searchTerm
    $githubResults = Search-GitHubRepositories -SearchTerm $searchTerm
    
    $selectedSoftware = Show-SearchResults -WingetResults $wingetResults -GitHubResults $githubResults
    
    if ($selectedSoftware.Count -gt 0) {
        Add-SoftwareToCategory -SelectedSoftware $selectedSoftware
    }
}

# ===== SOFTWARE CATEGORIES =====
# Load software categories from JSON file
function Load-SoftwareCategories {
    $jsonPath = ".\software-categories.json"
    
    if (-not (Test-Path $jsonPath)) {
        Write-Host "❌ Error: Software categories file not found: $jsonPath" -ForegroundColor Red
        Write-Host "Please ensure the software-categories.json file exists in the same directory as this script." -ForegroundColor Yellow
        exit 1
    }
    
    try {
        $jsonContent = Get-Content -Path $jsonPath -Raw -Encoding UTF8
        $categoriesObject = $jsonContent | ConvertFrom-Json
        
        # Convert PSCustomObject to hashtable for PowerShell 5.1 compatibility
        $categories = @{}
        foreach ($property in $categoriesObject.PSObject.Properties) {
            $categoryName = $property.Name
            $subcategories = @{}
            
            foreach ($subProperty in $property.Value.PSObject.Properties) {
                $subcategoryName = $subProperty.Name
                $apps = @()
                
                foreach ($app in $subProperty.Value) {
                    $appHash = @{}
                    foreach ($appProperty in $app.PSObject.Properties) {
                        $appHash[$appProperty.Name] = $appProperty.Value
                    }
                    $apps += $appHash
                }
                
                $subcategories[$subcategoryName] = $apps
            }
            
            $categories[$categoryName] = $subcategories
        }
        
        return $categories
    }
    catch {
        Write-Host "❌ Error loading software categories: $($_.Exception.Message)" -ForegroundColor Red
        Write-Host "Please check that the JSON file is valid." -ForegroundColor Yellow
        exit 1
    }
}

# Initialize software categories from JSON file
$softwareCategories = Load-SoftwareCategories

# ===== PAGING UTILITY FUNCTION =====
function Show-PagedList {
    param(
        [array]$Items,
        [string]$Title,
        [string]$Subtitle = "",
        [int]$PageSize = 10,
        [scriptblock]$DisplayItem,
        [string]$Legend = ""
    )
    
    if ($Items.Count -eq 0) {
        Clear-Host
        Write-Host "╔══════════════════════════════════════════════════╗" -ForegroundColor Cyan
        Write-Host "║           Software Installation Manager          ║" -ForegroundColor Cyan
        Write-Host "║                   $($Title.PadRight(27))          ║" -ForegroundColor Cyan
        if ($Subtitle) {
            Write-Host "║              $($Subtitle.PadRight(32))║" -ForegroundColor Cyan
        }
        Write-Host "╚══════════════════════════════════════════════════╝" -ForegroundColor Cyan
        Write-Host ""
        Write-Host "No items to display." -ForegroundColor Yellow
        Write-Host ""
        Write-Host "Press any key to continue..." -ForegroundColor Gray
        $null = $Host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown")
        return ""
    }
    
    $totalPages = [Math]::Ceiling($Items.Count / $PageSize)
    $currentPage = 1
    
    while ($true) {
        Clear-Host
        Write-Host "╔══════════════════════════════════════════════════╗" -ForegroundColor Cyan
        Write-Host "║           Software Installation Manager          ║" -ForegroundColor Cyan
        Write-Host "║                   $($Title.PadRight(27))          ║" -ForegroundColor Cyan
        if ($Subtitle) {
            Write-Host "║              $($Subtitle.PadRight(32))║" -ForegroundColor Cyan
        }
        Write-Host "╚══════════════════════════════════════════════════╝" -ForegroundColor Cyan
        Write-Host ""
        
        # Calculate start and end indices for current page
        $startIndex = ($currentPage - 1) * $PageSize
        $endIndex = [Math]::Min($startIndex + $PageSize - 1, $Items.Count - 1)
        
        # Display page header
        Write-Host "Page $currentPage of $totalPages (showing items $($startIndex + 1)-$($endIndex + 1) of $($Items.Count))" -ForegroundColor Gray
        Write-Host ""
        
        # Display items for current page
        for ($i = $startIndex; $i -le $endIndex; $i++) {
            if ($DisplayItem) {
                & $DisplayItem $Items[$i] ($i + 1)
            } else {
                Write-Host "$($i + 1). $($Items[$i])" -ForegroundColor White
            }
        }
        
        # Display legend if provided
        if ($Legend) {
            Write-Host ""
            Write-Host $Legend -ForegroundColor DarkGray
        }
        
        # Display navigation options
        Write-Host ""
        Write-Host "Navigation:" -ForegroundColor Cyan
        if ($currentPage -gt 1) {
            Write-Host "P. Previous page" -ForegroundColor Yellow
        }
        if ($currentPage -lt $totalPages) {
            Write-Host "N. Next page" -ForegroundColor Yellow
        }
        if ($totalPages -gt 1) {
            Write-Host "G. Go to page" -ForegroundColor Yellow
        }
        Write-Host ""
        
        # Add context-specific options based on the title
        if ($Title -eq "Software List") {
            Write-Host "Enter numbers separated by commas to select software," -ForegroundColor Cyan
            Write-Host "or type 'ALL' to select everything in this category:" -ForegroundColor Cyan
            Write-Host ""
            Write-Host "B. Back to subcategories" -ForegroundColor Gray
            Write-Host "M. Back to main categories" -ForegroundColor Gray
        } else {
            Write-Host "B. Back" -ForegroundColor Gray
        }
        Write-Host "Q. Quit" -ForegroundColor Gray
        Write-Host ""
        Write-Host "Enter your choice: " -ForegroundColor Cyan -NoNewline
        
        $choice = Read-Host
        $choice = $choice.Trim().ToUpper()
        
        switch ($choice) {
            "Q" { return "Q" }
            "B" { return "B" }
            "M" { return "M" }
            "ALL" { return "ALL" }
            "P" {
                if ($currentPage -gt 1) {
                    $currentPage--
                }
            }
            "N" {
                if ($currentPage -lt $totalPages) {
                    $currentPage++
                }
            }
            "G" {
                Write-Host "Enter page number (1-$totalPages): " -ForegroundColor Cyan -NoNewline
                $pageInput = Read-Host
                $targetPage = 0
                if ([int]::TryParse($pageInput, [ref]$targetPage) -and $targetPage -ge 1 -and $targetPage -le $totalPages) {
                    $currentPage = $targetPage
                } else {
                    Write-Host "Invalid page number. Press any key to continue..." -ForegroundColor Red
                    $null = $Host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown")
                }
            }
            default {
                # Check if it's a selection (numbers or comma-separated numbers)
                if ($choice -match '^[\d,\s]+$' -or $choice -eq "ALL") {
                    return $choice
                } else {
                    Write-Host "Invalid choice. Press any key to continue..." -ForegroundColor Red
                    $null = $Host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown")
                }
            }
        }
    }
}

# ===== NAVIGATION FUNCTIONS =====
function Show-MainCategories {
    Clear-Host
    Write-Host "╔══════════════════════════════════════════════════╗" -ForegroundColor Cyan
    Write-Host "║           Software Installation Manager          ║" -ForegroundColor Cyan
    Write-Host "║                 Main Categories                  ║" -ForegroundColor Cyan
    Write-Host "╚══════════════════════════════════════════════════╝" -ForegroundColor Cyan
    Write-Host ""
    
    $categories = $softwareCategories.Keys | Sort-Object
    for ($i = 0; $i -lt $categories.Count; $i++) {
        $categoryName = $categories[$i]
        $subcategoryCount = $softwareCategories[$categoryName].Keys.Count
        Write-Host "$($i + 1). $categoryName" -ForegroundColor Yellow
        Write-Host "    Contains $subcategoryCount sections" -ForegroundColor Gray
    }
    
    Write-Host ""
    Write-Host "0. Show currently installed software" -ForegroundColor Gray
    Write-Host "S. Search & add new software" -ForegroundColor Green
    Write-Host "E. Export software list to file" -ForegroundColor Gray
    Write-Host "Q. Quit" -ForegroundColor Gray
    Write-Host ""
    Write-Host "Enter your choice: " -ForegroundColor Cyan -NoNewline
}

function Show-Subcategories {
    param([string]$categoryName)
    
    Clear-Host
    Write-Host "╔══════════════════════════════════════════════════╗" -ForegroundColor Cyan
    Write-Host "║           Software Installation Manager          ║" -ForegroundColor Cyan
    Write-Host "║              $($categoryName.PadRight(32))║" -ForegroundColor Cyan
    Write-Host "╚══════════════════════════════════════════════════╝" -ForegroundColor Cyan
    Write-Host ""
    
    $subcategories = $softwareCategories[$categoryName].Keys | Sort-Object
    for ($i = 0; $i -lt $subcategories.Count; $i++) {
        $subcategoryName = $subcategories[$i]
        $softwareCount = $softwareCategories[$categoryName][$subcategoryName].Count
        Write-Host "$($i + 1). $subcategoryName" -ForegroundColor Yellow
        Write-Host "    Contains $softwareCount apps" -ForegroundColor Gray
    }
    
    Write-Host ""
    Write-Host "B. Back to main categories" -ForegroundColor Gray
    Write-Host "Q. Quit" -ForegroundColor Gray
    Write-Host ""
    Write-Host "Enter your choice: " -ForegroundColor Cyan -NoNewline
}

function Show-SoftwareList {
    param(
        [string]$categoryName,
        [string]$subcategoryName
    )
    
    $softwareList = $softwareCategories[$categoryName][$subcategoryName]
    $subtitle = "$categoryName > $subcategoryName"
    $legend = "Legend: [W]=Winget, [M]=MSI, [E]=EXE, [PS-M]=PowerShell Module, [PS-S]=PowerShell Script, [C]=Custom Install, [GH]=GitHub Release"
    
    $displayScript = {
        param($software, $index)
        
        $typeIndicator = switch ($software.Type) {
            "Winget" { "[W]" }
            "MSI" { "[M]" }
            "EXE" { "[E]" }
            "PowerShellModule" { "[PS-M]" }
            "PowerShellScript" { "[PS-S]" }
            "CustomInstall" { "[C]" }
            "GitHub" { "[GH]" }
            default { "[?]" }
        }
        
        Write-Host "$index. $typeIndicator $($software.Name)" -ForegroundColor White
        Write-Host "    $($software.Description)" -ForegroundColor DarkGray
    }
    
    return Show-PagedList -Items $softwareList -Title "Software List" -Subtitle $subtitle -PageSize 8 -DisplayItem $displayScript -Legend $legend
}

function Get-UserMenuChoice {
    param(
        [string]$prompt = "Enter your choice: ",
        [string[]]$validChoices = @()
    )
    
    do {
        Write-Host $prompt -ForegroundColor Cyan -NoNewline
        $choice = Read-Host
        $choice = $choice.Trim().ToUpper()
        
        if ($validChoices.Count -eq 0 -or $choice -in $validChoices -or $choice -match '^\d+$' -or $choice -match '^[\d,\s]+$') {
            return $choice
        }
        
        Write-Host "Invalid choice. Please try again." -ForegroundColor Red
    } while ($true)
}

function Navigate-SoftwareMenu {
    $currentLevel = "main"
    $selectedCategory = ""
    $selectedSubcategory = ""
    
    while ($true) {
        switch ($currentLevel) {
            "main" {
                Show-MainCategories
                $choice = Get-UserMenuChoice
                
                switch ($choice) {
                    "Q" { return }
                    "0" {
                        Clear-Host
                        Write-Host "Scanning your system for installed software..." -ForegroundColor Cyan
                        $installedSoftware = Get-InstalledSoftware
                        
                        $displayScript = {
                            param($software, $index)
                            $name = if ($software.Name.Length -gt 35) { $software.Name.Substring(0, 32) + "..." } else { $software.Name }
                            $version = if ($software.Version.Length -gt 12) { $software.Version.Substring(0, 9) + "..." } else { $software.Version }
                            $publisher = if ($software.Publisher.Length -gt 20) { $software.Publisher.Substring(0, 17) + "..." } else { $software.Publisher }
                            $source = $software.Source
                            
                            Write-Host "$index. $name" -ForegroundColor White
                            Write-Host "    Version: $version | Publisher: $publisher | Source: $source" -ForegroundColor DarkGray
                        }
                        
                        Show-PagedList -Items $installedSoftware -Title "Installed Software" -PageSize 15 -DisplayItem $displayScript | Out-Null
                    }
                    "S" {
                        Show-SearchMenu
                    }
                    "E" {
                        Clear-Host
                        Write-Host "Exporting software list..." -ForegroundColor Cyan
                        $installedSoftware = Get-InstalledSoftware -ExportToFile -ExportPath "installed_software_$(Get-Date -Format 'yyyyMMdd_HHmmss').json"
                        Write-Host "Export completed!" -ForegroundColor Green
                        Write-Host "`nPress any key to continue..." -ForegroundColor Gray
                        $null = $Host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown")
                    }
                    default {
                        $categoryIndex = [int]$choice - 1
                        $categories = $softwareCategories.Keys | Sort-Object
                        if ($categoryIndex -ge 0 -and $categoryIndex -lt $categories.Count) {
                            $selectedCategory = $categories[$categoryIndex]
                            $currentLevel = "subcategory"
                        }
                    }
                }
            }
            
            "subcategory" {
                Show-Subcategories -categoryName $selectedCategory
                $choice = Get-UserMenuChoice
                
                switch ($choice) {
                    "Q" { return }
                    "B" { $currentLevel = "main" }
                    default {
                        $subcategoryIndex = [int]$choice - 1
                        $subcategories = $softwareCategories[$selectedCategory].Keys | Sort-Object
                        if ($subcategoryIndex -ge 0 -and $subcategoryIndex -lt $subcategories.Count) {
                            $selectedSubcategory = $subcategories[$subcategoryIndex]
                            $currentLevel = "software"
                        }
                    }
                }
            }
            
            "software" {
                $choice = Show-SoftwareList -categoryName $selectedCategory -subcategoryName $selectedSubcategory
                
                switch ($choice) {
                    "Q" { return }
                    "B" { $currentLevel = "subcategory" }
                    "M" { $currentLevel = "main" }
                    "ALL" {
                        $softwareList = $softwareCategories[$selectedCategory][$selectedSubcategory]
                        Install-SelectedSoftware -softwareList $softwareList -selections (1..$softwareList.Count)
                    }
                    default {
                        if ($choice -match '^[\d,\s]+$') {
                            $selections = $choice -split ',' | ForEach-Object { [int]$_.Trim() }
                            $softwareList = $softwareCategories[$selectedCategory][$selectedSubcategory]
                            Install-SelectedSoftware -softwareList $softwareList -selections $selections
                        }
                    }
                }
            }
        }
    }
}

function Install-SelectedSoftware {
    param(
        [array]$softwareList,
        [array]$selections
    )
    
    # Confirm selections
    $selectedNames = $selections | ForEach-Object { $softwareList[$_-1].Name }
    Write-Host "`nSelected software: $($selectedNames -join ', ')" -ForegroundColor Yellow
    Write-Host "Proceed with installation? (y/n): " -ForegroundColor Cyan -NoNewline
    $confirm = Read-Host
    
    if ($confirm -ne 'y' -and $confirm -ne 'Y') {
        Write-Host "Installation cancelled." -ForegroundColor Yellow
        Write-Host "`nPress any key to continue..." -ForegroundColor Gray
        $null = $Host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown")
        return
    }
    
    # Install selected software
    $successCount = 0
    $failureCount = 0
    
    foreach ($num in $selections) {
        if ($num -le $softwareList.Count -and $num -gt 0) {
            $app = $softwareList[$num-1]
            $success = $false
            
            Write-Host ""
            Write-Host ("="*50) -ForegroundColor Cyan
            Write-Host "Installing: $($app.Name) [$($app.Type)]" -ForegroundColor Cyan
            Write-Host ("="*50) -ForegroundColor Cyan
            
            switch ($app.Type) {
                "Winget" {
                    if (Get-Command winget -ErrorAction SilentlyContinue) {
                        $success = Install-WingetSoftware -Id $app.Id -Name $app.Name
                    } else {
                        Write-Host "Winget not available. Skipping $($app.Name)" -ForegroundColor Red
                        Add-Content -Path $LogPath -Value "SKIPPED: $($app.Name) - Winget not available"
                    }
                }
                
                "MSI" {
                    $success = Install-MSIPackage -Name $app.Name -Url $app.Url -Arguments $app.Arguments
                }
                
                "EXE" {
                    $success = Install-EXEPackage -Name $app.Name -Url $app.Url -Arguments $app.Arguments
                }
                
                "PowerShellModule" {
                    $success = Install-PowerShellModule -ModuleName $app.ModuleName
                }
                
                "PowerShellScript" {
                    $success = Install-PowerShellScript -Name $app.Name -Url $app.Url -Arguments $app.Arguments
                }
                
                "CustomInstall" {
                    if ($app.Name -eq "Stable Diffusion WebUI (Automatic1111)") {
                        $success = Install-StableDiffusionWebUI -Name $app.Name
                    } else {
                        Write-Host "Unknown custom installation: $($app.Name)" -ForegroundColor Red
                        Add-Content -Path $LogPath -Value "ERROR: Unknown custom installation $($app.Name)"
                    }
                }
                
                "GitHub" {
                    $success = Install-GitHubRelease -Name $app.Name -Repository $app.Repository -AssetPattern $app.AssetPattern -InstallPath $app.InstallPath -Arguments $app.Arguments -PostInstallScript $app.PostInstallScript
                }
                
                default {
                    Write-Host "Unknown installation type: $($app.Type)" -ForegroundColor Red
                    Add-Content -Path $LogPath -Value "ERROR: Unknown installation type $($app.Type) for $($app.Name)"
                }
            }
            
            if ($success) {
                $successCount++
            } else {
                $failureCount++
            }
            
            Start-Sleep -Seconds 2
        }
    }
    
    # Show installation summary
    Write-Host ""
    Write-Host ("="*50) -ForegroundColor Green
    Write-Host "INSTALLATION SUMMARY" -ForegroundColor Green
    Write-Host ("="*50) -ForegroundColor Green
    Write-Host "Successful: $successCount" -ForegroundColor Green
    Write-Host "Failed: $failureCount" -ForegroundColor $(if ($failureCount -gt 0) { "Red" } else { "Green" })
    Write-Host "Total: $($successCount + $failureCount)" -ForegroundColor Cyan
    Write-Host "`nCheck $LogPath for detailed logs." -ForegroundColor Gray
    Write-Host ("="*50) -ForegroundColor Green
    
    Write-Host "`nPress any key to continue..." -ForegroundColor Gray
    $null = $Host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown")
}

# ===== MAIN EXECUTION =====
# Check if Winget is available
$wingetAvailable = $false
if (Get-Command winget -ErrorAction SilentlyContinue) {
    $wingetAvailable = $true
    Write-Host "Winget is available" -ForegroundColor Green
} else {
    Write-Host "Winget not found. Some installations may not be available." -ForegroundColor Yellow
}

# Start the navigation menu
Navigate-SoftwareMenu

Write-Host ""
Write-Host 'Thank you for using Software Installation Manager!' -ForegroundColor Green
