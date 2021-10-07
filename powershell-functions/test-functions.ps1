. .\Get-ParentResourceId.ps1

$ResourceIDPass = "/subscriptions/affa3e80-5743-41c0-9f42-178059561abc/resourceGroups/rgp-use-infrabot-dev/providers/Microsoft.KeyVault/vaults/kvl-use-infrabot-dev"
$ResourceIDFail = "/subscriptions/affa3e80-5743-41c0-9f42-178059561abc/resourceGroups/rgp-use-infrabot-dev/providers/Microsoft.Storage/storageAccounts/stouseinfrabotdev/blobServices/default/containers/delete"
$result = Get-ParentResourceId -ResourceID $ResourceIDFail
Write-Host $result