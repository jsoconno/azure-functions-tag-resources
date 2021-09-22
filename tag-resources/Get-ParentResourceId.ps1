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
                $value = Get-AzTag -ResourceId $CurrentResourceID -ErrorAction silentlycontinue
                if ($value -ne $Null) {
                    Write-Host "Found tags for resource $($CurrentResourceID)"
                    Break
                }
            } catch {
                Write-Host "$($CurrentResourceID) cannot be tagged.  Searching for parent."
            }
        } else {
            Write-Host "Skipping $($CurrentResourceID)"
        }
    }

    Return $CurrentResourceID
}