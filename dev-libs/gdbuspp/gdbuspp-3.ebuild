# Copyright 1999-2025 Gentoo Authors
# Distributed under the terms of the GNU General Public License v2

EAPI=8

inherit meson

DESCRIPTION="GLib-based D-Bus C++ interface library"
HOMEPAGE="https://github.com/OpenVPN/gdbuspp"

if [[ ${PV} == "9999" ]]; then
	EGIT_REPO_URI="https://github.com/OpenVPN/gdbuspp.git"
	inherit git-r3
else
	SRC_URI="https://github.com/OpenVPN/gdbuspp/archive/v${PV}.tar.gz -> ${P}.tar.gz"
	KEYWORDS="~amd64 ~arm ~arm64 ~x86"
fi

LICENSE="AGPL-3"
SLOT="0/3"

IUSE="debug doc doxygen"

RDEPEND="
	dev-libs/glib:2
"

DEPEND="
	${RDEPEND}
	doxygen? ( app-text/doxygen )
"

BDEPEND="
	dev-build/meson
	virtual/pkgconfig
"

src_configure() {
	local emesonargs=(
		$(meson_use debug)
		$(meson_use doxygen)
		-Dinternal_debug=false
		-Dwerror=false
	)
	meson_src_configure
}

src_compile() {
	meson_src_compile
}

src_install() {
	meson_src_install

	# Install documentation
	dodoc README.md

	# Install examples if available
	if use doc; then
		docinto examples
		dodoc -r docs/*.cpp
	fi
}