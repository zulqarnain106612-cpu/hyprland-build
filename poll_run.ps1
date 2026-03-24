$env:GITHUB_TOKEN = 'TOKEN_REMOVED'
$runId = 23508417117
$completed = $false
$attempts = 0
$maxAttempts = 210

while (-not $completed -and $attempts -lt $maxAttempts) {
    $attempts++
    try {
        $run = curl.exe -s -H "Authorization: token $env:GITHUB_TOKEN" -H "Accept: application/vnd.github+json" "https://api.github.com/repos/zulqarnain1066-hub/hyprland-build/actions/runs/$runId" | ConvertFrom-Json
        $ts = (Get-Date).ToString('HH:mm:ss')
        
        if ($run.status -eq 'completed') {
            Write-Host "[$ts] ✓ COMPLETED: conclusion=$($run.conclusion)" -ForegroundColor Green
            $completed = $true
            
            # Get and display job failure details if failed
            if ($run.conclusion -eq 'failure') {
                Write-Host "`nFetching failed jobs..." -ForegroundColor Yellow
                $jobs = curl.exe -s -H "Authorization: token $env:GITHUB_TOKEN" -H "Accept: application/vnd.github+json" "https://api.github.com/repos/zulqarnain1066-hub/hyprland-build/actions/runs/$runId/jobs" | ConvertFrom-Json
                $jobs.jobs | Where-Object { $_.conclusion -eq 'failure' } | ForEach-Object {
                    Write-Host "Failed Job: $($_.name)" -ForegroundColor Red
                    $_.steps | Where-Object { $_.conclusion -eq 'failure' } | ForEach-Object {
                        Write-Host "  - Step: $($_.name)" -ForegroundColor Red
                    }
                }
            } else {
                Write-Host "All steps passed! " -ForegroundColor Green
            }
        } else {
            Write-Host "[$ts] Poll #$attempts : status=$($run.status)"
        }
    }
    catch {
        Write-Host "Error on poll $attempts : $_"
    }
    
    if (-not $completed -and $attempts -lt $maxAttempts) {
        Start-Sleep -Seconds 20
    }
}

if (-not $completed) {
    Write-Host "Timeout: Did not complete within $(($maxAttempts * 20)/60) minutes" -ForegroundColor Yellow
}
