az login

$AzureSubscription = "SubscriptionName"
az account set --subscription $AzureSubscription

$RGName = "ResourceGroupForDatabase"
$SrvName = "AzureSQLServer"
$DbName = "AzureSQLDatabase"
$FailOverGrp = "FailOverGroupName"

$ParterRG = "ResourceGroupForFailoverDatabase"
$PartnerSrv = "FailoverAzureSQLServer"
$PartnerDb = "FailoverAzureSQLDatabase"

$RestoreDateTime = (Get-Date).ToUniversalTime().AddMinutes(-5)
$RestoreDateTimeString = '{0:yyyy-MM-dd_HH:mm}' -f $RestoreDateTime
$RestoreName = '{0}_{1}' -f $DbName, $RestoreDateTimeString

# format the datetime as Sortable date/time pattern 'yyyy-MM-ddTHH:mm:ss'
# see: https://docs.microsoft.com/en-us/dotnet/standard/base-types/standard-date-and-time-format-strings
$azRestoreTime = '{0:s}' -f $RestoreDateTime

$BeforeRestoreName = '{0}_BEFORE_RESTORE' -f $DbName

Write-Host "Restoring $($DbName) to $($RestoreName)"
# Restore Dev Database to new name
az sql db restore --dest-name $RestoreName --resource-group $RGName --server $SrvName --name $DbName  --time $azRestoreTime

Write-Host "Removing $($DbName) From Failover Group $($FailOverGrp)"
# Remove db from Failover Group
az sql failover-group update --name $FailOverGrp --remove-db $DbName --resource-group $RGName --server $SrvName

Write-Host "Deleting Link from $($SrvName)\$($DbName) to $($PartnerSrv)\$($PartnerDb)"
# Delete link to replicated server
az sql db replica delete-link --partner-server $PartnerSrv --partner-resource-group $ParterRG --resource-group $RGName --server $SrvName --name $DbName 

Write-Host "Renaming $($DbName) to $($BeforeRestoreName)"
# Rename database being restored
az sql db rename --new-name $BeforeRestoreName --resource-group $RGName --server $SrvName --name $DbName

Write-Host "Renaming $($RestoreName) to $($DbName)"
# Rename restore to original name
az sql db rename --new-name $DbName --resource-group $RGName --server $SrvName --name $RestoreName

Write-Host "Deleting Replicated DB $($PartnerSrv)\$($PartnerDb)"
# Delete replicated database
az sql db delete --resource-group $ParterRG --server $PartnerSrv --name $PartnerDb

Write-Host "Creating Replicated DB $($PartnerSrv)\$($PartnerDb)"
# Create Replicated Database
az sql db replica create --name $PartnerDb --partner-server $PartnerSrv --partner-resource-group $ParterRG --resource-group $RGName --server $SrvName

Write-Host "Adding $($SrvName)\$($DbName) to Failover group $($FailOverGrp)"
# Adding restored database to failover group
az sql failover-group update --name $FailOverGrp --add-db $DbName --resource-group $RGName --server $SrvName