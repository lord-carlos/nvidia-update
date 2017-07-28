# Ask For Elevated Permissions if Required
If (!([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]"Administrator")) {
	Start-Process powershell.exe "-NoProfile -ExecutionPolicy Bypass -File `"$PSCommandPath`"" -Verb RunAs
	Exit
}

#Options
$cleanInstall = $FALSE          #Will delete old drivers and install the new ones
$secondaryDrive = $FALSE        #If you don't want to download a 400Mb file to your SSD
$scheduleTask = $FALSE          #To run this script every X week
$scheduleDay = "Sunday"         #When should the task run. Default = Sunday
$scheduleTime = "12pm"          #At what time should the task run. Default 12pm

#Extracting To Current Directory Of The Script File.
$extractDir = $PSScriptRoot 

#Checking What File Archiver Is Installed.
if (Test-Path $env:programfiles\7-zip\7z.exe) {
    $archiverProgram = "$env:programfiles\7-zip\7z.exe"
} elseif (Test-Path $env:programfiles\WinRAR\WinRAR.exe) {
    $archiverProgram = "$env:programfiles\WinRAR\WinRAR.exe"
} else {
    Write-Host "Sorry but it looks like you don't have a supported archiver"
    Write-Host "Press any key to exit"
    $key = $host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown")
	exit
}

#Checking The Installed Version.
Write-Host "Trying to detect installed driver version"
try {  
    $ins_version = (Get-WmiObject Win32_PnPSignedDriver | Where-Object {$_.devicename -like "*nvidia*" -and $_.devicename -notlike "*audio*"}).DriverVersion.SubString(7).Remove(1,1).Insert(3,".")
} catch {
    Write-Host "Sorry, it looks like you don't have a compatible Nvidia device"
    Write-Host "Press any key to exit"
    $key = $host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown")
	exit
}
    Write-Host "Installed version `t$ins_version"

#Getting The Latest Version.
$link = Invoke-WebRequest -Uri 'https://www.nvidia.com/Download/processFind.aspx?psid=101&pfid=816&osid=57&lid=1&whql=1&lang=en-us&ctk=0' -Method GET
$version = $link.parsedhtml.GetElementsByClassName("gridItem")[2].innerText
Write-Host "Latest version `t`t$version"

#Comparing Installed And The Latest Versions.
if($version -eq $ins_version) {
	Write-Host "The installed version is the same as the latest version"
    Write-Host "Press any key to exit"
    $key = $host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown")
	exit
}

#Setting The Download Folder To Temp.
if (!$secondaryDrive) {
    $dlFile = "$env:temp\$version.exe"
} else {
    $dlFile = "D:\$version.exe"
}

#Determening What Version Of Windows Is Being Used
if ([Environment]::OSVersion.Version -ge (new-object 'Version' 9,1)) {
	$windowsVersion = "win10"
} else {
	$windowsVersion = "win8-win7"
}
if ((gwmi win32_operatingsystem | select osarchitecture).osarchitecture -eq "64-bit")
{
	$windowsArchitecture = "64bit"
} else {
	$windowsArchitecture = "32bit"
}

#Generating The Download Link.
$url = "http://us.download.nvidia.com/Windows/$version/$version-desktop-$windowsVersion-$windowsArchitecture-international-whql.exe"

#Downloading The Installer.
Write-Host "Downloading the latest version to $dlFile"
(New-Object System.Net.WebClient).DownloadFile($url, $dlFile)

#Extracting The Files.
Write-Host "Download finished, extracting the files now"
if($archiverProgram = "$env:programfiles\7-zip\7z.exe") {
    Start-Process -FilePath $archiverProgram -ArgumentList "x $dlFile Display.Driver NVI2 EULA.txt ListDevices.txt setup.cfg setup.exe -o$extractDir\$version\" -wait
} elseif ($archiverProgram = "$env:programfiles\WinRAR\WinRAR.exe") {
    Start-Process -FilePath $archiverProgram -ArgumentList 'x $dlFile $extractDir\$version\ -IBCK Display.Driver NVI2 EULA.txt ListDevices.txt setup.cfg setup.exe' -wait
}

#Installing The Drivers.
Write-Host "Installing the drivers now"
$install_args = "-s -noreboot -noeula"
if($cleanInstall){
	$install_args = $install_args + " -clean"
}
Start-Process -FilePath "$extractDir\$version\setup.exe" -ArgumentList $install_args -wait

#Creating A Scheduled Task With The Same Options
if ($scheduleTask -ne $FALSE) {
    Write-Host "Creating A Scheduled Task..."
    New-Item C:\Task\ -type directory 2>&1 | Out-Null
    Copy-Item .\Nvidia.ps1 -Destination C:\Task\ 2>&1 | Out-Null
    $taskname = "Nvidia-Updater"
    $descreption = "Update Your Driver!"
    $action = New-ScheduledTaskAction -Execute "C:\Task\Nvidia.ps1"
    $trigger =  New-ScheduledTaskTrigger -Weekly -WeeksInterval $scheduleTask -DaysOfWeek $scheduleDay -At $scheduleTime
    Register-ScheduledTask -TaskName $taskname -Action $action -Trigger $trigger -Description $descreption 2>&1 | Out-Null
}

#Cleaning And Finishing.
Write-Host "deleting downloaded file $dlFile"
Remove-Item $dlFile
Write-Host "Press any key to exit"
$key = $host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown")
