<#
.SYNOPSIS
Install software with SCCM

.DESCRIPTION
This Scrip it meant to be used with my Install-Wrapper Script. You can get that script from 
http://www.sccmtst.com/2017/11/advanced-software-install-wrapper-script.html

This script will allow you to install multiple peaces of software. To use the script first create 
a script for each of your software installs using the Install-Wrapper script. Then add each script 
name to the Installs variable in the order they need to be installed in. Then if you need the script 
to stop if an install fails change the ExitOnfail variable to $True.

.NOTES
Created By: Kris Gross
Contact: Krisgross@sccmtst.com
Twitter: @kmgamd
Version 1.0.0.1

.LINK
You can get updates to this script and others from here
http://www.sccmtst.com/
#>

#Variables to set
#Do not use spaces in the filenames
$Installs = "Install-1.ps1","Install-2.ps1","Install-3.ps1"
#Change this to $True if you want the script to stop if one of the $Installs fails
$ExitOnFail = $False

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
    Add-LogEntry "******************************************************************************************************************************************************" "1"
    Exit $script:Returncode    
}

function Get-HardwareInventory() 
{
    $SMSClient = [wmiclass] "\\$env:COMPUTERNAME\root\ccm:SMS_Client"
    $SMSClient.TriggerSchedule("{00000000-0000-0000-0000-000000000001}")
    Add-LogEntry "Running Hardware Inventory." "1"
}

function Install-Software
{
    forEach ($Install in $Installs)
    {
        Add-LogEntry "Starting Install $Install" "1"
        Invoke-Expression .\"$Install"
        IF ($LASTEXITCODE -NE 0)
        {
            Add-LogEntry "ERROR: $Install Failed" "3"
            IF ($ExitOnFail)
            {
                $script:Returncode = 1
                Exit-Script
            }
        }
    }
}
    
New-LogFile
Install-Software
Get-HardwareInventory