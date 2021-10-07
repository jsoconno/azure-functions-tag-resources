function Get-ParentResourceId {
    <#
        .SYNOPSIS
            Attempts to find the parent resource that needs to be tagged based on a resource update.
        .DESCRIPTION
            Traverses the resource id and searches for the first available taggable resource.
        .INPUTS
            ResourceId is the ID of the resource from Azure.
            IgnoreList is a list of items along the path to ignore when considering what should be tested for taggability.
            CleanList is a list of strings that should be cleaned from the result returned by the function.
        .OUTPUTS
            The ID of the parent resource for which a change was made.
        .EXAMPLE
            Get-ParentResourceId -ResourceId $AuthorizationScope
        .LINK
            None
        .NOTES
            The baseline resource id was not used as the output because of some identified issues where non-taggable resources were sucessful in calling Get-AzTag.
    #>

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