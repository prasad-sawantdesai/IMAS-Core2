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

# Error handling
$ErrorActionPreference = "Stop"
trap {
    Write-Host "? Installation failed: $_" -ForegroundColor Red
    Write-Host "At: $($_.InvocationInfo.ScriptName):$($_.InvocationInfo.ScriptLineNumber)" -ForegroundColor Yellow
    Write-Host "`nPress any key to exit..."
    $null = $Host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown")
    exit 1
}

# Function to find Visual Studio installation
function Find-VisualStudio {
    param([string]$PreferredVersion)
    
    Write-Host "? Searching for Visual Studio installation..." -ForegroundColor Cyan
    
    # First, try using vswhere.exe (recommended method)
    $vswherePath = "C:\Program Files (x86)\Microsoft Visual Studio\Installer\vswhere.exe"
    if (Test-Path $vswherePath) {
        try {
            $vsPath = & $vswherePath -latest -property installationPath 2>$null
            if ($vsPath -and (Test-Path $vsPath)) {
                $vsVersion = & $vswherePath -latest -property installationVersion 2>$null
                $vsEdition = Split-Path $vsPath -Leaf
                Write-Host "? Found Visual Studio at: $vsPath" -ForegroundColor Green
                Write-Host "  Version: $vsVersion, Edition: $vsEdition" -ForegroundColor Gray
                return @{
                    Path = $vsPath
                    Version = $vsVersion
                    Edition = $vsEdition
                }
            }
        } catch {
            Write-Host "? vswhere.exe failed, trying manual detection..." -ForegroundColor Yellow
        }
    }
    
    # Fallback: Manual detection
    $basePaths = @(
        "C:\Program Files\Microsoft Visual Studio",
        "C:\Program Files (x86)\Microsoft Visual Studio"
    )
    
    $versions = @("2022", "2019", "18", "17", "16")
    
    if ($PreferredVersion -ne "Auto") {
        $versions = @($PreferredVersion) + ($versions | Where-Object { $_ -ne $PreferredVersion })
    }
    
    foreach ($basePath in $basePaths) {
        if (-not (Test-Path $basePath)) { continue }
        
        foreach ($version in $versions) {
            $editions = @("Community", "Professional", "Enterprise")
            foreach ($edition in $editions) {
                $vsPath = Join-Path $basePath "$version\$edition"
                if (Test-Path $vsPath) {
                    Write-Host "? Found Visual Studio $version $edition at: $vsPath" -ForegroundColor Green
                    return @{
                        Path = $vsPath
                        Version = $version
                        Edition = $edition
                    }
                }
            }
        }
    }
    
    Write-Host "? Visual Studio not found. Please install Visual Studio 2019 or 2022 with C++ development tools." -ForegroundColor Red
    exit 1
}

# Function to find CMake
function Find-CMake {
    param([string]$VSPath)
    
    Write-Host "? Searching for CMake..." -ForegroundColor Cyan
    
    # Check if cmake is in PATH
    try {
        $cmakeVersion = & cmake --version 2>$null
        if ($LASTEXITCODE -eq 0) {
            Write-Host " CMake found in PATH" -ForegroundColor Green
            return "cmake"
        }
    } catch {}
    
    # Check Visual Studio CMake
    $vsCMakePath = Join-Path $VSPath "Common7\IDE\CommonExtensions\Microsoft\CMake\CMake\bin"
    if (Test-Path (Join-Path $vsCMakePath "cmake.exe")) {
        Write-Host " CMake found in Visual Studio: $vsCMakePath" -ForegroundColor Green
        return Join-Path $vsCMakePath "cmake.exe"
    }
    
    Write-Host " CMake not found. Please install CMake or Visual Studio with CMake tools." -ForegroundColor Red
    exit 1
}

# Function to find MSVC compiler
function Find-MSVC {
    param([string]$VSPath)
    
    Write-Host "? Searching for MSVC compiler..." -ForegroundColor Cyan
    
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
                Write-Host " MSVC compiler found: $compilerPath" -ForegroundColor Green
                return $compilerPath
            }
        }
    }
    
    Write-Host " MSVC compiler path not found, but continuing..." -ForegroundColor Yellow
    return $null
}

# Main function
function Start-Installation {
    # Main installation process
    Write-Host @"
    +------------------------------------------------------------+
                                                               
              IMAS-Core Windows Installation Script            
                                                               
    +------------------------------------------------------------+
"@ -ForegroundColor Cyan

    Write-Host "? Installation Parameters:" -ForegroundColor Cyan
    Write-Host "  Workspace Directory: $WorkspaceDir"
    Write-Host "  Install Prefix: $InstallPrefix"
    Write-Host "  Python Bindings: $EnablePythonBindings"
    Write-Host "  Skip vcpkg Bootstrap: $SkipVcpgBootstrap"
    Write-Host ""

    # Step 1: Find Visual Studio
    Write-Host "`n==== Step 1: Detecting Visual Studio ====" -ForegroundColor Magenta
    $vs = Find-VisualStudio -PreferredVersion $VSVersion

    # Step 2: Find CMake
    Write-Host "`n==== Step 2: Detecting CMake ====" -ForegroundColor Magenta
    $cmake = Find-CMake -VSPath $vs.Path

# Step 3: Find MSVC
    Write-Host "`n==== Step 3: Detecting MSVC Compiler ====" -ForegroundColor Magenta
    $msvc = Find-MSVC -VSPath $vs.Path

# Step 4: Create workspace directory
    Write-Host "`n==== Step 4: Creating Workspace ====" -ForegroundColor Magenta
    if (Test-Path $WorkspaceDir) {
    Write-Host " Workspace directory already exists: $WorkspaceDir" -ForegroundColor Yellow
    $response = Read-Host "Do you want to continue? (y/n)"
    if ($response -ne "y") {
        Write-Host "? Installation cancelled by user." -ForegroundColor Cyan
        exit 0
    }
    } else {
    New-Item -ItemType Directory -Path $WorkspaceDir -Force | Out-Null
    Write-Host " Created workspace directory: $WorkspaceDir" -ForegroundColor Green
}

Set-Location $WorkspaceDir
$WorkspaceDir = (Get-Location).Path  # Get absolute path
Write-Host "? Working in: $WorkspaceDir" -ForegroundColor Cyan

# Step 5: Setup vcpkg
Write-Host "`n==== Step 5: Setting up vcpkg ====" -ForegroundColor Magenta
$vcpkgDir = Join-Path $WorkspaceDir "vcpkg"

if (Test-Path $vcpkgDir) {
    Write-Host " vcpkg directory already exists" -ForegroundColor Yellow
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
    Write-Host "? Cloning vcpkg repository..." -ForegroundColor Cyan
    & git clone https://github.com/microsoft/vcpkg.git
    if ($LASTEXITCODE -ne 0) {
        throw "Failed to clone vcpkg repository"
    }
    Write-Host " vcpkg cloned successfully" -ForegroundColor Green
    
    Write-Host "? Bootstrapping vcpkg..." -ForegroundColor Cyan
    Set-Location $vcpkgDir
    & .\bootstrap-vcpkg.bat
    if ($LASTEXITCODE -ne 0) {
        throw "vcpkg bootstrap failed"
    }
    Write-Host " vcpkg bootstrapped successfully" -ForegroundColor Green
    Set-Location $WorkspaceDir
}

# Step 6: Clone IMAS-Core
Write-Host "`n==== Step 6: Cloning IMAS-Core Repository ====" -ForegroundColor Magenta
$imasCoreDir = Join-Path $WorkspaceDir "IMAS-Core"

if (Test-Path $imasCoreDir) {
    Write-Host " IMAS-Core directory already exists" -ForegroundColor Yellow
    $response = Read-Host "Do you want to update it? (y/n)"
    if ($response -eq "y") {
        Set-Location $imasCoreDir
        Write-Host "? Checking out develop branch..." -ForegroundColor Cyan
        & git checkout develop
        Write-Host "? Pulling latest changes..." -ForegroundColor Cyan
        & git pull
        if ($LASTEXITCODE -ne 0) {
            Write-Host " Git pull failed, continuing anyway..." -ForegroundColor Yellow
        }
        Set-Location $WorkspaceDir
    }
} else {
    Write-Host "? Cloning IMAS-Core repository..." -ForegroundColor Cyan
    & git clone https://github.com/iterorganization/IMAS-Core.git
    if ($LASTEXITCODE -ne 0) {
        throw "Failed to clone IMAS-Core repository"
    }
    Write-Host " IMAS-Core cloned successfully" -ForegroundColor Green
    
    Set-Location $imasCoreDir
    Write-Host "? Checking out develop branch..." -ForegroundColor Cyan
    & git checkout develop
    Set-Location $WorkspaceDir
}

# Step 7: Configure environment variables
Write-Host "`n==== Step 7: Configuring Environment ====" -ForegroundColor Magenta
$env:VCPKG_ROOT = $vcpkgDir
Write-Host " Set VCPKG_ROOT=$env:VCPKG_ROOT" -ForegroundColor Green

# Add vcpkg to PATH for this session
if (-not $env:PATH.Contains($vcpkgDir)) {
    $env:PATH += ";$vcpkgDir"
    Write-Host " Added vcpkg to PATH" -ForegroundColor Green
}

# Add MSVC to PATH if found
if ($msvc -and -not $env:PATH.Contains($msvc)) {
    $env:PATH += ";$msvc"
    Write-Host " Added MSVC to PATH" -ForegroundColor Green
}

# Step 8: Configure CMake
Write-Host "`n==== Step 8: Configuring CMake Build ====" -ForegroundColor Magenta
Set-Location $imasCoreDir

$buildDir = Join-Path $imasCoreDir "build"
if (Test-Path $buildDir) {
    Write-Host " Build directory already exists" -ForegroundColor Yellow
    $response = Read-Host "Do you want to remove it and reconfigure? (y/n)"
    if ($response -eq "y") {
        Remove-Item -Recurse -Force $buildDir
        Write-Host " Removed old build directory" -ForegroundColor Green
    }
}

$vcpkgToolchain = Join-Path $vcpkgDir "scripts\buildsystems\vcpkg.cmake"
# Convert to forward slashes for CMake
$vcpkgToolchain = $vcpkgToolchain -replace '\\', '/'
$InstallPrefixCMake = $InstallPrefix -replace '\\', '/'

Write-Host "? Using vcpkg toolchain: $vcpkgToolchain" -ForegroundColor Cyan

$cmakeArgs = @(
    "-Bbuild"
    "-S."
    "-DVCPKG=ON"
    "-DCMAKE_INSTALL_PREFIX=$InstallPrefixCMake"
    "-DCMAKE_TOOLCHAIN_FILE=$vcpkgToolchain"
    "-DAL_BACKEND_UDA=OFF"
    "-DAL_BACKEND_MDSPLUS=OFF"
    "-DAL_BACKEND_HDF5=ON"
)

if ($EnablePythonBindings) {
    $cmakeArgs += "-DAL_PYTHON_BINDINGS=ON"
    Write-Host "? Python bindings enabled" -ForegroundColor Cyan
}

Write-Host "? Running CMake configuration..." -ForegroundColor Cyan
Write-Host "Command: $cmake $($cmakeArgs -join ' ')" -ForegroundColor Gray

& $cmake @cmakeArgs
if ($LASTEXITCODE -ne 0) {
    throw "CMake configuration failed"
}
Write-Host " CMake configuration completed successfully" -ForegroundColor Green

# Step 9: Build and Install
Write-Host "`n==== Step 9: Building and Installing IMAS-Core ====" -ForegroundColor Magenta
Write-Host "? This may take a while..." -ForegroundColor Cyan

& $cmake --build build --target install
if ($LASTEXITCODE -ne 0) {
    throw "Build and installation failed"
}
Write-Host " IMAS-Core built and installed successfully!" -ForegroundColor Green

# Step 10: Summary
Write-Host "`n==== Installation Complete! ====" -ForegroundColor Magenta
Write-Host @"

+------------------------------------------------------------+
                                                           
          Installation Completed Successfully! ?           
                                                           
+------------------------------------------------------------+

Installation Summary:
    Workspace: $WorkspaceDir
    Installation: $InstallPrefix
    vcpkg: $vcpkgDir
    IMAS-Core: $imasCoreDir

To use IMAS-Core, you may need to add the following to your PATH:
  $InstallPrefix\bin

Environment Variables (for this session):
  VCPKG_ROOT = $env:VCPKG_ROOT

To make these permanent, add them to your system environment variables.

"@ -ForegroundColor Green

    Write-Host "Press any key to exit..."
    $null = $Host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown")
}

# Execute the main installation function
Start-Installation

