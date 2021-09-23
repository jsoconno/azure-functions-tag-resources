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
        # $e = $_.Exception
        # $line = $_.InvocationInfo.ScriptLineNumber
        # $msg = $e.Message
        # $func = $MyInvocation.MyCommand
        # Write-Host -ForegroundColor Red "The function $func had and error on line $line with the following message:`n $e"
        Throw $_.Exception
    }
}