Start-Transcript -Append "$PSScriptRoot/../logs/log.txt"

$currentPrincipal = New-Object Security.Principal.WindowsPrincipal([Security.Principal.WindowsIdentity]::GetCurrent())
if(-not $currentPrincipal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)){
    Write-Output "Script not being run with Admin Privileges. Stopping."
    exit
}
if(($PSVersionTable.PSVersion | Select-object -expandproperty Major) -lt 3){ # check Powershell version > 3+
    Write-Output "The Powershell version does not support PSScriptRoot. Stopping." 
    exit
}

$StartTime = Get-Date
Write-Output "Running Win Script on $StartTime`n"

$productType = (Get-CimInstance -ClassName Win32_OperatingSystem).ProductType

& $PSScriptRoot/recon.ps1

$installTools = Read-Host "Install tools? May take a while: [y/n] (Default: n)"
if(($installTools -eq "y") -or ($installTools -eq "Y")){
    & $PSScriptRoot/install-tools.ps1
}

& $PSScriptRoot/enable-firewall.ps1
& $PSScriptRoot/enable-defender.ps1

& $PSScriptRoot/import-gpo.ps1
& $PSScriptRoot/import-secpol.ps1
& $PSScriptRoot/auditpol.ps1
& $PSScriptRoot/uac.ps1
<#
add check for if gpo break -> prob try/catch?
if gpo AND secpol breaks, run uac.ps1, auditpol.ps1
#>

$SecurePassword = ConvertTo-SecureString -String 'CyberPatriot123!@#' -AsPlainText -Force

if(!((Get-Content -LiteralPath "$PSScriptRoot/../users.txt" -Raw) -match '\S') -and !((Get-Content -LiteralPath "$PSScriptRoot/../admins.txt" -Raw) -match '\S')){
    & $PSScriptRoot/local-users.ps1 -Password $SecurePassword
    if(($productType -eq "2") -or ($ad -eq "Y")){
        & $PSScriptRoot/ad-users.ps1 -Password $SecurePassword
    }
} else {
    Write-Output "users.txt and admins.txt have not been filled in. Stopping." -ForegroundColor Red
}
& $PSScriptRoot/services.ps1
& $PSScriptRoot/registry-hardening.ps1

& $PSScriptRoot/remove-nondefaultshares.ps1 
cmd /c (bcdedit /set {current} nx AlwaysOn)

$firefox = Read-Host "Is Firefox on this system? [y/n] (Default: n)"
if(($firefox -eq "Y") -or ($firefox -eq "y")){
    Write-Output "Configuring Firefox"
    & $PSScriptRoot/configure-firefox.ps1
}
$chrome = Read-Host "Is Chrome on this system? [y/n] (Default: n)"
if(($chrome -eq "Y") -or ($chrome -eq "y")){
    reg add "HKLM\SOFTWARE\Policies\Google\Chrome" /v SyncDisabled /t REG_DWORD /d 1 # disable chrome sync
}

# view hidden files
reg add HKCU\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced /v Hidden /t REG_DWORD /d 1 /f
reg add HKCU\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced /v ShowSuperHidden /t REG_DWORD /d 1 /f
taskkill /f /im explorer.exe
Start-Sleep 2
Start-Process explorer.exe

# & $PSScriptRoot/service-enum.ps1 -productType $productType

$EndTime = Get-Date
$ts = New-TimeSpan -Start $StartTime -End $EndTime
Write-output "Elapsed Time (HH:MM:SS): $ts`n"
Stop-Transcript
Add-Content -Path "$PSScriptRoot/../logs/log.txt" "Script finished at $EndTime"
Invoke-Item "$PSScriptRoot/../logs/log.txt"