<#
.SYNOPSIS
    Installs the Windows Terminal Skill for GitHub Copilot CLI.

.DESCRIPTION
    This script safely installs the Windows Terminal Skill by:
    1. Copying the module to ~/.copilot/skills/windows-terminal/
    2. Creating the PowerShell profile if it doesn't exist
    3. Adding the Import-Module statement to the profile (if not already present)

    Supports both local and remote installation:
    - Local: .\Install-WindowsTerminalSkill.ps1
    - Remote: irm https://raw.githubusercontent.com/shanselman/windows-terminal-copilot-skill/main/Install-WindowsTerminalSkill.ps1 | iex

.PARAMETER Force
    Overwrites existing installation without prompting.

.EXAMPLE
    .\Install-WindowsTerminalSkill.ps1

.EXAMPLE
    .\Install-WindowsTerminalSkill.ps1 -Force

.EXAMPLE
    irm https://raw.githubusercontent.com/shanselman/windows-terminal-copilot-skill/main/Install-WindowsTerminalSkill.ps1 | iex
#>

[CmdletBinding()]
param(
    [switch]$Force
)

$ErrorActionPreference = 'Stop'

# Define paths
$SkillSourcePath = $PSScriptRoot
$SkillDestPath = Join-Path $env:USERPROFILE '.copilot\skills\windows-terminal'
$ModuleManifest = 'WindowsTerminalSkill.psd1'
$ImportStatement = "Import-Module `"$SkillDestPath\$ModuleManifest`""

# GitHub raw content base URL for remote installation
$GitHubBaseUrl = 'https://raw.githubusercontent.com/shanselman/windows-terminal-copilot-skill/main'

# Detect if running remotely (PSScriptRoot is empty when piped from irm)
$IsRemoteInstall = [string]::IsNullOrEmpty($SkillSourcePath)

Write-Host "Windows Terminal Skill Installer" -ForegroundColor Cyan
Write-Host "=================================" -ForegroundColor Cyan
Write-Host ""

# Step 1: Check PowerShell version
Write-Host "Checking PowerShell version..." -ForegroundColor Yellow
if ($PSVersionTable.PSVersion.Major -lt 7) {
    Write-Warning "PowerShell 7+ is recommended. You are running PowerShell $($PSVersionTable.PSVersion)."
    Write-Warning "The skill may not work correctly in older versions."
}
else {
    Write-Host "  PowerShell $($PSVersionTable.PSVersion) detected." -ForegroundColor Green
}

# Step 2: Copy skill files to destination
Write-Host "Installing skill files..." -ForegroundColor Yellow

if ($IsRemoteInstall) {
    Write-Host "  Remote installation detected. Downloading from GitHub..." -ForegroundColor Yellow
}

if (Test-Path -Path $SkillDestPath) {
    if (-not $Force -and -not $IsRemoteInstall) {
        $response = Read-Host "  Skill directory already exists at '$SkillDestPath'. Overwrite? (y/N)"
        if ($response -notmatch '^[Yy]') {
            Write-Host "  Skipping file copy." -ForegroundColor Gray
        }
        else {
            Remove-Item -Path $SkillDestPath -Recurse -Force
        }
    }
    else {
        Remove-Item -Path $SkillDestPath -Recurse -Force
    }
}

if (-not (Test-Path -Path $SkillDestPath)) {
    # Create destination directory
    New-Item -ItemType Directory -Path $SkillDestPath -Force | Out-Null

    # Files to install
    $filesToCopy = @(
        'WindowsTerminalSkill.psm1',
        'WindowsTerminalSkill.psd1',
        'SKILL.md',
        'README.md'
    )

    foreach ($file in $filesToCopy) {
        if ($IsRemoteInstall) {
            # Download from GitHub
            $fileUrl = "$GitHubBaseUrl/$file"
            $destPath = Join-Path $SkillDestPath $file
            try {
                Invoke-RestMethod -Uri $fileUrl -OutFile $destPath
                Write-Host "  Downloaded $file" -ForegroundColor Green
            }
            catch {
                Write-Warning "  Failed to download $file from $fileUrl"
            }
        }
        else {
            # Copy from local source
            $sourcePath = Join-Path $SkillSourcePath $file
            if (Test-Path -Path $sourcePath) {
                Copy-Item -Path $sourcePath -Destination $SkillDestPath -Force
                Write-Host "  Copied $file" -ForegroundColor Green
            }
            else {
                Write-Warning "  File not found: $file"
            }
        }
    }
}

# Step 3: Ensure $PROFILE exists
Write-Host "Configuring PowerShell profile..." -ForegroundColor Yellow

if (-not (Test-Path -Path $PROFILE)) {
    Write-Host "  Profile does not exist. Creating: $PROFILE" -ForegroundColor Yellow
    
    # Create parent directory if needed
    $profileDir = Split-Path -Path $PROFILE -Parent
    if (-not (Test-Path -Path $profileDir)) {
        New-Item -ItemType Directory -Path $profileDir -Force | Out-Null
    }
    
    # Create the profile file
    New-Item -ItemType File -Path $PROFILE -Force | Out-Null
    Write-Host "  Profile created." -ForegroundColor Green
}
else {
    Write-Host "  Profile exists: $PROFILE" -ForegroundColor Green
}

# Step 4: Check if profile is writable
Write-Host "Checking profile write access..." -ForegroundColor Yellow
try {
    # Test write access by opening the file for append
    $testStream = [System.IO.File]::OpenWrite($PROFILE)
    $testStream.Close()
    Write-Host "  Profile is writable." -ForegroundColor Green
}
catch {
    Write-Error "Cannot write to profile: $PROFILE. Please check file permissions."
    exit 1
}

# Step 5: Check if import already exists in profile
Write-Host "Checking for existing import statement..." -ForegroundColor Yellow

$profileContent = Get-Content -Path $PROFILE -Raw -ErrorAction SilentlyContinue
if ([string]::IsNullOrEmpty($profileContent)) {
    $profileContent = ""
}

# Check for existing import (handle variations)
$importPatterns = @(
    [regex]::Escape("Import-Module") + ".*" + [regex]::Escape("WindowsTerminalSkill"),
    [regex]::Escape("Import-Module") + ".*" + [regex]::Escape("windows-terminal")
)

$importExists = $false
foreach ($pattern in $importPatterns) {
    if ($profileContent -match $pattern) {
        $importExists = $true
        break
    }
}

if ($importExists) {
    Write-Host "  Import statement already exists in profile. No changes needed." -ForegroundColor Green
}
else {
    Write-Host "  Adding import statement to profile..." -ForegroundColor Yellow
    
    # Add a newline if the profile doesn't end with one
    $newContent = $profileContent
    if (-not [string]::IsNullOrEmpty($newContent) -and -not $newContent.EndsWith("`n")) {
        $newContent += "`n"
    }
    
    # Add a comment and the import statement
    $newContent += "`n# Windows Terminal Skill for GitHub Copilot CLI`n"
    $newContent += $ImportStatement + "`n"
    
    # Write the updated content
    Set-Content -Path $PROFILE -Value $newContent -NoNewline
    Write-Host "  Import statement added." -ForegroundColor Green
}

# Summary
Write-Host ""
Write-Host "Installation complete!" -ForegroundColor Green
Write-Host ""
Write-Host "Next steps:" -ForegroundColor Cyan
Write-Host "  1. Restart your terminal or run: . `$PROFILE" -ForegroundColor White
Write-Host "  2. Start a Copilot CLI session" -ForegroundColor White
Write-Host "  3. Try: !tab `"My Task`" blue" -ForegroundColor White
Write-Host ""
