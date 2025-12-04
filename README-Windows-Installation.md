# IMAS-Core Windows Installation Guide

This guide provides instructions for installing IMAS-Core on Windows systems.

## 📋 Prerequisites

Before installing IMAS-Core, ensure you have:

1. **Git** - [Download Git for Windows](https://git-scm.com/download/win)
2. **Visual Studio 2019 or 2022** with:
   - Desktop development with C++
   - CMake tools for Windows
   - Windows 10/11 SDK
3. **PowerShell 5.1 or later** (included with Windows 10/11)

## 🚀 Quick Start - Automated Installation

### Option 1: Run the PowerShell Script (Recommended)

The easiest way to install IMAS-Core is using the automated PowerShell script:

```powershell
# Download and run the installation script
.\Install-IMAS-Windows.ps1
```

### Script Options

The script supports various parameters for customization:

```powershell
# Basic installation with defaults
.\Install-IMAS-Windows.ps1

# Custom workspace and installation directories
.\Install-IMAS-Windows.ps1 -WorkspaceDir "C:\IMAS" -InstallPrefix "C:\IMAS\install"

# Disable Python bindings
.\Install-IMAS-Windows.ps1 -EnablePythonBindings $false

# Skip vcpkg bootstrap (if already installed)
.\Install-IMAS-Windows.ps1 -SkipVcpkgBootstrap

# Specify Visual Studio version
.\Install-IMAS-Windows.ps1 -VSVersion "2022"
```

### Script Parameters

| Parameter | Description | Default |
|-----------|-------------|---------|
| `-WorkspaceDir` | Directory for IMAS workspace | `.\imas_workspace` |
| `-InstallPrefix` | Installation directory | `$HOME\imas-install` |
| `-EnablePythonBindings` | Enable Python bindings | `$true` |
| `-SkipVcpkgBootstrap` | Skip vcpkg bootstrap | `$false` |
| `-VSVersion` | Visual Studio version (2022, 2019, Auto) | `Auto` |

## 📝 Manual Installation

If you prefer to install manually or need more control, follow these steps:

### Step 1: Create Workspace

```powershell
mkdir imas_workspace
cd .\imas_workspace\
```

### Step 2: Setup vcpkg

```powershell
# Clone vcpkg
git clone https://github.com/microsoft/vcpkg.git
cd .\vcpkg\

# Bootstrap vcpkg
.\bootstrap-vcpkg.bat

cd ..
```

### Step 3: Clone IMAS-Core

```powershell
# Clone repository
git clone https://github.com/iterorganization/IMAS-Core.git
cd .\IMAS-Core\

# Checkout develop branch
git checkout develop
```

### Step 4: Configure Environment

```powershell
# Set VCPKG_ROOT (adjust path to your location)
$env:VCPKG_ROOT = "C:\Users\YourUsername\imas_workspace\vcpkg"

# Add vcpkg to PATH
$env:PATH += ";$env:VCPKG_ROOT"
```

### Step 5: Configure Build

```powershell
# Configure CMake (adjust paths as needed)
cmake -Bbuild -S . `
  -DVCPKG=ON `
  -DAL_PYTHON_BINDINGS=ON `
  -DCMAKE_INSTALL_PREFIX="C:\Users\YourUsername\imas-install" `
  -DCMAKE_TOOLCHAIN_FILE="$env:VCPKG_ROOT\scripts\buildsystems\vcpkg.cmake"
```

### Step 6: Build and Install

```powershell
# Build and install
cmake --build build --target install
```

## 🔧 Configuration Options

### CMake Build Options

- `-DVCPKG=ON` - Use vcpkg for dependency management
- `-DAL_PYTHON_BINDINGS=ON` - Enable Python bindings (requires Python)
- `-DCMAKE_INSTALL_PREFIX` - Installation directory
- `-DCMAKE_TOOLCHAIN_FILE` - Path to vcpkg toolchain file

### Build Types

```powershell
# Debug build
cmake -Bbuild -DCMAKE_BUILD_TYPE=Debug ...

# Release build (default)
cmake -Bbuild -DCMAKE_BUILD_TYPE=Release ...
```

## 🔄 Updating IMAS-Core

To update an existing installation:

```powershell
cd C:\Users\YourUsername\imas_workspace\IMAS-Core

# Pull latest changes
git checkout develop
git pull

# Rebuild and install
cmake --build build --target install
```

## 🐛 Troubleshooting

### CMake Not Found

**Problem:** CMake is not recognized as a command.

**Solution:**
1. Install CMake from [cmake.org](https://cmake.org/download/), OR
2. Add Visual Studio's CMake to PATH:
   ```powershell
   $env:PATH += ";C:\Program Files\Microsoft Visual Studio\2022\Community\Common7\IDE\CommonExtensions\Microsoft\CMake\CMake\bin"
   ```

### vcpkg Bootstrap Fails

**Problem:** `bootstrap-vcpkg.bat` fails to run.

**Solution:**
1. Ensure Visual Studio C++ tools are installed
2. Run PowerShell as Administrator
3. Check that you have internet connectivity for downloading dependencies

### CMake Configuration Fails

**Problem:** CMake configuration step fails.

**Solution:**
1. Verify all paths are correct (no typos)
2. Remove build directory and try again:
   ```powershell
   Remove-Item -Recurse -Force build
   ```
3. Check that `VCPKG_ROOT` is set correctly:
   ```powershell
   echo $env:VCPKG_ROOT
   ```

### Build Fails

**Problem:** Build fails during compilation.

**Solution:**
1. Ensure vcpkg dependencies installed correctly
2. Check error messages for specific missing dependencies
3. Verify sufficient disk space (vcpkg can require several GB)
4. Try cleaning and rebuilding:
   ```powershell
   cmake --build build --target clean
   cmake --build build --target install
   ```

### Python Bindings Issues

**Problem:** Python bindings fail to build.

**Solution:**
1. Ensure Python is installed and in PATH
2. Disable Python bindings if not needed:
   ```powershell
   cmake -Bbuild -DAL_PYTHON_BINDINGS=OFF ...
   ```

## 📁 Directory Structure

After installation, your directory structure will look like:

```
imas_workspace/
├── vcpkg/                    # vcpkg package manager
│   ├── vcpkg.exe
│   └── scripts/
│       └── buildsystems/
│           └── vcpkg.cmake
└── IMAS-Core/                # IMAS-Core source
    ├── build/                # Build directory
    └── ...

imas-install/                 # Installation directory
├── bin/                      # Executables
├── lib/                      # Libraries
└── include/                  # Headers
```

## 🔐 Environment Variables

For permanent installation, add these to your system environment variables:

1. **VCPKG_ROOT**: Path to vcpkg directory
   - Example: `C:\Users\YourUsername\imas_workspace\vcpkg`

2. **PATH**: Add installation bin directory
   - Example: `C:\Users\YourUsername\imas-install\bin`

### Setting Permanent Environment Variables

1. Open System Properties (Win + Pause/Break)
2. Click "Advanced system settings"
3. Click "Environment Variables"
4. Add or modify variables as needed

## 📚 Additional Resources

- [IMAS-Core Repository](https://github.com/iterorganization/IMAS-Core)
- [vcpkg Documentation](https://vcpkg.io/)
- [CMake Documentation](https://cmake.org/documentation/)

## 💡 Tips

1. **Disk Space**: Ensure you have at least 10 GB of free disk space
2. **Antivirus**: Some antivirus software may slow down vcpkg; consider adding exceptions
3. **Build Time**: First build can take 30-60 minutes depending on your system
4. **Parallel Builds**: Use `-j` flag to speed up builds:
   ```powershell
   cmake --build build --target install -j 8
   ```

## 📞 Support

For issues and questions:
- Check the troubleshooting section above
- Review `WINDOWS_INSTALL_COMMANDS.txt` for detailed command reference
- Open an issue on the IMAS-Core GitHub repository

## 📄 Files Included

- `Install-IMAS-Windows.ps1` - Automated installation script
- `WINDOWS_INSTALL_COMMANDS.txt` - Manual command reference
- `README-Windows-Installation.md` - This file

---

**Note:** Replace `YourUsername` and paths in examples with your actual Windows username and desired installation locations.

