# Copyright 1999-2025 Gentoo Authors
# Distributed under the terms of the GNU General Public License v2

EAPI=8

inherit meson systemd toolchain-funcs

DESCRIPTION="OpenVPN 3 Linux - Next generation OpenVPN client"
HOMEPAGE="https://github.com/OpenVPN/openvpn3-linux"

if [[ ${PV} == "9999" ]]; then
	EGIT_REPO_URI="https://github.com/OpenVPN/openvpn3-linux.git"
	inherit git-r3
else
	SRC_URI="https://github.com/OpenVPN/openvpn3-linux/archive/v${PV}.tar.gz -> ${P}.tar.gz"
	KEYWORDS="~amd64 ~arm64 ~x86"
fi

LICENSE="AGPL-3"
SLOT="0"

IUSE="bash-completion dco man selinux systemd test"
RESTRICT="!test? ( test )"

REQUIRED_USE="
	systemd? ( || ( systemd ) )
"

RDEPEND="
	acct-group/openvpn
	acct-user/openvpn
	dev-cpp/asio
	dev-libs/gdbuspp:=
	dev-libs/glib:2
	dev-libs/jsoncpp:=
	=dev-libs/openvpn3-core-3.10.4*
	dev-libs/openssl:=
	dev-libs/tinyxml2:=
	dev-libs/libnl:3
	sys-libs/libcap-ng
	sys-apps/util-linux
	dco? ( >=net-vpn/ovpn-dco-0.2 )
	selinux? ( sec-policy/selinux-openvpn )
	systemd? ( sys-apps/systemd )
"

DEPEND="
	${RDEPEND}
	test? ( dev-cpp/gtest )
"

BDEPEND="
	dev-build/meson
	virtual/pkgconfig
	sys-devel/gcc:=[cxx]
	man? ( dev-python/docutils )
"

pkg_setup() {
	# Check for C++17 support
	if [[ ${MERGE_TYPE} != binary ]]; then
		if tc-is-gcc && [[ $(gcc-major-version) -lt 7 ]]; then
			die "OpenVPN 3 Linux requires GCC 7 or later for C++17 support"
		fi
	fi
}

src_prepare() {
	default

	# Apply patch to fix DNS address string compilation error
	# eapply "${FILESDIR}/${P}-fix-dns-address-string.patch"

	# Ensure build-version.h is available in src/ directory
	# The meson build system expects this for tarball builds
	if [[ ! -f src/build-version.h ]]; then
		einfo "Creating minimal build-version.h file"
		cat > src/build-version.h <<-EOF
		#ifndef OPENVPN3_LINUX_BUILD_VERSION_H
		#define OPENVPN3_LINUX_BUILD_VERSION_H
		#define PACKAGE_VERSION "${PV}"
		#define PACKAGE_NAME "OpenVPN3/Linux"
		#define PACKAGE_GUIVERSION "${PV}"
		#define OPENVPN3_LINUX_VERSION "${PV}"
		#endif
		EOF
	fi
}

src_configure() {
	local emesonargs=(
		$(meson_feature bash-completion)
		$(meson_feature man generate-man)
		$(meson_feature selinux)
		$(meson_feature dco)
		$(meson_feature test unit_tests)
		-Dwerror=false
		-Dasio_path=/usr
		-Dopenvpn3_core_path=/usr/include
		--prefix=/usr
		--sysconfdir=/etc
		--localstatedir=/var
	)

	# Set systemd paths if systemd is enabled
	if use systemd; then
		emesonargs+=(
			-Dsystemd_system_unit_dir="$(systemd_get_systemunitdir)"
		)
	fi

	meson_src_configure
}

src_compile() {
	meson_src_compile
}

src_test() {
	meson_src_test
}

src_install() {
	meson_src_install

	# Install documentation
	dodoc README.md QUICK-START.md
	
	if use man; then
		dodoc docs/man/*.rst
	fi

	# Create necessary directories
	keepdir /etc/openvpn3
	keepdir /var/lib/openvpn3

	# Install D-Bus policy files
	# Note: D-Bus policy files are installed automatically by meson
	# insinto /usr/share/dbus-1/system.d
	# doins src/policy/*.conf

	# Install systemd service files if systemd is enabled
	if use systemd; then
		systemd_dounit distro/systemd/*.service
	fi

	# Set proper permissions
	fowners openvpn:openvpn /var/lib/openvpn3
	fperms 0750 /var/lib/openvpn3
}

pkg_postinst() {
	elog "OpenVPN 3 Linux has been installed."
	elog ""
	elog "To get started, see the quick start guide:"
	elog "  https://github.com/OpenVPN/openvpn3-linux/blob/master/QUICK-START.md"
	elog ""
	elog "Configuration files should be placed in /etc/openvpn3/"
	elog ""
	elog "OpenVPN 3 Linux provides these main utilities:"
	elog "  - openvpn3: Modern command-line interface"
	elog "  - openvpn2: Compatible interface similar to OpenVPN 2.x"
	elog "  - openvpn3-admin: Administrative interface (requires root)"
	elog ""
	
	if use systemd; then
		elog "Systemd service files have been installed. You can enable"
		elog "the OpenVPN 3 services with:"
		elog "  systemctl enable --now openvpn3-autoload"
	fi

	if use dco; then
		elog ""
		elog "Data Channel Offload (DCO) support is enabled."
		elog "Make sure you have the ovpn-dco kernel module loaded:"
		elog "  modprobe ovpn-dco"
	fi

	elog ""
	elog "For D-Bus integration to work properly, you may need to restart"
	elog "the D-Bus service or reboot the system."
}
