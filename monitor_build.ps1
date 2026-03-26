$token   = $env:GH_TOKEN  # set via: $env:GH_TOKEN = '<your_token>'
$repo    = 'zulqarnain1066-hub/hyprland-build'
$headers = @{ Authorization = "token $token"; 'Content-Type' = 'application/json' }

Write-Host "[1] Triggering workflow..."
try {
    Invoke-RestMethod -Uri "https://api.github.com/repos/$repo/actions/workflows/build.yml/dispatches" -Method POST -Headers $headers -Body '{"ref":"main"}' | Out-Null
    Write-Host "    Triggered OK"
} catch {
    Write-Host "    Note: $($_.ErrorDetails.Message)"
}

Start-Sleep -Seconds 10

Write-Host "[2] Monitoring (polls every 30s, max 60min)..."
$runId = $null
$done  = $false
$i     = 0
while (-not $done -and $i -lt 120) {
    $runs = Invoke-RestMethod "https://api.github.com/repos/$repo/actions/runs" -Headers $headers
    if ($runs.total_count -gt 0) {
        $run   = $runs.workflow_runs[0]
        $runId = $run.id
        Write-Host "    Status: $($run.status) | Conclusion: $($run.conclusion)"
        if ($run.status -eq 'completed') {
            $done = $true
        }
    }
    if (-not $done) {
        Start-Sleep -Seconds 30
    }
    $i++
}

if (-not $runId) {
    Write-Host "No run found"
    exit 1
}

Write-Host "[3] Getting artifact..."
$arts = Invoke-RestMethod "https://api.github.com/repos/$repo/actions/runs/$runId/artifacts" -Headers $headers
if ($arts.total_count -gt 0) {
    $art = $arts.artifacts[0]
    Write-Host "    Name: $($art.name)"
    Write-Host "    Size: $($art.size_in_bytes) bytes"
    Write-Host "    ID:   $($art.id)"
    $art.id | Out-File "$PSScriptRoot\artifact_id.txt" -NoNewline
    Write-Host "    Saved artifact ID to artifact_id.txt"
} else {
    Write-Host "    No artifact - build may have failed"
    $logurl = 'https://github.com/' + $repo + '/actions/runs/' + [string]$runId
    Write-Host ('    Logs: ' + $logurl)
}
