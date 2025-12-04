#Requires -Version 5.1
<#
.SYNOPSIS
    IMAS-Core Windows Installation Script

.DESCRIPTION
    This script automates the installation of IMAS-Core on Windows systems.
    It handles vcpkg setup, repository cloning, and CMake configuration.

.PARAMETER WorkspaceDir
    The directory where IMAS workspace will be created. Defaults to .\imas_workspace

.PARAMETER InstallPrefix
    The installation prefix for IMAS-Core. Defaults to $HOME\imas-install

.PARAMETER EnablePythonBindings
    Enable Python bindings. Default is $true

.PARAMETER SkipVcpkgBootstrap
    Skip vcpkg bootstrap if already installed. Default is $false

.PARAMETER VSVersion
    Visual Studio version (2022, 2019). Default is auto-detect

.EXAMPLE
    .\Install-IMAS-Windows.ps1
    
.EXAMPLE
    .\Install-IMAS-Windows.ps1 -WorkspaceDir "C:\IMAS" -InstallPrefix "C:\IMAS\install"

.EXAMPLE
    .\Install-IMAS-Windows.ps1 -SkipVcpkgBootstrap -EnablePythonBindings $false
#>

[CmdletBinding()]
param(
    [Parameter(Mandatory=$false)]
    [string]$WorkspaceDir = ".\imas_workspace",
    
    [Parameter(Mandatory=$false)]
    [string]$InstallPrefix = "$HOME\imas-install",
    
    [Parameter(Mandatory=$false)]
    [bool]$EnablePythonBindings = $true,
    
    [Parameter(Mandatory=$false)]
    [bool]$SkipVcpkgBootstrap = $false,
    
    [Parameter(Mandatory=$false)]
    [ValidateSet("2022", "2019", "Auto")]
    [string]$VSVersion = "Auto"
)

# Color output functions
function Write-Success {
    param([string]$Message)
    Write-Host "✓ $Message" -ForegroundColor Green
}

function Write-Info {
    param([string]$Message)
    Write-Host "ℹ $Message" -ForegroundColor Cyan
}

function Write-Warning {
    param([string]$Message)
    Write-Host "⚠ $Message" -ForegroundColor Yellow
}

function Write-Error {
    param([string]$Message)
    Write-Host "✗ $Message" -ForegroundColor Red
}

function Write-Step {
    param([string]$Message)
    Write-Host "`n==== $Message ====" -ForegroundColor Magenta
}

# Error handling
$ErrorActionPreference = "Stop"
trap {
    Write-Error "Installation failed: $_"
    Write-Host "`nPress any key to exit..."
    $null = $Host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown")
    exit 1
}

# Function to find Visual Studio installation
function Find-VisualStudio {
    param([string]$PreferredVersion)
    
    Write-Info "Searching for Visual Studio installation..."
    
    $vsBasePath = "C:\Program Files\Microsoft Visual Studio"
    $versions = @("2022", "2019")
    
    if ($PreferredVersion -ne "Auto") {
        $versions = @($PreferredVersion) + ($versions | Where-Object { $_ -ne $PreferredVersion })
    }
    
    foreach ($version in $versions) {
        $editions = @("Community", "Professional", "Enterprise")
        foreach ($edition in $editions) {
            $vsPath = Join-Path $vsBasePath "$version\$edition"
            if (Test-Path $vsPath) {
                Write-Success "Found Visual Studio $version $edition at: $vsPath"
                return @{
                    Path = $vsPath
                    Version = $version
                    Edition = $edition
                }
            }
        }
    }
    
    Write-Error "Visual Studio not found. Please install Visual Studio 2019 or 2022 with C++ development tools."
    exit 1
}

# Function to find CMake
function Find-CMake {
    param([string]$VSPath)
    
    Write-Info "Searching for CMake..."
    
    # Check if cmake is in PATH
    try {
        $cmakeVersion = & cmake --version 2>$null
        if ($LASTEXITCODE -eq 0) {
            Write-Success "CMake found in PATH"
            return "cmake"
        }
    } catch {}
    
    # Check Visual Studio CMake
    $vsCMakePath = Join-Path $VSPath "Common7\IDE\CommonExtensions\Microsoft\CMake\CMake\bin"
    if (Test-Path (Join-Path $vsCMakePath "cmake.exe")) {
        Write-Success "CMake found in Visual Studio: $vsCMakePath"
        return Join-Path $vsCMakePath "cmake.exe"
    }
    
    Write-Error "CMake not found. Please install CMake or Visual Studio with CMake tools."
    exit 1
}

# Function to find MSVC compiler
function Find-MSVC {
    param([string]$VSPath)
    
    Write-Info "Searching for MSVC compiler..."
    
    $vcToolsPath = Join-Path $VSPath "VC\Tools\MSVC"
    if (Test-Path $vcToolsPath) {
        $msvcVersions = Get-ChildItem $vcToolsPath | Sort-Object Name -Descending
        if ($msvcVersions.Count -gt 0) {
            $latestMSVC = $msvcVersions[0].FullName
            
            # Determine architecture
            $hostArch = if ([Environment]::Is64BitOperatingSystem) { "Hostx64" } else { "Hostx86" }
            $targetArch = if ([Environment]::Is64BitOperatingSystem) { "x64" } else { "x86" }
            
            $compilerPath = Join-Path $latestMSVC "bin\$hostArch\$targetArch"
            if (Test-Path $compilerPath) {
                Write-Success "MSVC compiler found: $compilerPath"
                return $compilerPath
            }
        }
    }
    
    Write-Warning "MSVC compiler path not found, but continuing..."
    return $null
}

# Main installation process
Write-Host @"
╔════════════════════════════════════════════════════════════╗
║                                                            ║
║          IMAS-Core Windows Installation Script            ║
║                                                            ║
╚════════════════════════════════════════════════════════════╝
"@ -ForegroundColor Cyan

Write-Info "Installation Parameters:"
Write-Host "  Workspace Directory: $WorkspaceDir"
Write-Host "  Install Prefix: $InstallPrefix"
Write-Host "  Python Bindings: $EnablePythonBindings"
Write-Host "  Skip vcpkg Bootstrap: $SkipVcpkgBootstrap"
Write-Host ""

# Step 1: Find Visual Studio
Write-Step "Step 1: Detecting Visual Studio"
$vs = Find-VisualStudio -PreferredVersion $VSVersion

# Step 2: Find CMake
Write-Step "Step 2: Detecting CMake"
$cmake = Find-CMake -VSPath $vs.Path

# Step 3: Find MSVC
Write-Step "Step 3: Detecting MSVC Compiler"
$msvc = Find-MSVC -VSPath $vs.Path

# Step 4: Create workspace directory
Write-Step "Step 4: Creating Workspace"
if (Test-Path $WorkspaceDir) {
    Write-Warning "Workspace directory already exists: $WorkspaceDir"
    $response = Read-Host "Do you want to continue? (y/n)"
    if ($response -ne "y") {
        Write-Info "Installation cancelled by user."
        exit 0
    }
} else {
    New-Item -ItemType Directory -Path $WorkspaceDir -Force | Out-Null
    Write-Success "Created workspace directory: $WorkspaceDir"
}

Set-Location $WorkspaceDir
$WorkspaceDir = (Get-Location).Path  # Get absolute path
Write-Info "Working in: $WorkspaceDir"

# Step 5: Setup vcpkg
Write-Step "Step 5: Setting up vcpkg"
$vcpkgDir = Join-Path $WorkspaceDir "vcpkg"

if (Test-Path $vcpkgDir) {
    Write-Warning "vcpkg directory already exists"
    if (-not $SkipVcpkgBootstrap) {
        $response = Read-Host "Do you want to re-bootstrap vcpkg? (y/n)"
        if ($response -eq "y") {
            Set-Location $vcpkgDir
            & .\bootstrap-vcpkg.bat
            if ($LASTEXITCODE -ne 0) {
                throw "vcpkg bootstrap failed"
            }
            Set-Location $WorkspaceDir
        }
    }
} else {
    Write-Info "Cloning vcpkg repository..."
    & git clone https://github.com/microsoft/vcpkg.git
    if ($LASTEXITCODE -ne 0) {
        throw "Failed to clone vcpkg repository"
    }
    Write-Success "vcpkg cloned successfully"
    
    Write-Info "Bootstrapping vcpkg..."
    Set-Location $vcpkgDir
    & .\bootstrap-vcpkg.bat
    if ($LASTEXITCODE -ne 0) {
        throw "vcpkg bootstrap failed"
    }
    Write-Success "vcpkg bootstrapped successfully"
    Set-Location $WorkspaceDir
}

# Step 6: Clone IMAS-Core
Write-Step "Step 6: Cloning IMAS-Core Repository"
$imasCoreDir = Join-Path $WorkspaceDir "IMAS-Core"

if (Test-Path $imasCoreDir) {
    Write-Warning "IMAS-Core directory already exists"
    $response = Read-Host "Do you want to update it? (y/n)"
    if ($response -eq "y") {
        Set-Location $imasCoreDir
        Write-Info "Checking out develop branch..."
        & git checkout develop
        Write-Info "Pulling latest changes..."
        & git pull
        if ($LASTEXITCODE -ne 0) {
            Write-Warning "Git pull failed, continuing anyway..."
        }
        Set-Location $WorkspaceDir
    }
} else {
    Write-Info "Cloning IMAS-Core repository..."
    & git clone https://github.com/iterorganization/IMAS-Core.git
    if ($LASTEXITCODE -ne 0) {
        throw "Failed to clone IMAS-Core repository"
    }
    Write-Success "IMAS-Core cloned successfully"
    
    Set-Location $imasCoreDir
    Write-Info "Checking out develop branch..."
    & git checkout develop
    Set-Location $WorkspaceDir
}

# Step 7: Configure environment variables
Write-Step "Step 7: Configuring Environment"
$env:VCPKG_ROOT = $vcpkgDir
Write-Success "Set VCPKG_ROOT=$env:VCPKG_ROOT"

# Add vcpkg to PATH for this session
if (-not $env:PATH.Contains($vcpkgDir)) {
    $env:PATH += ";$vcpkgDir"
    Write-Success "Added vcpkg to PATH"
}

# Add MSVC to PATH if found
if ($msvc -and -not $env:PATH.Contains($msvc)) {
    $env:PATH += ";$msvc"
    Write-Success "Added MSVC to PATH"
}

# Step 8: Configure CMake
Write-Step "Step 8: Configuring CMake Build"
Set-Location $imasCoreDir

$buildDir = Join-Path $imasCoreDir "build"
if (Test-Path $buildDir) {
    Write-Warning "Build directory already exists"
    $response = Read-Host "Do you want to remove it and reconfigure? (y/n)"
    if ($response -eq "y") {
        Remove-Item -Recurse -Force $buildDir
        Write-Success "Removed old build directory"
    }
}

$vcpkgToolchain = Join-Path $vcpkgDir "scripts\buildsystems\vcpkg.cmake"
Write-Info "Using vcpkg toolchain: $vcpkgToolchain"

$cmakeArgs = @(
    "-Bbuild",
    "-S", ".",
    "-DVCPKG=ON",
    "-DCMAKE_INSTALL_PREFIX=`"$InstallPrefix`"",
    "-DCMAKE_TOOLCHAIN_FILE=`"$vcpkgToolchain`""
)

if ($EnablePythonBindings) {
    $cmakeArgs += "-DAL_PYTHON_BINDINGS=ON"
    Write-Info "Python bindings enabled"
}

Write-Info "Running CMake configuration..."
Write-Host "Command: $cmake $($cmakeArgs -join ' ')" -ForegroundColor Gray

& $cmake @cmakeArgs
if ($LASTEXITCODE -ne 0) {
    throw "CMake configuration failed"
}
Write-Success "CMake configuration completed successfully"

# Step 9: Build and Install
Write-Step "Step 9: Building and Installing IMAS-Core"
Write-Info "This may take a while..."

& $cmake --build build --target install
if ($LASTEXITCODE -ne 0) {
    throw "Build and installation failed"
}
Write-Success "IMAS-Core built and installed successfully!"

# Step 10: Summary
Write-Step "Installation Complete!"
Write-Host @"

╔════════════════════════════════════════════════════════════╗
║                                                            ║
║          Installation Completed Successfully! ✓            ║
║                                                            ║
╚════════════════════════════════════════════════════════════╝

Installation Summary:
  • Workspace: $WorkspaceDir
  • Installation: $InstallPrefix
  • vcpkg: $vcpkgDir
  • IMAS-Core: $imasCoreDir

To use IMAS-Core, you may need to add the following to your PATH:
  $InstallPrefix\bin

Environment Variables (for this session):
  VCPKG_ROOT = $env:VCPKG_ROOT

To make these permanent, add them to your system environment variables.

"@ -ForegroundColor Green

Write-Host "Press any key to exit..."
$null = $Host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown")

