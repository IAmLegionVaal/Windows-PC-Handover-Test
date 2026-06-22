<#
.SYNOPSIS
Creates a Windows workstation handover quality-control report.
#>
[CmdletBinding()]
param(
    [ValidateRange(5,50)][int]$MinimumFreeSpacePercent=15,
    [string]$OutputRoot="$env:PUBLIC\Documents\WindowsPCHandoverReports"
)

Set-StrictMode -Version 2.0
$ErrorActionPreference='Stop'
$runPath=Join-Path $OutputRoot ("Handover_{0}_{1}" -f $env:COMPUTERNAME,(Get-Date -Format 'yyyyMMdd_HHmmss'))
$checks=New-Object System.Collections.Generic.List[object]

function Add-Check{
    param([string]$Area,[string]$Check,[string]$Status,[string]$Details)
    $script:checks.Add([pscustomobject]@{Area=$Area;Check=$Check;Status=$Status;Details=$Details})
}
function Try-Check{
    param([scriptblock]$Action,[string]$Area,[string]$Check)
    try{& $Action}catch{Add-Check $Area $Check 'Unknown' $_.Exception.Message}
}

try{
    if($env:OS -ne 'Windows_NT'){throw 'Windows is required.'}
    New-Item $runPath -ItemType Directory -Force|Out-Null

    Try-Check{
        $os=Get-CimInstance Win32_OperatingSystem
        Add-Check 'Windows' 'Operating system' 'Info' ("$($os.Caption) $($os.Version) build $($os.BuildNumber)")
        $uptime=(Get-Date)-$os.LastBootUpTime
        Add-Check 'Windows' 'Recent restart' $(if($uptime.TotalDays -le 14){'Pass'}else{'Warning'}) ("Uptime {0:N1} days" -f $uptime.TotalDays)
    } 'Windows' 'Operating system'

    Try-Check{
        $pending=(Test-Path 'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Component Based Servicing\RebootPending') -or (Test-Path 'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\WindowsUpdate\Auto Update\RebootRequired')
        Add-Check 'Windows' 'No pending restart' $(if($pending){'Warning'}else{'Pass'}) ([string]$pending)
    } 'Windows' 'Pending restart'

    Try-Check{
        $system=Get-CimInstance Win32_ComputerSystem
        Add-Check 'Hardware' 'Computer identity' 'Info' ("$($system.Manufacturer) $($system.Model); RAM {0:N1} GB" -f ($system.TotalPhysicalMemory/1GB))
    } 'Hardware' 'Computer identity'

    Try-Check{
        foreach($volume in Get-Volume|Where-Object DriveLetter){
            $percent=if($volume.Size -gt 0){[math]::Round(($volume.SizeRemaining/$volume.Size)*100,1)}else{0}
            Add-Check 'Storage' ("Drive $($volume.DriveLetter):") $(if($volume.HealthStatus -eq 'Healthy' -and $percent -ge $MinimumFreeSpacePercent){'Pass'}else{'Warning'}) ("Health=$($volume.HealthStatus); Free=$percent%")
        }
    } 'Storage' 'Volumes'

    Try-Check{
        $errors=@(Get-CimInstance Win32_PnPEntity|Where-Object ConfigManagerErrorCode -ne 0)
        Add-Check 'Hardware' 'Device Manager errors' $(if($errors.Count -eq 0){'Pass'}else{'Fail'}) ("Count=$($errors.Count)")
        $errors|Select-Object Name,PNPClass,Manufacturer,ConfigManagerErrorCode,DeviceID|
            Export-Csv (Join-Path $runPath 'DeviceErrors.csv') -NoTypeInformation
    } 'Hardware' 'Device Manager errors'

    Try-Check{
        if(Get-Command Get-MpComputerStatus -ErrorAction SilentlyContinue){
            $d=Get-MpComputerStatus
            Add-Check 'Protection' 'Microsoft Defender' $(if($d.AntivirusEnabled -and $d.RealTimeProtectionEnabled){'Pass'}else{'Fail'}) ("AV=$($d.AntivirusEnabled); RealTime=$($d.RealTimeProtectionEnabled); SignatureAge=$($d.AntivirusSignatureAge)")
        }
    } 'Protection' 'Microsoft Defender'

    Try-Check{
        $profiles=Get-NetFirewallProfile
        $disabled=@($profiles|Where-Object{-not $_.Enabled})
        Add-Check 'Protection' 'Firewall profiles' $(if($disabled.Count -eq 0){'Pass'}else{'Fail'}) ("Disabled=$($disabled.Count)")
    } 'Protection' 'Firewall profiles'

    Try-Check{
        $adapters=@(Get-NetAdapter|Where-Object Status -eq 'Up')
        Add-Check 'Network' 'Connected adapter' $(if($adapters.Count -gt 0){'Pass'}else{'Warning'}) ("Connected=$($adapters.Count)")
        $internet=(Test-NetConnection 'www.microsoft.com' -Port 443 -WarningAction SilentlyContinue).TcpTestSucceeded
        Add-Check 'Network' 'HTTPS connectivity' $(if($internet){'Pass'}else{'Warning'}) ([string]$internet)
    } 'Network' 'Connectivity'

    Try-Check{
        $licensed=Get-CimInstance SoftwareLicensingProduct|Where-Object{$_.ApplicationID -eq '55c92734-d682-4d71-983e-d6ec3f16059f' -and $_.PartialProductKey}|Select-Object -First 1
        Add-Check 'Windows' 'Activation' $(if($licensed.LicenseStatus -eq 1){'Pass'}else{'Warning'}) ("LicenseStatus=$($licensed.LicenseStatus)")
    } 'Windows' 'Activation'

    Try-Check{
        $hotfix=Get-HotFix|Sort-Object InstalledOn -Descending|Select-Object -First 1
        Add-Check 'Maintenance' 'Recent hotfix' $(if($hotfix -and $hotfix.InstalledOn -ge (Get-Date).AddDays(-90)){'Pass'}else{'Warning'}) $(if($hotfix){"$($hotfix.HotFixID) installed $($hotfix.InstalledOn)"}else{'No hotfix returned'})
    } 'Maintenance' 'Recent hotfix'

    $checks|Export-Csv (Join-Path $runPath 'HandoverChecks.csv') -NoTypeInformation -Encoding UTF8
    $checks|ConvertTo-Json -Depth 3|Out-File (Join-Path $runPath 'HandoverChecks.json') -Encoding UTF8
    $checks|ConvertTo-Html -Title 'Windows PC Handover Report' -PreContent "<h1>Windows PC Handover Report</h1><p>$env:COMPUTERNAME - $(Get-Date)</p>"|
        Out-File (Join-Path $runPath 'HandoverReport.html') -Encoding UTF8

    $fails=@($checks|Where-Object Status -eq 'Fail').Count
    $warns=@($checks|Where-Object Status -eq 'Warning').Count
    Write-Host "[OK] Handover report created: $runPath" -ForegroundColor Green
    if($fails -gt 0 -or $warns -gt 0){exit 2}else{exit 0}
}catch{Write-Error $_.Exception.Message;exit 1}
