param(
    [Parameter(Mandatory=$true)]
    [string]$UmbrelHost,
    
    [Parameter(Mandatory=$true)]
    [string]$UmbrelUser = "umbrel",

    [Parameter(Mandatory=$false)]
    [string]$SshKeyPath = "$HOME\.ssh\id_rsa"
)

# Validate SSH key exists
if (-not (Test-Path $SshKeyPath)) {
    Write-Error "SSH key not found at $SshKeyPath. Please ensure you have set up SSH key authentication."
    Write-Host "You can generate a new key pair using: ssh-keygen -t rsa -b 4096"
    Write-Host "Then copy the public key to Umbrel using: ssh-copy-id ${UmbrelUser}@${UmbrelHost}"
    exit 1
}

# Source directory where our OPI files are
$sourceDir = $PSScriptRoot
$appName = "opi"

Write-Host "Creating deployment package..."
# Create a temp directory for deployment
$tempDir = New-Item -ItemType Directory -Force -Path "$sourceDir\temp-deploy"

# Copy all required files to temp directory
$filesToCopy = @(
    "docker-compose.yaml",
    "docker-entrypoint.sh",
    "umbrel-app.yml",
    "Dockerfile",
    ".env",
    "umbrel-app-store.yml"
)

foreach ($file in $filesToCopy) {
    $filePath = "$sourceDir\$file"
    if (Test-Path $filePath) {
        Write-Host "Copying $file..."
        Copy-Item $filePath -Destination $tempDir
    } else {
        Write-Warning "File not found: $file - searching in parent directory..."
        $parentPath = Join-Path $sourceDir "..\$file"
        if (Test-Path $parentPath) {
            Write-Host "Found $file in parent directory, copying..."
            Copy-Item $parentPath -Destination $tempDir
        } else {
            Write-Warning "File not found in parent directory either: $file"
        }
    }
}

# Copy required directories
$dirsToCopy = @("modules", "ord")
foreach ($dir in $dirsToCopy) {
    $dirPath = "$sourceDir\$dir"
    if (Test-Path $dirPath) {
        Write-Host "Copying directory $dir..."
        Copy-Item $dirPath -Destination $tempDir -Recurse
    } else {
        Write-Warning "Directory not found: $dir - searching in parent directory..."
        $parentPath = Join-Path $sourceDir "..\$dir"
        if (Test-Path $parentPath) {
            Write-Host "Found $dir in parent directory, copying..."
            Copy-Item $parentPath -Destination $tempDir -Recurse
        } else {
            Write-Warning "Directory not found in parent directory either: $dir"
        }
    }
}

# Create deployment script for Umbrel
$deployScript = @"
#!/bin/bash
set -e

# Set up app directory in Umbrel
APP_DIR="/home/umbrel/umbrel/app-store/opi-community-indexer"
STORE_DIR="/home/umbrel/umbrel/app-store"

# Create directories
mkdir -p "\$APP_DIR"
mkdir -p "\$APP_DIR/data/postgres"
mkdir -p "\$APP_DIR/data/opi"
mkdir -p "\$APP_DIR/data/bitcoin"

# Copy files
cp -r * "\$APP_DIR/"

# Copy store configuration
if [ -f "umbrel-app-store.yml" ]; then
    cp umbrel-app-store.yml "\$STORE_DIR/"
fi

# Set permissions
chmod 755 "\$APP_DIR/data"
chmod -R 777 "\$APP_DIR/data/postgres"
chmod -R 777 "\$APP_DIR/data/opi"
chmod +x "\$APP_DIR/docker-entrypoint.sh"
chown -R 1000:1000 "\$APP_DIR"

# Verify deployment
if [ ! -f "\$APP_DIR/docker-compose.yaml" ]; then
    echo "Error: docker-compose.yaml not found in \$APP_DIR"
    ls -la "\$APP_DIR"
    exit 1
fi

if [ ! -f "\$APP_DIR/docker-entrypoint.sh" ]; then
    echo "Error: docker-entrypoint.sh not found in \$APP_DIR"
    ls -la "\$APP_DIR"
    exit 1
fi

chmod +x "\$APP_DIR/docker-entrypoint.sh"
if [ ! -x "\$APP_DIR/docker-entrypoint.sh" ]; then
    echo "Error: Failed to make docker-entrypoint.sh executable in \$APP_DIR"
    ls -la "\$APP_DIR/docker-entrypoint.sh"
    exit 1
fi

# Create docker network if it doesn't exist
docker network inspect bitcoin >/dev/null 2>&1 || docker network create bitcoin

echo "OPI app files deployed successfully!"
echo "You can now install OPI from your Umbrel dashboard."
echo "Note: Please ensure you have at least 100GB of free space for the database."
"@

$deployScript | Out-File -FilePath "$tempDir\deploy.sh" -Encoding ASCII
((Get-Content "$tempDir\deploy.sh") -join "`n") + "`n" | Set-Content "$tempDir\deploy.sh" -NoNewline -Force

Write-Host "Deploying to Umbrel at $UmbrelHost..."

# Use SSH to copy files and execute deployment (with key authentication)
try {
    # Test SSH connection
    $sshArgs = "-i `"$SshKeyPath`""
    $testResult = ssh $sshArgs "${UmbrelUser}@${UmbrelHost}" "echo 'SSH connection successful'" 2>&1
    if ($LASTEXITCODE -eq 0) {
        # Create temp directory on Umbrel
        ssh $sshArgs "${UmbrelUser}@${UmbrelHost}" "mkdir -p ~/opi-temp"
        
        # Copy files to Umbrel
        scp $sshArgs -r "$tempDir\*" "${UmbrelUser}@${UmbrelHost}:~/opi-temp/"
        
        # Execute deployment script
        ssh "${UmbrelUser}@${UmbrelHost}" "cd ~/opi-temp && chmod +x deploy.sh && ./deploy.sh"
          # Verify app store registration
        Write-Host "Verifying app store registration..."
        $verifyResult = ssh $sshArgs "${UmbrelUser}@${UmbrelHost}" "test -f /home/umbrel/umbrel/app-store/opi/umbrel-app.yml && echo 'OK'"
        if ($verifyResult -eq "OK") {
            Write-Host "App store registration verified."
            
            # Check available disk space
            $spaceCheck = ssh $sshArgs "${UmbrelUser}@${UmbrelHost}" "df -h /home/umbrel/umbrel/app-store/opi/data"
            Write-Host "Storage space available for OPI:"
            Write-Host $spaceCheck
            
            # Cleanup
            ssh $sshArgs "${UmbrelUser}@${UmbrelHost}" "rm -rf ~/opi-temp"
            Write-Host "Deployment completed successfully!"
        } else {
            Write-Warning "App store registration could not be verified. Please check the Umbrel dashboard."
        }
    }
} catch {
    Write-Error "Deployment failed: $_"
} finally {
    # Clean up local temp directory
    Remove-Item -Recurse -Force $tempDir
}
