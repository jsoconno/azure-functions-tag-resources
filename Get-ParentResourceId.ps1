function Add-Tag {
    param(
        $ResourceID,
        $TagKey,
        $TagValue
    )
    $Resource = Get-AzResource -ResourceId $ResourceID
    $Resource.ForEach{
        if (!($_.Tags.ContainsKey($TagKey))) {
            $_.Tags.Add($TagKey, $TagValue)
        }
        $_ | Set-AzResource -Tags $_.Tags -Force
    }
}

function Remove-Tag {
    param(
        $ResourceID,
        $TagKey
    )
    $Resource = Get-AzResource -ResourceId $ResourceID
    $Resource.ForEach{
        if ($_.Tags.ContainsKey($TagKey)) {
            $_.Tags.Remove($TagKey)
        }
        $_ | Set-AzResource -Tags $_.Tags -Force
    }
}

function Test-TagUpdate {
    param(
        $ResourceID
    )

    $Tag = @{"Test" = "Test"}

    try {
        Add-Tag -ResourceId $ResourceID -TagKey "Test" -TagValue "Test" -ErrorAction SilentlyContinue
        Remove-Tag -ResourceId $ResourceID -TagKey "Test"
        Get-AzTag -ResourceId $ResourceID
        Return "Pass"
    } catch {
        Write-Host $Error[0]
        Return "Fail"
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
            Write-Host "Trying to get tags for $($CurrentResourceID)" 
            try {
                $Tags = Get-AzTag -ResourceId $CurrentResourceID -ErrorAction silentlycontinue
                if ($Null -ne $Tags) {
                    Write-Host "Found tags for resource $($CurrentResourceID)"
                    try {
                        $TestResult = Test-TagUpdate -ResourceId $CurrentResourceID
                        if ($TestResult -eq "Pass") {
                            Break
                        }
                    } catch {
                        "Test for tagging resource failed: $CurrentResourceID.  Continuing search."
                    }
                }
            } catch {
                Write-Host $Error[0]
                Write-Host "$($CurrentResourceID) cannot be tagged.  Searching for parent."
            }
        } else {
            Write-Host "Skipping $($CurrentResourceID)"
        }
    }

    Return $CurrentResourceID
}

# $ResourceIDPass = "/subscriptions/affa3e80-5743-41c0-9f42-178059561abc/resourceGroups/rgp-use-infrabot-dev/providers/Microsoft.Storage/storageAccounts/stouseinfrabotdev"
# $ResourceIDFail = "/subscriptions/affa3e80-5743-41c0-9f42-178059561abc/resourceGroups/rgp-use-infrabot-dev/providers/Microsoft.Storage/storageAccounts/stouseinfrabotdev/blobServices/default/containers/test"
# Get-ParentResourceId -ResourceID $ResourceIDFail