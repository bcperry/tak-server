# TAK Certificate Data Package Creation Script for Windows PowerShell
# Makes an ATAK / iTAK friendly data package containing CA, user cert, user key

param(
    [Parameter(Mandatory=$true)]
    [string]$IP,
    [Parameter(Mandatory=$true)]
    [string]$USER
)

if (-not $IP -or -not $USER) {
    Write-Host "No arguments supplied. Need an IP and a user eg. .\windowsscripts\certDP.ps1 192.168.0.2 user1"
    exit
}

# Create server.pref file
$serverPref = @"
<?xml version='1.0' encoding='ASCII' standalone='yes'?>
<preferences>
  <preference version="1" name="cot_streams">
    <entry key="count" class="class java.lang.Integer">1</entry>
    <entry key="description0" class="class java.lang.String">TAK Server</entry>
    <entry key="enabled0" class="class java.lang.Boolean">true</entry>
    <entry key="connectString0" class="class java.lang.String">$IP`:8089:ssl</entry>
  </preference>
  <preference version="1" name="com.atakmap.app_preferences">
    <entry key="displayServerConnectionWidget" class="class java.lang.Boolean">true</entry>
    <entry key="caLocation" class="class java.lang.String">cert/$IP.p12</entry>
    <entry key="caPassword" class="class java.lang.String">atakatak</entry>
    <entry key="clientPassword" class="class java.lang.String">atakatak</entry>
    <entry key="certificateLocation" class="class java.lang.String">cert/$USER.p12</entry>
  </preference>
</preferences>
"@

$serverPref | Out-File -FilePath "server.pref" -Encoding ASCII

# Create manifest.xml file
$manifest = @"
<MissionPackageManifest version="2">
  <Configuration>
    <Parameter name="uid" value="sponsored-by-cloudrf-the-api-for-rf"/>
    <Parameter name="name" value="$USER DP"/>
    <Parameter name="onReceiveDelete" value="true"/>
  </Configuration>
  <Contents>
    <Content ignore="false" zipEntry="certs\server.pref"/>
    <Content ignore="false" zipEntry="certs\$IP.p12"/>
    <Content ignore="false" zipEntry="certs\$USER.p12"/>
  </Contents>
</MissionPackageManifest>
"@

$manifest | Out-File -FilePath "manifest.xml" -Encoding ASCII

# Create the data package zip file
$zipPath = "tak\certs\files\$USER-$IP.dp.zip"

# Ensure the directory exists
$zipDir = Split-Path $zipPath -Parent
if (-not (Test-Path $zipDir)) {
    New-Item -Path $zipDir -ItemType Directory -Force | Out-Null
}

# Create temporary directory for zip contents
$tempDir = New-TemporaryFile | ForEach-Object { Remove-Item $_; New-Item -ItemType Directory -Path $_ }

try {
    # Copy files to temp directory
    Copy-Item "manifest.xml" "$tempDir\manifest.xml"
    Copy-Item "server.pref" "$tempDir\server.pref"
    Copy-Item "tak\certs\files\$IP.p12" "$tempDir\$IP.p12"
    Copy-Item "tak\certs\files\$USER.p12" "$tempDir\$USER.p12"
    
    # Create zip file
    Compress-Archive -Path "$tempDir\*" -DestinationPath $zipPath -Force
    
    Write-Host "-------------------------------------------------------------"
    Write-Host "Created certificate data package for $USER @ $IP as $zipPath"
    
} finally {
    # Clean up temporary files
    Remove-Item "manifest.xml" -ErrorAction SilentlyContinue
    Remove-Item "server.pref" -ErrorAction SilentlyContinue
    Remove-Item $tempDir -Recurse -Force -ErrorAction SilentlyContinue
}
