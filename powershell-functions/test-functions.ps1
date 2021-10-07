# . .\Get-ParentResourceId.ps1

# $ErrorActionPreference = "Continue"

# $ErrorActionPreference = "SilentlyContinue"

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
        $ResourceId
    )

    $ResourceIdList = $ResourceId -Split '/'
    # This should be created as a parameter
    $IgnoreList = @('subscriptions', 'resourceGroups', 'providers')
    $CleanList = @("/providers/Microsoft.Resources/tags/default", "/blobServices/default")

    for ($ia=$ResourceIdList.length-1; $ia -ge 0; $ia--) {
        $CurrentResourceIdList = $ResourceIdList[0..($ia)]
        $CurrentResourceId = $CurrentResourceIdList -Join '/'
        $CurrentHead = $CurrentResourceIdList[-1]
        if (!($IgnoreList -Contains $CurrentHead)) {
            Write-Host "Validating ability to tag $($CurrentResourceId)" 
            $Error.Clear()
            try {
                try {
                    Write-Host "Running tagging test..."
                    $Result = (Get-AzTag -ResourceId $CurrentResourceId -ErrorAction Stop).id
                } catch {
                    Write-Host "Test failed." -ForegroundColor Red
                }
            } catch {
                Throw $_.Exception
                Write-Host "$($CurrentResourceId) cannot be tagged.  Searching for parent."
            }
            if (!$Error) {
                Write-Host "Test passed." -ForegroundColor Green
                Break
            }
        } else {
            Write-Host "Skipping resource $($CurrentResourceId)."
        }
    }

    foreach ($String in $CleanList) {
        $Result = $Result.Replace($String, "")
    }

    Return $Result
}

$ResourceIDPass = "/subscriptions/affa3e80-5743-41c0-9f42-178059561abc/resourceGroups/rgp-use-infrabot-dev/providers/Microsoft.KeyVault/vaults/kvl-use-infrabot-dev"
$ResourceIDFail = "/subscriptions/affa3e80-5743-41c0-9f42-178059561abc/resourceGroups/rgp-use-infrabot-dev/providers/Microsoft.Storage/storageAccounts/stouseinfrabotdev/blobServices/default/containers/delete"
$result = Get-ParentResourceId -ResourceID $ResourceIDFail
Write-Host $result