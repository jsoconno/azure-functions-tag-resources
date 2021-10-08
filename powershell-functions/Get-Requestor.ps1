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
        $Requestor
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
                # Set the requestor back to the principal id if there is a failure getting the name from Azure.
                $Requestor = $PrincipalId
            }
        }
    }

    # Return the requestor.
    Return $Requestor
}