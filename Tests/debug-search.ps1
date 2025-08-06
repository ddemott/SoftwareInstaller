# Debug search test
$scriptDirectory = Split-Path -Parent $MyInvocation.MyCommand.Path
$parentDirectory = Split-Path -Parent $scriptDirectory
$mainScriptPath = Join-Path $parentDirectory "SoftwareInstaller.ps1"

# Load only the functions, not the main execution
$scriptContent = Get-Content $mainScriptPath -Raw
$functionsOnly = $scriptContent -replace '# Start the navigation menu[\s\S]*', ''
Invoke-Expression $functionsOnly

# Test the search function with debug output
function Debug-Search-WingetPackages {
    param([string]$SearchTerm)
    
    Write-Host "=== DEBUG: Starting search for '$SearchTerm' ===" -ForegroundColor Yellow
    
    # Use Start-Process to better control encoding and output
    $processInfo = New-Object System.Diagnostics.ProcessStartInfo
    $processInfo.FileName = "winget"
    $processInfo.Arguments = "search `"$SearchTerm`" --accept-source-agreements"
    $processInfo.RedirectStandardOutput = $true
    $processInfo.RedirectStandardError = $true
    $processInfo.UseShellExecute = $false
    $processInfo.CreateNoWindow = $true
    $processInfo.StandardOutputEncoding = [System.Text.Encoding]::UTF8
    
    $process = New-Object System.Diagnostics.Process
    $process.StartInfo = $processInfo
    $process.Start() | Out-Null
    
    $output = $process.StandardOutput.ReadToEnd()
    $errorOutput = $process.StandardError.ReadToEnd()
    $process.WaitForExit()
    
    Write-Host "=== DEBUG: Raw output ===" -ForegroundColor Yellow
    Write-Host $output
    Write-Host "=== DEBUG: Error output ===" -ForegroundColor Yellow
    Write-Host $errorOutput
    Write-Host "=== DEBUG: Exit code: $($process.ExitCode) ===" -ForegroundColor Yellow
    
    if ($process.ExitCode -ne 0 -and $errorOutput) {
        Write-Host "❌ Winget search error: $errorOutput" -ForegroundColor Red
        return @()
    }
    
    $searchResults = $output -split "`n" | Where-Object { $_.Trim() -ne "" }
    
    Write-Host "=== DEBUG: Split lines ===" -ForegroundColor Yellow
    for ($i = 0; $i -lt $searchResults.Count; $i++) {
        Write-Host "Line $i`: '$($searchResults[$i])'" -ForegroundColor Gray
    }
    
    $packages = @()
    $headerPassed = $false
    
    foreach ($line in $searchResults) {
        Write-Host "=== DEBUG: Processing line: '$line' ===" -ForegroundColor Cyan
        
        # Skip header lines
        if ($line -match "^Name\s+Id\s+Version" -or $line -match "^-+\s+-+\s+-+") {
            Write-Host "DEBUG: Found header line, marking headerPassed = true" -ForegroundColor Green
            $headerPassed = $true
            continue
        }
        
        if (-not $headerPassed) { 
            Write-Host "DEBUG: Skipping line - header not passed yet" -ForegroundColor Yellow
            continue 
        }
        
        # Clean the line of any problematic characters
        $cleanLine = $line -replace '[^\x20-\x7E]', ' ' -replace '\s+', ' '
        $cleanLine = $cleanLine.Trim()
        
        Write-Host "DEBUG: Clean line: '$cleanLine'" -ForegroundColor Magenta
        
        if ($cleanLine.Length -eq 0) { 
            Write-Host "DEBUG: Skipping empty line" -ForegroundColor Yellow
            continue 
        }
        
        # Try to parse the line - winget format is typically: Name Id Version [Source]
        if ($cleanLine -match '^(.+?)\s+([^\s]+)\s+([^\s]+)(?:\s+(.+?))?$') {
            $name = $matches[1].Trim()
            $id = $matches[2].Trim()
            $version = $matches[3].Trim()
            
            Write-Host "DEBUG: Regex matched - Name: '$name', ID: '$id', Version: '$version'" -ForegroundColor Green
            
            # Skip if the name or ID look malformed
            if ($name.Length -gt 0 -and $id.Length -gt 0 -and $name -notmatch '^[^a-zA-Z0-9]+$') {
                Write-Host "DEBUG: Adding package to results" -ForegroundColor Green
                $packages += [PSCustomObject]@{
                    Name = $name
                    Id = $id
                    Version = $version
                    Type = "Winget"
                }
            } else {
                Write-Host "DEBUG: Skipping malformed entry" -ForegroundColor Red
            }
        } else {
            Write-Host "DEBUG: Regex did not match" -ForegroundColor Red
        }
    }
    
    Write-Host "=== DEBUG: Final package count: $($packages.Count) ===" -ForegroundColor Yellow
    return $packages
}

Write-Host "Testing debug search for 'Spyder'..." -ForegroundColor Cyan
$results = Debug-Search-WingetPackages -SearchTerm "Spyder"

Write-Host "`n=== FINAL RESULTS ===" -ForegroundColor Green
foreach ($result in $results) {
    Write-Host "Name: $($result.Name)" -ForegroundColor White
    Write-Host "ID: $($result.Id)" -ForegroundColor Gray
    Write-Host "Version: $($result.Version)" -ForegroundColor Gray
    Write-Host "---" -ForegroundColor DarkGray
}
