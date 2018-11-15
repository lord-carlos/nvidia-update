# This script is designed to install the bare essential Nvidia drivers
# This will not install Nvidia GeForce or Shadowplay
# There are options below for customizing the install
# The defaults should suffice for most users

# Verify user has elevated permissions
If (!([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]"Administrator")) {
    Start-Process powershell.exe "-NoProfile -ExecutionPolicy Bypass -File `"$PSCommandPath`"" -Verb RunAs
    Exit
}


# Installer options
$cleanInstall = $FALSE          # Will delete old drivers and install the new ones
$secondaryDrive = $FALSE        # Download and extract to a secondary drive location
$customInstallFolder = "D"      # Chooses the drive to install too if the above option is enabled (Default = D)
$scheduleTask = $FALSE          # Creates a Scheduled Task to run to check for driver updates
$scheduleDay = "Sunday"         # When should the scheduled task should run (Default = Sunday)
$scheduleTime = "12pm"          # The time the scheduled task should run (Default = 12pm)
$location = "US"                # Set your location for download. US or UK (Default is US)


# Extracting to current directory of the script file
$extractDir = $PSScriptRoot
$filesToExtract = "Display.Driver HDAudio NVI2 PhysX EULA.txt ListDevices.txt setup.cfg setup.exe"


# Checking if 7zip or WinRAR are installed
if (Test-Path $env:programfiles\7-zip\7z.exe) {
    $archiverProgram = "$env:programfiles\7-zip\7z.exe"
} elseif (Test-Path $env:programfiles\WinRAR\WinRAR.exe) {
    $archiverProgram = "$env:programfiles\WinRAR\WinRAR.exe"
} else {
    Write-Host "Sorry but it looks like you don't have a supported archiver."
    Write-Host "Please install 7zip or WinRAR."
    Write-Host "Press any key to exit..."
    $key = $host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown")
    exit
}


# Checking currently installed driver version
Write-Host "Attempting to detect currently installed driver version..."
try {
    $ins_version = (Get-WmiObject Win32_PnPSignedDriver | Where-Object {$_.devicename -like "*nvidia*" -and $_.devicename -notlike "*audio*"}).DriverVersion.SubString(7).Remove(1, 1).Insert(3, ".")
} catch {
    Write-Host "Unable to detect a compatible Nvidia device."
    Write-Host "Press any key to exit..."
    $key = $host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown")
    exit
}
Write-Host "Installed version `t$ins_version"

# Checking latest driver version from Nvidia website
$link = Invoke-WebRequest -Uri 'https://www.nvidia.com/Download/processFind.aspx?psid=101&pfid=816&osid=57&lid=1&whql=1&lang=en-us&ctk=0' -Method GET -UseBasicParsing
$link -match '<td class="gridItem">([^<]+?)</td>' | Out-Null
$version = $matches[1]
Write-Host "Latest version `t`t$version"


# Comparing installed driver version to latest driver version from Nvidia
if ($version -eq $ins_version) {
    Write-Host "The installed version is the same as the latest version."
    Write-Host "Press any key to exit..."
    $key = $host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown")
    exit
}


# Setting the custom download directory if the $secondaryDrive varible is set to TRUE
if (!$secondaryDrive) {
    $dlFile = "$env:temp\$version.exe"
} else {
    $dlFile = "${customInstallFolder}:\$version.exe"
}


# Checking Windows version
if ([Environment]::OSVersion.Version -ge (new-object 'Version' 9, 1)) {
    $windowsVersion = "win10"
} else {
    $windowsVersion = "win8-win7"
}


# Checking Windows bitness
if ((Get-WmiObject win32_operatingsystem | Select-Object osarchitecture).osarchitecture -eq "64-bit") {
    $windowsArchitecture = "64bit"
} else {
    $windowsArchitecture = "32bit"
}


# Generating the download link
$url = "http://$location.download.nvidia.com/Windows/$version/$version-desktop-$windowsVersion-$windowsArchitecture-international-whql.exe"


# Downloading the installer
Write-Host "Downloading the latest version to $dlFile"
(New-Object System.Net.WebClient).DownloadFile($url, $dlFile)


# Extracting setup files
Write-Host "Download finished, extracting the files now..."
if ($archiverProgram -eq "$env:programfiles\7-zip\7z.exe") {
    Start-Process -FilePath $archiverProgram -ArgumentList "x $dlFile $filesToExtract -o""$extractDir\$version\""" -wait
} elseif ($archiverProgram -eq "$env:programfiles\WinRAR\WinRAR.exe") {
    Start-Process -FilePath $archiverProgram -ArgumentList 'x $dlFile $extractDir\$version\ -IBCK $filesToExtract' -wait
}


# Installing drivers
Write-Host "Installing Nvidia drivers now..."
$install_args = "-s -noreboot -noeula"
if ($cleanInstall) {
    $install_args = $install_args + " -clean"
}
Start-Process -FilePath "$extractDir\$version\setup.exe" -ArgumentList $install_args -wait


# Creating a scheduled task if the $scheduleTask varible is set to TRUE
if ($scheduleTask -ne $FALSE) {
    Write-Host "Creating A Scheduled Task..."
    New-Item C:\Task\ -type directory 2>&1 | Out-Null
    Copy-Item .\Nvidia.ps1 -Destination C:\Task\ 2>&1 | Out-Null
    $taskname = "Nvidia-Updater"
    $description = "Update Your Driver!"
    $action = New-ScheduledTaskAction -Execute "C:\Task\Nvidia.ps1"
    $trigger = New-ScheduledTaskTrigger -Weekly -WeeksInterval $scheduleTask -DaysOfWeek $scheduleDay -At $scheduleTime
    Register-ScheduledTask -TaskName $taskname -Action $action -Trigger $trigger -Description $description 2>&1 | Out-Null
}


# Cleaning up downloaded files
Write-Host "Deleting downloaded file $dlFile"
Remove-Item $dlFile
#Remove-Item $extractDir\$version\ -Force -Recurse


# Driver installed, requesting a reboot
Write-Host "Driver installed. You may need to reboot to finish installation."
Write-Host "Would you like to reboot now?"
$Readhost = Read-Host "(Y/N) Default is no"
Switch ($ReadHost) {
    Y {Write-host "Rebooting now..."; Start-Sleep -s 2; Restart-Computer}
    N {Write-Host "Exiting script in 5 seconds."; Start-Sleep -s 5}
    Default {Write-Host "Exiting script in 5 seconds"; Start-Sleep -s 5}
}


# End of script
exit
