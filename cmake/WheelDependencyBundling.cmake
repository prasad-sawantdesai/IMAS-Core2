# WheelDependencyBundling.cmake
# 
# Intelligent cross-platform handling of runtime dependencies for Python wheels.
# This module provides platform-specific logic for determining which system libraries
# should be bundled in the wheel vs excluded.
#
# Usage:
#   include(WheelDependencyBundling)
#   setup_wheel_dependency_bundling()

include_guard(GLOBAL)

# ==============================================================================
# Platform Detection
# ==============================================================================
if(WIN32)
  set(WHEEL_PLATFORM "Windows")
elseif(APPLE)
  set(WHEEL_PLATFORM "macOS")
else()
  set(WHEEL_PLATFORM "Linux")
endif()

message(STATUS "Python Wheel: Configuring for ${WHEEL_PLATFORM} platform")

# ==============================================================================
# Function: setup_wheel_dependency_bundling
# 
# Configures intelligent runtime dependency bundling based on the target platform.
# This function must be called BEFORE the install(TARGETS ... RUNTIME_DEPENDENCIES)
# ==============================================================================
function(setup_wheel_dependency_bundling)
  # Get library search directories
  if(DEFINED ENV{LD_LIBRARY_PATH})
    string(REPLACE ":" ";" LIBRARY_DIRS $ENV{LD_LIBRARY_PATH})
  else()
    set(LIBRARY_DIRS)
  endif()

  # On macOS, also check homebrew and common installation paths
  if(APPLE AND DEFINED ENV{HOMEBREW_PREFIX})
    list(APPEND LIBRARY_DIRS "$ENV{HOMEBREW_PREFIX}/lib")
  endif()

  # Store in parent scope for use in install() commands
  set(WHEEL_LIBRARY_DIRS "${LIBRARY_DIRS}" PARENT_SCOPE)

  # Configure platform-specific exclusion rules
  if(WHEEL_PLATFORM STREQUAL "Windows")
    configure_windows_bundling()
  elseif(WHEEL_PLATFORM STREQUAL "macOS")
    configure_macos_bundling()
  else()  # Linux
    configure_linux_bundling()
  endif()
endfunction()

# ==============================================================================
# LINUX Configuration
# ==============================================================================
function(configure_linux_bundling)
  message(STATUS "Wheel Bundling: Configuring for Linux (manylinux2014 compatible)")

  # For manylinux wheels, we SHOULD bundle libstdc++ and libgcc
  # They're forward-compatible and ensure the wheel works on older systems
  set(WHEEL_PRE_EXCLUDE_REGEXES
    "api-ms-"                    # Never appear on Linux
    "ext-ms-"                    # Never appear on Linux
    PARENT_SCOPE)

  # System libraries to EXCLUDE (truly system-provided on standard distros)
  set(WHEEL_POST_EXCLUDE_REGEXES
    # Core system libraries that are always available on any Linux
    "^/lib(64)?/ld-"             # Dynamic linker
    "^/lib(64)?/libc\\.so"       # C library
    "^/lib(64)?/libm\\.so"       # Math library
    "^/lib(64)?/libpthread\\.so" # POSIX threads
    "^/lib(64)?/libdl\\.so"      # Dynamic loader
    "^/lib(64)?/libresolv\\.so"  # DNS resolver
    "^/lib(64)?/librt\\.so"      # Real-time library
    "^/lib(64)?/libutil\\.so"    # Utility library
    "^/lib(64)?/libnsl\\.so"     # Network services
    
    # System-specific X11/graphics (usually available)
    "^/usr/lib.*/libX11\\.so"
    "^/usr/lib.*/libGL\\.so"
    "^/usr/lib.*/libglx\\.so"
    
    # Kernel modules
    "^/lib/modules/"
    
    # Intel compiler libraries (exclude if not building with Intel compiler)
    # Uncomment if needed:
    # "iccifort/.*/lib/intel64/lib"
    # ".*/imkl/.*/compiler/.*/linux/compiler/lib"
    PARENT_SCOPE)

  # DO BUNDLE (important for wheel distribution):
  # - libstdc++.so.6         (C++ standard library - different versions have different ABIs)
  # - libgcc_s.so.1          (GCC runtime - needed for stack unwinding, exception handling)
  # - libgomp.so.1           (OpenMP runtime - if using parallel code)
  # - All third-party libraries (HDF5, MDSplus, Boost, UDA, etc.)
  
  message(STATUS "  ✓ Will BUNDLE: libstdc++.so.6, libgcc_s.so.1, libgomp.so.1 (compiler runtimes)")
  message(STATUS "  ✓ Will BUNDLE: All third-party libraries (HDF5, MDSplus, Boost, UDA, etc.)")
  message(STATUS "  ✗ Will EXCLUDE: GLIBC and core system libraries only")
endfunction()

# ==============================================================================
# Windows Configuration
# ==============================================================================
function(configure_windows_bundling)
  message(STATUS "Wheel Bundling: Configuring for Windows (VCPKG managed)")

  # Windows system DLLs to exclude
  set(WHEEL_PRE_EXCLUDE_REGEXES
    # Visual C++ runtime redistributables - user should install these separately
    "api-ms-win-"                # Windows API sets
    "ext-ms-"                    # Windows extensions
    PARENT_SCOPE)

  set(WHEEL_POST_EXCLUDE_REGEXES
    # Windows system directory (never bundle)
    ".*[Ss]ystem32.*\\.dll"
    ".*[Ss]ystem32.*\\.exe"
    ".*[Ww]indows.*\\.dll"
    
    # Visual C++ redistributable runtime (user's responsibility)
    # vcruntime*.dll, msvcp*.dll, etc. (handled by api-ms- prefix above)
    
    # Windows drivers
    ".*\\.sys"
    
    # COM interfaces
    ".*\\.ocx"
    PARENT_SCOPE)

  # DO BUNDLE (on Windows via VCPKG):
  # - All DLLs from VCPKG installation directory
  # - Third-party libraries: HDF5, MDSplus, Boost, UDA, etc.
  # - Note: Visual C++ redistributables should NOT be bundled; users install separately
  
  message(STATUS "  ✓ Will BUNDLE: All DLLs from VCPKG (third-party libraries)")
  message(STATUS "  ✗ Will EXCLUDE: Windows system DLLs")
  message(STATUS "  ⚠ NOTE: Users must install Visual C++ Redistributable separately")
endfunction()

# ==============================================================================
# macOS Configuration
# ==============================================================================
function(configure_macos_bundling)
  message(STATUS "Wheel Bundling: Configuring for macOS (delocate-compatible)")

  set(WHEEL_PRE_EXCLUDE_REGEXES
    "api-ms-"                    # Never appear on macOS
    "ext-ms-"                    # Never appear on macOS
    PARENT_SCOPE)

  # macOS system libraries and frameworks to exclude
  set(WHEEL_POST_EXCLUDE_REGEXES
    # System frameworks (provided by OS)
    "^/System/Library/Frameworks/"
    "^/System/Library/PrivateFrameworks/"
    
    # Core dylibs (provided by OS)
    "^/usr/lib/libSystem"        # C library
    "^/usr/lib/libobjc"          # Objective-C runtime
    "^/usr/lib/libc\\+\\+"       # C++ standard library (system version)
    "^/usr/lib/libc\\+\\+abi"    # C++ ABI library
    "^/usr/lib/libz"             # zlib (usually provided)
    "^/usr/lib/libbz2"           # bzip2 (usually provided)
    "^/usr/lib/libffi"           # FFI library
    "^/usr/lib/libm"             # Math library
    "^/usr/lib/libpthread"       # POSIX threads
    "^/usr/lib/libdl"            # Dynamic loader
    
    # Apple-specific libraries
    "^/usr/lib/libapple_crypto"
    "^/usr/lib/libcups"
    "^/usr/lib/libxar"
    PARENT_SCOPE)

  # DO BUNDLE (on macOS):
  # - All third-party dylibs (HDF5, MDSplus, Boost, UDA, etc.)
  # - Note: Use delocate tool to rewrite @rpath references
  
  message(STATUS "  ✓ Will BUNDLE: All third-party dylibs (HDF5, MDSplus, Boost, UDA, etc.)")
  message(STATUS "  ✗ Will EXCLUDE: macOS system frameworks and core dylibs")
  message(STATUS "  ℹ Use 'delocate-wheel' to fix install names in the final wheel")
endfunction()

# ==============================================================================
# Macro: install_with_bundled_dependencies
#
# Simplified wrapper around install(TARGETS ... RUNTIME_DEPENDENCIES)
# that uses the configured exclusion rules.
#
# Usage:
#   install_with_bundled_dependencies(
#     TARGETS my_target
#     DESTINATION my_destination
#   )
# ==============================================================================
macro(install_with_bundled_dependencies)
  # Parse arguments
  set(options)
  set(oneValueArgs DESTINATION)
  set(multiValueArgs TARGETS)
  cmake_parse_arguments(BUNDLE "${options}" "${oneValueArgs}" "${multiValueArgs}" ${ARGN})

  install(
    TARGETS ${BUNDLE_TARGETS}
    DESTINATION ${BUNDLE_DESTINATION}
    RUNTIME_DEPENDENCIES
      DIRECTORIES ${WHEEL_LIBRARY_DIRS}
      PRE_EXCLUDE_REGEXES ${WHEEL_PRE_EXCLUDE_REGEXES}
      POST_EXCLUDE_REGEXES ${WHEEL_POST_EXCLUDE_REGEXES}
  )
endmacro()

# ==============================================================================
# Diagnostic Functions
# ==============================================================================

# Print current configuration
function(print_wheel_bundling_config)
  message(STATUS "")
  message(STATUS "========== Wheel Dependency Bundling Configuration ==========")
  message(STATUS "Platform: ${WHEEL_PLATFORM}")
  message(STATUS "Library directories: ${WHEEL_LIBRARY_DIRS}")
  message(STATUS "")
  message(STATUS "PRE_EXCLUDE_REGEXES (applied before searching):")
  foreach(regex ${WHEEL_PRE_EXCLUDE_REGEXES})
    message(STATUS "  - ${regex}")
  endforeach()
  message(STATUS "")
  message(STATUS "POST_EXCLUDE_REGEXES (applied after searching):")
  foreach(regex ${WHEEL_POST_EXCLUDE_REGEXES})
    message(STATUS "  - ${regex}")
  endforeach()
  message(STATUS "==============================================================")
  message(STATUS "")
endfunction()
