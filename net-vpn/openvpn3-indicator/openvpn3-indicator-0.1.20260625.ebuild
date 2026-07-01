# Copyright 1999-2026 Gentoo Authors
# Distributed under the terms of the GNU General Public License v2

EAPI=8

PYTHON_COMPAT=( python3_{11..14} )

inherit gnome2-utils python-single-r1 xdg

# Upstream ships no tagged releases, only a rolling main branch whose version is
# derived from the commit date. Pin a specific commit and version it by that date.
EGIT_COMMIT="19370b8c319bc0dcd568a3cb8a2682120f99bc64"

DESCRIPTION="Simple GTK indicator GUI to control OpenVPN 3 Linux tunnels"
HOMEPAGE="https://github.com/OpenVPN/openvpn3-indicator"
SRC_URI="https://github.com/OpenVPN/openvpn3-indicator/archive/${EGIT_COMMIT}.tar.gz -> ${P}.tar.gz"
S="${WORKDIR}/${PN}-${EGIT_COMMIT}"

LICENSE="AGPL-3"
SLOT="0"
KEYWORDS="amd64 arm64 x86"

REQUIRED_USE="${PYTHON_REQUIRED_USE}"

# The app is a self-contained Python zipapp launched via a shebang, so all
# runtime imports (gi, dbus, secretstorage, setproctitle) must resolve against
# the same interpreter that gets hardcoded into the executable.
RDEPEND="
	${PYTHON_DEPS}
	$(python_gen_cond_dep '
		dev-python/dbus-python[${PYTHON_USEDEP}]
		dev-python/pygobject:3[${PYTHON_USEDEP}]
		dev-python/secretstorage[${PYTHON_USEDEP}]
		dev-python/setproctitle[${PYTHON_USEDEP}]
	')
	dev-libs/libayatana-appindicator
	x11-libs/gtk+:3[introspection]
	net-vpn/openvpn3-linux[${PYTHON_SINGLE_USEDEP}]
"

DEPEND="${RDEPEND}"

BDEPEND="
	${PYTHON_DEPS}
	app-arch/zip
"

src_configure() {
	python_setup
}

src_compile() {
	# Pass VERSION explicitly: the Makefile derives it from git history, which
	# is unavailable for release tarballs and unreliable inside the sandbox.
	# HARDCODE_PYTHON becomes the shebang of the generated zipapp executable.
	emake VERSION="${PV}" HARDCODE_PYTHON="${PYTHON}" all
}

src_install() {
	# Use the "package" target (staging only); the desktop/mime/icon/schema
	# database updates that the "install" target runs are handled by xdg.eclass.
	emake \
		DESTDIR="${D}" \
		PREFIX="${EPREFIX}/usr" \
		BINDIR="${EPREFIX}/usr/bin" \
		DATADIR="${EPREFIX}/usr/share" \
		AUTOSTART="${EPREFIX}/etc/xdg/autostart" \
		VERSION="${PV}" \
		HARDCODE_PYTHON="${PYTHON}" \
		package

	# The Makefile installs man pages pre-gzipped, but /usr/share/man is a
	# docompress-ed directory; decompress them so Portage handles compression
	# itself (avoids the double-compression QA notice).
	find "${ED}"/usr/share/man -type f -name '*.gz' -exec gunzip {} + || die

	einstalldocs
}

pkg_postinst() {
	xdg_pkg_postinst
	# Compile the installed GSettings schema; xdg.eclass does not do this and
	# the app aborts at startup if its schema is not in gschemas.compiled.
	gnome2_schemas_update
}

pkg_postrm() {
	xdg_pkg_postrm
	gnome2_schemas_update
}
