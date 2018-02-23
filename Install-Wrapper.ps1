<#
.SYNOPSIS
Install software with SCCM

.DESCRIPTION
This script is meant to be used with SCCM to do advanced installs that require configuration or other special 
actions that SCCM doesn’t do easily. With this script you can Install new software, uninstall old software, 
remove a shortcut and run various software configurations. The script will log all aspects to 
C:\windows\CCM\Logs\ConfigMgrOps.log. 

To use the script enter the corresponding information for the variables under Software Information and at the 
bottom of the script uncomment the actions you need to perform The Install-Software function currently only works with msi files.

.NOTES
Created By: Kris Gross
Contact: Krisgross@sccmtst.com
Twitter: @kmgamd
Version 1.0.0.0

.LINK
You can get updates to this script and others from here
http://www.sccmtst.com/
#>

# Software Information
$SoftwareTitle = "Google Chrome"
$SoftwareVersion = "57.0.2987.98"
$SoftwareInstallFile = "googlechromestandaloneenterprise64.msi"
$SoftwareSetupSyntax = "/qn"
# This is used to uninstall old software to get this information run
# Get-WmiObject Win32_Product | Sort-Object -Property Name | Format-Table IdentifyingNumber, Name
$UninstallAPPID = "{AFD7A60B-D384-335B-AFD8-48F4ED8072C2}"

# DO NOT CHANGE #
$Computername = $env:computername
$CCMPath = "$ENV:windir\CCM"
$MiniNTPath = "$env:SystemDrive\MININT\SMSOSD"
$PublicDesktop = "$env:PUBLIC\Desktop"
$ScriptName = $MyInvocation.MyCommand.Name
$LogFile = "$CCMPath\Logs\ConfigMgrOps.log"
$OSType = Get-WmiObject -Class Win32_OperatingSystem | Select-Object -ExpandProperty OSArchitecture
If ($OSType -eq "64-bit") {$WinSysFolder = "SysWow64"} Else {$WinSysFolder = "System32"}
$Returncode = 0
#####################################

function New-LogFile() 
{
    $LogFilePaths =  "$LogFile", "$MiniNTPath\Logs\ConfigMgrOps.log","$env:TEMP\ConfigMgrOps.log"
    Foreach ($LogFilePath in $LogFilePaths) 
    {
        $script:NewLogError = $null
        $script:ConfigMgrLogFile = $LogFilePath
        Add-LogEntry "********************************************************************************************************************" "1"
        Add-LogEntry "Log file successfully intialized for $ScriptName." 1
        If (-Not($script:NewLogError)) { break }
    }
    If ($script:NewLogError) 
    {
        $script:Returncode = 1
        Exit $script:Returncode
    }
}
function Add-LogEntry ($LogMessage, $Messagetype) 
{
    # Date and time is set to the CMTrace standard
    # The Number after the log message in each function corisponts to the message type
    # 1 is info
    # 2 is a warning
    # 3 is a error
    Add-Content $script:ConfigMgrLogFile "<![LOG[$LogMessage]LOG]!><time=`"$((Get-Date -format HH:mm:ss)+".000+300")`" date=`"$(Get-Date -format MM-dd-yyyy)`" component=`"$ScriptName`" context=`"`" type=`"$Messagetype`" thread=`"`" file=`"powershell.exe`">"  -Errorvariable script:NewLogError
}

function Exit-Script() 
{
    Remove-Item env:SEE_MASK_NOZONECHECKS
    Add-LogEntry "Closing the log file for $ScriptName." "1"
    Add-LogEntry "********************************************************************************************************************" "1"
    Exit $script:Returncode    
}

function Uninstall-OldVersions() 
{
    #Some software where will not install with out a reboot after uninstalling the old software
    Add-LogEntry "Uninstalling old versions of the software." "1"
    IF (!(Get-WmiObject win32_Product | Where-Object IdentifyingNumber -EQ $UninstallAPPID)) 
    {
        Add-LogEntry "WARNING: old software not found on computer" "2"
    }
    else 
    {
        Start-Process $env:windir\$WinSysFolder\msiexec.exe "/x $UninstallAPPID /qn /norestart" -PassThru | Wait-Process -Timeout 600
    }
    IF (Get-WmiObject win32_Product | Where-Object IdentifyingNumber -EQ $UninstallAPPID) 
    {
        Add-LogEntry "ERROR: old software not uninstalled" "3"
    }
}

function Install-Software() 
{
    $env:SEE_MASK_NOZONECHECKS = 1
    If ($SoftwareInstallFile.EndsWith(".msi")) 
    {
        $SoftwareFilePath = "$env:windir\$winsysfolder\msiexec.exe"
        $SoftwareSetupSyntax = "/i " + """" + $PSScriptroot + "\" + $SoftwareInstallFile + """ " + $SoftwareSetupSyntax
    }
    Else 
    {
        $SoftwareFilePath = "$PSScriptroot\$SoftwareInstallFile"
    }
    Add-LogEntry "Attempting to install software $SoftwareTitle, $SoftwareVersion" "1"

    If (Test-Path $SoftwareFilePath) 
    {
        Add-LogEntry "Disabling open file security warning" "1"
        # Only functional on PS 3+; can also modify the zone identifier or set SEE_MASK_NOZONECHECKS
        Unblock-File -Path $SoftwareFilePath | Out-Null
        Start-Process "$env:windir\system32\cmd.exe" "/c echo.>""$SoftwareFilePath"":Zone.Identifier"
        Add-LogEntry "Running command line: `"$SoftwareFilePath`" $SoftwareSetupSyntax" "1"
        $Result = Start-Process $SoftwareFilePath $SoftwareSetupSyntax -PassThru ; $Result | Wait-Process -Timeout 900
        # $i = 0 ; Do { Start-Sleep 2 ; $i++ } Until ((Get-Process vstor_redist | Stop-Process -Force -PassThru) -or $i -gt 60)
        $script:Returncode = ($Result).ExitCode
        Add-LogEntry "Finished running command line." "1"
        Verify-Install 
	}
    Else 
    { 
        $script:Returncode = "1"
        Add-LogEntry "ERROR: File path $SoftwareFilePath doesn't appear to exist." "3"
        Verify-Install 
	}
}

function Verify-Install() 
{
    If ($script:Returncode -eq "0") 
    {
        Add-LogEntry "$SoftwareTitle, $SoftwareVersion appears to have installed successfully." "1" 
    }
    If ($script:Returncode -eq "3010") 
    {
        Add-LogEntry "WARNING: $SoftwareTitle, $SoftwareVersion appears to have installed successfully but a reboot is required." "2" 
    }
    IF (($script:Returncode -NE "0") -or ($script:Returncode -eq "3010"))
    {
        Add-LogEntry "ERROR: Return code $script:Returncode" "3"
        Add-LogEntry "ERROR: There was a problem while installing $SoftwareTitle, $SoftwareVersion " "3"
        Exit-Script
        Exit $script:Returncode 
    }
}

function Remove-Shortcuts() 
{
    Add-LogEntry "Attempting to remove shortcuts from public desktop." "1"
    $ShortcutFile = "$PublicDesktop\$SoftwareTitle.lnk"
    Add-LogEntry "Searching for $ShortcutFile" "1"
    If (Test-Path $ShortcutFile) 
    {
        Add-LogEntry "File exists, removing." "1"
        Remove-Item $ShortcutFile
        Start-Sleep -Seconds 3
        If (Test-Path $ShortcutFile) {Add-LogEntry "ERROR: Shortcut not removed" "3"}
    }
    else 
    {
        Add-LogEntry "WARNING: Shortcut not found on computer" "2"
    }
}

 # Use this function to do misc configuration, such as copying config. files
function Install-SoftwareConfiguration()
{
    Add-LogEntry "Starting post install configs." "1"
}
     
# Update ConfigMgr Hardware Inventory
function Get-HardwareInventory() 
{
    $SMSClient = [wmiclass] "\\$env:COMPUTERNAME\root\ccm:SMS_Client"
    $SMSClient.TriggerSchedule("{00000000-0000-0000-0000-000000000001}")
    Add-LogEntry "Running Hardware Inventory." "1"
}

#Actions: Uncomment the actions you want to run
New-LogFile
Uninstall-OldVersions
#Remove-Shortcuts
Install-Software
#Install-SoftwareConfiguration
Get-HardwareInventory
Exit-Script