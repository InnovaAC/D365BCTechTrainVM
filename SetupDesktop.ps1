﻿if (!(Test-Path function:Log)) {
    function Log([string]$line, [string]$color = "Gray") {
        ("<font color=""$color"">" + [DateTime]::Now.ToString([System.Globalization.DateTimeFormatInfo]::CurrentInfo.ShortTimePattern.replace(":mm",":mm:ss")) + " $line</font>") | Add-Content -Path "c:\demo\status.txt"
        Write-Host -ForegroundColor $color $line 
    }
}

Import-Module -name bccontainerhelper -DisableNameChecking

. (Join-Path $PSScriptRoot "settings.ps1")

Log -color Green "Setting up Desktop Experience"

$codeCmd = "C:\Program Files\Microsoft VS Code\bin\Code.cmd"
$codeExe = "C:\Program Files\Microsoft VS Code\Code.exe"
#$codeCmd = "C:\Users\student\AppData\Local\Programs\Microsoft VS Code\bin\Code.cmd"
#$codeExe = "C:\Users\student\AppData\Local\Programs\Microsoft VS Code\Code.exe"

$firsttime = (!(Test-Path $codeExe))
$disableVsCodeUpdate = $false

if ($firsttime) {
    $Folder = "C:\DOWNLOAD\VSCode"
    $Filename = "$Folder\VSCodeSetup-stable.exe"

    New-Item $Folder -itemtype directory -ErrorAction ignore | Out-Null
    if (!(Test-Path $Filename)) {
#        $sourceUrl = "https://go.microsoft.com/fwlink/?Linkid=852157"
        $sourceUrl = "https://www.dropbox.com/s/w0ecxm4gqslrbp5/vscode.exe?dl=1"

        Download-File -SourceUrl $sourceUrl -destinationFile $Filename
    }
    
    Log "Installing Visual Studio Code (this might take a few minutes)"
    $setupParameters = “/VerySilent /CloseApplications /NoCancel /LoadInf=""c:\demo\vscode.inf"" /MERGETASKS=!runcode"
    Start-Process -FilePath $Filename -WorkingDirectory $Folder -ArgumentList $setupParameters -Wait -Passthru | Out-Null

#    Log "Downloading samples"
#    $Folder = "C:\DOWNLOAD"
#    $Filename = "$Folder\samples.zip"
#    Download-File -sourceUrl "https://www.github.com/Microsoft/AL/archive/master.zip" -destinationFile $filename

#    Remove-Item -Path "$folder\AL-master" -Force -Recurse -ErrorAction Ignore | Out-null
#    [Reflection.Assembly]::LoadWithPartialName("System.IO.Compression.Filesystem") | Out-Null
#    [System.IO.Compression.ZipFile]::ExtractToDirectory($filename, $folder)
    
#    $alFolder = "$([Environment]::GetFolderPath("MyDocuments"))\AL"
#    Remove-Item -Path "$alFolder\Samples" -Recurse -Force -ErrorAction Ignore | Out-Null
#    New-Item -Path "$alFolder\Samples" -ItemType Directory -Force -ErrorAction Ignore | Out-Null
#    Copy-Item -Path "$folder\AL-master\samples\*" -Destination "$alFolder\samples" -Recurse -ErrorAction Ignore
#    Copy-Item -Path "$folder\AL-master\snippets\*" -Destination "$alFolder\snippets" -Recurse -ErrorAction Ignore
}

if (Test-Path "C:\Demo\Extensions\$containerName\*.vsix") {
    $vsixFileName = (Get-Item "C:\Demo\Extensions\$containerName\*.vsix").FullName
    if ($vsixFileName -ne "") {
    
        Log "Installing .vsix"
        & $codeCmd @('--install-extension', $VsixFileName) | Out-Null
    
        $username = [Environment]::UserName
        if (Test-Path -path "c:\Users\Default\.vscode" -PathType Container -ErrorAction Ignore) {
            if (!(Test-Path -path "c:\Users\$username\.vscode" -PathType Container -ErrorAction Ignore)) {
                Copy-Item -Path "c:\Users\Default\.vscode" -Destination "c:\Users\$username\" -Recurse -Force -ErrorAction Ignore
            }
        }
    }
}

if ($disableVsCodeUpdate) {
    $vsCodeSettingsFile = Join-Path ([Environment]::GetFolderPath("ApplicationData")) "Code\User\settings.json"
    '{
        "update.channel": "none"
    }' | Set-Content $vsCodeSettingsFile
}

Log "Creating Desktop Shortcuts"
New-DesktopShortcut -Name "Landing Page" -TargetPath "http://${publicDnsName}" -IconLocation "C:\Program Files\Internet Explorer\iexplore.exe, 3"
New-DesktopShortcut -Name "Visual Studio Code" -TargetPath $codeExe
New-DesktopShortcut -Name "PowerShell ISE" -TargetPath "C:\Windows\system32\WindowsPowerShell\v1.0\powershell_ise.exe" -WorkingDirectory "c:\demo"
New-DesktopShortcut -Name "Command Prompt" -TargetPath "C:\Windows\system32\cmd.exe" -WorkingDirectory "c:\demo"
New-DesktopShortcut -Name "BC Container Helper" -TargetPath "powershell.exe" -Arguments "-noexit ""& { Write-BcContainerHelperWelcomeText }""" -WorkingDirectory "C:\demo"
New-DesktopShortcut -Name "Workshop Files" -TargetPath "C:\WorkshopFiles\" #1CF

Log -color Green "Desktop setup complete!"
