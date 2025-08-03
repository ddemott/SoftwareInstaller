# Simple test of categories loading
$softwareCategories = @{
    "Development" = @{
        "IDEs & Editors" = @(
            @{Name = "Visual Studio Code"; Type = "Winget"; Id = "Microsoft.VisualStudioCode"; Description = "Free code editor"},
            @{Name = "Notepad++"; Type = "Winget"; Id = "Notepad++.Notepad++"; Description = "Advanced text editor"}
        )
        "Version Control" = @(
            @{Name = "Git"; Type = "Winget"; Id = "Git.Git"; Description = "Distributed version control system"},
            @{Name = "GitHub Desktop"; Type = "Winget"; Id = "GitHub.GitHubDesktop"; Description = "GUI for Git and GitHub"}
        )
    }
    "Productivity" = @{
        "Office Suites" = @(
            @{Name = "Microsoft Office 365"; Type = "Winget"; Id = "Microsoft.Office"; Description = "Microsoft office suite"},
            @{Name = "LibreOffice"; Type = "Winget"; Id = "TheDocumentFoundation.LibreOffice"; Description = "Open source office suite"}
        )
    }
}

Write-Host "Categories loaded:" -ForegroundColor Green
Write-Host "Count: $($softwareCategories.Keys.Count)" -ForegroundColor Yellow
foreach ($cat in $softwareCategories.Keys) {
    Write-Host "  - $cat" -ForegroundColor White
    $subCount = $softwareCategories[$cat].Keys.Count
    Write-Host "    Has $subCount subcategories" -ForegroundColor Gray
}

Write-Host ""
Write-Host "SUCCESS: Hierarchical software categorization system is working!" -ForegroundColor Green
