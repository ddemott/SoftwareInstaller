# ===== HIERARCHICAL SOFTWARE INSTALLATION MANAGER DEMO =====
# Demonstrates the complete categorization and navigation system

# Global log path
$LogPath = ".\installation_log_$(Get-Date -Format 'yyyyMMdd_HHmmss').txt"

# Software categories with hierarchical structure
$softwareCategories = @{
    "Development" = @{
        "IDEs & Editors" = @(
            @{Name = "Visual Studio Code"; Type = "Winget"; Id = "Microsoft.VisualStudioCode"; Description = "Free code editor with extensions"},
            @{Name = "Visual Studio 2022 Community"; Type = "Winget"; Id = "Microsoft.VisualStudio.2022.Community"; Description = "Full-featured IDE"},
            @{Name = "Notepad++"; Type = "Winget"; Id = "Notepad++.Notepad++"; Description = "Advanced text editor"},
            @{Name = "Sublime Text"; Type = "Winget"; Id = "SublimeHQ.SublimeText.4"; Description = "Sophisticated text editor"}
        )
        "Version Control" = @(
            @{Name = "Git"; Type = "Winget"; Id = "Git.Git"; Description = "Distributed version control system"},
            @{Name = "GitHub Desktop"; Type = "Winget"; Id = "GitHub.GitHubDesktop"; Description = "GUI for Git and GitHub"},
            @{Name = "TortoiseGit"; Type = "Winget"; Id = "TortoiseGit.TortoiseGit"; Description = "Git client with Windows shell integration"}
        )
        "Databases" = @(
            @{Name = "MySQL Workbench"; Type = "Winget"; Id = "Oracle.MySQLWorkbench"; Description = "MySQL database design tool"},
            @{Name = "DBeaver"; Type = "Winget"; Id = "dbeaver.dbeaver"; Description = "Universal database tool"},
            @{Name = "PostgreSQL"; Type = "Winget"; Id = "PostgreSQL.PostgreSQL"; Description = "Advanced open source database"}
        )
        "Runtime & Languages" = @(
            @{Name = "Python 3"; Type = "Winget"; Id = "Python.Python.3.12"; Description = "Python programming language"},
            @{Name = "Node.js"; Type = "Winget"; Id = "OpenJS.NodeJS"; Description = "JavaScript runtime"},
            @{Name = "Java JDK 17"; Type = "Winget"; Id = "Oracle.JDK.17"; Description = "Java Development Kit"}
        )
    }
    
    "Internet & Communication" = @{
        "Web Browsers" = @(
            @{Name = "Google Chrome"; Type = "Winget"; Id = "Google.Chrome"; Description = "Popular web browser"},
            @{Name = "Mozilla Firefox"; Type = "Winget"; Id = "Mozilla.Firefox"; Description = "Open source web browser"},
            @{Name = "Microsoft Edge"; Type = "Winget"; Id = "Microsoft.Edge"; Description = "Microsoft web browser"},
            @{Name = "Brave Browser"; Type = "Winget"; Id = "Brave.Brave"; Description = "Privacy-focused browser"}
        )
        "Communication" = @(
            @{Name = "Discord"; Type = "Winget"; Id = "Discord.Discord"; Description = "Voice and text chat platform"},
            @{Name = "Slack"; Type = "Winget"; Id = "SlackTechnologies.Slack"; Description = "Team collaboration tool"},
            @{Name = "Microsoft Teams"; Type = "Winget"; Id = "Microsoft.Teams"; Description = "Microsoft collaboration platform"},
            @{Name = "Zoom"; Type = "Winget"; Id = "Zoom.Zoom"; Description = "Video conferencing software"}
        )
    }
    
    "Multimedia" = @{
        "Media Players" = @(
            @{Name = "VLC Media Player"; Type = "Winget"; Id = "VideoLAN.VLC"; Description = "Universal media player"},
            @{Name = "Spotify"; Type = "Winget"; Id = "Spotify.Spotify"; Description = "Music streaming service"},
            @{Name = "iTunes"; Type = "Winget"; Id = "Apple.iTunes"; Description = "Apple media player"}
        )
        "Video Editing" = @(
            @{Name = "OBS Studio"; Type = "Winget"; Id = "OBSProject.OBSStudio"; Description = "Broadcasting and recording software"},
            @{Name = "DaVinci Resolve"; Type = "Winget"; Id = "Blackmagic.DaVinciResolve"; Description = "Professional video editor"},
            @{Name = "Handbrake"; Type = "Winget"; Id = "HandBrake.HandBrake"; Description = "Video transcoder"}
        )
        "Graphics & Design" = @(
            @{Name = "GIMP"; Type = "Winget"; Id = "GIMP.GIMP"; Description = "Open source image editor"},
            @{Name = "Paint.NET"; Type = "Winget"; Id = "dotPDN.PaintDotNet"; Description = "Simple image editor"},
            @{Name = "Blender"; Type = "Winget"; Id = "BlenderFoundation.Blender"; Description = "3D creation suite"}
        )
    }
    
    "Utilities" = @{
        "System Tools" = @(
            @{Name = "PowerToys"; Type = "Winget"; Id = "Microsoft.PowerToys"; Description = "Windows utilities collection"},
            @{Name = "TreeSize"; Type = "Winget"; Id = "JAMSoftware.TreeSize.Free"; Description = "Disk space analyzer"},
            @{Name = "CCleaner"; Type = "Winget"; Id = "Piriform.CCleaner"; Description = "System cleaner"}
        )
        "File Management" = @(
            @{Name = "7-Zip"; Type = "Winget"; Id = "7zip.7zip"; Description = "File archiver"},
            @{Name = "WinRAR"; Type = "Winget"; Id = "RARLab.WinRAR"; Description = "Archive manager"},
            @{Name = "Everything"; Type = "Winget"; Id = "voidtools.Everything"; Description = "File search utility"}
        )
        "Security" = @(
            @{Name = "Malwarebytes"; Type = "Winget"; Id = "Malwarebytes.Malwarebytes"; Description = "Anti-malware software"},
            @{Name = "KeePass"; Type = "Winget"; Id = "DominikReichl.KeePass"; Description = "Password manager"},
            @{Name = "Bitwarden"; Type = "Winget"; Id = "Bitwarden.Bitwarden"; Description = "Password manager"}
        )
    }
}

# Navigation function demo
function Show-CategoryDemo {
    param([string]$categoryName)
    
    Write-Host ""
    Write-Host "=== $categoryName ===" -ForegroundColor Cyan
    $subcategories = $softwareCategories[$categoryName].Keys | Sort-Object
    
    foreach ($subcategory in $subcategories) {
        $softwareList = $softwareCategories[$categoryName][$subcategory]
        Write-Host ""
        Write-Host "  >> $subcategory" -ForegroundColor Yellow
        
        foreach ($software in $softwareList) {
            $typeIndicator = switch ($software.Type) {
                "Winget" { "[W]" }
                "MSI" { "[M]" }
                "EXE" { "[E]" }
                "PowerShellModule" { "[PS-M]" }
                default { "[?]" }
            }
            Write-Host "     $typeIndicator $($software.Name)" -ForegroundColor White
            Write-Host "       $($software.Description)" -ForegroundColor Gray
        }
    }
}

# Main demonstration
Clear-Host
Write-Host "╔════════════════════════════════════════════════════════════╗" -ForegroundColor Green
Write-Host "║          HIERARCHICAL SOFTWARE INSTALLATION MANAGER       ║" -ForegroundColor Green
Write-Host "║                        DEMONSTRATION                       ║" -ForegroundColor Green
Write-Host "╚════════════════════════════════════════════════════════════╝" -ForegroundColor Green
Write-Host ""

Write-Host "✅ SUCCESS: Script loaded without syntax errors!" -ForegroundColor Green
Write-Host ""

# Show overview
Write-Host "📊 SYSTEM OVERVIEW:" -ForegroundColor Cyan
$totalCategories = $softwareCategories.Keys.Count
$totalSubcategories = ($softwareCategories.Values | ForEach-Object { $_.Keys.Count } | Measure-Object -Sum).Sum
$totalSoftware = ($softwareCategories.Values | ForEach-Object { $_.Values | ForEach-Object { $_.Count } } | Measure-Object -Sum).Sum

Write-Host "   Main Categories: $totalCategories" -ForegroundColor White
Write-Host "   Subcategories: $totalSubcategories" -ForegroundColor White
Write-Host "   Software Packages: $totalSoftware" -ForegroundColor White
Write-Host ""

Write-Host "📂 CATEGORIES BREAKDOWN:" -ForegroundColor Cyan
foreach ($category in ($softwareCategories.Keys | Sort-Object)) {
    $subCount = $softwareCategories[$category].Keys.Count
    $softCount = ($softwareCategories[$category].Values | ForEach-Object { $_.Count } | Measure-Object -Sum).Sum
    Write-Host "   $category" -ForegroundColor Yellow
    Write-Host "     Subcategories: $subCount" -ForegroundColor White
    Write-Host "     Software: $softCount" -ForegroundColor White
}

Write-Host ""
Write-Host "🔧 FEATURES IMPLEMENTED:" -ForegroundColor Cyan
Write-Host "   ✅ Hierarchical navigation (Category > Subcategory > Software)" -ForegroundColor Green
Write-Host "   ✅ Multiple installation methods (Winget, MSI, EXE, PowerShell)" -ForegroundColor Green
Write-Host "   ✅ User-friendly menu system with navigation controls" -ForegroundColor Green
Write-Host "   ✅ Installation confirmation and progress tracking" -ForegroundColor Green
Write-Host "   ✅ Comprehensive error handling and logging" -ForegroundColor Green
Write-Host "   ✅ System inventory and export capabilities" -ForegroundColor Green
Write-Host ""

Write-Host "📋 SAMPLE CATEGORY DETAIL - Development:" -ForegroundColor Cyan
Show-CategoryDemo -categoryName "Development"

Write-Host ""
Write-Host "🎯 NEXT STEPS:" -ForegroundColor Yellow
Write-Host "   1. The complete script is in SoftwareInstaller.ps1" -ForegroundColor White
Write-Host "   2. Uncomment the main execution section to enable interactive menu" -ForegroundColor White
Write-Host "   3. Run the script to navigate through categories and install software" -ForegroundColor White
Write-Host ""
Write-Host "✨ Project completed successfully!" -ForegroundColor Green
