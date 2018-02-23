<#
.SYNOPSIS
Uninstall Software

.DESCRIPTION
This Scrip it meant to be used with my Install-Wrapper Script. You can get that script from 
http://www.sccmtst.com/2017/11/advanced-software-install-wrapper-script.html

This script will is used when you need to uninstall multipule items with a single deployment and
is meant to be used for the uninstall command when using the Multi-Install-Wrapper.ps1
Enter the applciation ID in the $UninstallAPPID variabel, you can use 1 or multipule IDs 

.NOTES
Created By: Kris Gross
Contact: Krisgross@sccmtst.com
Twitter: @kmgamd
Version 1.0.0.0

.LINK
You can get updates to this script and others from here
http://www.sccmtst.com/
#>

# Applications you want to uninstall
#You can run the below line to get this info
# Get-WmiObject Win32_Product | Sort-Object -Property Name | Format-Table IdentifyingNumber, Name
$UninstallAPPID = "{1D7D1271-5258-4F5A-B8C1-7176BF398782}","{56DDDFB8-7F79-4480-89D5-25E1F52AB28F}","{19589375-5C58-4AFA-842F-8B34744CCEAD}","{B2A2E8AF-BC48-4191-B2C4-3846A19835CA}","{D4C80B0C-CF67-43A7-90C3-466853543B54}","{AA7D90D2-2387-4FA5-A3AF-96811BE49BFD}"

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
    foreach ($APPID in $UninstallAPPID)
    {
        #Some software where will not install with out a reboot after uninstalling the old software
        Add-LogEntry "Uninstalling $APPID." "1"
        IF (!(Get-WmiObject win32_Product | Where-Object IdentifyingNumber -EQ $APPID)) 
        {
            Add-LogEntry "WARNING: $APPID not found on computer" "2"
        }
        else 
        {
            Start-Process $env:windir\$WinSysFolder\msiexec.exe "/x $APPID /qn /norestart" -PassThru | Wait-Process -Timeout 600
        }
        IF (Get-WmiObject win32_Product | Where-Object IdentifyingNumber -EQ $APPID) 
        {
            Add-LogEntry "ERROR: $APPID not uninstalled" "3"
        }
    }
}

New-LogFile
Uninstall-OldVersions
Exit-Script