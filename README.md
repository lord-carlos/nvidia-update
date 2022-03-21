<img src="./logo.svg" width="128" align="right">

<br/>
<br/>
<br/>

# nvidia-update

Checks for a new version of the Nvidia Driver, downloads and installs it.

## Usage

* Download `nvidia.ps1`
* Right click and select `Run with PowerShell`
* If the script finds a newer version of the nvidia driver online it will download and install it.

### Optional parameters

* `-clean` - deletes the old driver and installs the newest one
* `-folder <path_to_folder>` - the directory where the script will download and extract the new driver

### How to pass the optional parameters

* While holding `shift` press `right click` in the folder with the script
* Select `Open PowerShell window here`
* Enter `.\nvidia.ps1 <parameters>` (ex: `.\nvidia.ps1 -clean -folder C:\NVIDIA`)

## Running the script regularly and automatically

You can use `SchTasks` to run the script automatically with:

```ps
$path = "C:"
New-Item -ItemType Directory -Force -Path $path | Out-Null
Invoke-WebRequest -Uri "https://github.com/lord-carlos/nvidia-update/raw/master/nvidia.ps1" -OutFile "$path\nvidia.ps1" -UseBasicParsing
SchTasks /Create /SC DAILY /TN "Nvidia-Updater" /TR "powershell -NoProfile -ExecutionPolicy Bypass -File $path\nvidia.ps1" /ST 10:00
schtasks /run /tn "Nvidia-Updater"
```

## Requirements / Dependencies

7-Zip or WinRar are needed to extract the drivers.


## FAQ

Q. How do we check for the latest driver version from Nvidia website ?

> We use the NVIDIA [Advanced Driver Search](https://www.nvidia.com/Download/Find.aspx).
>
> Example:
> ```https://www.nvidia.com/Download/processFind.aspx?psid=101&pfid=845&osid=57&lid=1&whql=1&ctk=0&dtcid=0```
>
> * **psid**: Product Series ID (_GeForce 10 Series_: 101)
> * **pfid**: Product ID (e.g. _GeForce GTX 1080 Ti_: 845)
> * **osid**: Operating System ID (e.g. _Windows 10 64-bit_: 57)
> * **lid**: Language ID (e.g. _English (US)_: 1)
> * **whql**: Driver channel (_Certified_: 0, Beta: 1)
> * **dtcid**: Windows Driver Type (_Standard_: 0, DCH: 1)

