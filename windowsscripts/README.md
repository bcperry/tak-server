# Windows PowerShell Scripts for TAK Server

This directory contains Windows PowerShell equivalents of the original bash scripts for running TAK Server on Windows systems.

## Prerequisites

- Windows 10/11 or Windows Server 2016+
- PowerShell 5.0 or later
- Docker Desktop for Windows
- Docker Compose (included with Docker Desktop)

## Scripts

### setup.ps1
Main setup script that:
- Checks for required ports availability
- Verifies TAK server release file checksums
- Extracts and configures the TAK server
- Generates SSL certificates
- Creates user accounts with random passwords
- Starts Docker containers

**Usage:**
```powershell
.\windowsscripts\setup.ps1
```

### cleanup.ps1
Cleanup script that:
- Stops and removes Docker containers
- Removes Docker volumes
- Cleans up directories
- Optionally removes Docker images

**Usage:**
```powershell
.\windowsscripts\cleanup.ps1
```

### certDP.ps1
Certificate data package creation script that:
- Creates ATAK/iTAK compatible data packages
- Includes CA certificates, user certificates, and connection preferences

**Usage:**
```powershell
.\windowsscripts\certDP.ps1 <IP_ADDRESS> <USERNAME>
```

Example:
```powershell
.\windowsscripts\certDP.ps1 192.168.1.100 user1
```

### shareCerts.ps1
Certificate sharing script that:
- Copies certificate files to a share directory
- Starts a simple HTTP server (requires Python)
- **WARNING: This makes certificates accessible without authentication**

**Usage:**
```powershell
.\windowsscripts\shareCerts.ps1
```

## PowerShell Execution Policy

If you encounter execution policy errors, you may need to temporarily allow script execution:

```powershell
Set-ExecutionPolicy -ExecutionPolicy RemoteSigned -Scope CurrentUser
```

## Differences from Bash Scripts

1. **File Paths**: Uses Windows-style paths and PowerShell path handling
2. **Networking**: Uses `Get-NetIPConfiguration` instead of `ifconfig`
3. **Port Checking**: Uses `Get-NetTCPConnection` instead of `netstat`
4. **Archive Handling**: Uses `Expand-Archive` and `Compress-Archive` instead of `unzip`/`zip`
5. **Color Output**: Uses PowerShell `Write-Host` with color parameters
6. **Temp Directory**: Uses `$env:TEMP` instead of `/tmp`
7. **File Operations**: Uses PowerShell cmdlets like `Copy-Item`, `Remove-Item`, etc.

## Notes

- Scripts maintain the same functionality as the original bash scripts
- Random password generation uses PowerShell's `Get-Random` function
- File permissions are handled differently on Windows (no `chown` equivalent needed)
- HTTP server functionality requires Python to be installed (same as original)

## Troubleshooting

1. **Docker not found**: Ensure Docker Desktop is installed and running
2. **Permission errors**: Run PowerShell as Administrator if needed
3. **Execution policy**: See PowerShell Execution Policy section above
4. **Network issues**: Check Windows Firewall settings for required ports

## Security Considerations

- Generated passwords are displayed once and not stored
- Certificate files contain sensitive information
- The `shareCerts.ps1` script creates an unauthenticated web server - use with caution
- Consider the security implications of running Docker containers with elevated privileges
