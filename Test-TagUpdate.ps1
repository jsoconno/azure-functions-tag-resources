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