param (
    [string]$UmbrelHost = "192.168.1.66",
    [string]$UmbrelUser = "umbrel"
)

Write-Host "=== Checking Umbrel Environment ===" -ForegroundColor Cyan

# SSH Commands to check system status
$sshCommands = @(
    "echo '>>> Disk Space:' && df -h /home/umbrel",
    "echo '>>> Memory Status:' && free -h",
    "echo '>>> Docker Status:' && docker ps",
    "echo '>>> Docker Space Usage:' && docker system df",
    "echo '>>> OPI Logs:' && docker logs opi_web_1 2>&1 | tail -n 50 || echo 'OPI container not running'",
    "echo '>>> Database Logs:' && docker logs opi_db_1 2>&1 | tail -n 50 || echo 'Database container not running'"
)

foreach ($cmd in $sshCommands) {
    Write-Host "`nExecuting: $cmd" -ForegroundColor Yellow
    ssh "${UmbrelUser}@${UmbrelHost}" $cmd
}

# Check if we can access the app
try {
    $response = Invoke-WebRequest -Uri "http://${UmbrelHost}:3000" -Method GET
    Write-Host "`nOPI Web Interface:" -ForegroundColor Green
    Write-Host "Status Code: $($response.StatusCode)"
} catch {
    Write-Host "`nCannot access OPI Web Interface:" -ForegroundColor Red
    Write-Host $_.Exception.Message
}
