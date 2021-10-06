# . .\Get-ParentResourceId.ps1

# $ErrorActionPreference = "Continue"

$ErrorActionPreference = "SilentlyContinue"

function Add-Tag {
    param(
        $ResourceID,
        $TagKey,
        $TagValue
    )
    try {
        $Resource.ForEach{
            if (!($_.Tags.ContainsKey($TagKey))) {
                $_.Tags.Add($TagKey, $TagValue)
            }
            $_ | Set-AzResource -Tags $_.Tags -Force
        }
    } catch {
        Throw $_.Exception
    }
}

function Remove-Tag {
    param(
        $ResourceID,
        $TagKey
    )
    try {
        $Resource = Get-AzResource -ResourceId $ResourceID -ErrorAction Stop
        $Resource.ForEach{
            if ($_.Tags.ContainsKey($TagKey)) {
                $_.Tags.Remove($TagKey)
            }
            $_ | Set-AzResource -Tags $_.Tags -Force
        }
    } catch {
        Throw $_.Exception
    }
}

function Get-ParentResourceId {
    param(
        $ResourceID
    )

    $ResourceIDList = $ResourceID -Split '/'
    $IgnoreList = @('subscriptions', 'resourceGroups', 'providers')

    for ($ia=$ResourceIDList.length-1; $ia -ge 0; $ia--) {
        $CurrentResourceIDList = $ResourceIDList[0..($ia)]
        $CurrentResourceID = $CurrentResourceIDList -Join '/'
        $CurrentHead = $CurrentResourceIDList[-1]
        if (!($IgnoreList -Contains $CurrentHead)) {
            Write-Host "Validating ability to tag $($CurrentResourceID)" 
            $Error.clear()
            try {
                try {
                    Write-Host "Running tagging test..."
                    Add-Tag -ResourceID $CurrentResourceID -TagKey "Test" -TagValue "Test" -ErrorAction SilentlyContinue
                    Remove-Tag -ResourceID $CurrentResourceID -TagKey "Test" -ErrorAction SilentlyContinue
                } catch {
                    Write-Host "Test failed." -ForegroundColor Red
                }
            } catch {
                Throw $_.Exception
                Write-Host "$($CurrentResourceID) cannot be tagged.  Searching for parent."
            }
            if (!$Error) {
                Write-Host "Test passed." -ForegroundColor Green
                Break
            }
        } else {
            Write-Host "Skipping resource $($CurrentResourceID)."
        }
    }

    Return $CurrentResourceID
}

$ResourceIDPass = "/subscriptions/affa3e80-5743-41c0-9f42-178059561abc/resourceGroups/rgp-use-infrabot-dev/providers/Microsoft.KeyVault/vaults/kvl-use-infrabot-dev"
$ResourceIDFail = "/subscriptions/affa3e80-5743-41c0-9f42-178059561abc/resourceGroups/rgp-use-infrabot-dev/providers/Microsoft.Storage/storageAccounts/stouseinfrabotdev/blobServices/default/containers/delete"
Get-ParentResourceId -ResourceID $ResourceIDFail