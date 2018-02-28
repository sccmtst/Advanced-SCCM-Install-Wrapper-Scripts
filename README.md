# Advanced-SCCM-Install-Wrapper-Scripts
These scripts provide additional funtion to SCCM Application deployments. If you need to do more then just install software 
like remove a old shortcuts or uninstall another product you can do all of that with this set of scripts.
The Install-Wrapper script is the primary script, add the information needed for your software in this script 
then if you need install other software as part of this deployment build another Install-Wrapper script and add both Isntall-Wrapper script
to the Multi-Install-Wrapper script. The Multi-Install-Wrapper script will run each Install-Wrapper script and provide detailed info of 
the install proccess. Then to supliment the Install proccess I have Uninstall-Wrapper script that you can use as the uninstall commands for the SCCM 
Application deployment. 

For more inforamtion visit http://sccmtst.com
