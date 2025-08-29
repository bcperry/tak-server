# TAK Server Cleanup Script for Windows PowerShell

# Determine Docker Compose command
$DOCKER_COMPOSE = "docker-compose"
if (-not (Get-Command "docker-compose" -ErrorAction SilentlyContinue)) {
    $DOCKER_COMPOSE = "docker compose"
    Write-Host "Docker compose command set to new style $DOCKER_COMPOSE"
}

# Stop and remove containers
& $DOCKER_COMPOSE down

# Remove Docker volume
& docker volume rm --force tak-server_db_data

# Remove directories
if (Test-Path "tak") {
    Remove-Item -Path "tak" -Recurse -Force -ErrorAction SilentlyContinue
}

if (Test-Path "$env:TEMP\takserver") {
    Remove-Item -Path "$env:TEMP\takserver" -Recurse -Force -ErrorAction SilentlyContinue
}

# Comment out the lines below to save yourself rebuilding the images
& docker image rm tak-server-db --force
& docker image rm tak-server-tak --force

Write-Host "Cleanup completed."
