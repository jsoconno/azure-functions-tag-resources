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
        # $e = $_.Exception
        # $line = $_.InvocationInfo.ScriptLineNumber
        # $msg = $e.Message
        # $func = $MyInvocation.MyCommand
        # Write-Host -ForegroundColor Red "The function $func had and error on line $line with the following message:`n $e"
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
        # $e = $_.Exception
        # $line = $_.InvocationInfo.ScriptLineNumber
        # $msg = $e.Message
        # $func = $MyInvocation.MyCommand
        # Write-Host -ForegroundColor Red "The function $func had and error on line $line with the following message:`n $e"
        Throw $_.Exception
    }
}

function Test-TagUpdate {
    param(
        $ResourceID
    )

    $Tag = @{"Test" = "Test"}

    try {
        Add-Tag -ResourceId $ResourceID -TagKey "Test" -TagValue "Test" -ErrorAction Stop
        Remove-Tag -ResourceId $ResourceID -TagKey "Test" -ErrorAction Stop
        Get-AzTag -ResourceId $ResourceID -ErrorAction Stop
        Return "Pass"
    } catch {
        $e = $_.Exception
        $line = $_.InvocationInfo.ScriptLineNumber
        $msg = $e.Message
        $func = $MyInvocation.MyCommand
        Write-Host -ForegroundColor Red "The function $func had and error on line $line with the following message:`n $e"
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
            Write-Host "Validating ability to tag $($CurrentResourceID)" 
            $Error.clear()
            try {
                $Resource = Get-AzResource -ResourceId $CurrentResourceID -ErrorAction Stop
                $Tags = $Resource.Tags
                try {
                    Write-Host "Running tagging test..."
                    Add-Tag -ResourceID $CurrentResourceID -TagKey "Test" -TagValue "Test"
                    Remove-Tag -ResourceID $CurrentResourceID -TagKey "Test"
                } catch {
                    Write-Host "Test failed." -ForegroundColor Red
                }
            } catch {
                $e = $_.Exception
                $line = $_.InvocationInfo.ScriptLineNumber
                $msg = $e.Message
                $func = $MyInvocation.MyCommand
                Write-Host -ForegroundColor Red "The function $func had and error on line $line with the following message:`n $e"
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

$ResourceIDPass = "/subscriptions/affa3e80-5743-41c0-9f42-178059561abc/resourceGroups/rgp-use-infrabot-dev/providers/Microsoft.Storage/storageAccounts/stouseinfrabotdev"
$ResourceIDFail = "/subscriptions/affa3e80-5743-41c0-9f42-178059561abc/resourceGroups/rgp-use-infrabot-dev/providers/Microsoft.Storage/storageAccounts/stouseinfrabotdev/blobServices/default/containers/test"
Get-ParentResourceId -ResourceID $ResourceIDFail