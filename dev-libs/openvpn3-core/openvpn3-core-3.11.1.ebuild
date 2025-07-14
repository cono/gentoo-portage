# Copyright 1999-2025 Gentoo Authors
# Distributed under the terms of the GNU General Public License v2

EAPI=8

inherit cmake

DESCRIPTION="OpenVPN 3 Core Library - C++ library for OpenVPN 3 client"
HOMEPAGE="https://github.com/OpenVPN/openvpn3"

if [[ ${PV} == "9999" ]]; then
	EGIT_REPO_URI="https://github.com/OpenVPN/openvpn3.git"
	inherit git-r3
else
	SRC_URI="https://github.com/OpenVPN/openvpn3/archive/release/${PV}.tar.gz -> ${P}.tar.gz"
	S="${WORKDIR}/openvpn3-release-${PV}"
	KEYWORDS="~amd64 ~arm64 ~x86"
fi

LICENSE="MPL-2.0"
SLOT="0"

IUSE=""

RDEPEND="
	dev-cpp/asio
	dev-libs/openssl:=
"

DEPEND="
	${RDEPEND}
"

BDEPEND="
	dev-build/cmake
	virtual/pkgconfig
"

src_configure() {
	local mycmakeargs=(
		-DCMAKE_BUILD_TYPE=Release
	)
	cmake_src_configure
}

src_install() {
	# Install headers
	doheader -r openvpn

	# Install documentation
	dodoc README.md

	# Create a pkg-config file for easy discovery
	cat > "${T}"/openvpn3-core.pc <<-EOF
	prefix=${EPREFIX}/usr
	includedir=\${prefix}/include

	Name: openvpn3-core
	Description: OpenVPN 3 Core Library
	Version: ${PV}
	Cflags: -I\${includedir}
	EOF

	insinto /usr/$(get_libdir)/pkgconfig
	doins "${T}"/openvpn3-core.pc
}