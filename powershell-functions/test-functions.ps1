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
        [string]$ResourceId,
        [array]$IgnoreList = @('subscriptions', 'resourceGroups', 'providers'),
        [array]$CleanList = @("/providers/Microsoft.Resources/tags/default", "/blobServices/default")
    )

    # Create an array of each element in the resource id.
    $ResourceIdList = $ResourceId -Split '/'
    
    # Using the items in the array, construct a new id to tag starting with the longest and moving backwards.
    for ($ia=$ResourceIdList.length-1; $ia -ge 0; $ia--) {

        # For each id, set the current list, create the current id, and identify the current head for ignore actions.
        $CurrentResourceIdList = $ResourceIdList[0..($ia)]
        $CurrentResourceId = $CurrentResourceIdList -Join '/'
        $CurrentHead = $CurrentResourceIdList[-1]

        # Perform logic to determine if a resource is taggable.
        if (!($IgnoreList -contains $CurrentHead)) {

            # Clear all errors to start
            $Error.Clear()

            # Try to get tags based on the resource id
            try {
                try {
                    Write-Host "Running tagging test for $($CurrentResourceId)"
                    # Store the id of the resulting object from calling Get-AzTag (this value is different from the actual resource id).
                    $Result = (Get-AzTag -ResourceId $CurrentResourceId -ErrorAction Stop).id
                } catch {
                    # Log results of failed tests.
                    Write-Host "Test failed." -ForegroundColor Red
                }
            } catch {
                # Capture exceptions.
                Throw $_.Exception
                Write-Host "$($CurrentResourceId) cannot be tagged.  Searching for parent."
            }
            if (!$Error) {
                # Log results of passed tests.
                Write-Host "Test passed." -ForegroundColor Green
                Break
            }
        } else {
            # Log results of ignored tests.
            Write-Host "Ignoring resource $($CurrentResourceId)."
        }
    }

    # Remove text from the id output from the Get-AzTag object to get to the base resource.
    # This was done rather than 
    foreach ($String in $CleanList) {
        $Result = $Result.Replace($String, "")
    }

    # Return the result from the function.
    Return $Result
}

$ResourceIDPass = "/subscriptions/affa3e80-5743-41c0-9f42-178059561abc/resourceGroups/rgp-use-infrabot-dev/providers/Microsoft.KeyVault/vaults/kvl-use-infrabot-dev"
$ResourceIDFail = "/subscriptions/affa3e80-5743-41c0-9f42-178059561abc/resourceGroups/rgp-use-infrabot-dev/providers/Microsoft.Storage/storageAccounts/stouseinfrabotdev/blobServices/default/containers/delete"
$result = Get-ParentResourceId -ResourceID $ResourceIDFail
Write-Host $result