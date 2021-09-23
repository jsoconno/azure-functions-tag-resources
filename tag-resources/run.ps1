param($eventGridEvent, $TriggerMetadata)

$ErrorActionPreference = "Continue"

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
                    Add-Tag -ResourceID $CurrentResourceID -TagKey "Test" -TagValue "Test" -ErrorAction SilentlyContinue
                    Remove-Tag -ResourceID $CurrentResourceID -TagKey "Test" -ErrorAction SilentlyContinue
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

$caller = $eventGridEvent.data.claims.name
$lastOperation = $eventGridEvent.data.authorization.action

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
Write-Host "Operation Name: $lastOperation"
Write-Host "Caller: $caller"
$resourceId = $eventGridEvent.data.resourceUri
Write-Host "ResourceId: $resourceId"

if (($null -eq $caller) -or ($null -eq $resourceId)) {
    Write-Host "ResourceId or Caller is null"
    exit;
}

$ignore = @("providers/Microsoft.Resources/deployments", "providers/Microsoft.Resources/tags", "Microsoft.Resources/tags/write")

foreach ($case in $ignore) {
    if ($resourceId -match $case) {
        Write-Host "Skipping event as resourceId contains: $case"
        exit;
    }
}

# Get first taggable resource
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
        LastModifiedBy = $caller;
        LastModifiedDate = $(Get-Date);
        LastOperation = $lastOperation;
    }
    Update-AzTag -ResourceId $resourceId -Operation Merge -Tag $tag
    Write-Host "Added or updated ModifiedBy tag with user: $caller"
}