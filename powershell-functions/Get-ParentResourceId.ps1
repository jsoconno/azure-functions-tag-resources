. .\Add-Tag.ps1
. .\Remove-Tag.ps1

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