﻿if (Get-ScheduledTask -TaskName SetupVm -ErrorAction Ignore) {
    Remove-item -Path (Join-Path $PSScriptRoot "setupStart.ps1") -Force -ErrorAction Ignore
    schtasks /DELETE /TN SetupVm /F | Out-Null
}

function Log([string]$line, [string]$color = "Gray") {
    ("<font color=""$color"">" + [DateTime]::Now.ToString([System.Globalization.DateTimeFormatInfo]::CurrentInfo.ShortTimePattern.replace(":mm",":mm:ss")) + " $line</font>") | Add-Content -Path "c:\demo\status.txt" 
}

Import-Module -name bccontainerhelper -DisableNameChecking

. (Join-Path $PSScriptRoot "settings.ps1")

Log "Enabling File Download in IE"
Set-ItemProperty -Path "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Internet Settings\Zones\3" -Name "1803" -Value 0
Set-ItemProperty -Path "HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\Internet Settings\Zones\3" -Name "1803" -Value 0

Log "Enabling Font Download in IE"
Set-ItemProperty -Path "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Internet Settings\Zones\3" -Name "1604" -Value 0
Set-ItemProperty -Path "HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\Internet Settings\Zones\3" -Name "1604" -Value 0

Log "Disabling Server Manager Open At Logon"
New-ItemProperty -Path "HKCU:\Software\Microsoft\ServerManager" -Name "DoNotOpenServerManagerAtLogon" -PropertyType "DWORD" -Value "0x1" –Force | Out-Null

#Disable default security settings in IE
New-Item "HKLM:\SOFTWARE\Policies\Microsoft\Internet Explorer"
new-ItemProperty -Path "HKLM:\SOFTWARE\Policies\Microsoft\Internet Explorer\" -Name "DisableFirstRunCustomize" -Value '00000001' -PropertyType DWORD

New-Item "HKCU:\SOFTWARE\Policies\Microsoft\Internet Explorer"
New-Item "HKCU:\SOFTWARE\Policies\Microsoft\Internet Explorer\Main"

new-ItemProperty -Path "HKCU:\SOFTWARE\Policies\Microsoft\Internet Explorer\Main" -Name "DisableFirstRunCustomize" -Value '00000001' -PropertyType DWORD

Log "Add Import bccontainerhelper to PowerShell profile"
$winPsFolder = Join-Path ([Environment]::GetFolderPath("MyDocuments")) "WindowsPowerShell"
New-Item $winPsFolder -ItemType Directory -Force -ErrorAction Ignore | Out-Null
"Import-Module bccontainerhelper -DisableNameChecking" | Set-Content (Join-Path $winPsFolder "Profile.ps1")

Log "Adding Landing Page to Startup Group"
New-DesktopShortcut -Name "Landing Page" -TargetPath "C:\Program Files\Internet Explorer\iexplore.exe" -FolderName "Startup" -Arguments "http://$publicDnsName"
if ($style -eq "devpreview") {
    New-DesktopShortcut -Name "Modern Dev Tools" -TargetPath "C:\Program Files\Internet Explorer\iexplore.exe" -FolderName "Startup" -Arguments "http://aka.ms/moderndevtools"
}

<#
$navDockerImage.Split(',') | ForEach-Object {
    $registry = $_.Split('/')[0]
    if (($registry -ne "microsoft") -and ($registryUsername -ne "") -and ($registryPassword -ne "")) {
        Log "Logging in to $registry"
        docker login "$registry" -u "$registryUsername" -p "$registryPassword"
    }
    Log "Pulling $_ (this might take ~30 minutes)"
    docker pull "$_"
}
#>

Log "Installing Visual C++ Redist"
#Prerequisites url change
#$vcRedistUrl = "https://download.microsoft.com/download/2/E/6/2E61CFA4-993B-4DD4-91DA-3737CD5CD6E3/vcredist_x86.exe"
$vcRedistUrl = "https://www.dropbox.com/s/49136h0xydxfj9b/vcredist_x86.exe?dl=1"
$vcRedistFile = "C:\DOWNLOAD\vcredist_x86.exe"
Download-File -sourceUrl $vcRedistUrl -destinationFile $vcRedistFile
Start-Process $vcRedistFile -argumentList "/q" -wait

Log "Installing SQL Native Client"
#Prerequisites url change
#$sqlncliUrl = "https://download.microsoft.com/download/3/A/6/3A632674-A016-4E31-A675-94BE390EA739/ENU/x64/sqlncli.msi"
$sqlncliUrl = "https://www.dropbox.com/s/u0uhsjpdg4lebqx/sqlncli.msi?dl=1"
$sqlncliFile = "C:\DOWNLOAD\sqlncli.msi"
Download-File -sourceUrl $sqlncliUrl -destinationFile $sqlncliFile
Start-Process "C:\Windows\System32\msiexec.exe" -argumentList "/i $sqlncliFile ADDLOCAL=ALL IACCEPTSQLNCLILICENSETERMS=YES /qn" -wait

Log "Installing OpenXML 2.5"
#Prerequisites url change
#$openXmlUrl = "https://download.microsoft.com/download/5/5/3/553C731E-9333-40FB-ADE3-E02DC9643B31/OpenXMLSDKV25.msi"
$openXmlUrl = "https://www.dropbox.com/s/px4b99szlvts8nj/OpenXMLSDKV25.msi?dl=1"
$openXmlFile = "C:\DOWNLOAD\OpenXMLSDKV25.msi"
Download-File -sourceUrl $openXmlUrl -destinationFile $openXmlFile
Start-Process $openXmlFile -argumentList "/qn /q /passive" -wait

. "c:\demo\SetupNavContainer.ps1"
. "c:\demo\SetupDesktop.ps1"
. "c:\demo\SetupWorkshop.ps1"

#Cleanup
#docker pull microsoft/dynamics-nav:devpreview

$downloadWorkshopFilesScript = 'c:\Demo\DownloadWorkshopFiles\DownloadWorkshopFiles.ps1'
$logonAction = New-ScheduledTaskAction -Execute "powershell.exe" -Argument $downloadWorkshopFilesScript
$logonTrigger = New-ScheduledTaskTrigger -AtLogOn
Register-ScheduledTask -TaskName "RenewWorkshopAtLogon" `
                        -Action $logonAction `
                        -Trigger $logonTrigger `
                        -RunLevel Highest `
                        -User $vmAdminUsername | Out-Null



$finalSetupScript = (Join-Path $PSScriptRoot "FinalSetupScript.ps1")
if (Test-Path $finalSetupScript) {
    Log "Running FinalSetupScript"
    . $finalSetupScript
}

if ($RunWindowsUpdate -eq "Yes") {
    Log "Installing Windows Updates"
    #TLS12 need from April'20
    [Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12
    install-module PSWindowsUpdate -force
    Get-WUInstall -install -acceptall -autoreboot | ForEach-Object { Log ($_.Status + " " + $_.KB + " " +$_.Title) }
    Log "Windows updates installed"
}
