# PowerShell Script to Generate Android Keystore (Non-Interactive)
# Usage: .\generate-keystore.ps1

param(
    [string]$KeystorePassword = $env:KEYSTORE_PASSWORD,
    [string]$KeyPassword = $env:KEY_PASSWORD,
    [string]$KeystorePath = "upload-keystore.jks",
    [string]$Alias = "upload",
    [string]$Name = "Md Sadique Alam",
    [string]$OrganizationalUnit = "5",
    [string]$Organization = "Meatvo",
    [string]$City = "Bokaro",
    [string]$State = "Jharkhand",
    [string]$CountryCode = "IN"
)

Write-Host "========================================" -ForegroundColor Cyan
Write-Host "Android Keystore Generator" -ForegroundColor Cyan
Write-Host "========================================" -ForegroundColor Cyan
Write-Host ""

# Check if keystore already exists
if (Test-Path $KeystorePath) {
    Write-Host "WARNING: Keystore file already exists: $KeystorePath" -ForegroundColor Yellow
    $overwrite = Read-Host "Do you want to overwrite it? (yes/no)"
    if ($overwrite -ne "yes") {
        Write-Host "Operation cancelled." -ForegroundColor Red
        exit 1
    }
    Remove-Item $KeystorePath -Force
    Write-Host "Existing keystore removed." -ForegroundColor Green
}

# Check if password is provided
if ([string]::IsNullOrEmpty($KeystorePassword)) {
    Write-Host "ERROR: Keystore password not provided!" -ForegroundColor Red
    Write-Host ""
    Write-Host "Please set environment variable (recommended):" -ForegroundColor Yellow
    Write-Host "  `$env:KEYSTORE_PASSWORD = '<your-keystore-password>'" -ForegroundColor Yellow
    Write-Host ""
    Write-Host "Or pass as parameter (avoid shell history):" -ForegroundColor Yellow
    Write-Host "  .\generate-keystore.ps1 -KeystorePassword (Read-Host -AsSecureString)" -ForegroundColor Yellow
    Write-Host ""
    Write-Host "For security, you can also enter it now (will not be displayed):" -ForegroundColor Yellow
    $securePassword = Read-Host "Enter keystore password" -AsSecureString
    $KeystorePassword = [Runtime.InteropServices.Marshal]::PtrToStringAuto(
        [Runtime.InteropServices.Marshal]::SecureStringToBSTR($securePassword)
    )
}

# Use key password same as keystore password if not provided
if ([string]::IsNullOrEmpty($KeyPassword)) {
    $KeyPassword = $KeystorePassword
}

Write-Host "Configuration:" -ForegroundColor Cyan
Write-Host "  Keystore Path: $KeystorePath" -ForegroundColor Gray
Write-Host "  Alias: $Alias" -ForegroundColor Gray
Write-Host "  Name: $Name" -ForegroundColor Gray
Write-Host "  Organization: $Organization" -ForegroundColor Gray
Write-Host "  Location: $City, $State, $CountryCode" -ForegroundColor Gray
Write-Host ""

# Build the distinguished name (DN)
$DN = "CN=$Name, OU=$OrganizationalUnit, O=$Organization, L=$City, ST=$State, C=$CountryCode"

Write-Host "Generating keystore..." -ForegroundColor Yellow

try {
    # Use direct keytool execution with & operator for better argument handling
    Write-Host "Running keytool command..." -ForegroundColor Gray
    
    # Capture output
    $output = & keytool -genkey -v `
        -keystore $KeystorePath `
        -keyalg RSA `
        -keysize 2048 `
        -validity 10000 `
        -alias $Alias `
        -dname $DN `
        -storepass $KeystorePassword `
        -keypass $KeyPassword `
        2>&1
    
    $exitCode = $LASTEXITCODE
    # Separate stdout and stderr from output
    $stdout = @()
    $stderr = @()
    foreach ($line in $output) {
        if ($line -is [System.Management.Automation.ErrorRecord]) {
            $stderr += $line.ToString()
        } elseif ($line -is [string] -and $line -notmatch "password") {
            $stdout += $line
        }
    }
    
    if ($exitCode -eq 0) {
        Write-Host ""
        Write-Host "SUCCESS: Keystore generated successfully!" -ForegroundColor Green
        Write-Host ""
        
        if (Test-Path $KeystorePath) {
            $fullPath = (Resolve-Path $KeystorePath).Path
            Write-Host "Location: $fullPath" -ForegroundColor Cyan
            Write-Host ""
            
            # Display keystore info
            Write-Host "Keystore Information:" -ForegroundColor Cyan
            $infoOutput = & keytool -list -v -keystore $KeystorePath -alias $Alias -storepass $KeystorePassword 2>&1
            if ($LASTEXITCODE -eq 0) {
                Write-Host $infoOutput
            }
            
            Write-Host ""
            Write-Host "IMPORTANT SECURITY NOTES:" -ForegroundColor Yellow
            Write-Host "  1. Keep your keystore password safe and secure!" -ForegroundColor Yellow
            Write-Host "  2. Add '$KeystorePath' to .gitignore" -ForegroundColor Yellow
            Write-Host "  3. Backup the keystore file in a secure location" -ForegroundColor Yellow
            Write-Host "  4. Never commit keystore to version control" -ForegroundColor Yellow
            Write-Host ""
        } else {
            Write-Host "WARNING: Keystore file not found after generation" -ForegroundColor Yellow
        }
    } else {
        Write-Host ""
        Write-Host "ERROR: Failed to generate keystore" -ForegroundColor Red
        if ($stderr) {
            Write-Host "Error details:" -ForegroundColor Red
            Write-Host $stderr -ForegroundColor Red
        }
        if ($stdout) {
            Write-Host "Output:" -ForegroundColor Yellow
            Write-Host $stdout -ForegroundColor Yellow
        }
        exit 1
    }
} catch {
    Write-Host ""
    Write-Host "ERROR occurred during keystore generation" -ForegroundColor Red
    Write-Host "Details: $($_.Exception.Message)" -ForegroundColor Red
    exit 1
}
