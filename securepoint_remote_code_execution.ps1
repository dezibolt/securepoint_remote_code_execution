###########################################################################
## Powershell script for automated remote code execution on securepoints ##
##                                  V2.1                                 ##
##                                                                       ##
## Updated 19.08.2022                                                    ##
## System expects csv-input from EXT-COM Dashboard export                ##
## Example csv can be found in the github repository:                    ##
## https://github.com/dezibolt/securepoint_remote_code_execution         ##
##                                                                       ##
## This script needs PoshSSH Module installed in Powershell              ##
###########################################################################

$path = Read-Host "Input path to your csv-file"
$delim = Read-Host "Input used Delimiter for csv-file"
$varcommand = Read-Host "Input command you would like to execute"
$saveconfig = Read-Host "Do you want to save the config after execution? (YES/NO)"


$id = 1
$csv = ipcsv $path -Delimiter $delim

#generate UIDs for the columns
$uidcsv = $csv | Group-Object -Property ip | ForEach-Object {
    $ipId = $id++
    foreach ($item in $_.Group) {
        [PsCustomObject]@{
            uid = $ipId
            ip = $item.ip
            username = $item.username
            password = $item.password
        }
    }
}

#count UIDs for the loop
$count = $uidcsv.Count

#troubleshoot keynegotiation failed
Get-SSHTrustedHost | Remove-SSHTrustedHost

#loop through every firewall and execute specified command
for ($i=0; $i -lt $count; $i++) {

set-variable -name "varwebfw" -value $uidcsv.ip[$i]
set-variable -name "varusername" -value $uidcsv.username[$i]
set-variable -name "varpassword" -value $uidcsv.password[$i]

$varpasswordsec =  convertto-securestring -asplaintext -force $varpassword
$LoginCreds = New-Object System.Management.Automation.PSCredential($varusername,$varpasswordsec)

echo +++++
echo "Trying to connect to $varwebfw"
echo +++++

New-SSHSession -ComputerName $varwebfw -Credential $LoginCreds -AcceptKey

invoke-sshcommand -sessionID 0 -command $varcommand | foreach output

if ($saveconfig -like "yes"){
echo ""
echo ""
echo "config will be saved now"
invoke-sshcommand -sessionID 0 -command "system config save" | foreach output
}

get-sshsession | remove-sshsession

}
