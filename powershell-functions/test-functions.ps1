. .\Get-ParentResourceId.ps1

# Update the resource id and run to test the current state of the funciton.
$ResourceId = "/subscriptions/affa3e80-5743-41c0-9f42-178059561abc/resourceGroups/rgp-use-infrabot-dev/providers/Microsoft.KeyVault/vaults/kvl-use-infrabot-dev"
$result = Get-ParentResourceId -ResourceID $ResourceId
Write-Host $result