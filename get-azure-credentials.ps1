# The purpose of this file is to be able to get credentials for an SPN from Azure to use with GitHub actions.
# You will need to change these variables to your own information
# yYou will need to make sure that you have installed Az.KeVault with Install-Module Az.KeyVault

<#
    .SYNOPSIS
        Get SPN details to use with GitHub actions.
    .DESCRIPTION
        This script gets details about an existing service principals client id, client secret, tenant id, and subscripiton id.
    .PARAMETER SpnName
		Name of the target service principal.
    .PARAMETER AzSubscriptionName
		Name of the Azure subscription.
    .PARAMETER KeyVaultName
		Name of the Key Vault where the client secret of the service principal is stored.
    .PARAMETER SecretName
		Name of secret in the Key Vault that contains the client secret.
    .INPUTS
		SpnName, AzSubscriptionName, KeyVaultName, and SecretName are all strings and are all mandatory.
    .OUTPUTS
        A JSON file with the attributes you need to copy for GitHub.
    .EXAMPLE
        ./get-azure-credentials.ps1 -SpnName <spn-name> -AzSubscriptionName <sub-name> -KeyVaultName <kvl-name> -SecretName <secret-name>
    .LINK
        None
    .NOTES
		You should add azure-credentials.json to your .gitignore file so that you don't accidentally commit your service principal details to GitHub.
#>

param(
    [parameter(Mandatory=$true)]
    [string]$SpnName,
    [parameter(Mandatory=$true)]
    [string]$AzSubscriptionName,
    [parameter(Mandatory=$true)]
    [string]$KeyVaultName,
    [parameter(Mandatory=$true)]
    [string]$SecretName
)

$Subscription = (Get-AzSubscription -SubscriptionName $AzSubscriptionName)
Set-AzContext $Subscription.Id

$Principal = Get-AzADServicePrincipal -DisplayName $SpnName
$OutputObject = [PSCustomObject]@{
    clientId = $Principal.ApplicationId
    clientSecret = Get-AzKeyVaultSecret -VaultName $KeyVaultName -Name $SecretName -AsPlainText
    subscriptionId = $Subscription.Id
    tenantId = $Subscription.TenantId
}
$OutputObject | ConvertTo-Json | Out-File -FilePath "./azure-credentials.json"