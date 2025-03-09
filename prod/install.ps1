﻿<#
.SYNOPSIS
    Set up PST Import Service files to Windows Server

.DESCRIPTION
    This PowerShell-script will set up PST Import Service files to Windows Server
    NOTE: You need to do some preparations before and after deploying this script. Please check preparation instructions from GitHub.

.VERSION
    1.0.0

.AUTHOR
    Jan Parttimaa (https://github.com/janparttimaa/pst-import-service)

.COPYRIGHT
    © 2024-2025 Jan Parttimaa. All rights reserved.

.LICENSE
    This script is licensed under the MIT License.
    You may obtain a copy of the License at https://opensource.org/licenses/MIT

.RELEASE NOTES
    1.0.0 - Initial release

.EXAMPLE
    powershell.exe -ExecutionPolicy Bypass -File .\install.ps1

    This example is how to run this script running Windows PowerShell. Run this command with your admin rights.
#>

# Function to check if the drive letter exists
function Get-ValidDriveLetter {
    param (
        [string]$promptMessage
    )
    while ($true) {
        $driveLetter = Read-Host -Prompt $promptMessage
        if (Test-Path "$driveLetter\") {
            Write-Host "Drive letter '$driveLetter' found." -ForegroundColor Green
            return $driveLetter
        } else {
            Write-Host "Drive letter '$driveLetter' not found. Please try again." -ForegroundColor Red
        }
    }
}

# Ask for the drive letter
$driveLetter = Get-ValidDriveLetter -promptMessage "Enter the drive letter where you want to create the folders (e.g., F:)"

# Create hidden folder "PST Import Service$" and visible folder "Tools"
Write-Host "Creating hidden folder 'PST Import Service$'..." -Verbose
New-Item -Path "$driveLetter\PST Import Service$" -ItemType Directory -Force -Verbose
Write-Host "Setting folder 'PST Import Service$' attributes to Hidden..." -Verbose
Set-ItemProperty -Path "$driveLetter\PST Import Service$" -Name Attributes -Value ([System.IO.FileAttributes]::Hidden) -Verbose
Write-Host "Creating visible folder 'Tools'..." -Verbose
New-Item -Path "$driveLetter\Tools" -ItemType Directory -Force -Verbose

# Download the latest version of AzCopy portable binary
Write-Host "Downloading the latest version of AzCopy portable binary..." -Verbose
$azCopyUrl = "https://aka.ms/downloadazcopy-v10-windows"
$azCopyPath = "$driveLetter\Tools\azcopy.zip"
Invoke-WebRequest -Uri $azCopyUrl -OutFile $azCopyPath -Verbose
Write-Host "Expanding AzCopy archive..." -Verbose
Expand-Archive -Path $azCopyPath -DestinationPath "$driveLetter\Tools" -Verbose

# Find the name of the extracted folder
Write-Host "Finding the name of the extracted AzCopy folder..." -Verbose
$extractedFolder = Get-ChildItem -Path "$driveLetter\Tools" | Where-Object { $_.PSIsContainer -and $_.Name -like "azcopy*" } | Select-Object -First 1

# Move azcopy.exe to Tools folder and delete the zip file
Write-Host "Moving azcopy.exe to Tools folder..." -Verbose
Move-Item -Path "$($extractedFolder.FullName)\azcopy.exe" -Destination "$driveLetter\Tools\azcopy.exe" -Verbose
Write-Host "Deleting AzCopy zip file..." -Verbose
Remove-Item -Path $azCopyPath -Verbose

# Output the name of the extracted folder
Write-Host "The extracted folder name is: $($extractedFolder.Name)" -Verbose

# Create the batch script "pstis.bat"
Write-Host "Creating batch script 'pstis.bat'..." -Verbose
$batchScript = @"
@echo off
chcp 65001>nul
TITLE PST Import Service
echo PST Import Service [Version 1.0]  && echo (c) 2024-2025 Jan Parttimaa. All rights reserved.
echo.
echo Type username of employee which PST-files will be imported and press Enter.
echo.
set /p username=Username: 
echo.
echo Paste SAS URL and press Enter.
echo.
set /p URL=SAS URL: 
echo.
"$driveLetter\Tools\azcopy.exe" copy "$driveLetter\PST Import Service$\%username%\*" "%URL%"
echo This window will close after 120 seconds...
timeout /t 120
"@
$batchScriptPath = "$driveLetter\Tools\pstis.bat"
Set-Content -Path $batchScriptPath -Value $batchScript -Verbose

# Create shortcut to "pstis.bat" in the root of the specified drive
Write-Host "Creating shortcut to 'pstis.bat' in the root of the specified drive..." -Verbose
$shortcut = New-Object -ComObject WScript.Shell
$shortcutPath = "$driveLetter\Execute PST Import Service.lnk"
$shortcutTarget = $batchScriptPath
$shortcutIcon = $batchScriptPath  # Set the icon to the .bat file itself
$shortcutShortcut = $shortcut.CreateShortcut($shortcutPath)
$shortcutShortcut.TargetPath = $shortcutTarget
$shortcutShortcut.IconLocation = $shortcutIcon
$shortcutShortcut.Save()

Write-Host "Folders and files created successfully!" -Verbose