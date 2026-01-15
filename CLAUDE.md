# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Repository Overview

This is a Gentoo Portage overlay containing custom ebuilds for packages not yet in the main Gentoo tree or with modifications. Current packages include OpenVPN 3 Linux stack and KeePassXC password manager.

## Package Structure

The overlay contains the following packages:

### dev-libs/gdbuspp
- **Current version**: 3.ebuild
- **Description**: GDBus++ - C++ wrapper for GLib's GDBus functionality
- **Purpose**: Dependency for OpenVPN 3 Linux

### dev-libs/openvpn3-core
- **Current versions**: 3.10.4.ebuild, 3.11.1.ebuild
- **Description**: OpenVPN 3 Core Library - C++ library for OpenVPN 3 client
- **Purpose**: Core library used by OpenVPN 3 Linux
- **Note**: Version 3.10.4 is specifically for compatibility with openvpn3-linux v24

### net-vpn/openvpn3-linux
- **Current version**: 24.ebuild
- **Description**: OpenVPN 3 Linux - Next generation OpenVPN client
- **Dependencies**: Specifically depends on openvpn3-core-3.10.4 for compatibility
- **Features**: D-Bus based architecture, systemd integration, modern C++ implementation

### app-admin/keepassxc
- **Current version**: 2.7.10-r2.ebuild
- **Description**: KeePassXC - KeePass Cross-platform Community Edition password manager
- **Build system**: CMake
- **USE flags**: X, autotype, browser, doc, keeshare, keyring (default), network (default), ssh-agent (default), test, yubikey
- **Why 2.7.10**: Version 2.7.11 has an Auto-Type regression bug (https://github.com/keepassxreboot/keepassxc/issues/12723)
- **Note**: Ebuild and patches imported from Gentoo main tree with unbundled zxcvbn

## Recent Changes and Fixes

### KeePassXC (2.7.10-r2)
- **Added**: New package app-admin/keepassxc-2.7.10-r2
- **Reason**: Version 2.7.11 has Auto-Type regression (upstream issue #12723)
- **Patches**: cmake_minimum, tests, zxcvbn patches from Gentoo main tree
- **Feature**: Unbundled zxcvbn library for better security

### OpenVPN 3 Core Library (3.10.4)
- **Created**: openvpn3-core-3.10.4.ebuild for compatibility with openvpn3-linux v24
- **Fixed**: Documentation file reference from README.md to README.rst
- **Added**: Installation of test directory (needed for openvpn3-linux build)
- **Fixed**: Both 3.10.4 and 3.11.1 ebuilds updated with same fixes

### OpenVPN 3 Linux (v24)
- **Fixed**: Dependency constraint to use specific openvpn3-core-3.10.4 version instead of latest
- **Fixed**: Removed manual D-Bus policy file installation (handled by meson automatically)
- **Fixed**: Removed manual systemd service file installation (handled by meson automatically)
- **Removed**: Commented out problematic patch application
- **Simplified**: Installation process relies on meson's automatic file handling

## Development Workflow

### Testing Packages
```bash
# Test individual packages
ebuild package-version.ebuild clean unpack
ebuild package-version.ebuild manifest
emerge -pv package-name

# Test dependencies
emerge -pvt openvpn3-linux
```

### Making Changes
```bash
# After modifying an ebuild
ebuild package-version.ebuild manifest
git add package-category/package-name/
git commit -m "descriptive message"
git push
```

### Common Issues and Solutions

1. **Missing files during installation**: Check if meson is already handling the installation automatically
2. **Dependency version conflicts**: Use specific version constraints (e.g., =dev-libs/openvpn3-core-3.10.4*)
3. **Build failures**: Ensure all required headers and test files are installed by dependencies

## Package Dependencies

```
openvpn3-linux-24
├── =dev-libs/openvpn3-core-3.10.4*  (specific version required)
├── dev-libs/gdbuspp:=
├── dev-libs/jsoncpp:=
├── dev-libs/openssl:=
├── dev-libs/tinyxml2:=
├── dev-libs/libnl:3
├── sys-libs/libcap-ng
└── sys-apps/systemd (if USE=systemd)
```

## Build System Notes

- **OpenVPN 3 Core**: Uses CMake, mostly header-only library
- **OpenVPN 3 Linux**: Uses Meson, automatically handles D-Bus and systemd file installation
- **GDBuspp**: Uses Meson
- **KeePassXC**: Uses CMake, Qt5-based application

## Testing Commands

```bash
# Build and test individual packages
emerge -av openvpn3-linux

# Check dependencies
equery depends openvpn3-linux
equery graph openvpn3-linux

# Verify file installation
equery files openvpn3-linux
```

## Future Development

- Monitor upstream releases for new versions
- Keep 3.11.1 version of openvpn3-core for future openvpn3-linux versions
- Consider adding USE flags for optional features
- Monitor for Gentoo mainline inclusion

## Notes for Future Development

- The overlay follows standard Gentoo development practices
- All packages have been tested and successfully build
- Meson build system handles most file installation automatically
- Version constraints are crucial for compatibility between packages