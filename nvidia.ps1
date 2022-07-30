# This script is designed to install the bare essential Nvidia drivers
# This will not install Nvidia GeForce or Shadowplay
# There are options below for customizing the install
# The defaults should suffice for most users


# Installer options
param
(
	[switch]
	$clean = $false, # Will delete old drivers and install the new ones

	[string]
	$folder = "$env:TEMP"   # Downloads and extracts the driver here
)

$scheduleTask = $false  # Creates a Scheduled Task to run to check for driver updates
$scheduleDay = "Sunday" # When should the scheduled task run (Default = Sunday)
$scheduleTime = "12pm"  # The time the scheduled task should run (Default = 12pm)

# Checking if 7zip or WinRAR are installed
# Check 7zip install path on registry
if (Test-Path -Path HKLM:\SOFTWARE\7-Zip)
{
	$7zpath = Get-ItemProperty -Path HKLM:\SOFTWARE\7-Zip -Name Path
	$7zpath = $7zpath.Path
	$7zpathexe = Join-Path -Path $7zpath -ChildPath "7z.exe"
	if (Test-Path -Path $7zpathexe)
	{
		$archiverProgram = $7zpathexe
		$7zipinstalled = $true
	}
}
elseif (-not $7zipinstalled)
{
	if (Test-Path -Path HKLM:\SOFTWARE\WinRAR)
	{
		$WinRARPath = Get-ItemProperty -Path HKLM:\SOFTWARE\WinRAR -Name exe64
		$WinRARPath = $WinRARPath.exe64
		if (Test-Path -Path $winrarpath)
		{
			$archiverProgram = $WinRARPath
		}
	}
}
else
{
	Write-Host "Sorry, but it looks like you don't have a supported archiver."

	$Choice = Read-Host -Prompt "Would you like to install 7-Zip now? (Y/N)"
	if ($Choice -eq 'y')
	{
		# Get the latest 7-Zip download URL
		$Parameters = @{
			Uri             = "https://sourceforge.net/projects/sevenzip/best_release.json"
			UseBasicParsing = $true
			Verbose         = $true
		}
		$bestRelease = (Invoke-RestMethod @Parameters).platform_releases.windows.filename

		# Download the latest 7-Zip x64
		$Parameters = @{
			Uri             = "https://nchc.dl.sourceforge.net/project/sevenzip$($bestRelease)"
			OutFile         = "$PSScriptRoot\7Zip.exe"
			UseBasicParsing = $true
			Verbose         = $true
		}
		Invoke-WebRequest @Parameters

		Start-Process -FilePath "$PSScriptRoot\7Zip.exe" -Wait -ArgumentList "/S"

		# Delete the installer once it completes
		Remove-Item -Path "$PSScriptRoot\7Zip.exe" -Force
	}
	else
	{
		Write-Verbose -Message "Press any key to exit..." -Verbose
		$host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown")
		exit
	}
}

# Checking currently installed driver version
try
{
	if (Test-Path -Path "C:\Windows\System32\DriverStore\FileRepository\nv_dispi.inf_amd64_*\nvidia-smi.exe")
	{
		# The NVIDIA System Management Interface (nvidia-smi) is a command line utility, based on top of the NVIDIA Management Library (NVML)
		$ins_version = nvidia-smi.exe --format=csv,noheader --query-gpu=driver_version
	}

	Write-Verbose -Message "Installed version: $ins_version" -Verbose
}
catch
{
	Write-Host -ForegroundColor Yellow "Unable to detect a compatible Nvidia device."
	Write-Host "Press any key to exit..."
	$host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown")
	exit
}


# Checking latest driver version from Nvidia website
$Parameters = @{
	Uri             = "https://www.nvidia.com/Download/processFind.aspx?psid=101&pfid=816&osid=57&lid=1&whql=1&lang=en-us&ctk=0&dtcid=1"
	Method          = "Get"
	UseBasicParsing = $true
	Verbose         = $true
}
$link = Invoke-WebRequest @Parameters
$link -match '<td class="gridItem">([^<]+?)</td>' | Out-Null
$version = $matches[1]
Write-Verbose -Message "Latest version: $version" -Verbose


# Comparing installed driver version to latest driver version from Nvidia
if (!$clean -and ($version -eq $ins_version)) {
    Write-Host "The installed version is the same as the latest version."
    Write-Host "Press any key to exit..."
    $host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown")
    exit
}


# Checking Windows version
if ([Environment]::OSVersion.Version -ge (new-object 'Version' 9, 1)) {
    $windowsVersion = "win10-win11"
}
else {
    $windowsVersion = "win8-win7"
}


# Checking Windows bitness
if ([Environment]::Is64BitOperatingSystem) {
    $windowsArchitecture = "64bit"
}
else {
    $windowsArchitecture = "32bit"
}


# Create a new temp folder NVIDIA
$nvidiaTempFolder = "$folder\NVIDIA"
New-Item -Path $nvidiaTempFolder -ItemType Directory 2>&1 | Out-Null


# Generating the download link
$url = "https://international.download.nvidia.com/Windows/$version/$version-desktop-$windowsVersion-$windowsArchitecture-international-dch-whql.exe"
$rp_url = "https://international.download.nvidia.com/Windows/$version/$version-desktop-$windowsVersion-$windowsArchitecture-international-dch-whql-rp.exe"


# Downloading the installer
$dlFile = "$nvidiaTempFolder\$version.exe"
Write-Host "Downloading the latest version to $dlFile"
Start-BitsTransfer -Source $url -Destination $dlFile

if ($?) {
    Write-Host "Proceed..."
}
else {
    Write-Host "Download failed, trying alternative RP package now..."
    Start-BitsTransfer -Source $rp_url -Destination $dlFile
}

# Extracting setup files
$extractFolder = "$nvidiaTempFolder\$version"
$filesToExtract = "Display.Driver HDAudio NVI2 PhysX EULA.txt ListDevices.txt setup.cfg setup.exe"
Write-Host "Download finished, extracting the files now..."

if ($7zipinstalled) {
    Start-Process -FilePath $archiverProgram -NoNewWindow -ArgumentList "x -bso0 -bsp1 -bse1 -aoa $dlFile $filesToExtract -o""$extractFolder""" -wait
}
elseif ($archiverProgram -eq $winrarpath) {
    Start-Process -FilePath $archiverProgram -NoNewWindow -ArgumentList 'x $dlFile $extractFolder -IBCK $filesToExtract' -wait
}
else {
    Write-Host "Something went wrong. No archive program detected. This should not happen."
    Write-Host "Press any key to exit..."
    $host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown")
    exit
}


# Remove unneeded dependencies from setup.cfg
(Get-Content "$extractFolder\setup.cfg") | Where-Object { $_ -notmatch 'name="\${{(EulaHtmlFile|FunctionalConsentFile|PrivacyPolicyFile)}}' } | Set-Content "$extractFolder\setup.cfg" -Encoding UTF8 -Force


# Installing drivers
Write-Host "Installing Nvidia drivers now..."
$install_args = "-passive -noreboot -noeula -nofinish -s"
if ($clean) {
    $install_args = $install_args + " -clean"
}
Start-Process -FilePath "$extractFolder\setup.exe" -ArgumentList $install_args -wait


# Creating a scheduled task if the $scheduleTask varible is set to TRUE
if ($scheduleTask)
{
	Write-Verbose -Message "Creating A Scheduled Task..." -Verbose

	$Parameters = @{
		Path     = $env:SystemDrive\Task
		ItemType = "Directory"
		Force    = $true
	}
	New-Item @Parameters

	$Parameters = @{
		Path     = $env:SystemDrive\Task
		ItemType = "Directory"
		Force    = $true
	}
	Copy-Item @Parameters

	$ScriptName = Split-Path -Path $PSCommandPath -Leaf
	Copy-Item -Path $ScriptName -Destination $env:SystemDrive\Task

	$scheduleDay = "Sunday" # When should the scheduled task run (Default = Sunday)
	$scheduleTime = "12pm"  # The time the scheduled task should run (Default = 12pm)
	$Action     = New-ScheduledTaskAction -Execute powershell.exe -Argument "-ExecutionPolicy Bypass -NoProfile -NoLogo -WindowStyle Hidden -File `"$env:SystemDrive\Task\Nvidia.ps1`""
	$Trigger    = New-ScheduledTaskTrigger -Weekly -WeeksInterval $scheduleTask -DaysOfWeek $scheduleDay -At $scheduleTime
	$Settings   = New-ScheduledTaskSettingsSet -Compatibility Win8
	$Principal  = New-ScheduledTaskPrincipal -UserId $env:USERNAME -RunLevel Highest
	$Parameters = @{
		TaskName    = "Nvidia-Updater"
		Description = "Update Your Driver!"
		Principal   = $Principal
		Action      = $Action
		Settings    = $Settings
		Trigger     = $Trigger
	}
	Register-ScheduledTask @Parameters -Force
}

# Cleaning up downloaded files
Write-Host "Deleting downloaded files"
Remove-Item $nvidiaTempFolder -Recurse -Force

# Driver installed, requesting a reboot
Write-Host -ForegroundColor Green "Driver installed. You may need to reboot to finish installation."
Write-Host "Would you like to reboot now?"
$Readhost = Read-Host -Prompt "(Y/N) Default is no"
switch ($ReadHost)
{
	Y
	{
		Write-Verbose -Message "Rebooting now..." -Verbose
		Start-Sleep -Seconds 2
		Restart-Computer
	}
	N
	{
		Write-Verbose -Message "Exiting script in 5 seconds." -Verbose
		Start-Sleep -Seconds 5
	}
	Default
	{
		Write-Verbose -Message "Exiting script in 5 seconds" -Verbose
		Start-Sleep -Seconds 5
	}
}

# End of script
exit
