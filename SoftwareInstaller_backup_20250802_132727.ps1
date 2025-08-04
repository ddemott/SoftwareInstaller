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

# ===== SOFTWARE CATEGORIES =====
$softwareCategories = @{
    "Development" = @{
        "IDEs & Editors" = @(
            @{Name = "Visual Studio Code"; Type = "Winget"; Id = "Microsoft.VisualStudioCode"; Description = "Free code editor with extensions"},
            @{Name = "Visual Studio 2022 Community"; Type = "Winget"; Id = "Microsoft.VisualStudio.2022.Community"; Description = "Full-featured IDE"},
            @{Name = "JetBrains IntelliJ IDEA"; Type = "Winget"; Id = "JetBrains.IntelliJIDEA.Community"; Description = "Java IDE"},
            @{Name = "Notepad++"; Type = "Winget"; Id = "Notepad++.Notepad++"; Description = "Advanced text editor"},
            @{Name = "Sublime Text"; Type = "Winget"; Id = "SublimeHQ.SublimeText.4"; Description = "Sophisticated text editor"}
        )
        "Version Control" = @(
            @{Name = "Git"; Type = "Winget"; Id = "Git.Git"; Description = "Distributed version control system"},
            @{Name = "GitHub Desktop"; Type = "Winget"; Id = "GitHub.GitHubDesktop"; Description = "GUI for Git and GitHub"},
            @{Name = "TortoiseGit"; Type = "Winget"; Id = "TortoiseGit.TortoiseGit"; Description = "Git client with Windows shell integration"},
            @{Name = "Sourcetree"; Type = "Winget"; Id = "Atlassian.Sourcetree"; Description = "Git GUI client"}
        )
        "Databases" = @(
            @{Name = "MySQL Workbench"; Type = "Winget"; Id = "Oracle.MySQLWorkbench"; Description = "MySQL database design tool"},
            @{Name = "DBeaver"; Type = "Winget"; Id = "dbeaver.dbeaver"; Description = "Universal database tool"},
            @{Name = "PostgreSQL"; Type = "Winget"; Id = "PostgreSQL.PostgreSQL"; Description = "Advanced open source database"},
            @{Name = "MongoDB Compass"; Type = "Winget"; Id = "MongoDB.Compass.Full"; Description = "MongoDB GUI client"}
        )
        "Runtime & Languages" = @(
            @{Name = "Python 3"; Type = "Winget"; Id = "Python.Python.3.12"; Description = "Python programming language"},
            @{Name = "Node.js"; Type = "Winget"; Id = "OpenJS.NodeJS"; Description = "JavaScript runtime"},
            @{Name = "Java JDK 17"; Type = "Winget"; Id = "Oracle.JDK.17"; Description = "Java Development Kit"},
            @{Name = ".NET SDK"; Type = "Winget"; Id = "Microsoft.DotNet.SDK.8"; Description = ".NET development framework"},
            @{Name = "Go"; Type = "Winget"; Id = "GoLang.Go"; Description = "Go programming language"},
            @{Name = "Rust"; Type = "Winget"; Id = "Rustlang.Rustup"; Description = "Rust programming language"}
        )
        "API & Tools" = @(
            @{Name = "Postman"; Type = "Winget"; Id = "Postman.Postman"; Description = "API development platform"},
            @{Name = "Insomnia"; Type = "Winget"; Id = "Insomnia.Insomnia"; Description = "REST client"},
            @{Name = "Docker Desktop"; Type = "Winget"; Id = "Docker.DockerDesktop"; Description = "Containerization platform"},
            @{Name = "Wireshark"; Type = "Winget"; Id = "WiresharkFoundation.Wireshark"; Description = "Network protocol analyzer"}
        )
        "PowerShell Modules" = @(
            @{Name = "Posh-Git"; Type = "PowerShellModule"; ModuleName = "posh-git"; Description = "Git integration for PowerShell"},
            @{Name = "PowerShellGet"; Type = "PowerShellModule"; ModuleName = "PowerShellGet"; Description = "Package management for PowerShell"},
            @{Name = "Az PowerShell"; Type = "PowerShellModule"; ModuleName = "Az"; Description = "Azure PowerShell module"}
        )
    }
    
    "Internet & Communication" = @{
        "Web Browsers" = @(
            @{Name = "Google Chrome"; Type = "Winget"; Id = "Google.Chrome"; Description = "Popular web browser"},
            @{Name = "Mozilla Firefox"; Type = "Winget"; Id = "Mozilla.Firefox"; Description = "Open source web browser"},
            @{Name = "Microsoft Edge"; Type = "Winget"; Id = "Microsoft.Edge"; Description = "Microsoft's web browser"},
            @{Name = "Brave Browser"; Type = "Winget"; Id = "Brave.Brave"; Description = "Privacy-focused browser"},
            @{Name = "Opera"; Type = "Winget"; Id = "Opera.Opera"; Description = "Feature-rich web browser"}
        )
        "Communication" = @(
            @{Name = "Discord"; Type = "Winget"; Id = "Discord.Discord"; Description = "Voice and text chat platform"},
            @{Name = "Slack"; Type = "Winget"; Id = "SlackTechnologies.Slack"; Description = "Team collaboration tool"},
            @{Name = "Microsoft Teams"; Type = "Winget"; Id = "Microsoft.Teams"; Description = "Microsoft's collaboration platform"},
            @{Name = "Zoom"; Type = "Winget"; Id = "Zoom.Zoom"; Description = "Video conferencing software"},
            @{Name = "Skype"; Type = "Winget"; Id = "Microsoft.Skype"; Description = "Video calling service"}
        )
        "Email & Calendar" = @(
            @{Name = "Thunderbird"; Type = "Winget"; Id = "Mozilla.Thunderbird"; Description = "Open source email client"},
            @{Name = "Outlook"; Type = "Winget"; Id = "Microsoft.Office"; Description = "Microsoft email client"}
        )
        "File Transfer" = @(
            @{Name = "FileZilla"; Type = "Winget"; Id = "TimKosse.FileZilla.Client"; Description = "FTP client"},
            @{Name = "WinSCP"; Type = "Winget"; Id = "WinSCP.WinSCP"; Description = "SFTP and SCP client"},
            @{Name = "qBittorrent"; Type = "Winget"; Id = "qBittorrent.qBittorrent"; Description = "BitTorrent client"}
        )
    }
    
    "Multimedia" = @{
        "Media Players" = @(
            @{Name = "VLC Media Player"; Type = "Winget"; Id = "VideoLAN.VLC"; Description = "Universal media player"},
            @{Name = "MPC-HC"; Type = "Winget"; Id = "clsid2.mpc-hc"; Description = "Lightweight media player"},
            @{Name = "Spotify"; Type = "Winget"; Id = "Spotify.Spotify"; Description = "Music streaming service"},
            @{Name = "iTunes"; Type = "Winget"; Id = "Apple.iTunes"; Description = "Apple's media player"}
        )
        "Audio Editing" = @(
            @{Name = "Audacity"; Type = "Winget"; Id = "Audacity.Audacity"; Description = "Open source audio editor"},
            @{Name = "Reaper"; Type = "Winget"; Id = "Cockos.REAPER"; Description = "Digital audio workstation"},
            @{Name = "FL Studio"; Type = "Winget"; Id = "ImageLine.FLStudio"; Description = "Music production software"}
        )
        "Video Editing" = @(
            @{Name = "OBS Studio"; Type = "Winget"; Id = "OBSProject.OBSStudio"; Description = "Broadcasting and recording software"},
            @{Name = "DaVinci Resolve"; Type = "Winget"; Id = "Blackmagic.DaVinciResolve"; Description = "Professional video editor"},
            @{Name = "Handbrake"; Type = "Winget"; Id = "HandBrake.HandBrake"; Description = "Video transcoder"},
            @{Name = "FFmpeg"; Type = "Winget"; Id = "Gyan.FFmpeg"; Description = "Multimedia framework"}
        )
        "Graphics & Design" = @(
            @{Name = "GIMP"; Type = "Winget"; Id = "GIMP.GIMP"; Description = "Open source image editor"},
            @{Name = "Paint.NET"; Type = "Winget"; Id = "dotPDN.PaintDotNet"; Description = "Simple image editor"},
            @{Name = "Inkscape"; Type = "Winget"; Id = "Inkscape.Inkscape"; Description = "Vector graphics editor"},
            @{Name = "Blender"; Type = "Winget"; Id = "BlenderFoundation.Blender"; Description = "3D creation suite"},
            @{Name = "Adobe Photoshop"; Type = "Winget"; Id = "Adobe.Photoshop.2024"; Description = "Professional image editor"}
        )
    }
    
    "Productivity" = @{
        "Office Suites" = @(
            @{Name = "Microsoft Office 365"; Type = "Winget"; Id = "Microsoft.Office"; Description = "Microsoft's office suite"},
            @{Name = "LibreOffice"; Type = "Winget"; Id = "TheDocumentFoundation.LibreOffice"; Description = "Open source office suite"},
            @{Name = "WPS Office"; Type = "Winget"; Id = "Kingsoft.WPSOffice"; Description = "Alternative office suite"}
        )
        "PDF Tools" = @(
            @{Name = "Adobe Acrobat Reader"; Type = "Winget"; Id = "Adobe.Acrobat.Reader.64-bit"; Description = "PDF reader"},
            @{Name = "Foxit Reader"; Type = "Winget"; Id = "Foxit.FoxitReader"; Description = "Alternative PDF reader"},
            @{Name = "Sumatra PDF"; Type = "Winget"; Id = "SumatraPDF.SumatraPDF"; Description = "Lightweight PDF reader"},
            @{Name = "PDFCreator"; Type = "Winget"; Id = "pdfforge.PDFCreator"; Description = "PDF creation tool"}
        )
        "Note Taking" = @(
            @{Name = "Notion"; Type = "Winget"; Id = "Notion.Notion"; Description = "All-in-one workspace"},
            @{Name = "Obsidian"; Type = "Winget"; Id = "Obsidian.Obsidian"; Description = "Knowledge management tool"},
            @{Name = "OneNote"; Type = "Winget"; Id = "Microsoft.OneNote"; Description = "Microsoft's note-taking app"},
            @{Name = "Evernote"; Type = "Winget"; Id = "Evernote.Evernote"; Description = "Note organization service"}
        )
        "Cloud Storage" = @(
            @{Name = "Google Drive"; Type = "Winget"; Id = "Google.GoogleDrive"; Description = "Google's cloud storage"},
            @{Name = "Dropbox"; Type = "Winget"; Id = "Dropbox.Dropbox"; Description = "Cloud storage service"},
            @{Name = "OneDrive"; Type = "Winget"; Id = "Microsoft.OneDrive"; Description = "Microsoft's cloud storage"}
        )
    }
    
    "Gaming" = @{
        "Game Launchers" = @(
            @{Name = "Steam"; Type = "Winget"; Id = "Valve.Steam"; Description = "PC gaming platform"},
            @{Name = "Epic Games Launcher"; Type = "Winget"; Id = "EpicGames.EpicGamesLauncher"; Description = "Epic's game launcher"},
            @{Name = "Origin"; Type = "Winget"; Id = "ElectronicArts.Origin"; Description = "EA's game launcher"},
            @{Name = "Ubisoft Connect"; Type = "Winget"; Id = "Ubisoft.Connect"; Description = "Ubisoft's game launcher"},
            @{Name = "GOG Galaxy"; Type = "Winget"; Id = "GOG.Galaxy"; Description = "DRM-free games platform"}
        )
        "Gaming Tools" = @(
            @{Name = "MSI Afterburner"; Type = "Winget"; Id = "Guru3D.Afterburner"; Description = "GPU overclocking tool"},
            @{Name = "OBS Studio"; Type = "Winget"; Id = "OBSProject.OBSStudio"; Description = "Game streaming software"},
            @{Name = "Fraps"; Type = "Winget"; Id = "Beepa.Fraps"; Description = "Game recording software"}
        )
        "Emulation" = @(
            @{Name = "RetroArch"; Type = "Winget"; Id = "Libretro.RetroArch"; Description = "Multi-system emulator"},
            @{Name = "Dolphin Emulator"; Type = "Winget"; Id = "DolphinEmulator.Dolphin"; Description = "GameCube/Wii emulator"}
        )
    }
    
    "Utilities" = @{
        "System Tools" = @(
            @{Name = "PowerToys"; Type = "Winget"; Id = "Microsoft.PowerToys"; Description = "Windows utilities collection"},
            @{Name = "Process Monitor"; Type = "Winget"; Id = "Microsoft.Sysinternals.ProcessMonitor"; Description = "System monitoring tool"},
            @{Name = "TreeSize"; Type = "Winget"; Id = "JAMSoftware.TreeSize.Free"; Description = "Disk space analyzer"},
            @{Name = "CCleaner"; Type = "Winget"; Id = "Piriform.CCleaner"; Description = "System cleaner"},
            @{Name = "Speccy"; Type = "Winget"; Id = "Piriform.Speccy"; Description = "System information tool"}
        )
        "File Management" = @(
            @{Name = "7-Zip"; Type = "Winget"; Id = "7zip.7zip"; Description = "File archiver"},
            @{Name = "WinRAR"; Type = "Winget"; Id = "RARLab.WinRAR"; Description = "Archive manager"},
            @{Name = "Everything"; Type = "Winget"; Id = "voidtools.Everything"; Description = "File search utility"},
            @{Name = "FreeCommander"; Type = "Winget"; Id = "Marek.FreeCommander"; Description = "File manager"}
        )
        "Security" = @(
            @{Name = "Malwarebytes"; Type = "Winget"; Id = "Malwarebytes.Malwarebytes"; Description = "Anti-malware software"},
            @{Name = "Bitdefender"; Type = "Winget"; Id = "Bitdefender.Bitdefender"; Description = "Antivirus software"},
            @{Name = "KeePass"; Type = "Winget"; Id = "DominikReichl.KeePass"; Description = "Password manager"},
            @{Name = "Bitwarden"; Type = "Winget"; Id = "Bitwarden.Bitwarden"; Description = "Password manager"}
        )
        "Remote Access" = @(
            @{Name = "TeamViewer"; Type = "Winget"; Id = "TeamViewer.TeamViewer"; Description = "Remote desktop software"},
            @{Name = "AnyDesk"; Type = "Winget"; Id = "AnyDeskSoftwareGmbH.AnyDesk"; Description = "Remote desktop tool"},
            @{Name = "Chrome Remote Desktop"; Type = "Winget"; Id = "Google.ChromeRemoteDesktop"; Description = "Google's remote access tool"}
        )
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
            default { "[?]" }
        }
        Write-Host "$($i + 1). $typeIndicator $($software.Name)" -ForegroundColor White
        Write-Host "    $($software.Description)" -ForegroundColor DarkGray
    }
    
    Write-Host ""
    Write-Host "Legend: [W]=Winget, [M]=MSI, [E]=EXE, [PS-M]=PowerShell Module, [PS-S]=PowerShell Script" -ForegroundColor DarkGray
    Write-Host ""
    Write-Host "Enter numbers separated by commas to select software," -ForegroundColor Cyan
    Write-Host "or type 'ALL' to select everything in this category:" -ForegroundColor Cyan
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
                        Clear-Host
                        Write-Host "Scanning your system for installed software..." -ForegroundColor Cyan
                        $installedSoftware = Get-InstalledSoftware
                        
                        Write-Host "`nInstalled Software (showing first 50):" -ForegroundColor Cyan
                        $installedSoftware | Select-Object -First 50 | Format-Table Name, Version, Publisher, Source -AutoSize
                        
                        if ($installedSoftware.Count -gt 50) {
                            $remaining = $installedSoftware.Count - 50
                            Write-Host "... and $remaining more entries" -ForegroundColor Gray
                        }
                        
                        Write-Host "`nPress any key to continue..." -ForegroundColor Gray
                        $null = $Host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown")
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
                Show-SoftwareList -categoryName $selectedCategory -subcategoryName $selectedSubcategory
                $choice = Get-UserMenuChoice
                
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
            
            Write-Host "`n" + "="*50 -ForegroundColor Cyan
            Write-Host "Installing: $($app.Name) [$($app.Type)]" -ForegroundColor Cyan
            Write-Host "="*50 -ForegroundColor Cyan
            
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
    Write-Host "`n" + "="*50 -ForegroundColor Green
    Write-Host "INSTALLATION SUMMARY" -ForegroundColor Green
    Write-Host "="*50 -ForegroundColor Green
    Write-Host "Successful: $successCount" -ForegroundColor Green
    Write-Host "Failed: $failureCount" -ForegroundColor $(if ($failureCount -gt 0) { "Red" } else { "Green" })
    Write-Host "Total: $($successCount + $failureCount)" -ForegroundColor Cyan
    Write-Host "`nCheck $LogPath for detailed logs." -ForegroundColor Gray
    Write-Host "="*50 -ForegroundColor Green
    
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
Write-Host "Thank you for using Software Installation Manager!" -ForegroundColor Green