# Deployment script for OPI on Umbrel
$ErrorActionPreference = "Stop"

# Define paths
$sourceDir = $PSScriptRoot
$appName = "opi"
$umbrelDir = "$env:USERPROFILE\umbrel"
$appStoreDir = "$umbrelDir\app-store\$appName"

# Create Umbrel directory structure
Write-Host "Creating Umbrel directory structure..."
@(
    $umbrelDir,
    "$umbrelDir\app-store",
    $appStoreDir,
    "$appStoreDir\modules"
) | ForEach-Object {
    if (-not (Test-Path $_)) {
        New-Item -ItemType Directory -Force -Path $_ | Out-Null
        Write-Host "Created directory: $_"
    }
}

# Copy required files
Write-Host "Copying application files..."
@(
    "docker-compose.yaml",
    "docker-entrypoint.sh",
    "umbrel-app.yml",
    "Dockerfile"
) | ForEach-Object {
    Copy-Item "$sourceDir\$_" -Destination "$appStoreDir\" -Force
    Write-Host "Copied $_"
}

# Copy modules directory
Write-Host "Copying modules..."
Copy-Item "$sourceDir\modules" -Destination "$appStoreDir" -Recurse -Force
Write-Host "Copied modules directory"

# Create data directories
Write-Host "Creating data directories..."
@(
    "$appStoreDir\data",
    "$appStoreDir\data\postgres",
    "$appStoreDir\data\opi"
) | ForEach-Object {
    New-Item -ItemType Directory -Force -Path $_ | Out-Null
    Write-Host "Created directory: $_"
}

# Fix permissions on docker-entrypoint.sh
Write-Host "Setting execute permissions on docker-entrypoint.sh..."
icacls "$appStoreDir\docker-entrypoint.sh" /grant "*S-1-1-0:(RX)" /T

Write-Host "Deployment completed successfully!"
Write-Host "You can now install OPI from your Umbrel dashboard."
