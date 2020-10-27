<#
.SYNOPSIS

Updates the SQL Always On Listener to use the IP Address of a cloud service IP.
Required when the cloud service VIP is changed by shutting down all SQL Instances. 

.DESCRIPTION

Updates the SQL Always On Listener to use the IP Address of a cloud service IP.
Required when the cloud service VIP is changed by shutting down all SQL Instances. 

.PARAMETER SubscriptionName

The name of the subscription stored in WA PowerShell to use. Use quotes around subscription names with spaces.

.PARAMETER ServiceName

The name of the cloud service that hosts the SQL Server Always On Availability Group Nodes

.PARAMETER ServiceName

The name of the cloud service to retrieve the IP address. 

.EXAMPLE

 powershell .\update-sql-vips.ps1 -SubscriptionName "my subscription" -ServiceName "mycloudservice" -AvailabilityGroupName SQLAG -Nodes SQLAO-01, SQLAO-02, SQLAO-03
#>


param 
(
    # Subscription Name 
    [Parameter(Mandatory = $true)]
    [String]$SubscriptionName,

    # Cloud Service Name to Delete 
    [Parameter(Mandatory = $true)]
    [String]$ServiceName,

    # Name of the Availability Group  
    [Parameter(Mandatory = $true)]
    [String]$AvailabilityGroupName,

    # SQL Nodes to restart SQL on to update (specify all nodes)
    [Parameter(Mandatory = $true)]
    $Nodes
)


Select-AzureSubscription $SubscriptionName

$serviceIP = (Resolve-DnsName  "$ServiceName.cloudapp.net").IPAddress

Write-Host "Updating SQL Always On to use Service IP: $serviceIP" -ForegroundColor Green

$uri = Get-AzureWinRMUri -ServiceName $ServiceName -Name $nodes[0] # primary 

$domainCreds = Get-Credential -Message "Enter Domain / SQL Admin Credentials to Update" # Prompt for credentials

Invoke-Command -ConnectionUri $uri -Credential $domainCreds -Authentication Credssp -ArgumentList $serviceIP, $AvailabilityGroupName, $nodes -ScriptBlock {
    param($serviceIP, $AvailabilityGroupName, $nodes)

    $probePort = "59999"
    $elevatedScriptPath = Join-Path $env:TEMP "UpdateSQLVIP.ps1"

$elevatedScript = @"
Get-ClusterResource | Where { `$_.OwnerGroup -eq "$AvailabilityGroupName" -and `$_.ResourceType -eq "IP Address" } | Set-ClusterParameter -Multiple @{"Address"="$serviceIP";"ProbePort"="$probePort";SubnetMask="255.255.255.255";"Network"=(Get-ClusterNetwork)[0].Name;"OverrideAddressMatch"=1;"EnableDhcp"=0} -ErrorAction Continue
"@

    Write-Host "Creating Updated Script: $elevatedScript"
     
    $elevatedScript | Out-File $elevatedScriptPath

    $cmd = "powershell -f '$elevatedScriptPath'" 
    $taskName = "UpdateSQLVIP"

    Write-Host "Creating and Running Scheduled task for Script" $elevatedScriptPath
    & schtasks /CREATE /TN $taskName  /RU "NT AUTHORITY\SYSTEM" /SD 01/01/2020 /ST 00:00:00  /SC Once /RL HIGHEST /TR $cmd /F  
    & schtasks /RUN /I /TN $taskName 

    do{
        sleep 60
        $output = Get-ScheduledTask -TaskName $taskName
        Write-Host "  Current Task State: " $output.State
    } While ($output.State -eq "Running")

    Write-Host
    Write-Host "Deleting Scheduled Task"
    & schtasks /Delete /F /TN $TaskName

    foreach($node in $nodes)
    {
        Write-Host "Restarting MSSQLSERVER on $node" -ForegroundColor Green
        Invoke-Command -ComputerName $node -ScriptBlock {
            Restart-Service -Name "MSSQLSERVER" -Force
        }
    }
}