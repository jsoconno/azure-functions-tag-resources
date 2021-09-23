. .\Get-ParentResourceId.ps1

$ResourceID = "/subscriptions/affa3e80-5743-41c0-9f42-178059561abc/resourceGroups/rgp-use-infrabot-dev/providers/Microsoft.Storage/storageAccounts/stouseinfrabotdev/blobServices/default/containers/test/providers/Microsoft.Resources/tags/default"

Get-ParentResourceId -ResourceId $ResourceId