#requires -version 5.1
[CmdletBinding()]
param(
    [switch]$QuickScan,
    [switch]$FullScan,
    [switch]$Laptop,
    [switch]$Hardware,
    [switch]$CPU,
    [switch]$GPU,
    [switch]$RAM,
    [switch]$Storage,
    [switch]$Battery,
    [switch]$Motherboard,
    [switch]$Ports,
    [switch]$Network,
    [switch]$Drivers,
    [switch]$Windows,
    [switch]$Thermal,
    [switch]$Security,
    [switch]$Performance,
    [switch]$Display,
    [switch]$InputDevices,
    [switch]$Audio,
    [switch]$Camera,
    [switch]$CompleteDiagnostic
)

$ErrorActionPreference = 'Continue'
$script:Results = [System.Collections.Generic.List[object]]::new()
$script:Started = Get-Date

function Write-Logo {
    Clear-Host
    Write-Host @"
   ███████╗██╗███╗   ███╗ ██████╗
   ██╔════╝██║████╗ ████║██╔═══██╗
   ███████╗██║██╔████╔██║██║   ██║
   ╚════██║██║██║╚██╔╝██║██║   ██║
   ███████║██║██║ ╚═╝ ██║╚██████╔╝
   ╚══════╝╚═╝╚═╝     ╚═╝ ╚═════╝

   S I M O   T E S T
   // PROFESSIONAL PC DIAGNOSTICS //
"@ -ForegroundColor Green
}

function Write-Status {
    param([string]$Label,[string]$Message,[ConsoleColor]$Color = [ConsoleColor]::Gray)
    Write-Host ('[{0}] {1}' -f $Label,$Message) -ForegroundColor $Color
}

function Add-Result {
    param(
        [string]$Component,
        [ValidateSet('NORMAL','ATTENTION','ANOMALY_DETECTED','NOT_DETERMINED','NOT_SUPPORTED')]
        [string]$Status,
        [ValidateSet('LOW','MEDIUM','HIGH')]
        [string]$Confidence,
        [string]$Message,
        [string]$Source = 'Windows API'
    )
    $script:Results.Add([pscustomobject]@{
        Time = (Get-Date).ToString('s')
        Component = $Component
        Status = $Status
        Confidence = $Confidence
        Message = $Message
        Source = $Source
    })
}

function Get-CimSafe {
    param([string]$ClassName,[string]$Namespace='root/cimv2',[int]$TimeoutSec=10)
    try { Get-CimInstance -ClassName $ClassName -Namespace $Namespace -OperationTimeoutSec $TimeoutSec -ErrorAction Stop }
    catch { $null }
}

function Invoke-Module {
    param([string]$Name,[scriptblock]$Action)
    Write-Host "`n╔══ $Name" -ForegroundColor Cyan
    try { & $Action }
    catch { Add-Result $Name 'NOT_DETERMINED' 'LOW' $_.Exception.Message 'Module exception' }
}

function Test-Admin {
    try {
        $p = New-Object Security.Principal.WindowsPrincipal([Security.Principal.WindowsIdentity]::GetCurrent())
        return $p.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
    } catch { return $false }
}

function Invoke-SystemModule {
    $os = Get-CimSafe Win32_OperatingSystem
    $cs = Get-CimSafe Win32_ComputerSystem
    if (-not $os -or -not $cs) { Add-Result 'SYSTEM' 'NOT_DETERMINED' 'LOW' 'Windows system information unavailable'; return }
    Add-Result 'SYSTEM' 'NORMAL' 'HIGH' ("{0} {1} build {2}; {3} GB RAM" -f $os.Caption,$os.OSArchitecture,$os.BuildNumber,[math]::Round($cs.TotalPhysicalMemory/1GB,1)) 'Win32_OperatingSystem/Win32_ComputerSystem'
}

function Invoke-CPUModule {
    $cpus = @(Get-CimSafe Win32_Processor)
    if (!$cpus) { Add-Result 'CPU' 'NOT_DETERMINED' 'LOW' 'CPU telemetry unavailable'; return }
    foreach($cpu in $cpus) {
        $msg = "{0}; {1} cores / {2} logical processors; max {3} MHz" -f $cpu.Name,$cpu.NumberOfCores,$cpu.NumberOfLogicalProcessors,$cpu.MaxClockSpeed
        $status='NORMAL'; $conf='HIGH'
        if ($cpu.NumberOfCores -lt 1 -or $cpu.NumberOfLogicalProcessors -lt 1) { $status='ANOMALY_DETECTED'; $conf='HIGH' }
        Add-Result 'CPU' $status $conf $msg 'Win32_Processor'
    }
}

function Invoke-RAMModule {
    $modules=@(Get-CimSafe Win32_PhysicalMemory)
    if(!$modules){Add-Result 'RAM' 'NOT_DETERMINED' 'LOW' 'Physical memory information unavailable';return}
    $total=($modules|Measure-Object Capacity -Sum).Sum
    $bad=@($modules|Where-Object {$_.Status -and $_.Status -notmatch 'OK'})
    if($bad.Count){Add-Result 'RAM' 'ANOMALY_DETECTED' 'MEDIUM' ("{0} memory module(s) report non-OK status" -f $bad.Count) 'Win32_PhysicalMemory'}
    else{Add-Result 'RAM' 'NORMAL' 'MEDIUM' ("{0} module(s), {1} GB detected; Windows-reported status has no anomaly" -f $modules.Count,[math]::Round($total/1GB,1)) 'Win32_PhysicalMemory'}
    foreach($m in $modules){ Add-Result 'RAM-MODULE' 'NORMAL' 'MEDIUM' ("{0}; {1} MB; {2} MT/s" -f $m.Manufacturer,[math]::Round($m.Capacity/1MB),$m.Speed) 'Win32_PhysicalMemory' }
}

function Invoke-GPUModule {
    $gpus=@(Get-CimSafe Win32_VideoController)
    if(!$gpus){Add-Result 'GPU' 'NOT_DETERMINED' 'LOW' 'Video controller information unavailable';return}
    foreach($g in $gpus){
        $status='NORMAL'; $conf='MEDIUM'
        if($g.ConfigManagerErrorCode -and $g.ConfigManagerErrorCode -ne 0){$status='ANOMALY_DETECTED';$conf='HIGH'}
        $vram=if($g.AdapterRAM){[math]::Round($g.AdapterRAM/1GB,2)}else{'N/A'}
        Add-Result 'GPU' $status $conf ("{0}; VRAM reported {1} GB; PnP error code {2}" -f $g.Name,$vram,$g.ConfigManagerErrorCode) 'Win32_VideoController'
    }
}

function Invoke-StorageModule {
    $disks=@(Get-CimSafe Win32_DiskDrive)
    if(!$disks){Add-Result 'STORAGE' 'NOT_DETERMINED' 'LOW' 'Disk information unavailable';return}
    foreach($d in $disks){
        $size=[math]::Round($d.Size/1GB,1)
        Add-Result 'STORAGE' 'NORMAL' 'MEDIUM' ("{0}; {1} GB; interface {2}; media {3}" -f $d.Model,$size,$d.InterfaceType,$d.MediaType) 'Win32_DiskDrive'
    }
    try{
        $pd=@(Get-PhysicalDisk -ErrorAction Stop)
        foreach($d in $pd){
            $status='NORMAL'; if($d.HealthStatus -ne 'Healthy'){$status='ATTENTION'}
            Add-Result 'STORAGE-HEALTH' $status 'HIGH' ("{0}; health {1}; operational {2}" -f $d.FriendlyName,$d.HealthStatus,$d.OperationalStatus) 'Get-PhysicalDisk'
        }
    }catch{Add-Result 'STORAGE-HEALTH' 'NOT_SUPPORTED' 'LOW' 'Get-PhysicalDisk is unavailable or storage provider did not expose health data'}
}

function Invoke-BatteryModule {
    $b=@(Get-CimSafe Win32_Battery)
    if(!$b){Add-Result 'BATTERY' 'NOT_SUPPORTED' 'HIGH' 'No Windows battery device reported; likely desktop or unsupported firmware';return}
    foreach($x in $b){
        $status='NORMAL'; $conf='MEDIUM'
        if($x.BatteryStatus -eq 4){$status='NORMAL'}
        Add-Result 'BATTERY' $status $conf ("{0}; charge {1}%; status code {2}; estimated runtime {3} min" -f $x.Name,$x.EstimatedChargeRemaining,$x.BatteryStatus,$x.EstimatedRunTime) 'Win32_Battery'
    }
    try{
        $batt=Get-CimInstance -Namespace root/cimv2/power -ClassName Win32_Battery -ErrorAction Stop
        if($batt.Count -eq 0){Add-Result 'BATTERY-HEALTH' 'NOT_DETERMINED' 'LOW' 'Design/full-charge capacity not exposed by this firmware'}
    }catch{Add-Result 'BATTERY-HEALTH' 'NOT_DETERMINED' 'LOW' 'Battery health telemetry unavailable'}
}

function Invoke-MotherboardModule {
    $bb=Get-CimSafe Win32_BaseBoard; $bios=Get-CimSafe Win32_BIOS
    if(!$bb -and !$bios){Add-Result 'MOTHERBOARD' 'NOT_DETERMINED' 'LOW' 'Baseboard/BIOS data unavailable';return}
    if($bb){Add-Result 'MOTHERBOARD' 'NORMAL' 'HIGH' ("{0} {1}; serial {2}" -f $bb.Manufacturer,$bb.Product,$bb.SerialNumber) 'Win32_BaseBoard'}
    if($bios){Add-Result 'BIOS' 'NORMAL' 'HIGH' ("{0}; version {1}; release {2}" -f $bios.Manufacturer,$bios.SMBIOSBIOSVersion,$bios.ReleaseDate) 'Win32_BIOS'}
}

function Invoke-PortsModule {
    $dev=@(Get-PnpDevice -PresentOnly -ErrorAction SilentlyContinue | Where-Object {$_.Class -match 'USB|Bluetooth|Ports'})
    if(!$dev){Add-Result 'PORTS' 'NOT_DETERMINED' 'LOW' 'PnP port inventory unavailable';return}
    $bad=@($dev|Where-Object {$_.Status -ne 'OK'})
    if($bad.Count){Add-Result 'PORTS' 'ATTENTION' 'MEDIUM' ("{0} present port-related PnP device(s) report a non-OK status" -f $bad.Count) 'Get-PnpDevice'}
    else{Add-Result 'PORTS' 'NORMAL' 'MEDIUM' ("{0} present USB/Bluetooth/port-related devices report OK" -f $dev.Count) 'Get-PnpDevice'}
}

function Invoke-NetworkModule {
    $ad=@(Get-NetAdapter -ErrorAction SilentlyContinue)
    if(!$ad){Add-Result 'NETWORK' 'NOT_DETERMINED' 'LOW' 'Network adapter inventory unavailable';return}
    foreach($a in $ad){
        $status=if($a.Status -eq 'Up' -or $a.Status -eq 'Disabled'){'NORMAL'}else{'ATTENTION'}
        Add-Result 'NETWORK' $status 'HIGH' ("{0}; status {1}; link {2}; MAC {3}" -f $a.Name,$a.Status,$a.LinkSpeed,$a.MacAddress) 'Get-NetAdapter'
    }
}

function Invoke-DriversModule {
    $dev=@(Get-PnpDevice -ErrorAction SilentlyContinue)
    if(!$dev){Add-Result 'DRIVERS' 'NOT_DETERMINED' 'LOW' 'PnP inventory unavailable';return}
    $bad=@($dev|Where-Object {$_.Status -ne 'OK' -and $_.Status -ne 'Unknown'})
    if($bad.Count){Add-Result 'DRIVERS' 'ATTENTION' 'HIGH' ("{0} PnP device(s) have non-OK status" -f $bad.Count) 'Get-PnpDevice'}
    else{Add-Result 'DRIVERS' 'NORMAL' 'HIGH' ("{0} PnP devices checked; no non-OK device status detected" -f $dev.Count) 'Get-PnpDevice'}
}

function Invoke-WindowsModule {
    $os=Get-CimSafe Win32_OperatingSystem
    $sfc=(Get-WinEvent -FilterHashtable @{LogName='System';Id=1001} -MaxEvents 1 -ErrorAction SilentlyContinue)
    if($os){Add-Result 'WINDOWS' 'NORMAL' 'HIGH' ("{0}; build {1}; boot {2}" -f $os.Caption,$os.BuildNumber,$os.LastBootUpTime) 'Win32_OperatingSystem'}
    try{
        $def=Get-MpComputerStatus -ErrorAction Stop
        $status=if($def.RealTimeProtectionEnabled){'NORMAL'}else{'ATTENTION'}
        Add-Result 'DEFENDER' $status 'HIGH' ("AntivirusEnabled={0}; RealTimeProtection={1}; SignatureAge={2} day(s)" -f $def.AntivirusEnabled,$def.RealTimeProtectionEnabled,$def.AntivirusSignatureAge) 'Microsoft Defender API'
    }catch{Add-Result 'DEFENDER' 'NOT_SUPPORTED' 'LOW' 'Microsoft Defender status API unavailable'}
}

function Invoke-ThermalModule {
    $temps=@(Get-CimInstance -Namespace root/wmi -ClassName MSAcpi_ThermalZoneTemperature -ErrorAction SilentlyContinue)
    if(!$temps){Add-Result 'THERMAL' 'NOT_DETERMINED' 'LOW' 'ACPI thermal zone temperature not exposed; software cannot infer CPU/GPU temperature';return}
    foreach($t in $temps){
        $c=($t.CurrentTemperature/10)-273.15
        $status=if($c -ge 95){'ATTENTION'}else{'NORMAL'}
        Add-Result 'THERMAL' $status 'LOW' ("ACPI thermal zone reports {0:N1} °C; sensor identity/coverage is firmware dependent" -f $c) 'MSAcpi_ThermalZoneTemperature'
    }
}

function Invoke-SecurityModule {
    try{$tpm=Get-Tpm -ErrorAction Stop; $s=if($tpm.TpmPresent -and $tpm.TpmReady){'NORMAL'}else{'ATTENTION'};Add-Result 'TPM' $s 'HIGH' ("Present={0}; Ready={1}; Enabled={2}" -f $tpm.TpmPresent,$tpm.TpmReady,$tpm.TpmEnabled) 'Get-Tpm'}catch{Add-Result 'TPM' 'NOT_SUPPORTED' 'LOW' 'TPM API unavailable'}
    try{$sb=Confirm-SecureBootUEFI -ErrorAction Stop;$s=if($sb){'NORMAL'}else{'ATTENTION'};Add-Result 'SECURE_BOOT' $s 'HIGH' ("Secure Boot enabled={0}" -f $sb) 'Confirm-SecureBootUEFI'}catch{Add-Result 'SECURE_BOOT' 'NOT_DETERMINED' 'LOW' 'Secure Boot state unavailable in current boot mode'}
    try{$bl=@(Get-BitLockerVolume -ErrorAction Stop);$unprot=@($bl|Where-Object {$_.ProtectionStatus -ne 'On'});$s=if($unprot.Count){'ATTENTION'}else{'NORMAL'};Add-Result 'BITLOCKER' $s 'MEDIUM' ("{0} BitLocker volume(s); {1} not actively protected" -f $bl.Count,$unprot.Count) 'Get-BitLockerVolume'}catch{Add-Result 'BITLOCKER' 'NOT_SUPPORTED' 'LOW' 'BitLocker management API unavailable'}
}

function Invoke-PerformanceModule {
    try{
        $cpu=(Get-Counter '\Processor(_Total)\% Processor Time' -SampleInterval 1 -MaxSamples 2 -ErrorAction Stop).CounterSamples[-1].CookedValue
        Add-Result 'PERFORMANCE' 'NORMAL' 'MEDIUM' ("CPU utilization sample: {0:N1}%" -f $cpu) 'Performance Counter'
    }catch{Add-Result 'PERFORMANCE' 'NOT_DETERMINED' 'LOW' 'Performance counter unavailable'}
}

function Invoke-DisplayModule {
    $mon=@(Get-CimSafe WmiMonitorID -Namespace root/wmi)
    $gpu=@(Get-CimSafe Win32_VideoController)
    if($gpu){foreach($g in $gpu){Add-Result 'DISPLAY' 'NORMAL' 'MEDIUM' ("Controller {0}; {1}x{2}; refresh {3} Hz when reported" -f $g.Name,$g.CurrentHorizontalResolution,$g.CurrentVerticalResolution,$g.CurrentRefreshRate) 'Win32_VideoController'}}
    else{Add-Result 'DISPLAY' 'NOT_DETERMINED' 'LOW' 'Display controller information unavailable'}
    if(!$mon){Add-Result 'MONITOR' 'NOT_DETERMINED' 'LOW' 'Physical monitor EDID not exposed by WMI'}
}

function Invoke-InputModule {
    $kbd=@(Get-PnpDevice -Class Keyboard -PresentOnly -ErrorAction SilentlyContinue)
    $mouse=@(Get-PnpDevice -Class Mouse -PresentOnly -ErrorAction SilentlyContinue)
    $tp=@(Get-PnpDevice -PresentOnly -ErrorAction SilentlyContinue|Where-Object {$_.FriendlyName -match 'Touchpad|Precision Touchpad'})
    if($kbd){Add-Result 'KEYBOARD' 'NORMAL' 'MEDIUM' ("{0} keyboard PnP device(s) present; physical key operation requires manual test" -f $kbd.Count) 'Get-PnpDevice'}else{Add-Result 'KEYBOARD' 'NOT_DETERMINED' 'LOW' 'Keyboard PnP inventory unavailable'}
    if($mouse){Add-Result 'MOUSE' 'NORMAL' 'MEDIUM' ("{0} pointing device(s) present; physical button/sensor operation requires manual test" -f $mouse.Count) 'Get-PnpDevice'}
    if($tp){Add-Result 'TOUCHPAD' 'NORMAL' 'MEDIUM' ("{0} touchpad device(s) detected; gesture operation requires manual test" -f $tp.Count) 'Get-PnpDevice'}
}

function Invoke-AudioModule {
    $a=@(Get-PnpDevice -Class Media -PresentOnly -ErrorAction SilentlyContinue)
    if(!$a){Add-Result 'AUDIO' 'NOT_DETERMINED' 'LOW' 'Audio PnP devices unavailable';return}
    $bad=@($a|Where-Object {$_.Status -ne 'OK'})
    Add-Result 'AUDIO' $(if($bad.Count){'ATTENTION'}else{'NORMAL'}) 'MEDIUM' ("{0} audio/media PnP device(s); {1} non-OK" -f $a.Count,$bad.Count) 'Get-PnpDevice'
}

function Invoke-CameraModule {
    $c=@(Get-PnpDevice -PresentOnly -ErrorAction SilentlyContinue|Where-Object {$_.Class -match 'Camera|Image'})
    if(!$c){Add-Result 'CAMERA' 'NOT_DETERMINED' 'LOW' 'No camera/image PnP device detected'}
    else{Add-Result 'CAMERA' 'NORMAL' 'MEDIUM' ("{0} camera/image PnP device(s) detected; image capture requires functional test" -f $c.Count) 'Get-PnpDevice'}
}

function Invoke-Complete {
    Invoke-SystemModule;Invoke-CPUModule;Invoke-RAMModule;Invoke-GPUModule;Invoke-StorageModule;Invoke-BatteryModule;Invoke-MotherboardModule;Invoke-PortsModule;Invoke-NetworkModule;Invoke-DriversModule;Invoke-WindowsModule;Invoke-ThermalModule;Invoke-SecurityModule;Invoke-PerformanceModule;Invoke-DisplayModule;Invoke-InputModule;Invoke-AudioModule;Invoke-CameraModule
}

function Show-Summary {
    Write-Host "`n════════════════════════════════════════════════════════════" -ForegroundColor DarkGreen
    Write-Host ' SIMO TEST — DIAGNOSTIC SUMMARY' -ForegroundColor Green
    Write-Host "════════════════════════════════════════════════════════════" -ForegroundColor DarkGreen
    if(!$script:Results.Count){Write-Host 'No diagnostic result.';return}
    $script:Results | Group-Object Status | Sort-Object Name | ForEach-Object { Write-Host ('{0,-20} {1,4}' -f $_.Name,$_.Count) -ForegroundColor $(switch($_.Name){'NORMAL' {'Green';break}'ATTENTION' {'Yellow';break}'ANOMALY_DETECTED' {'Red';break}default {'Gray'}}) }
    Write-Host "`nDETAILS" -ForegroundColor Cyan
    foreach($r in $script:Results){
        $color=switch($r.Status){'NORMAL'{'Green'}'ATTENTION'{'Yellow'}'ANOMALY_DETECTED'{'Red'}'NOT_SUPPORTED'{'DarkCyan'}default{'Gray'}}
        Write-Host ('[{0,-17}] [{1,-6}] {2}: {3}' -f $r.Status,$r.Confidence,$r.Component,$r.Message) -ForegroundColor $color
    }
    Write-Host "`nNo software-only result proves physical perfection. Use the manual checklist for physical verification." -ForegroundColor DarkGray
    Write-Host "Elapsed: $([math]::Round(((Get-Date)-$script:Started).TotalSeconds,1)) s" -ForegroundColor DarkGray
    Write-Host "`n   S I M O   T E S T  // END OF DIAGNOSTIC" -ForegroundColor Green
}

Write-Logo
Write-Status 'SYSTEM' 'Initializing diagnostic engine...' Cyan
if(Test-Admin){Write-Status 'OK' 'Administrator privileges detected.' Green}else{Write-Status 'ATTENTION' 'PowerShell is not elevated. Some diagnostics will be unavailable.' Yellow}
Write-Status 'ENGINE' 'Evidence-based diagnostic mode enabled.' Green

$requested = $QuickScan -or $FullScan -or $Laptop -or $Hardware -or $CPU -or $GPU -or $RAM -or $Storage -or $Battery -or $Motherboard -or $Ports -or $Network -or $Drivers -or $Windows -or $Thermal -or $Security -or $Performance -or $Display -or $InputDevices -or $Audio -or $Camera -or $CompleteDiagnostic

if($CompleteDiagnostic -or $FullScan -or $Hardware){Invoke-Complete}
elseif($QuickScan){Invoke-SystemModule;Invoke-CPUModule;Invoke-RAMModule;Invoke-GPUModule;Invoke-StorageModule;Invoke-WindowsModule;Invoke-DriversModule}
elseif($Laptop){Invoke-SystemModule;Invoke-CPUModule;Invoke-RAMModule;Invoke-GPUModule;Invoke-StorageModule;Invoke-BatteryModule;Invoke-MotherboardModule;Invoke-PortsModule;Invoke-NetworkModule;Invoke-ThermalModule;Invoke-DisplayModule;Invoke-InputModule;Invoke-AudioModule;Invoke-CameraModule}
elseif($CPU){Invoke-CPUModule}
elseif($GPU){Invoke-GPUModule}
elseif($RAM){Invoke-RAMModule}
elseif($Storage){Invoke-StorageModule}
elseif($Battery){Invoke-BatteryModule}
elseif($Motherboard){Invoke-MotherboardModule}
elseif($Ports){Invoke-PortsModule}
elseif($Network){Invoke-NetworkModule}
elseif($Drivers){Invoke-DriversModule}
elseif($Windows){Invoke-WindowsModule}
elseif($Thermal){Invoke-ThermalModule}
elseif($Security){Invoke-SecurityModule}
elseif($Performance){Invoke-PerformanceModule}
elseif($Display){Invoke-DisplayModule}
elseif($InputDevices){Invoke-InputModule}
elseif($Audio){Invoke-AudioModule}
elseif($Camera){Invoke-CameraModule}
else {
    do {
        Write-Host "`n[1] Quick Scan`n[2] Full Scan`n[3] Laptop Scan`n[4] Hardware`n[5] CPU`n[6] GPU`n[7] RAM`n[8] Storage`n[9] Battery`n[10] Motherboard`n[11] USB / Ports`n[12] Network`n[13] Drivers`n[14] Windows`n[15] Thermal`n[16] Security`n[17] Performance`n[18] Display`n[19] Input`n[20] Audio`n[21] Camera`n[22] Complete Diagnostic`n[Q] Exit" -ForegroundColor White
        $choice=Read-Host 'SIMO TEST >'
        switch($choice.ToUpperInvariant()){
            '1'{Invoke-SystemModule;Invoke-CPUModule;Invoke-RAMModule;Invoke-GPUModule;Invoke-StorageModule;Invoke-WindowsModule;Invoke-DriversModule;Show-Summary}
            '2'{Invoke-Complete;Show-Summary}
            '3'{Invoke-SystemModule;Invoke-CPUModule;Invoke-RAMModule;Invoke-GPUModule;Invoke-StorageModule;Invoke-BatteryModule;Invoke-MotherboardModule;Invoke-PortsModule;Invoke-NetworkModule;Invoke-ThermalModule;Invoke-DisplayModule;Invoke-InputModule;Invoke-AudioModule;Invoke-CameraModule;Show-Summary}
            '4'{Invoke-Complete;Show-Summary}
            '5'{Invoke-CPUModule;Show-Summary}
            '6'{Invoke-GPUModule;Show-Summary}
            '7'{Invoke-RAMModule;Show-Summary}
            '8'{Invoke-StorageModule;Show-Summary}
            '9'{Invoke-BatteryModule;Show-Summary}
            '10'{Invoke-MotherboardModule;Show-Summary}
            '11'{Invoke-PortsModule;Show-Summary}
            '12'{Invoke-NetworkModule;Show-Summary}
            '13'{Invoke-DriversModule;Show-Summary}
            '14'{Invoke-WindowsModule;Show-Summary}
            '15'{Invoke-ThermalModule;Show-Summary}
            '16'{Invoke-SecurityModule;Show-Summary}
            '17'{Invoke-PerformanceModule;Show-Summary}
            '18'{Invoke-DisplayModule;Show-Summary}
            '19'{Invoke-InputModule;Show-Summary}
            '20'{Invoke-AudioModule;Show-Summary}
            '21'{Invoke-CameraModule;Show-Summary}
            '22'{Invoke-Complete;Show-Summary}
            'Q'{break}
            default{Write-Status 'ERROR' 'Unknown command.' Red}
        }
    } while($true)
}
