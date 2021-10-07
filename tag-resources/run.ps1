param($eventGridEvent, $TriggerMetadata)

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

function Get-Requestor {
    <#
        .SYNOPSIS
            Gets the requestor (caller) of a particular action in Azure.
        .DESCRIPTION
            Returns the name of the user, principal, or other identity used for creating or modifying a resource in Azure.
        .INPUTS
            Requestor is the value returned from the event when getting the claim name
        .OUTPUTS
            The name of the identity that requested the action to happen.
        .EXAMPLE
            Get-Requestor -Requestor $eventGridEvent.data.claims.name
        .LINK
            None
        .NOTES
            None
    #>

    param(
        [string]$Requestor
    )

    # Perform logic to test is the requestor is null.
    if ($null -eq $Requestor) {
        # If the requestor is null, check to see if the requestor is a service principal.
        if ($eventGridEvent.data.authorization.evidence.principalType -eq "ServicePrincipal") {
            # If the request is a service principal, attempt to get the principal name.
            $PrincipalId = $eventGridEvent.data.authorization.evidence.principalId
            $Requestor = (Get-AzADServicePrincipal -ObjectId $PrincipalId).DisplayName
            # If that fails, let the user konw there is likely a permissions issue.
            if ($null -eq $Requestor) {
                Write-Host "The identity does not have permission read the application from the directory."
                # Set the requestor back to the principal id if there is a failure getting the name from Azure.
                $Requestor = $PrincipalId
            }
        }
    }

    # Return the requestor.
    Return $Requestor
}

# Set high level variables.
$Requestor = Get-Requestor -Requestor $eventGridEvent.data.claims.name
$Action = $eventGridEvent.data.authorization.action
$ActionTimestamp = "$((Get-Date).AddHours(-4).ToString()) EST"
$AuthorizationScope = $eventGridEvent.data.authorization.scope # $eventGridEvent.data.resourceUri

Write-Host "Requestor: $($Requestor)"
Write-Host "Action: $($Action)"
Write-Host "ActionTimestamp: $($ActionTimestamp)"
Write-Host "AuthorizationScope: $($AuthorizationScope)"

Write-Host $eventGridEvent.data.claims.value

# Test if the requestor or the authorization scope is null.  If so, exit the process.
if (($null -eq $Requestor) -or ($null -eq $AuthorizationScope)) {
    Write-Host "Requestor or Authorization Scope is null."
    Exit;
}

# Ignore actions that contain the following strings by exiting the process.
$Ignore = @("Microsoft.Resources/deployments", "Microsoft.Resources/tags", "Microsoft.Resources/tags", "Microsoft.Authorization/policies", "microsoft.insights/components/Annotations/write")
foreach ($Case in $Ignore) {
    if ($Action.ToLower() -match $Case.ToLower()) {
        Write-Host "Skipping the event matching the case $Case"
        Exit;
    }
}

# Get the resource id of the parent resource that will be tagged.
$ResourceId = Get-ParentResourceId -ResourceId $AuthorizationScope # $(Get-ParentResourceId -ResourceId $AuthorizationScope).id

# Get the current tags for the identified parent resource.
$Tags = (Get-AzTag -ResourceId $ResourceId).Properties

# Tag the resource based on whether or not this is the first time it is being deployed or modified in some way.
if (!($Tags.TagsProperty.ContainsKey('CreatedBy')) -or ($null -eq $Tags)) {
    Write-Host "Adding tags stating the resource $($ResourceId) was created on $($ActionTimestamp) by $($Requestor) with action $($Action)."
    # Create tag map to merge with the existing tags.
    $Tag = @{
        CreatedBy = $Requestor;
        CreatedDate = $ActionTimestamp;
        LastOperation = $Action;
    }
    # Update tags.
    Update-AzTag -ResourceId $ResourceId -Operation Merge -Tag $Tag
} else {
    Write-Host "Adding tags stating the resource $($ResourceId) was modified on $($ActionTimestamp) by $($Requestor) with action $($Action)."
    # Create tag map to merge with the existing tags.
    $Tag = @{
        LastModifiedBy = $Requestor;
        LastModifiedDate = $ActionTimestamp;
        LastOperation = $Action;
    }
    # Update tags.
    Update-AzTag -ResourceId $ResourceId -Operation Merge -Tag $Tag
}