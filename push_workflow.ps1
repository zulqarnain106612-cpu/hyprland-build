$token = 'TOKEN_REMOVED'
$headers = @{
    Authorization  = "token $token"
    'Content-Type' = 'application/json'
}

$yml     = Get-Content "$PSScriptRoot\build.yml" -Raw
$b64     = [Convert]::ToBase64String([System.Text.Encoding]::UTF8.GetBytes($yml))
$body    = @{ message = "Add build workflow"; content = $b64 } | ConvertTo-Json

try {
    $r = Invoke-RestMethod `
        -Uri 'https://api.github.com/repos/zulqarnain1066-hub/hyprland-build/contents/.github/workflows/build.yml' `
        -Method PUT `
        -Headers $headers `
        -Body $body
    Write-Host "PUSHED: $($r.content.name)"
} catch {
    Write-Host "ERROR: $($_.Exception.Message)"
    Write-Host $_.ErrorDetails.Message
}
