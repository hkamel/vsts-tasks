[CmdletBinding()]
param()

. $PSScriptRoot\..\..\..\Tests\lib\Initialize-Test.ps1
. $PSScriptRoot\MockVariable.ps1

#path to Utility.ps1 for SqlAzureDacpacDeployment task
. "$PSScriptRoot\..\Utility.ps1"

# TEST 1 : If connection failed because of firewall exception using Sqlcmd.exe
Register-Mock Get-Command { throw "Get-Command : The term 'invoke-sqlcmd' is not recognized as the name of a cmdlet, function, script file, or operable program. Check the spelling of the name, or if a path was included, verify that the path is correct and try again." }

$sqlErrorMsg = "Error at Line 123456 Sqlcmd: Error: Microsoft ODBC Driver 13 for SQL Server : Cannot open server 'a0nuel7r2k' requested by the login. Client with IP address '167.220.238.x' is not allowed to access the server.  To enable access, use the Windows Azure Management P
ortal or run sp_set_firewall_rule on the master database to create a firewall rule for this IP address or address range.  It may take up to five minutes for this change to take effect..
"
$firewallException = New-Object -TypeName System.Management.Automation.RemoteException -ArgumentList $sqlErrorMsg
$errors = @()
$errors += $firewallException

$startIP = "167.220.238.0"
$endIP = "167.220.238.255"

Register-Mock Invoke-Expression { Write-Error $firewallException } -ParametersEvaluator { }
$IPAddressRange = Get-AgentIPRange -serverName $serverName -sqlUserName $sqlUsername -sqlPassword $sqlPassword

Assert-AreEqual  $startIP $IPAddressRange.StartIPAddress
Assert-AreEqual $endIP $IPAddressRange.EndIPAddress

# TEST 2 : If connection succeeded without firewall exception using Sqlcmd.exe
$errors = @()
Register-Mock Invoke-Expression {  } -ParametersEvaluator { }

$IPAddressRange = Get-AgentIPRange -serverName $serverName -sqlUserName $sqlUsername -sqlPassword $sqlPassword

Assert-AreEqual 0 $IPAddressRange.Count

# TEST 3 : If connection failed because of firewall exception using Invoke-Sqlcmd
$errors = @()
$errors += $firewallException

Unregister-Mock Get-Command
Register-Mock Get-Command { return "Command exists" }
Register-Mock Invoke-Sqlcmd { Write-Error $firewallException }

$IPAddressRange = Get-AgentIPRange -serverName $serverName -sqlUserName $sqlUsername -sqlPassword $sqlPassword

Assert-WasCalled Invoke-Sqlcmd -- -ServerInstance "a0nuel7r2k.database.windows.net" -Username "TestUser" -Password "TestPassword" -Query "select getdate()" -ErrorVariable errors
Assert-AreEqual  $startIP $IPAddressRange.StartIPAddress
Assert-AreEqual $endIP $IPAddressRange.EndIPAddress

