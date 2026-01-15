# Cono's Gentoo Portage Overlay

This is a personal Gentoo Portage overlay containing custom ebuilds for packages not yet available in the main Gentoo tree.

## Packages

### dev-libs/gdbuspp

**Version**: 3  
**Description**: GLib-based D-Bus C++ interface library  
**Homepage**: https://github.com/OpenVPN/gdbuspp  

A modern C++17 wrapper library for the GLib-based D-Bus implementation, providing a clean interface for implementing D-Bus services and clients.

**USE flags**:
- `debug` - Enable debug mode compilation
- `doxygen` - Build API documentation with Doxygen  
- `test` - Build and run tests

### net-vpn/openvpn3-linux

**Version**: 24
**Description**: OpenVPN 3 Linux - Next generation OpenVPN client
**Homepage**: https://github.com/OpenVPN/openvpn3-linux

Next-generation OpenVPN client implementation built on OpenVPN 3 Core library with improved security through privilege separation and D-Bus architecture.

**USE flags**:
- `bash-completion` - Install bash command completion
- `dco` - Enable support for kernel data channel offload
- `man` - Build and install manual pages
- `selinux` - Install SELinux policy modules
- `systemd` - Enable systemd integration
- `test` - Build and run tests

**Dependencies**: Requires `dev-libs/gdbuspp` (provided by this overlay)

### app-admin/keepassxc

**Version**: 2.7.10-r2
**Description**: KeePassXC - KeePass Cross-platform Community Edition
**Homepage**: https://keepassxc.org

Cross-platform password manager that is community-driven and compatible with KeePass databases. This overlay provides version 2.7.10 because version 2.7.11 has an [Auto-Type regression bug](https://github.com/keepassxreboot/keepassxc/issues/12723).

**USE flags**:
- `X` - Enable X11 support
- `autotype` - Enable Auto-Type feature (requires X)
- `browser` - Enable browser integration and passkeys
- `doc` - Build documentation with asciidoctor
- `keeshare` - Enable KeeShare database sharing
- `keyring` - Enable freedesktop.org Secret Service integration (default)
- `network` - Enable network features (default)
- `ssh-agent` - Enable SSH agent integration (default)
- `test` - Build and run tests
- `yubikey` - Enable YubiKey hardware key support

## Installation

### Method 1: Manual Setup

1. Clone this repository:
   ```bash
   git clone https://github.com/cono/gentoo-portage.git /var/db/repos/cono
   ```

2. Add repository configuration in `/etc/portage/repos.conf/cono.conf`:
   ```ini
   [cono]
   location = /var/db/repos/cono
   sync-type = git
   sync-uri = https://github.com/cono/gentoo-portage.git
   auto-sync = no
   ```

3. Install packages:
   ```bash
   emerge -av dev-libs/gdbuspp
   emerge -av net-vpn/openvpn3-linux
   ```

### Method 2: Using eselect-repository

```bash
eselect repository add cono git https://github.com/cono/gentoo-portage.git
emerge --sync cono
emerge -av dev-libs/gdbuspp net-vpn/openvpn3-linux
```

## Build Requirements

- **Compiler**: GCC 7+ or Clang with C++17 support
- **Build system**: Meson build system
- **Dependencies**: See individual package metadata for complete dependency lists

## Usage Notes

### OpenVPN 3 Linux

After installation, OpenVPN 3 Linux provides these main utilities:

- `openvpn3` - Modern command-line interface
- `openvpn2` - Compatible interface similar to OpenVPN 2.x  
- `openvpn3-admin` - Administrative interface (requires root)

Configuration files should be placed in `/etc/openvpn3/`

For D-Bus integration to work properly, you may need to restart the D-Bus service or reboot the system after installation.

## Contributing

This overlay is maintained by q@cono.org.ua. Issues and suggestions are welcome via GitHub issues.

## License

Individual packages retain their original licenses:
- gdbuspp: AGPL-3.0
- openvpn3-linux: AGPL-3.0
- keepassxc: GPL-2/GPL-3 (dual licensed)

This overlay itself is provided under the GPL-2 license, consistent with Gentoo Portage.