param($eventGridEvent, $TriggerMetadata)

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
                    Get-AzTag -ResourceId $CurrentResourceID -ErrorAction SilentlyContinue
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

$Requestor = $eventGridEvent.data.claims.name
$Action = $eventGridEvent.data.authorization.action

if ($null -eq $Requestor) {
    if ($eventGridEvent.data.authorization.evidence.principalType -eq "ServicePrincipal") {
        $Requestor = (Get-AzADServicePrincipal -ObjectId $eventGridEvent.data.authorization.evidence.principalId).DisplayName
        if ($null -eq $Requestor) {
            Write-Host "MSI may not have permission to read the applications from the directory"
            $Requestor = $eventGridEvent.data.authorization.evidence.principalId
        }
    }
}

# Write-Host "Authorization Action: $($eventGridEvent.data.authorization.action)"
Write-Host "Authorization Scope: $($eventGridEvent.data.authorization.scope)"
Write-Host "Operation Name: $Action"
Write-Host "Caller: $Requestor"
$resourceId = $eventGridEvent.data.authorization.scope # $eventGridEvent.data.resourceUri
Write-Host "ResourceId: $resourceId"
Write-Host "Human Readable Action: $($eventGridEvent.data.operationName.localizedValue)"

if (($null -eq $Requestor) -or ($null -eq $resourceId)) {
    Write-Host "ResourceId or Caller is null"
    exit;
}

$ignore = @("providers/Microsoft.Resources/deployments", "providers/Microsoft.Resources/tags", "Microsoft.Resources/tags/write", "Microsoft.Authorization/policies/auditIfNotExists/action")

foreach ($case in $ignore) {
    if ($Action -match $case) {
        Write-Host "Skipping the event matching the case $case"
        exit;
    }
}

# # Get first taggable resource
# $resourceId = Get-ParentResourceId -ResourceId $resourceId
$resourceId = $(Get-ParentResourceId -ResourceId $resourceId).id.replace("/providers/Microsoft.Resources/tags/default", "").replace("blobServices/default", "")
Write-Host "Attempting to tag $($resourceId)"

$tags = (Get-AzTag -ResourceId $resourceId).Properties

Write-Host $tags

if (!($tags.TagsProperty.ContainsKey('CreatedBy')) -or ($null -eq $tags)) {
    Write-Host "Adding CreatedBy tags."
    $tag = @{
        CreatedBy = $Requestor;
        CreatedDate = $(Get-Date);
        LastOperation = $Action;
    }
    Update-AzTag -ResourceId $resourceId -Operation Merge -Tag $tag
    Write-Host "Added CreatedBy tag with user: $Requestor"
} else {
    Write-Host "Adding ModifiedBy tags."
    $tag = @{
        LastModifiedBy = $Requestor;
        LastModifiedDate = $(Get-Date);
        LastOperation = $Action;
    }
    Update-AzTag -ResourceId $resourceId -Operation Merge -Tag $tag
    Write-Host "Added or updated ModifiedBy tag with user: $Requestor"
}