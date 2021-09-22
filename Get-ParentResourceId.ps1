function Test-TagUpdate {
    param(
        $ResourceID
    )

    $Tag = @{"Test" = "Test"}

    try {
        Update-AzTag -ResourceId $ResourceID -Operation Merge -Tag $Tag -ErrorAction SilentlyContinue
        $Resource = Get-AzResource -ResourceId $ResourceID -ErrorAction SilentlyContinue
        $Resource.ForEach{
            if ($_.Tags.ContainsKey("Test")) {
                $_.Tags.Remove("Test")
            }
            $_ | Set-AzResource -Tags $_.Tags -ErrorAction SilentlyContinue -Force
        }
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