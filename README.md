<img src="./logo.svg" width="128" align="right">

<br/>
<br/>
<br/>

# nvidia-update

Checks for a new version of the Nvidia Driver, downloads and installs it.

### usage

* Download `nvidia.ps1` file into a folder of its own
* Right click and press `Run with powershell`
* The script will now detect your version, check for a new version online, download and extract it into the current directy.

Optional Parameters

* While holding `shift` press `right click` in the folder with the script
* select `open powershell window here`
* Enter:  `.\nvidia.ps1`

TODO: how to use parameters

### Running the script regular and automaticly

You can use `SchTasks` to run the script automaticly.

`SchTasks /Create /SC DAILY /TN “Nvidia-Updater” /TR “<path_to_script>” /ST 10:00`

### Requirements

Nvidia-update needs 7zip or WinRar installed into default locations. It looks at `programfiles\7-zip\7z.exe` and `programfiles\WinRAR\WinRAR.exe` to extract the drivers.
