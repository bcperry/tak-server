# TAK Certificate Sharing Script for Windows PowerShell
# WARNING: UNAUTHENTICATED USERS CAN NOW FETCH *CERTIFICATES*. THIS IS RISKY

Write-Warning "WARNING: UNAUTHENTICATED USERS CAN NOW FETCH *CERTIFICATES*. THIS IS RISKY"

# Create share directory if it doesn't exist
if (-not (Test-Path "share")) {
    New-Item -Path "share" -ItemType Directory | Out-Null
}

# Copy certificate zip files to share directory
if (Test-Path "tak\certs\files\*.zip") {
    Copy-Item -Path "tak\certs\files\*.zip" -Destination "share\" -Force
    Write-Host "Copied certificate files to share directory"
} else {
    Write-Warning "No certificate zip files found in tak\certs\files\"
}

# Change to share directory
Set-Location "share"

# Start HTTP server using Python (if available)
if (Get-Command "python" -ErrorAction SilentlyContinue) {
    Write-Host "Starting HTTP server on port 12345 using Python..."
    Write-Host "Access certificates at: http://localhost:12345"
    Write-Host "Press Ctrl+C to stop the server"
    & python -m http.server 12345
} elseif (Get-Command "python3" -ErrorAction SilentlyContinue) {
    Write-Host "Starting HTTP server on port 12345 using Python3..."
    Write-Host "Access certificates at: http://localhost:12345"
    Write-Host "Press Ctrl+C to stop the server"
    & python3 -m http.server 12345
} else {
    Write-Warning "Python not found. Cannot start HTTP server."
    Write-Host "Alternative: Use PowerShell's built-in web server (requires additional setup)"
    Write-Host "Certificate files are available in the 'share' directory"
}
