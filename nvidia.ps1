$r = Invoke-WebRequest -Uri 'https://www.nvidia.com/Download/processFind.aspx?psid=101&pfid=816&osid=57&lid=1&whql=1&lang=en-us&ctk=0' -Method GET

$clean = $FALSE #Do you want a clean installation?
$path_7z = "$env:programfiles\7-zip\7z.exe" #path to 7zip
$version = $r.parsedhtml.GetElementsByClassName("gridItem")[2].innerText
$dlFile = "$env:temp\$version.exe" #downloading to temp of current user.
$extractDir = $PSScriptRoot #extracting to current dir of the script file.

Write-Host "Trying to detect installed driver version."

$ins_version = (Get-WmiObject Win32_PnPSignedDriver | where {$_.devicename -like "*nvidia*" -and $_.devicename -notlike "*audio*"}).DriverVersion.SubString(7).Remove(1,1).Insert(3,".")

Write-Host "Detected installed version is: $ins_version"

if($version -eq $ins_version) {
	Write-Host "Installed version $ins_version is equals to latest version $version. Aborting"
	pause
	exit
}

if(Test-Path $extractDir\$version) {
	Write-Host "Old folder found, files already downloaded? Aborting."
	pause
	exit
}

$url = "http://uk.download.nvidia.com/Windows/$version/$version-desktop-win10-64bit-international-whql.exe"

Write-Host "Downloading $version from $url to $dlFile"

(New-Object System.Net.WebClient).DownloadFile($url, $dlFile)

Write-Host "Dl finished, extracting"
$args = "x $dlFile Display.Driver NVI2 EULA.txt ListDevices.txt setup.cfg setup.exe -o$extractDir\$version"
Write-Host $args
Start-Process  -FilePath $path_7z -ArgumentList $args -wait

Write-Host "deleting DL file $dlFile"
del $dlFile

$install_args = "-s -noreboot -noeula"
if($CLEAN){
	$install_args = $install_args + " -clean"
}

Start-Process  -FilePath "$extractDir\$version\setup.exe" -ArgumentList $install_args -wait

pause
