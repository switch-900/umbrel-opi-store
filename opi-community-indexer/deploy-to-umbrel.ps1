param(
    [Parameter(Mandatory=$true)]
    [string]$UmbrelHost,
    
    [Parameter(Mandatory=$true)]
    [string]$UmbrelUser = "umbrel"
)

# Source directory where our OPI files are
$sourceDir = $PSScriptRoot
$appName = "opi"

Write-Host "Creating deployment package..."
# Create a temp directory for deployment
$tempDir = New-Item -ItemType Directory -Force -Path "$sourceDir\temp-deploy"

# Copy all required files to temp directory
Copy-Item "$sourceDir\docker-compose.yaml" -Destination $tempDir
Copy-Item "$sourceDir\docker-entrypoint.sh" -Destination $tempDir
Copy-Item "$sourceDir\umbrel-app.yml" -Destination $tempDir
Copy-Item "$sourceDir\Dockerfile" -Destination $tempDir
Copy-Item "$sourceDir\modules" -Destination $tempDir -Recurse

# Create deployment script for Umbrel
$deployScript = @"
#!/bin/bash
set -e

# Set up app directory in Umbrel
APP_DIR="/home/umbrel/umbrel/app-store/opi"
mkdir -p "\$APP_DIR"
mkdir -p "\$APP_DIR/data/postgres"
mkdir -p "\$APP_DIR/data/opi"

# Copy files
cp -r * "\$APP_DIR/"

# Set permissions
chmod +x "\$APP_DIR/docker-entrypoint.sh"
chown -R 1000:1000 "\$APP_DIR"

echo "OPI app files deployed successfully!"
echo "You can now install OPI from your Umbrel dashboard."
"@

$deployScript | Out-File -FilePath "$tempDir\deploy.sh" -Encoding ASCII
((Get-Content "$tempDir\deploy.sh") -join "`n") + "`n" | Set-Content "$tempDir\deploy.sh" -NoNewline -Force

Write-Host "Deploying to Umbrel at $UmbrelHost..."

# Use SSH to copy files and execute deployment
try {
    # Test SSH connection
    ssh "${UmbrelUser}@${UmbrelHost}" "echo 'SSH connection successful'" 
    if ($LASTEXITCODE -eq 0) {
        # Create temp directory on Umbrel
        ssh "${UmbrelUser}@${UmbrelHost}" "mkdir -p ~/opi-temp"
        
        # Copy files to Umbrel
        scp -r "$tempDir\*" "${UmbrelUser}@${UmbrelHost}:~/opi-temp/"
        
        # Execute deployment script
        ssh "${UmbrelUser}@${UmbrelHost}" "cd ~/opi-temp && chmod +x deploy.sh && ./deploy.sh"
        
        # Cleanup
        ssh "${UmbrelUser}@${UmbrelHost}" "rm -rf ~/opi-temp"
        Write-Host "Deployment completed successfully!"
    }
} catch {
    Write-Error "Deployment failed: $_"
} finally {
    # Clean up local temp directory
    Remove-Item -Recurse -Force $tempDir
}
