# Create community store structure
$repoRoot = "c:\Users\Naomi\OPI\umbrel-opi-store"
$appId = "opi-community-indexer"

# Create repository structure
$dirs = @(
    $repoRoot,
    "$repoRoot\$appId"
)

foreach ($dir in $dirs) {
    if (-not (Test-Path $dir)) {
        New-Item -ItemType Directory -Force -Path $dir | Out-Null
        Write-Host "Created directory: $dir"
    }
}

# Copy store definition
Copy-Item "umbrel-app-store.yml" -Destination $repoRoot -Force

# Copy app files
$appFiles = @(
    "docker-compose.yaml",
    "docker-entrypoint.sh",
    "umbrel-app.yml",
    "Dockerfile"
)

foreach ($file in $appFiles) {
    Copy-Item $file -Destination "$repoRoot\$appId\" -Force
    Write-Host "Copied $file to community store"
}

# Copy modules directory
Copy-Item "modules" -Destination "$repoRoot\$appId\" -Recurse -Force
Copy-Item "ord" -Destination "$repoRoot\$appId\" -Recurse -Force

Write-Host "Community store structure created at $repoRoot"
Write-Host "Next steps:"
Write-Host "1. Create a new GitHub repository named 'umbrel-opi-store'"
Write-Host "2. Push the contents of $repoRoot to the repository"
Write-Host "3. Add the repository URL to Umbrel through the Community App Store interface"
