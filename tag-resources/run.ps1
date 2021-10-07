param($eventGridEvent, $TriggerMetadata)

function Get-ParentResourceId {

    param(
        $ResourceId
    )

    $ResourceIdList = $ResourceId -Split '/'
    # This should be created as a parameter
    $IgnoreList = @('subscriptions', 'resourceGroups', 'providers')

    for ($ia=$ResourceIdList.length-1; $ia -ge 0; $ia--) {
        $CurrentResourceIdList = $ResourceIdList[0..($ia)]
        $CurrentResourceId = $CurrentResourceIdList -Join '/'
        $CurrentHead = $CurrentResourceIdList[-1]
        if (!($IgnoreList -Contains $CurrentHead)) {
            Write-Host "Validating ability to tag $($CurrentResourceId)" 
            $Error.Clear()
            try {
                try {
                    Write-Host "Running tagging test..."
                    Get-AzTag -ResourceId $CurrentResourceId -ErrorAction SilentlyContinue
                } catch {
                    Write-Host "Test failed." -ForegroundColor Red
                }
            } catch {
                Throw $_.Exception
                Write-Host "$($CurrentResourceId) cannot be tagged.  Searching for parent."
            }
            if (!$Error) {
                Write-Host "Test passed." -ForegroundColor Green
                Break
            }
        } else {
            Write-Host "Skipping resource $($CurrentResourceId)."
        }
    }

    Write-Host "Function output: $($CurrentResourceId)"
    Return $CurrentResourceId
}

function Get-Requestor {

    param(
        $Requestor
    )

    if ($null -eq $Requestor) {
        if ($eventGridEvent.data.authorization.evidence.principalType -eq "ServicePrincipal") {
            $PrincipalId = $eventGridEvent.data.authorization.evidence.principalId
            $Requestor = (Get-AzADServicePrincipal -ObjectId $PrincipalId).DisplayName
            if ($null -eq $Requestor) {
                Write-Host "The identity does not have permission read the application from the directory."
                $Requestor = $PrincipalId
            }
        }
    }

    Return $Requestor
}

$Requestor = Get-Requestor -Requestor $eventGridEvent.data.claims.name
$Action = $eventGridEvent.data.authorization.action
$AuthorizationScope = $eventGridEvent.data.authorization.scope # $eventGridEvent.data.resourceUri
$EventTimestamp = $eventGridEvent.data.$eventTimestamp

Write-Host "Authorization Scope: $($AuthorizationScope)"
Write-Host "Event Timestamp: $($EventTimestamp)"

if (($null -eq $Requestor) -or ($null -eq $AuthorizationScope)) {
    Write-Host "Requestor or Authorization Scope is null."
    exit;
}

Write-Host "Function input: $($AuthorizationScope)"
$ResourceId = Get-ParentResourceId -ResourceId $AuthorizationScope # $(Get-ParentResourceId -ResourceId $AuthorizationScope).id
$StrangeId = $(Get-ParentResourceId -ResourceId $AuthorizationScope).id
$AnotherStrangeId = $AuthorizationScope.id
Write-Host "Strange ID: $($StrangeId)"
Write-Host "Another Strange ID: $($AnotherStrangeId)"
Write-Host "Initial Resource ID: $($ResourceId)"
$ResourceId = $ResourceId.replace("/providers/Microsoft.Resources/tags/default", "")
$ResourceId = $ResourceId.replace("/blobServices/default", "")
Write-Host "Clean Resource ID: $($ResourceId)"

Write-Host "Operation Name Properties: $($eventGridEvent.data.operationName.Properties)"

# cean this up
$Ignore = @("providers/Microsoft.Resources/deployments", "providers/Microsoft.Resources/tags", "Microsoft.Resources/tags/write", "Microsoft.Authorization/policies/auditIfNotExists/action", "microsoft.insights/components/Annotations/write")

foreach ($Case in $Ignore) {
    if ($Action -match $Case) {
        Write-Host "Skipping the event matching the case $Case"
        exit;
    }
}

Write-Host "Attempting to tag $($ResourceId)"

$Tags = (Get-AzTag -ResourceId $ResourceId).Properties

Write-Host $Tags

if (!($Tags.TagsProperty.ContainsKey('CreatedBy')) -or ($null -eq $Tags)) {
    Write-Host "Adding CreatedBy tags."
    $Tag = @{
        CreatedBy = $Requestor;
        CreatedDate = $(Get-Date);
        LastOperation = $Action;
    }
    Update-AzTag -ResourceId $ResourceId -Operation Merge -Tag $Tag
    Write-Host "Added CreatedBy tag with user: $Requestor"
} else {
    Write-Host "Adding ModifiedBy tags."
    $Tag = @{
        LastModifiedBy = $Requestor;
        LastModifiedDate = $(Get-Date);
        LastOperation = $Action;
    }
    Update-AzTag -ResourceId $ResourceId -Operation Merge -Tag $Tag
    Write-Host "Added or updated ModifiedBy tag with user: $Requestor"
}