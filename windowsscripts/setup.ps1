# TAK Server Setup Script for Windows PowerShell
# Sponsored by CloudRF.com - "The API for RF"

# Color functions for output formatting
function Write-Info { param($Message) Write-Host $Message -ForegroundColor Cyan }
function Write-Success { param($Message) Write-Host $Message -ForegroundColor Green }
function Write-Warning { param($Message) Write-Host $Message -ForegroundColor Yellow }
function Write-Danger { param($Message) Write-Host $Message -ForegroundColor Red }

# Determine Docker Compose command
$DOCKER_COMPOSE = "docker-compose"
if (-not (Get-Command "docker-compose" -ErrorAction SilentlyContinue)) {
    $DOCKER_COMPOSE = "docker compose"
    Write-Host "Docker compose command set to new style $DOCKER_COMPOSE"
}

Write-Success "`nTAK server setup script sponsored by CloudRF.com - `"The API for RF`"`n"
Write-Info "`nStep 1. Download the official docker image as a zip file from https://tak.gov/products/tak-server `nStep 2. Place the zip file in this tak-server folder.`n"
Write-Warning "`nYou should install this as a user. Elevated privileges (Run as Administrator) are only required to clean up a previous install eg. .\windowsscripts\cleanup.ps1`n"

# Detect architecture (Windows typically x64)
$arch = [System.Environment]::GetEnvironmentVariable("PROCESSOR_ARCHITECTURE")
$DOCKERFILE = "docker-compose.yml"

if ($arch -eq "ARM64") {
    $DOCKERFILE = "docker-compose.arm.yml"
    Write-Info "`nBuilding for arm64...`n"
}

# Function to check if required ports are in use
function Test-RequiredPorts {
    $ports = @(5432, 8089, 8443, 8444, 8446, 9000, 9001)
    
    foreach ($port in $ports) {
        $connections = Get-NetTCPConnection -LocalPort $port -ErrorAction SilentlyContinue
        if ($connections) {
            Write-Warning "`nAnother process is still using port $port. Use 'Get-NetTCPConnection -LocalPort $port' to find it, then stop the process and try again`n"
            exit 0
        } else {
            Write-Success "`nPort $port is available.."
        }
    }
}

# Function to handle existing tak folder
function Test-TakFolder {
    if (Test-Path ".\tak") {
        Write-Warning "`nDirectory 'tak' already exists. This will be removed along with the docker volume, do you want to continue? (y/n): "
        $dirc = Read-Host
        if ($dirc -eq "n" -or $dirc -eq "no") {
            Write-Host "Exiting now.."
            Start-Sleep 1
            exit 0
        }
        Remove-Item -Path ".\tak" -Recurse -Force -ErrorAction SilentlyContinue
        Remove-Item -Path "$env:TEMP\takserver" -Recurse -Force -ErrorAction SilentlyContinue
        & docker volume rm --force tak-server_db_data
    }
}

# Function to verify checksums
function Test-Checksum {
    Write-Host "`nChecking for TAK server release files (..RELEASE.zip) in the directory....`n"
    Start-Sleep 1

    $zipFiles = Get-ChildItem -Path "." -Filter "*-RELEASE-*.zip"
    if ($zipFiles) {
        Write-Warning "SECURITY WARNING: Make sure the checksums match! You should only download your release from a trusted source eg. tak.gov:`n"
        foreach ($file in $zipFiles) {
            Write-Host "Computed SHA1 Checksum: "
            $sha1 = Get-FileHash -Path $file.FullName -Algorithm SHA1
            Write-Host "$($sha1.Hash.ToLower())  $($file.Name)"
            Write-Host "Computed MD5 Checksum: "
            $md5 = Get-FileHash -Path $file.FullName -Algorithm MD5
            Write-Host "$($md5.Hash.ToLower())  $($file.Name)"
        }
        
        Write-Host "`nVerifying checksums against known values for $($zipFiles[0].Name)...`n"
        Start-Sleep 1
        
        # Check SHA1
        if (Test-Path "tak-sha1checksum.txt") {
            $knownSha1 = Get-Content "tak-sha1checksum.txt"
            $currentSha1 = Get-FileHash -Path $zipFiles[0].FullName -Algorithm SHA1
            $sha1Match = $false
            foreach ($line in $knownSha1) {
                if ($line -match $zipFiles[0].Name -and $line -match $currentSha1.Hash) {
                    $sha1Match = $true
                    break
                }
            }
            
            if (-not $sha1Match) {
                Write-Danger "SECURITY WARNING: The file is either different OR is not listed in the known releases.`nDo you really want to continue with this setup? (y/n): "
                $check = Read-Host
                if ($check -eq "n" -or $check -eq "no") {
                    Write-Host "`nExiting now..."
                    exit 0
                }
            } else {
                Write-Success "SHA1 Verification: PASSED"
            }
        }
        
        # Check MD5
        if (Test-Path "tak-md5checksum.txt") {
            $knownMd5 = Get-Content "tak-md5checksum.txt"
            $currentMd5 = Get-FileHash -Path $zipFiles[0].FullName -Algorithm MD5
            $md5Match = $false
            foreach ($line in $knownMd5) {
                if ($line -match $zipFiles[0].Name -and $line -match $currentMd5.Hash) {
                    $md5Match = $true
                    break
                }
            }
            
            if (-not $md5Match) {
                Write-Danger "SECURITY WARNING: The checksum is not correct, so the file is different. Do you really want to continue with this setup? (y/n): "
                $check = Read-Host
                if ($check -eq "n" -or $check -eq "no") {
                    Write-Host "`nExiting now..."
                    exit 0
                }
            } else {
                Write-Success "MD5 Verification: PASSED"
            }
        }
    } else {
        Write-Danger "`n`tPlease download the release of docker image as per instructions in README.md file. Exiting now...`n`n"
        Start-Sleep 1
        exit 0
    }
}

# Run initial checks
Test-RequiredPorts
Test-TakFolder

if (Test-Path "tak") {
    Write-Danger "Failed to remove the tak folder. You will need to do this as Administrator: .\windowsscripts\cleanup.ps1`n"
    exit 0
}

Test-Checksum

# The actual container setup starts here

# Get release version
$zipFiles = Get-ChildItem -Path "." -Filter "*.zip"
$release = ($zipFiles[0].BaseName -split '\.')[0..1] -join '.'

Write-Warning "`nPausing to let you know release version $release will be setup in 5 seconds.`nIf this is wrong, hit Ctrl-C now..."
Start-Sleep 5

# Set up directory structure
if (Test-Path "$env:TEMP\takserver") {
    Remove-Item -Path "$env:TEMP\takserver" -Recurse -Force
}

# Check for required tools
if (-not (Get-Command "Expand-Archive" -ErrorAction SilentlyContinue)) {
    Write-Danger "`nExpand-Archive cmdlet not available. Please ensure you're running PowerShell 5.0 or later.`n"
    exit 1
}

# Extract the zip file
try {
    Expand-Archive -Path "$release.zip" -DestinationPath "$env:TEMP\takserver" -Force
} catch {
    Write-Danger "`nFailed to extract $release.zip. Error: $($_.Exception.Message)`n"
    exit 1
}

if (-not (Test-Path "$env:TEMP\takserver\$release\tak")) {
    Write-Danger "`nA decompressed folder was NOT found at $env:TEMP\takserver\$release`n"
    Write-Danger "https://github.com/Cloud-RF/tak-server/blob/main/README.md`n"
    exit 1
}

# Move tak folder and set ownership (Windows equivalent)
Move-Item -Path "$env:TEMP\takserver\$release\tak" -Destination ".\tak" -Force

# Copy config file
Copy-Item -Path ".\CoreConfig.xml" -Destination ".\tak\CoreConfig.xml" -Force

# Generate admin username and password
$user = "admin"
$pwd = -join ((65..90) + (97..122) + (48..57) | Get-Random -Count 11 | ForEach-Object {[char]$_})
$password = $pwd + "Meh1!"

# Generate PostgreSQL password
$pgpwd = -join ((65..90) + (97..122) + (48..57) | Get-Random -Count 11 | ForEach-Object {[char]$_})
$pgpassword = $pgpwd + "Meh1!"

# Get IP address
$IP = (Get-NetIPConfiguration | Where-Object { $_.NetAdapter.Status -eq "Up" -and $_.IPv4Address.IPAddress -ne "127.0.0.1" } | Select-Object -First 1).IPv4Address.IPAddress

if (-not $IP) {
    Write-Danger "Could not determine IP address. Please set manually."
    exit 1
}

Write-Info "`nProceeding with IP address: $IP`n"

# Update CoreConfig.xml with passwords and IP (preserving line endings)
$coreConfig = Get-Content ".\tak\CoreConfig.xml" -Raw
$coreConfig = $coreConfig -replace 'password="[^"]*"', "password=`"$pgpassword`""
$coreConfig = $coreConfig -replace 'HOSTIP', $IP
$coreConfig = $coreConfig -replace 'takserver\.jks', "$IP.jks"
[System.IO.File]::WriteAllText(".\tak\CoreConfig.xml", $coreConfig)

# Better memory allocation (preserving Unix line endings)
$mem = "4000000"
if (Test-Path ".\tak\setenv.sh") {
    $setenvContent = Get-Content ".\tak\setenv.sh" -Raw
    $setenvContent = $setenvContent -replace '`awk ''/MemTotal/ {print \$2}'' /proc/meminfo`', $mem
    # Convert to Unix line endings and write
    $setenvContent = $setenvContent -replace "`r`n", "`n"
    [System.IO.File]::WriteAllText(".\tak\setenv.sh", $setenvContent)
}

# Set certificate variables
$country = "GB"
$state = "Warwickshire"
$city = "Coventry"
$orgunit = "TAK"

# Set environment variables
$env:COUNTRY = $country
$env:STATE = $state
$env:CITY = $city
$env:ORGANIZATIONAL_UNIT = $orgunit

# Create .env file for docker-compose
@"
COUNTRY=$country
STATE=$state
CITY=$city
ORGANIZATIONAL_UNIT=$orgunit
"@ | Set-Content ".env"

# Update cert-metadata.sh with configured country (preserving Unix line endings)
if (Test-Path ".\tak\certs\cert-metadata.sh") {
    $certMetadata = Get-Content ".\tak\certs\cert-metadata.sh" -Raw
    $certMetadata = $certMetadata -replace 'COUNTRY=US', 'COUNTRY=${COUNTRY}'
    $certMetadata = $certMetadata -replace "`r`n", "`n"
    [System.IO.File]::WriteAllText(".\tak\certs\cert-metadata.sh", $certMetadata)
}

# Start containers
Write-Host "Starting Docker containers..."
& $DOCKER_COMPOSE --file $DOCKERFILE up --force-recreate -d

# Certificate generation loop
do {
    Start-Sleep 5
    Write-Warning "------------CERTIFICATE GENERATION--------------`n"
    
    # Generate root CA
    $result1 = & $DOCKER_COMPOSE exec tak bash -c "cd /opt/tak/certs && ./makeRootCa.sh --ca-name CRFtakserver"
    if ($LASTEXITCODE -eq 0) {
        # Generate server certificate
        $result2 = & $DOCKER_COMPOSE exec tak bash -c "cd /opt/tak/certs && ./makeCert.sh server $IP"
        if ($LASTEXITCODE -eq 0) {
            # Generate client certificate
            $result3 = & $DOCKER_COMPOSE exec tak bash -c "cd /opt/tak/certs && ./makeCert.sh client $user"
            if ($LASTEXITCODE -eq 0) {
                # Set permissions
                & $DOCKER_COMPOSE exec tak bash -c "chown -R 1000:1000 /opt/tak/certs/"
                break
            }
        } else {
            Start-Sleep 5
        }
    }
} while ($true)

Write-Info "Creating certificates for 2 users in tak/certs/files for a quick setup via TAK's import function`n"

# Make 2 additional users
& $DOCKER_COMPOSE exec tak bash -c "cd /opt/tak/certs && ./makeCert.sh client user1"
& $DOCKER_COMPOSE exec tak bash -c "cd /opt/tak/certs && ./makeCert.sh client user2"
& $DOCKER_COMPOSE exec tak bash -c "chown -R 1000:1000 /opt/tak/certs/"

# Create data packages
& .\windowsscripts\certDP.ps1 $IP user1
& .\windowsscripts\certDP.ps1 $IP user2

Write-Info "Waiting for TAK server to connect to DB. This should loop several times only...`n"
Start-Sleep 5

# Wait for Java initialization and configure user
do {
    Start-Sleep 5
    $result = & $DOCKER_COMPOSE exec tak bash -c "cd /opt/tak/ && java -jar /opt/tak/utils/UserManager.jar usermod -A -p $password $user"
    if ($LASTEXITCODE -eq 0) {
        $result2 = & $DOCKER_COMPOSE exec tak bash -c "cd /opt/tak/ && java -jar utils/UserManager.jar certmod -A certs/files/$user.pem"
        if ($LASTEXITCODE -eq 0) {
            $result3 = & $DOCKER_COMPOSE exec tak bash -c "java -jar /opt/tak/db-utils/SchemaManager.jar upgrade"
            if ($LASTEXITCODE -eq 0) {
                break
            } else {
                Start-Sleep 5
            }
        } else {
            Start-Sleep 5
        }
    } else {
        Write-Info "No joy with DB at $IP, will retry in 5s. If this loops more than 10 times give up.`n"
    }
} while ($true)

# Copy certificate to current directory
Copy-Item -Path ".\tak\certs\files\$user.p12" -Destination "." -Force

# Show final status
& docker container ls

# Final messages
Write-Warning "`n`nImport the $user.p12 certificate from this folder to your browser's certificate store as per the README.md file`n"
Write-Success "Login at https://$IP`:8443 with your admin account. No need to run the /setup step as this has been done.`n"
Write-Info "Certificates and .zip data packages are in tak/certs/files `n`n"
Write-Success "Setup script sponsored by CloudRF.com - `"The API for RF`"`n`n"
Write-Danger "---------PASSWORDS----------------`n`n"
Write-Danger "Admin user name: $user`n"
Write-Danger "Admin password: $password`n"
Write-Danger "PostgreSQL password: $pgpassword`n`n"
Write-Danger "---------PASSWORDS----------------`n`n"
Write-Warning "MAKE A NOTE OF YOUR PASSWORDS. THEY WON'T BE SHOWN AGAIN.`n"
Write-Info "Docker containers should automatically start with the Docker service from now on.`n"
