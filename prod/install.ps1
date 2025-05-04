<#
.SYNOPSIS
    Set up PST Import Service files to Windows Server.

.DESCRIPTION
    This PowerShell-script will set up PST Import Service files to Windows Server.
    NOTE: You need to do some preparations before and after deploying this script. Please check preparation instructions from GitHub.

.VERSION
    20250504

.AUTHOR
    Jan Parttimaa (https://github.com/janparttimaa/pst-import-service)

.COPYRIGHT
    © 2024-2025 Jan Parttimaa. All rights reserved.

.LICENSE
    This script is licensed under the MIT License.
    You may obtain a copy of the License at https://opensource.org/licenses/MIT

.RELEASE NOTES
    20250309 - Initial release.
    20250311 - Added command that says when script will be closed after all needed things are done.
    20250504 - Added scheduled task for retention period. Hidden PST Import Service -folder will be cleared out of contents every 1 day of the month at 0:00 local time.
             - Log of the retention period actions can be found from "Logs\monthlycleanup.log" folder from the drive letter where PST Import Service is.

.EXAMPLE
    powershell.exe -ExecutionPolicy Bypass -File .\install.ps1
    This example is how to run this script running Windows PowerShell. Run this command with your admin rights.
#>

# Set variable for version
$version = "20250504"

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
    # Remove existing old file of azcopy.exe
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
$shortcutIcon = $batchScriptPath  # Set the icon to the .bat file itself
$shortcutShortcut = $shortcut.CreateShortcut($shortcutPath)
$shortcutShortcut.TargetPath = $shortcutTarget
$shortcutShortcut.IconLocation = $shortcutIcon
$shortcutShortcut.Save()

# Create PowerShell-script, that will cleanup PST Import Service first day of every month
Write-Host "Creating script for monthly cleanups for hidden ""PST Import Service"" -folder..." -Verbose

$targetScriptPath = "$driveLetter\$tools\monthlycleanup.ps1"
$folderPath = "$driveLetter\$pstImportService" 

# Define the content of the new script with concatenation
$scriptContent = @"
# Cleanup hidden PST Import Service -folder from content every first day of every month

if ((Get-Date).Day -eq 1) {
    Get-ChildItem -Path "$folderPath" -Recurse -Force | Remove-Item -Force -Recurse -ErrorAction SilentlyContinue
    Write-Output "PST Import Service [Version $version], `$(Get-Date -Format 'u'): First day of the month - Therefore, content have been cleared from folder ""$folderPath""." | Out-File "$driveLetter\$logs\monthlycleanup.log" -Append
} else {
    Write-Output "PST Import Service [Version $version], `$(Get-Date -Format 'u'): Not first day of the month - No need to content cleanup." | Out-File "$driveLetter\$logs\monthlycleanup.log" -Append
}
"@

# Replace placeholders with actual values
$scriptContent = $scriptContent -replace '\$driveLetter', $driveLetter -replace '\$folderPath', $folderPath -replace '\$placeholder', (Get-Date -Format 'u')

# Create the new script and write the content to it
New-Item -Path $targetScriptPath -ItemType File -Force
Set-Content -Path $targetScriptPath -Value $scriptContent

Write-Host "Folders and files for PST Import Service created successfully to specified drive. Creating scheduled task..." -Verbose

# Set variables to scheduled task
$taskName = "PST Import Service - Monthly Cleanup"
$description = "This task will make sure that hidden folder ""PST Import Service$"" will be cleared up first day every month."
$action = New-ScheduledTaskAction -Execute "powershell.exe" -Argument "-ExecutionPolicy Bypass -File $driveLetter\$tools\monthlycleanup.ps1"
$author = "Jan Parttimaa"

# Create a daily trigger at 00:00
$trigger = New-ScheduledTaskTrigger -Daily -At 00:00

# Define task settings, ensuring it will start on batteries and continue even if not idle
$settings = New-ScheduledTaskSettingsSet -StartWhenAvailable:$false -AllowStartIfOnBatteries:$true -DontStopOnIdleEnd:$true -DisallowHardTerminate:$false -DontStopIfGoingOnBatteries:$true -ExecutionTimeLimit (New-TimeSpan -Hours 1)

# Define the principal with highest privileges
$principal = New-ScheduledTaskPrincipal -UserId "SYSTEM" -LogonType ServiceAccount -RunLevel Highest

# Register the task
Register-ScheduledTask -TaskName $taskName -Action $action -Trigger $trigger -Settings $settings -Principal $principal -Description $description -Force

# Set author to the scheduled task
$taskObject = Get-ScheduledTask $taskName
$taskObject.Author = $author
$taskObject | Set-ScheduledTask

Write-Host "Done. Closing script..." -Verbose