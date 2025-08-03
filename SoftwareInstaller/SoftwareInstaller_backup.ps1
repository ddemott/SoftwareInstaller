# ReinstallSoftware.ps1
# Interactive console script to select and reinstall software after Windows 11 fresh install.
# Supports Winget and custom installs. Run as Administrator.

# Parameters
param (
    [string]$JsonPath = "apps.json",  # Optional Winget export file
    [string]$DownloadDir = "$env:TEMP\Installers",  # Temp folder for downloads
    [string]$LogPath = "reinstall_log.txt"  # Log file
)

# Elevate to Admin if not already
if (-not ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)) {
    Write-Host "This script requires Administrator privileges for software installation." -ForegroundColor Yellow
    Write-Host "Attempting to restart as Administrator..." -ForegroundColor Yellow
    Start-Process powershell.exe "-NoProfile -ExecutionPolicy Bypass -File `"$PSCommandPath`"" -Verb RunAs
    exit
}

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
                $item = $_
                $allSoftware += [PSCustomObject]@{
                    Name = $item.DisplayName
                    Version = $item.DisplayVersion
                    Publisher = $item.Publisher
                    InstallDate = $item.InstallDate
                    Source = "Registry"
                    UninstallString = $item.UninstallString
                }
            }
        } catch {
            Write-Warning "Could not access registry path: $path"
        }
    }
    
    # Get software from Winget (if available)
    if (Get-Command winget -ErrorAction SilentlyContinue) {
        Write-Host "  - Scanning Winget packages..." -ForegroundColor Gray
        try {
            $wingetList = winget list --accept-source-agreements | Out-String
            $wingetLines = $wingetList -split "`n" | Where-Object { $_ -match '\S' }
            
            # Skip header lines and parse winget output
            for ($i = 2; $i -lt $wingetLines.Count; $i++) {
                $line = $wingetLines[$i].Trim()
                if ($line -and $line -notmatch "^-+$" -and $line -notmatch "upgrades available") {
                    # Parse winget output (Name, Id, Version, Available, Source)
                    $parts = $line -split '\s{2,}' # Split on multiple spaces
                    if ($parts.Count -ge 3) {
                        $allSoftware += [PSCustomObject]@{
                            Name = $parts[0].Trim()
                            Version = if ($parts.Count -gt 2) { $parts[2].Trim() } else { "Unknown" }
                            Publisher = "Unknown"
                            InstallDate = $null
                            Source = "Winget"
                            WingetId = if ($parts.Count -gt 1) { $parts[1].Trim() } else { $null }
                        }
                    }
                }
            }
        } catch {
            $errorMsg = $_.Exception.Message
            Write-Warning "Could not retrieve Winget package list: $errorMsg"
        }
    }
    
    # Get PowerShell modules
    Write-Host "  - Scanning PowerShell modules..." -ForegroundColor Gray
    try {
        Get-Module -ListAvailable | ForEach-Object {
            $module = $_
            $allSoftware += [PSCustomObject]@{
                Name = "PowerShell Module: $($module.Name)"
                Version = $module.Version.ToString()
                Publisher = $module.Author
                InstallDate = $null
                Source = "PowerShell"
                ModulePath = $module.ModuleBase
            }
        }
    } catch {
        $errorMsg = $_.Exception.Message
        Write-Warning "Could not retrieve PowerShell modules: $errorMsg"
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

# ===== INSTALLATION FUNCTIONS =====

# Function to install via Winget
function Install-WingetSoftware {
    param (
        [string]$Id,
        [string]$Name = $Id
    )
    try {
        Write-Host "Installing $Name via Winget..." -ForegroundColor Yellow
        winget install --id $Id --silent --accept-package-agreements --accept-source-agreements
        Write-Host "$Name installed successfully." -ForegroundColor Green
        Add-Content -Path $LogPath -Value "SUCCESS: Winget install of $Name ($Id) completed"
        return $true
    } catch {
        $ErrorMessage = $_.Exception.Message
        Write-Host "Failed to install $Name - $ErrorMessage" -ForegroundColor Red
        Add-Content -Path $LogPath -Value "ERROR: Winget install of $Name ($Id) failed - $ErrorMessage"
        return $false
    }
}

# Function to install PowerShell modules
function Install-PowerShellModule {
    param (
        [string]$ModuleName,
        [string]$Repository = "PSGallery",
        [switch]$Force
    )
    try {
        Write-Host "Installing PowerShell module: $ModuleName..." -ForegroundColor Yellow
        $installParams = @{
            Name = $ModuleName
            Repository = $Repository
            Scope = "CurrentUser"
        }
        if ($Force) { $installParams.Force = $true }
        
        Install-Module @installParams
        Write-Host "PowerShell module $ModuleName installed successfully." -ForegroundColor Green
        Add-Content -Path $LogPath -Value "SUCCESS: PowerShell module $ModuleName installed"
        return $true
    } catch {
        $ErrorMessage = $_.Exception.Message
        Write-Host "Failed to install PowerShell module $ModuleName - $ErrorMessage" -ForegroundColor Red
        Add-Content -Path $LogPath -Value "ERROR: PowerShell module $ModuleName failed - $ErrorMessage"
        return $false
    }
}

# Function to install MSI packages
function Install-MSIPackage {
    param (
        [string]$Name,
        [string]$Url,
        [string[]]$Arguments = @("/quiet", "/norestart")
    )
    $InstallerPath = "$DownloadDir\$Name.msi"
    try {
        Write-Host "Downloading MSI: $Name from $Url..." -ForegroundColor Yellow
        Invoke-WebRequest -Uri $Url -OutFile $InstallerPath -UseBasicParsing
        
        Write-Host "Installing MSI: $Name..." -ForegroundColor Yellow
        $msiArgs = @("/i", "`"$InstallerPath`"") + $Arguments
        Start-Process msiexec.exe -ArgumentList $msiArgs -Wait -NoNewWindow
        
        Write-Host "$Name (MSI) installed successfully." -ForegroundColor Green
        Remove-Item $InstallerPath -Force -ErrorAction SilentlyContinue
        Add-Content -Path $LogPath -Value "SUCCESS: MSI install of $Name completed"
        return $true
    } catch {
        $ErrorMessage = $_.Exception.Message
        Write-Host "Failed to install MSI $Name - $ErrorMessage" -ForegroundColor Red
        Add-Content -Path $LogPath -Value "ERROR: MSI install of $Name failed - $ErrorMessage"
        if (Test-Path $InstallerPath) { Remove-Item $InstallerPath -Force -ErrorAction SilentlyContinue }
        return $false
    }
}

# Function to install EXE packages
function Install-EXEPackage {
    param (
        [string]$Name,
        [string]$Url,
        [string[]]$Arguments = @("/S")
    )
    $InstallerPath = "$DownloadDir\$Name.exe"
    try {
        Write-Host "Downloading EXE: $Name from $Url..." -ForegroundColor Yellow
        Invoke-WebRequest -Uri $Url -OutFile $InstallerPath -UseBasicParsing
        
        Write-Host "Installing EXE: $Name..." -ForegroundColor Yellow
        Start-Process $InstallerPath -ArgumentList $Arguments -Wait -NoNewWindow
        
        Write-Host "$Name (EXE) installed successfully." -ForegroundColor Green
        Remove-Item $InstallerPath -Force -ErrorAction SilentlyContinue
        Add-Content -Path $LogPath -Value "SUCCESS: EXE install of $Name completed"
        return $true
    } catch {
        $ErrorMessage = $_.Exception.Message
        Write-Host "Failed to install EXE $Name - $ErrorMessage" -ForegroundColor Red
        Add-Content -Path $LogPath -Value "ERROR: EXE install of $Name failed - $ErrorMessage"
        if (Test-Path $InstallerPath) { Remove-Item $InstallerPath -Force -ErrorAction SilentlyContinue }
        return $false
    }
}

# Function to install via PowerShell script
function Install-PowerShellScript {
    param (
        [string]$Name,
        [string]$Url,
        [string[]]$Arguments = @()
    )
    $ScriptPath = "$DownloadDir\$Name.ps1"
    try {
        Write-Host "Downloading PowerShell script: $Name from $Url..." -ForegroundColor Yellow
        Invoke-WebRequest -Uri $Url -OutFile $ScriptPath -UseBasicParsing
        
        Write-Host "Executing PowerShell script: $Name..." -ForegroundColor Yellow
        & $ScriptPath @Arguments
        
        Write-Host "$Name (PowerShell script) executed successfully." -ForegroundColor Green
        Remove-Item $ScriptPath -Force -ErrorAction SilentlyContinue
        Add-Content -Path $LogPath -Value "SUCCESS: PowerShell script $Name executed"
        return $true
    } catch {
        $ErrorMessage = $_.Exception.Message
        Write-Host "Failed to execute PowerShell script $Name - $ErrorMessage" -ForegroundColor Red
        Add-Content -Path $LogPath -Value "ERROR: PowerShell script $Name failed - $ErrorMessage"
        if (Test-Path $ScriptPath) { Remove-Item $ScriptPath -Force -ErrorAction SilentlyContinue }
        return $false
    }
}

# ===== SOFTWARE CATEGORIES =====
# Hierarchical software organization with categories and subcategories
$softwareCategories = @{
    "Development" = @{
        "IDEs & Editors" = @(
            @{Name = "Visual Studio Code"; Type = "Winget"; Id = "Microsoft.VisualStudioCode"; Description = "Lightweight code editor with extensions" },
            @{Name = "Visual Studio 2022 Community"; Type = "Winget"; Id = "Microsoft.VisualStudio.2022.Community"; Description = "Full-featured IDE for .NET development" },
            @{Name = "Notepad++"; Type = "Winget"; Id = "Notepad++.Notepad++"; Description = "Advanced text editor with syntax highlighting" },
            @{Name = "Sublime Text"; Type = "Winget"; Id = "SublimeHQ.SublimeText.4"; Description = "Sophisticated text editor for code, markup and prose" },
            @{Name = "Atom"; Type = "Winget"; Id = "GitHub.Atom"; Description = "Hackable text editor for the 21st Century" }
        ),
        "Version Control" = @(
            @{Name = "Git"; Type = "Winget"; Id = "Git.Git"; Description = "Distributed version control system" },
            @{Name = "GitHub Desktop"; Type = "Winget"; Id = "GitHub.GitHubDesktop"; Description = "Git collaboration tool with GUI" },
            @{Name = "TortoiseGit"; Type = "Winget"; Id = "TortoiseGit.TortoiseGit"; Description = "Windows shell interface to Git" },
            @{Name = "Sourcetree"; Type = "Winget"; Id = "Atlassian.Sourcetree"; Description = "Git GUI by Atlassian" }
        ),
        "Database Tools" = @(
            @{Name = "MySQL Workbench"; Type = "Winget"; Id = "Oracle.MySQLWorkbench"; Description = "Visual database design tool" },
            @{Name = "pgAdmin"; Type = "Winget"; Id = "PostgreSQL.pgAdmin"; Description = "PostgreSQL administration tool" },
            @{Name = "DBeaver"; Type = "Winget"; Id = "dbeaver.dbeaver"; Description = "Universal database tool" },
            @{Name = "SQL Server Management Studio"; Type = "Winget"; Id = "Microsoft.SQLServerManagementStudio"; Description = "SQL Server management tool" }
        ),
        "Runtime & SDKs" = @(
            @{Name = "Python"; Type = "Winget"; Id = "Python.Python.3.12"; Description = "Python programming language" },
            @{Name = "Node.js"; Type = "Winget"; Id = "OpenJS.NodeJS"; Description = "JavaScript runtime" },
            @{Name = ".NET SDK"; Type = "Winget"; Id = "Microsoft.DotNet.SDK.8"; Description = ".NET development framework" },
            @{Name = "Java Development Kit"; Type = "Winget"; Id = "Oracle.JDK.21"; Description = "Java development kit" },
            @{Name = "Go"; Type = "Winget"; Id = "GoLang.Go"; Description = "Go programming language" }
        ),
        "Containers & Virtualization" = @(
            @{Name = "Docker Desktop"; Type = "Winget"; Id = "Docker.DockerDesktop"; Description = "Container development platform" },
            @{Name = "VirtualBox"; Type = "Winget"; Id = "Oracle.VirtualBox"; Description = "Cross-platform virtualization" },
            @{Name = "VMware Workstation Player"; Type = "Winget"; Id = "VMware.WorkstationPlayer"; Description = "Desktop virtualization" }
        )
    },
    "Internet & Communication" = @{
        "Web Browsers" = @(
            @{Name = "Google Chrome"; Type = "Winget"; Id = "Google.Chrome"; Description = "Fast, secure web browser by Google" },
            @{Name = "Mozilla Firefox"; Type = "Winget"; Id = "Mozilla.Firefox"; Description = "Fast, private & safe web browser" },
            @{Name = "Microsoft Edge"; Type = "Winget"; Id = "Microsoft.Edge"; Description = "Modern web browser by Microsoft" },
            @{Name = "Opera"; Type = "Winget"; Id = "Opera.Opera"; Description = "Fast, secure, easy-to-use browser" },
            @{Name = "Brave Browser"; Type = "Winget"; Id = "Brave.Brave"; Description = "Privacy-focused web browser" }
        ),
        "Email Clients" = @(
            @{Name = "Mozilla Thunderbird"; Type = "Winget"; Id = "Mozilla.Thunderbird"; Description = "Free email application" },
            @{Name = "Microsoft Outlook"; Type = "Winget"; Id = "Microsoft.Office"; Description = "Email and calendar client" },
            @{Name = "eM Client"; Type = "Winget"; Id = "eMClient.eMClient"; Description = "Email client with calendar and tasks" }
        ),
        "Messaging & Video Calls" = @(
            @{Name = "Discord"; Type = "Winget"; Id = "Discord.Discord"; Description = "Voice, video and text communication" },
            @{Name = "Skype"; Type = "Winget"; Id = "Microsoft.Skype"; Description = "Video calling and messaging" },
            @{Name = "Zoom"; Type = "Winget"; Id = "Zoom.Zoom"; Description = "Video conferencing platform" },
            @{Name = "Microsoft Teams"; Type = "Winget"; Id = "Microsoft.Teams"; Description = "Chat, meetings, and collaboration" },
            @{Name = "Slack"; Type = "Winget"; Id = "SlackTechnologies.Slack"; Description = "Team collaboration hub" },
            @{Name = "WhatsApp"; Type = "Winget"; Id = "WhatsApp.WhatsApp"; Description = "Messaging app" }
        ),
        "Download Managers" = @(
            @{Name = "Internet Download Manager"; Type = "EXE"; Url = "http://mirror2.internetdownloadmanager.com/idman642build25.exe"; Arguments = @("/S"); Description = "Download accelerator and manager" },
            @{Name = "Free Download Manager"; Type = "Winget"; Id = "FreeDownloadManager.FreeDownloadManager"; Description = "Download accelerator and organizer" }
        )
    },
    "Multimedia" = @{
        "Media Players" = @(
            @{Name = "VLC Media Player"; Type = "Winget"; Id = "VideoLAN.VLC"; Description = "Cross-platform multimedia player" },
            @{Name = "Windows Media Player"; Type = "Winget"; Id = "Microsoft.WindowsMediaPlayer"; Description = "Microsoft's media player" },
            @{Name = "PotPlayer"; Type = "Winget"; Id = "Daum.PotPlayer"; Description = "Multimedia player with codec support" },
            @{Name = "Kodi"; Type = "Winget"; Id = "XBMCFoundation.Kodi"; Description = "Open source media center" }
        ),
        "Audio Editing" = @(
            @{Name = "Audacity"; Type = "Winget"; Id = "Audacity.Audacity"; Description = "Free audio editor and recorder" },
            @{Name = "Reaper"; Type = "Winget"; Id = "Cockos.REAPER"; Description = "Digital audio workstation" },
            @{Name = "FL Studio"; Type = "Winget"; Id = "ImageLine.FLStudio"; Description = "Music production software" }
        ),
        "Video Editing" = @(
            @{Name = "OBS Studio"; Type = "Winget"; Id = "OBSProject.OBSStudio"; Description = "Live streaming and recording" },
            @{Name = "Handbrake"; Type = "Winget"; Id = "HandBrake.HandBrake"; Description = "Video transcoder" },
            @{Name = "DaVinci Resolve"; Type = "Winget"; Id = "Blackmagic.DaVinciResolve"; Description = "Professional video editor" },
            @{Name = "Adobe Premiere Pro"; Type = "Winget"; Id = "Adobe.Premiere"; Description = "Professional video editing" }
        ),
        "Image Editing" = @(
            @{Name = "GIMP"; Type = "Winget"; Id = "GIMP.GIMP"; Description = "GNU Image Manipulation Program" },
            @{Name = "Paint.NET"; Type = "Winget"; Id = "dotPDN.PaintDotNet"; Description = "Image and photo editing software" },
            @{Name = "Adobe Photoshop"; Type = "Winget"; Id = "Adobe.Photoshop"; Description = "Professional image editor" },
            @{Name = "Canva"; Type = "Winget"; Id = "Canva.Canva"; Description = "Graphic design platform" }
        )
    },
    "Productivity" = @{
        "Office Suites" = @(
            @{Name = "Microsoft Office 365"; Type = "Winget"; Id = "Microsoft.Office"; Description = "Complete office suite" },
            @{Name = "LibreOffice"; Type = "Winget"; Id = "TheDocumentFoundation.LibreOffice"; Description = "Free office suite" },
            @{Name = "WPS Office"; Type = "Winget"; Id = "Kingsoft.WPSOffice"; Description = "Alternative office suite" }
        ),
        "Note Taking" = @(
            @{Name = "Notion"; Type = "Winget"; Id = "Notion.Notion"; Description = "All-in-one workspace" },
            @{Name = "Obsidian"; Type = "Winget"; Id = "Obsidian.Obsidian"; Description = "Knowledge management app" },
            @{Name = "OneNote"; Type = "Winget"; Id = "Microsoft.OneNote"; Description = "Digital notebook" },
            @{Name = "Evernote"; Type = "Winget"; Id = "Evernote.Evernote"; Description = "Note-taking and organization" }
        ),
        "PDF Tools" = @(
            @{Name = "Adobe Acrobat Reader DC"; Type = "MSI"; Url = "https://ardownload2.adobe.com/pub/adobe/reader/win/AcrobatDC/2400120163/AcroRdrDC2400120163_en_US.exe"; Arguments = @("/sAll", "/rs", "/msi", "EULA_ACCEPT=YES"); Description = "PDF viewer and editor" },
            @{Name = "Foxit Reader"; Type = "Winget"; Id = "Foxit.FoxitReader"; Description = "Fast PDF reader" },
            @{Name = "Sumatra PDF"; Type = "Winget"; Id = "SumatraPDF.SumatraPDF"; Description = "Lightweight PDF viewer" }
        ),
        "Cloud Storage" = @(
            @{Name = "Dropbox"; Type = "Winget"; Id = "Dropbox.Dropbox"; Description = "Cloud storage and sync" },
            @{Name = "Google Drive"; Type = "Winget"; Id = "Google.GoogleDrive"; Description = "Google's cloud storage" },
            @{Name = "OneDrive"; Type = "Winget"; Id = "Microsoft.OneDrive"; Description = "Microsoft's cloud storage" },
            @{Name = "Box"; Type = "Winget"; Id = "Box.Box"; Description = "Enterprise cloud content management" }
        )
    },
    "Gaming" = @{
        "Game Platforms" = @(
            @{Name = "Steam"; Type = "Winget"; Id = "Valve.Steam"; Description = "Gaming platform by Valve" },
            @{Name = "Epic Games Launcher"; Type = "Winget"; Id = "EpicGames.EpicGamesLauncher"; Description = "Epic Games platform" },
            @{Name = "GOG Galaxy"; Type = "Winget"; Id = "GOG.Galaxy"; Description = "DRM-free gaming platform" },
            @{Name = "Origin"; Type = "Winget"; Id = "ElectronicArts.Origin"; Description = "EA's gaming platform" },
            @{Name = "Ubisoft Connect"; Type = "Winget"; Id = "Ubisoft.Connect"; Description = "Ubisoft's gaming platform" }
        ),
        "Game Development" = @(
            @{Name = "Unity"; Type = "Winget"; Id = "Unity.Unity.2023"; Description = "Game development platform" },
            @{Name = "Unreal Engine"; Type = "Winget"; Id = "EpicGames.UnrealEngine"; Description = "Game engine by Epic Games" },
            @{Name = "Blender"; Type = "Winget"; Id = "BlenderFoundation.Blender"; Description = "3D creation suite" }
        ),
        "Gaming Utilities" = @(
            @{Name = "MSI Afterburner"; Type = "Winget"; Id = "Guru3D.Afterburner"; Description = "Graphics card overclocking" },
            @{Name = "Discord"; Type = "Winget"; Id = "Discord.Discord"; Description = "Gaming communication platform" },
            @{Name = "NVIDIA GeForce Experience"; Type = "Winget"; Id = "Nvidia.GeForceExperience"; Description = "NVIDIA GPU optimization" }
        )
    },
    "Utilities" = @{
        "File Management" = @(
            @{Name = "7-Zip"; Type = "Winget"; Id = "7zip.7zip"; Description = "File archiver with high compression ratio" },
            @{Name = "WinRAR"; Type = "Winget"; Id = "RARLab.WinRAR"; Description = "Archive manager for ZIP and RAR" },
            @{Name = "Total Commander"; Type = "Winget"; Id = "Ghisler.TotalCommander"; Description = "File manager for Windows" },
            @{Name = "Everything"; Type = "Winget"; Id = "voidtools.Everything"; Description = "Instant file search" }
        ),
        "System Optimization" = @(
            @{Name = "CCleaner"; Type = "Winget"; Id = "Piriform.CCleaner"; Description = "System cleaner and optimizer" },
            @{Name = "Malwarebytes"; Type = "Winget"; Id = "Malwarebytes.Malwarebytes"; Description = "Anti-malware protection" },
            @{Name = "Revo Uninstaller"; Type = "Winget"; Id = "RevoUninstaller.RevoUninstaller"; Description = "Advanced uninstaller" },
            @{Name = "Glary Utilities"; Type = "Winget"; Id = "Glarysoft.GlaryUtilities"; Description = "System maintenance suite" }
        ),
        "Remote Access" = @(
            @{Name = "TeamViewer"; Type = "EXE"; Url = "https://download.teamviewer.com/download/TeamViewer_Setup.exe"; Arguments = @("/S"); Description = "Remote access and support" },
            @{Name = "AnyDesk"; Type = "Winget"; Id = "AnyDeskSoftwareGmbH.AnyDesk"; Description = "Remote desktop software" },
            @{Name = "Chrome Remote Desktop"; Type = "Winget"; Id = "Google.ChromeRemoteDesktop"; Description = "Remote access via Chrome" }
        ),
        "Password Managers" = @(
            @{Name = "Bitwarden"; Type = "Winget"; Id = "Bitwarden.Bitwarden"; Description = "Open source password manager" },
            @{Name = "1Password"; Type = "Winget"; Id = "AgileBits.1Password"; Description = "Password manager and vault" },
            @{Name = "LastPass"; Type = "Winget"; Id = "LogMeIn.LastPass"; Description = "Password manager" },
            @{Name = "KeePass"; Type = "Winget"; Id = "DominikReichl.KeePass"; Description = "Free password manager" }
        )
    },
    "Development Tools" = @{
        "Terminal & Command Line" = @(
            @{Name = "Windows Terminal"; Type = "Winget"; Id = "Microsoft.WindowsTerminal"; Description = "Modern terminal application" },
            @{Name = "PowerShell"; Type = "Winget"; Id = "Microsoft.PowerShell"; Description = "Cross-platform automation tool" },
            @{Name = "Git Bash"; Type = "Winget"; Id = "Git.Git"; Description = "Bash emulation for Git" },
            @{Name = "Oh My Posh"; Type = "PowerShellScript"; Url = "https://ohmyposh.dev/install.ps1"; Arguments = @(); Description = "Prompt theme engine" }
        ),
        "Package Managers" = @(
            @{Name = "Chocolatey"; Type = "PowerShellScript"; Url = "https://chocolatey.org/install.ps1"; Arguments = @(); Description = "Package manager for Windows" },
            @{Name = "Scoop"; Type = "PowerShellScript"; Url = "https://get.scoop.sh"; Arguments = @(); Description = "Command-line installer" },
            @{Name = "Winget"; Type = "Winget"; Id = "Microsoft.AppInstaller"; Description = "Windows Package Manager" }
        ),
        "PowerShell Modules" = @(
            @{Name = "PSReadLine"; Type = "PowerShellModule"; ModuleName = "PSReadLine"; Description = "Command line editing experience" },
            @{Name = "Posh-Git"; Type = "PowerShellModule"; ModuleName = "posh-git"; Description = "Git integration for PowerShell" },
            @{Name = "PowerShellGet"; Type = "PowerShellModule"; ModuleName = "PowerShellGet"; Description = "Package management for PowerShell" },
            @{Name = "Az PowerShell"; Type = "PowerShellModule"; ModuleName = "Az"; Description = "Azure PowerShell module" }
        )
    }
}

# Navigation functions for hierarchical menu system
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
        Write-Host "$($i + 1). $categoryName ($subcategoryCount categories)" -ForegroundColor Yellow
    }
    
    Write-Host ""
    Write-Host "0. Show currently installed software" -ForegroundColor Gray
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
        Write-Host "$($i + 1). $subcategoryName ($softwareCount items)" -ForegroundColor Yellow
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
    
    Clear-Host
    Write-Host "╔══════════════════════════════════════════════════╗" -ForegroundColor Cyan
    Write-Host "║           Software Installation Manager          ║" -ForegroundColor Cyan
    Write-Host "║  $($categoryName.PadRight(20)) > $($subcategoryName.PadRight(20)) ║" -ForegroundColor Cyan
    Write-Host "╚══════════════════════════════════════════════════╝" -ForegroundColor Cyan
    Write-Host ""
    
    $softwareList = $softwareCategories[$categoryName][$subcategoryName]
    for ($i = 0; $i -lt $softwareList.Count; $i++) {
        $software = $softwareList[$i]
        $typeIndicator = switch ($software.Type) {
            "Winget" { "[W]" }
            "MSI" { "[M]" }
            "EXE" { "[E]" }
            "PowerShellModule" { "[PS-M]" }
            "PowerShellScript" { "[PS-S]" }
            "Custom" { "[C]" }
            default { "[?]" }
        }
        
        Write-Host "$($i + 1). $typeIndicator $($software.Name)" -ForegroundColor White
        Write-Host "    $($software.Description)" -ForegroundColor Gray
        Write-Host ""
    }
    
    Write-Host "Legend: [W]=Winget, [M]=MSI, [E]=EXE, [PS-M]=PowerShell Module, [PS-S]=PowerShell Script" -ForegroundColor DarkGray
    Write-Host ""
    Write-Host "Enter numbers separated by commas (e.g., 1,3,5) to select software," -ForegroundColor Cyan
    Write-Host "or 'ALL' to select everything in this category:" -ForegroundColor Cyan
    Write-Host ""
    Write-Host "B. Back to subcategories" -ForegroundColor Gray
    Write-Host "M. Back to main categories" -ForegroundColor Gray
    Write-Host "Q. Quit" -ForegroundColor Gray
    Write-Host ""
    Write-Host "Enter your choice: " -ForegroundColor Cyan -NoNewline
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
                        Write-Host "`nScanning your system for installed software..." -ForegroundColor Cyan
                        $installedSoftware = Get-InstalledSoftware
                        
                        Write-Host "`nInstalled Software (showing first 50):" -ForegroundColor Cyan
                        $installedSoftware | Select-Object -First 50 | Format-Table Name, Version, Publisher, Source -AutoSize
                        
                        if ($installedSoftware.Count -gt 50) {
                            Write-Host "... and $($installedSoftware.Count - 50) more packages" -ForegroundColor Gray
                        }
                        
                        Write-Host "`nPress any key to continue..." -ForegroundColor Yellow
                        $null = $Host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown")
                    }
                    "E" {
                        Write-Host "`nExporting software list..." -ForegroundColor Cyan
                        $installedSoftware = Get-InstalledSoftware -ExportToFile -ExportPath "installed_software_$(Get-Date -Format 'yyyyMMdd_HHmmss').json"
                        Write-Host "Export completed!" -ForegroundColor Green
                        Write-Host "`nPress any key to continue..." -ForegroundColor Yellow
                        $null = $Host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown")
                    }
                    default {
                        if ($choice -match '^\d+$') {
                            $categoryIndex = [int]$choice - 1
                            $categories = $softwareCategories.Keys | Sort-Object
                            if ($categoryIndex -ge 0 -and $categoryIndex -lt $categories.Count) {
                                $selectedCategory = $categories[$categoryIndex]
                                $currentLevel = "subcategory"
                            } else {
                                Write-Host "Invalid selection. Press any key to continue..." -ForegroundColor Red
                                $null = $Host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown")
                            }
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
                        if ($choice -match '^\d+$') {
                            $subcategoryIndex = [int]$choice - 1
                            $subcategories = $softwareCategories[$selectedCategory].Keys | Sort-Object
                            if ($subcategoryIndex -ge 0 -and $subcategoryIndex -lt $subcategories.Count) {
                                $selectedSubcategory = $subcategories[$subcategoryIndex]
                                $currentLevel = "software"
                            } else {
                                Write-Host "Invalid selection. Press any key to continue..." -ForegroundColor Red
                                $null = $Host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown")
                            }
                        }
                    }
                }
            }
            
            "software" {
                Show-SoftwareList -categoryName $selectedCategory -subcategoryName $selectedSubcategory
                $choice = Get-UserMenuChoice
                
                switch ($choice) {
                    "Q" { return }
                    "B" { $currentLevel = "subcategory" }
                    "M" { $currentLevel = "main" }
                    "ALL" {
                        $softwareToInstall = $softwareCategories[$selectedCategory][$selectedSubcategory]
                        Install-SelectedSoftware -softwareList $softwareToInstall
                        Write-Host "`nPress any key to continue..." -ForegroundColor Yellow
                        $null = $Host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown")
                    }
                    default {
                        if ($choice -match '^[\d,\s]+$') {
                            $selections = $choice -split '[,\s]+' | Where-Object { $_ -match '^\d+$' } | ForEach-Object { [int]$_ }
                            $softwareList = $softwareCategories[$selectedCategory][$selectedSubcategory]
                            $selectedSoftware = @()
                            
                            foreach ($selection in $selections) {
                                if ($selection -ge 1 -and $selection -le $softwareList.Count) {
                                    $selectedSoftware += $softwareList[$selection - 1]
                                }
                            }
                            
                            if ($selectedSoftware.Count -gt 0) {
                                Install-SelectedSoftware -softwareList $selectedSoftware
                                Write-Host "`nPress any key to continue..." -ForegroundColor Yellow
                                $null = $Host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown")
                            } else {
                                Write-Host "No valid selections made. Press any key to continue..." -ForegroundColor Red
                                $null = $Host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown")
                            }
                        }
                    }
                }
            }
        }
    }
}

function Install-SelectedSoftware {
    param([array]$softwareList)
    
    Write-Host "`n" + "="*60 -ForegroundColor Green
    Write-Host "INSTALLATION CONFIRMATION" -ForegroundColor Green
    Write-Host "="*60 -ForegroundColor Green
    Write-Host "Selected software for installation:" -ForegroundColor Cyan
    
    foreach ($software in $softwareList) {
        $typeIndicator = switch ($software.Type) {
            "Winget" { "[W]" }
            "MSI" { "[M]" }
            "EXE" { "[E]" }
            "PowerShellModule" { "[PS-M]" }
            "PowerShellScript" { "[PS-S]" }
            default { "[?]" }
        }
        Write-Host "  $typeIndicator $($software.Name)" -ForegroundColor White
    }
    
    Write-Host ""
    Write-Host "Proceed with installation? (Y/N): " -ForegroundColor Yellow -NoNewline
    $confirm = Read-Host
    
    if ($confirm.ToUpper() -ne 'Y') {
        Write-Host "Installation cancelled." -ForegroundColor Yellow
        return
    }
    
    # Install selected software
    $successCount = 0
    $failureCount = 0
    
    foreach ($software in $softwareList) {
        $success = $false
        
        Write-Host "`n" + "="*50 -ForegroundColor Cyan
        Write-Host "Installing: $($software.Name) [$($software.Type)]" -ForegroundColor Cyan
        Write-Host "="*50 -ForegroundColor Cyan
        
        switch ($software.Type) {
            "Winget" {
                if ($wingetAvailable) {
                    $success = Install-WingetSoftware -Id $software.Id -Name $software.Name
                } else {
                    Write-Host "Winget not available. Skipping $($software.Name)" -ForegroundColor Red
                    Add-Content -Path $LogPath -Value "SKIPPED: $($software.Name) - Winget not available"
                }
            }
            "MSI" {
                $success = Install-MSIPackage -Name $software.Name -Url $software.Url -Arguments $software.Arguments
            }
            "EXE" {
                $success = Install-EXEPackage -Name $software.Name -Url $software.Url -Arguments $software.Arguments
            }
            "PowerShellModule" {
                $success = Install-PowerShellModule -ModuleName $software.ModuleName
            }
            "PowerShellScript" {
                $success = Install-PowerShellScript -Name $software.Name -Url $software.Url -Arguments $software.Arguments
            }
            default {
                Write-Host "Unknown installation type: $($software.Type)" -ForegroundColor Red
                Add-Content -Path $LogPath -Value "ERROR: Unknown installation type $($software.Type) for $($software.Name)"
            }
        }
        
        if ($success) {
            $successCount++
        } else {
            $failureCount++
        }
        
        Start-Sleep -Seconds 1
    }
    
    # Installation summary
    Write-Host "`n" + "="*50 -ForegroundColor Green
    Write-Host "INSTALLATION SUMMARY" -ForegroundColor Green
    Write-Host "="*50 -ForegroundColor Green
    Write-Host "Successful: $successCount" -ForegroundColor Green
    Write-Host "Failed: $failureCount" -ForegroundColor $(if ($failureCount -gt 0) { "Red" } else { "Green" })
    Write-Host "Total: $($successCount + $failureCount)" -ForegroundColor Cyan
    Write-Host "`nCheck $LogPath for detailed logs." -ForegroundColor Gray
    Write-Host "="*50 -ForegroundColor Green
}

# Import from Winget JSON if exists (adds to Development > Package Managers category)
if (Test-Path $JsonPath) {
    try {
        $imported = (Get-Content $JsonPath | ConvertFrom-Json).Sources.Packages
        $importedSoftware = @()
        foreach ($pkg in $imported) {
            $importedSoftware += @{
                Name = $pkg.PackageIdentifier
                Type = "Winget"
                Id = $pkg.PackageIdentifier
                Description = "Imported from Winget export"
            }
        }
        
        if ($importedSoftware.Count -gt 0) {
            # Add imported software to a special category
            if (-not $softwareCategories.ContainsKey("Imported Software")) {
                $softwareCategories["Imported Software"] = @{}
            }
            $softwareCategories["Imported Software"]["From Winget Export"] = $importedSoftware
        }
        
        Write-Host "Imported $($imported.Count) apps from $JsonPath." -ForegroundColor Green
    } catch {
        $ErrorMessage = $_.Exception.Message
        Write-Host "Failed to import from $JsonPath - $ErrorMessage" -ForegroundColor Red
    }
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

Write-Host "`nThank you for using Software Installation Manager!" -ForegroundColor Green