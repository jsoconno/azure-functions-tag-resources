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

$caller = $eventGridEvent.data.claims.name
$lastOperation = $eventGridEvent.data.operationName

if ($null -eq $caller) {
    if ($eventGridEvent.data.authorization.evidence.principalType -eq "ServicePrincipal") {
        $caller = (Get-AzADServicePrincipal -ObjectId $eventGridEvent.data.authorization.evidence.principalId).DisplayName
        if ($null -eq $caller) {
            Write-Host "MSI may not have permission to read the applications from the directory"
            $caller = $eventGridEvent.data.authorization.evidence.principalId
        }
    }
}

# Write-Host "Authorization Action: $($eventGridEvent.data.authorization.action)"
Write-Host "Authorization Scope: $($eventGridEvent.data.authorization.scope)"
Write-Host "Operation Name: $($eventGridEvent.data.authorization.action)"
Write-Host "Caller: $caller"
$resourceId = $eventGridEvent.data.resourceUri
Write-Host "ResourceId: $resourceId"

if (($null -eq $caller) -or ($null -eq $resourceId)) {
    Write-Host "ResourceId or Caller is null"
    exit;
}

$ignore = @("providers/Microsoft.Resources/deployments", "providers/Microsoft.Resources/tags")

foreach ($case in $ignore) {
    if ($resourceId -match $case) {
        Write-Host "Skipping event as resourceId contains: $case"
        exit;
    }
}

$resourceId = Get-ParentResourceId -ResourceId $resourceId

$tags = (Get-AzTag -ResourceId $resourceId).Properties

if (-not ($tags.TagsProperty.ContainsKey('CreatedBy')) -or ($null -eq $tags)) {
    $tag = @{
        CreatedBy = $caller;
        CreatedDate = $(Get-Date);
        LastOperation = $lastOperation;
    }
    Update-AzTag -ResourceId $resourceId -Operation Merge -Tag $tag
    Write-Host "Added CreatedBy tag with user: $caller"
}
else {
    Write-Host "Tag already exists"
    $tag = @{
        ModifiedBy = $caller;
        ModifiedDate = $(Get-Date);
        LastOperation = $lastOperation;
    }
    Update-AzTag -ResourceId $resourceId -Operation Merge -Tag $tag
    Write-Host "Added or updated ModifiedBy tag with user: $caller"
}