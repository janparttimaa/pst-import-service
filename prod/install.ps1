<#
.SYNOPSIS
    Set up PST Import Service files to Windows Server.

.DESCRIPTION
    This PowerShell-script will set up PST Import Service files to Windows Server.
    NOTE: You need to do some preparations before and after deploying this script. Please check preparation instructions from GitHub.

.VERSION
    20250608

.AUTHOR
    Jan Parttimaa (https://github.com/janparttimaa/pst-import-service)

.COPYRIGHT
    © 2024-2025 Jan Parttimaa. All rights reserved.

.LICENSE
    This script is licensed under the MIT License.
    You may obtain a copy of the License at https://opensource.org/licenses/MIT

.RELEASENOTES
    20250309 - Initial release.
    20250311 - Added command that says when script will be closed after all needed things are done.
    20250504 - Added scheduled task for retention period. Hidden PST Import Service -folder will be cleared out of contents every 1 day of the month at 0:00 local time.
             - Log of the retention period actions can be found from "Logs\monthlycleanup.log" folder from the drive letter where PST Import Service is.
    20250608 - Fully integrated creation of monthlycleanup.ps1 script within install.ps1.
             - Replaced old logic with enhanced version that:
                 * Checks for folder existence before cleanup.
                 * Logs detailed status (deletion, skip, error).
                 * Ensures folder age is based on creation time.
                 * Appends logs to persistent monthly log file.

.EXAMPLE
    powershell.exe -ExecutionPolicy Bypass -File .\install.ps1
    This example is how to run this script running Windows PowerShell. Run this command with your admin rights.
#>

# Set variable for version
$version = "20250608"

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
$driveLetter = Get-ValidDriveLetter -promptMessage "Enter the drive letter where you want to onboard PST Import Service (e.g., F:)"

# Create hidden folder "PST Import Service$", visible folder "Tools" and visible folder "Logs"
$pstImportService = "PST Import Service$"
$tools = "Tools"
$logs = "Logs"
Write-Host "Creating hidden folder ""PST Import Service""..." -Verbose
New-Item -Path "$driveLetter\$pstImportService" -ItemType Directory -Force -Verbose
Write-Host "Setting folder ""PST Import Service"" attributes to Hidden..." -Verbose
Set-ItemProperty -Path "$driveLetter\$pstImportService" -Name Attributes -Value ([System.IO.FileAttributes]::Hidden) -Verbose
Write-Host "Creating visible folder ""Tools""..." -Verbose
New-Item -Path "$driveLetter\$tools" -ItemType Directory -Force -Verbose
Write-Host "Creating visible folder ""Logs""..." -Verbose
New-Item -Path "$driveLetter\$logs" -ItemType Directory -Force -Verbose

# Download the latest version of AzCopy portable binary
Write-Host "Downloading the latest version of AzCopy portable binary..." -Verbose
$azCopyUrl = "https://aka.ms/downloadazcopy-v10-windows"
$azCopyPath = "$driveLetter\$tools\azcopy.zip"
Invoke-WebRequest -Uri $azCopyUrl -OutFile $azCopyPath -Verbose
Write-Host "Expanding AzCopy archive..." -Verbose
Expand-Archive -Path $azCopyPath -DestinationPath "$driveLetter\$tools" -Verbose

# Find the name of the extracted folder
Write-Host "Finding the name of the extracted AzCopy folder..." -Verbose
$extractedFolder = Get-ChildItem -Path "$driveLetter\$tools" | Where-Object { $_.PSIsContainer -and $_.Name -like "azcopy*" } | Select-Object -First 1

# Check if existing old file azcopy.exe exists at the destination
if (Test-Path -Path "$driveLetter\$tools\azcopy.exe") {
    Remove-Item -Path "$driveLetter\$tools\azcopy.exe" -Force
}

# Move azcopy.exe to Tools folder and delete the zip file and extracted folder
Write-Host "Moving azcopy.exe to Tools folder..." -Verbose
Move-Item -Path "$($extractedFolder.FullName)\azcopy.exe" -Destination "$driveLetter\$tools\azcopy.exe" -Verbose
Write-Host "Deleting AzCopy zip file..." -Verbose
Remove-Item -Path $azCopyPath -Verbose
Remove-Item -Path "$driveLetter\$tools\$extractedFolder" -Force -Recurse -Verbose

# Create the batch script "pstis.bat"
Write-Host "Creating batch script ""pstis.bat""..." -Verbose
$batchScript = @"
@echo off
chcp 65001>nul
TITLE PST Import Service
echo PST Import Service [Version $version]  && echo (c) 2024-2025 Jan Parttimaa. All rights reserved.
echo.
echo Type username of employee which PST-files will be imported and press Enter.
echo.
set /p username=Username: 
echo.
echo Paste SAS URL and press Enter.
echo.
set /p URL=SAS URL: 
echo.
"$driveLetter\$tools\azcopy.exe" copy "$driveLetter\$pstImportService\%username%\*" "%URL%"
echo This window will close after 120 seconds...
timeout /t 120
"@
$batchScriptPath = "$driveLetter\$tools\pstis.bat"
Set-Content -Path $batchScriptPath -Value $batchScript -Verbose

# Create shortcut to "pstis.bat" in the root of the specified drive
Write-Host "Creating shortcut to ""pstis.bat"" in the root of the specified drive..." -Verbose
$shortcut = New-Object -ComObject WScript.Shell
$shortcutPath = "$driveLetter\Execute PST Import Service.lnk"
$shortcutTarget = $batchScriptPath
$shortcutIcon = $batchScriptPath
$shortcutShortcut = $shortcut.CreateShortcut($shortcutPath)
$shortcutShortcut.TargetPath = $shortcutTarget
$shortcutShortcut.IconLocation = $shortcutIcon
$shortcutShortcut.Save()

# Create updated PowerShell script for 30-day cleanup
# Create PowerShell-script that will cleanup PST Import Service subfolders older than 30 days
Write-Host "Creating script for monthly cleanups for hidden ""PST Import Service"" -folder..." -Verbose

$targetScriptPath = "$driveLetter\$tools\monthlycleanup.ps1"
$logPath = "$driveLetter\$logs\monthlycleanup.log"
$targetFolderPath = "$driveLetter\$pstImportService"

$scriptContent = @'
# Number of days to keep folders (folders older than this will be deleted)
$retentionDays = 30

# Get the current date for comparison
$currentDate = Get-Date

# Flag to track whether any deletion occurred
$deletionOccurred = $false

# Define the target path
$targetPath = "REPLACE_FOLDER_PATH"

# Define the target path for log file
$log = "REPLACE_LOG_PATH"

# Check if the target path exists
if (Test-Path $targetPath) {

    # Get all subdirectories in the target path, including hidden ones
    $subFolders = Get-ChildItem -Path $targetPath -Directory -Force

    # Loop through each subfolder
    foreach ($folder in $subFolders) {

        # Calculate the age of the folder in days based on its creation date
        $folderAge = ($currentDate - $folder.CreationTime).Days

        # If the folder is older than the retention period, delete it
        if ($folderAge -gt $retentionDays) {
            try {
                Remove-Item -Path $folder.FullName -Recurse -Force -ErrorAction Stop
                Write-Output "PST Import Service [Version $version], $(Get-Date -Format 'u'): Deleted folder '$($folder.FullName)' - Older than $retentionDays days." | Out-File $log -Append
                $deletionOccurred = $true
            } catch {
                Write-Output "PST Import Service [Version $version], $(Get-Date -Format 'u'): ERROR deleting folder '$($folder.FullName)': $_" | Out-File $log -Append
            }
        }
    }

    if (-not $deletionOccurred) {
        Write-Output "PST Import Service [Version $version], $(Get-Date -Format 'u'): No folders older than $retentionDays days found in '$targetPath' - No deletions performed." | Out-File $log -Append
    }

} else {
    Write-Output "PST Import Service [Version $version], $(Get-Date -Format 'u'): Target folder '$targetPath' does not exist." | Out-File $log -Append
}
'@

# Replace placeholders
$scriptContent = $scriptContent -replace 'REPLACE_FOLDER_PATH', $targetFolderPath
$scriptContent = $scriptContent -replace 'REPLACE_LOG_PATH', $logPath
$scriptContent = $scriptContent -replace '\[Version "\$version"\]', "[Version $version]"

# Write the content to the file
Set-Content -Path $targetScriptPath -Value $scriptContent -Encoding UTF8 -Force

Write-Host "Folders and files for PST Import Service created successfully to specified drive. Creating scheduled task..." -Verbose

# Set variables to scheduled task
$taskName = "PST Import Service - Monthly Cleanup"
$description = "This task will delete folders older than 30 days from ""PST Import Service$"" folder."
$action = New-ScheduledTaskAction -Execute "powershell.exe" -Argument "-ExecutionPolicy Bypass -File $targetScriptPath"
$author = "Jan Parttimaa"

# Create a daily trigger at 00:00
$trigger = New-ScheduledTaskTrigger -Daily -At 00:00

# Task settings
$settings = New-ScheduledTaskSettingsSet -StartWhenAvailable:$false -AllowStartIfOnBatteries:$true -DontStopOnIdleEnd:$true -DisallowHardTerminate:$false -DontStopIfGoingOnBatteries:$true -ExecutionTimeLimit (New-TimeSpan -Hours 1)

# Principal with SYSTEM account and highest privileges
$principal = New-ScheduledTaskPrincipal -UserId "SYSTEM" -LogonType ServiceAccount -RunLevel Highest

# Register and update scheduled task
Register-ScheduledTask -TaskName $taskName -Action $action -Trigger $trigger -Settings $settings -Principal $principal -Description $description -Force
$taskObject = Get-ScheduledTask $taskName
$taskObject.Author = $author
$taskObject | Set-ScheduledTask

Write-Host "Done. Closing script..." -Verbose