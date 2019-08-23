# This script is designed to install the bare essential Nvidia drivers
# This will not install Nvidia GeForce or Shadowplay
# There are options below for customizing the install
# The defaults should suffice for most users


# Installer options
param (
    [switch]$clean = $false,        # Will delete old drivers and install the new ones
    [string]$folder = "$env:temp"   # Downloads and extracts the driver here
)


$scheduleTask = $false  # Creates a Scheduled Task to run to check for driver updates
$scheduleDay = "Sunday" # When should the scheduled task run (Default = Sunday)
$scheduleTime = "12pm"  # The time the scheduled task should run (Default = 12pm)


# Checking if 7zip or WinRAR are installed
if (Test-Path $env:programfiles\7-zip\7z.exe) {
    $archiverProgram = "$env:programfiles\7-zip\7z.exe"
} elseif (Test-Path $env:programfiles\WinRAR\WinRAR.exe) {
    $archiverProgram = "$env:programfiles\WinRAR\WinRAR.exe"
} else {
    Write-Host "Sorry, but it looks like you don't have a supported archiver."
    Write-Host ""
    while ($choice -notmatch "[y|n]"){
    $choice = read-host "Would you like to install 7-Zip now? (Y/N)"
}
    if ($choice -eq "y"){
    # Download and silently install 7-zip if the user presses y
    $7zip = "https://www.7-zip.org/a/7z1900-x64.exe"
    $output = "$PSScriptRoot\7Zip.exe"
    (New-Object System.Net.WebClient).DownloadFile($7zip, $output)
	
    Start-Process "7Zip.exe" -Wait -ArgumentList "/S"
    # Delete the installer once it completes
    Remove-Item "$PSScriptRoot\7Zip.exe"
}
    else{
    Write-Host "Press any key to exit..."
    $host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown")
    exit
}
}


# Checking currently installed driver version
Write-Host "Attempting to detect currently installed driver version..."
try {
    $ins_version = (Get-WmiObject Win32_PnPSignedDriver | Where-Object {$_.devicename -like "*nvidia*" -and $_.devicename -notlike "*audio*"}).DriverVersion.SubString(7).Remove(1, 1).Insert(3, ".")
} catch {
    Write-Host "Unable to detect a compatible Nvidia device."
    Write-Host "Press any key to exit..."
    $host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown")
    exit
}
Write-Host "Installed version `t$ins_version"


# Checking latest driver version from Nvidia website
$link = Invoke-WebRequest -Uri 'https://www.nvidia.com/Download/processFind.aspx?psid=101&pfid=816&osid=57&lid=1&whql=1&lang=en-us&ctk=0' -Method GET -UseBasicParsing
$link -match '<td class="gridItem">([^<]+?)</td>' | Out-Null
$version = $matches[1]
Write-Host "Latest version `t`t$version"


# Comparing installed driver version to latest driver version from Nvidia
if (!$clean -and ($version -eq $ins_version)) {
    Write-Host "The installed version is the same as the latest version."
    Write-Host "Press any key to exit..."
    $host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown")
    exit
}


# Checking Windows version
if ([Environment]::OSVersion.Version -ge (new-object 'Version' 9, 1)) {
    $windowsVersion = "win10"
} else {
    $windowsVersion = "win8-win7"
}


# Checking Windows bitness
if ([Environment]::Is64BitOperatingSystem) {
    $windowsArchitecture = "64bit"
} else {
    $windowsArchitecture = "32bit"
}


# Create a new temp folder NVIDIA
$nvidiaTempFolder = "$folder\NVIDIA"
New-Item -Path $nvidiaTempFolder -ItemType Directory 2>&1 | Out-Null


# Generating the download link
$url = "https://international.download.nvidia.com/Windows/$version/$version-desktop-$windowsVersion-$windowsArchitecture-international-whql.exe"
$rp_url = "https://international.download.nvidia.com/Windows/$version/$version-desktop-$windowsVersion-$windowsArchitecture-international-whql-rp.exe"


# Downloading the installer
$dlFile = "$nvidiaTempFolder\$version.exe"
Write-Host "Downloading the latest version to $dlFile"
(New-Object System.Net.WebClient).DownloadFile($url, $dlFile)

if ($?) {
    Write-Host "Proceed..."
} else {
    Write-Host "Download failed, trying alternative RP package now..."
    (New-Object System.Net.WebClient).DownloadFile($rp_url, $dlFile)
}

# Extracting setup files
$extractFolder = "$nvidiaTempFolder\$version"
$filesToExtract = "Display.Driver HDAudio NVI2 PhysX EULA.txt ListDevices.txt setup.cfg setup.exe"
Write-Host "Download finished, extracting the files now..."
if ($archiverProgram -eq "$env:programfiles\7-zip\7z.exe") {
    Start-Process -FilePath $archiverProgram -ArgumentList "x $dlFile $filesToExtract -o""$extractFolder""" -wait
} elseif ($archiverProgram -eq "$env:programfiles\WinRAR\WinRAR.exe") {
    Start-Process -FilePath $archiverProgram -ArgumentList 'x $dlFile $extractFolder -IBCK $filesToExtract' -wait
}


# Remove unneeded dependencies from setup.cfg
(Get-Content "$extractFolder\setup.cfg") | Where-Object {$_ -notmatch 'name="\${{(EulaHtmlFile|FunctionalConsentFile|PrivacyPolicyFile)}}'} | Set-Content "$extractFolder\setup.cfg" -Encoding UTF8 -Force


# Installing drivers
Write-Host "Installing Nvidia drivers now..."
$install_args = "-s -noreboot -noeula"
if ($clean) {
    $install_args = $install_args + " -clean"
}
Start-Process -FilePath "$extractFolder\setup.exe" -ArgumentList $install_args -wait


# Creating a scheduled task if the $scheduleTask varible is set to TRUE
if ($scheduleTask) {
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
Write-Host "Deleting downloaded files"
Remove-Item $nvidiaTempFolder -Recurse -Force


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
