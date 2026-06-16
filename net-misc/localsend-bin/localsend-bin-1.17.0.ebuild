# Copyright 2026 Gentoo Authors
# Distributed under the terms of the GNU General Public License v2

EAPI=8

inherit desktop unpacker xdg

DESCRIPTION="An open-source cross-platform alternative to AirDrop"
HOMEPAGE="https://localsend.org/
	https://github.com/localsend/localsend"
SRC_URI="
	amd64? ( https://github.com/localsend/localsend/releases/download/v${PV}/LocalSend-${PV}-linux-x86-64.deb )
	arm64? ( https://github.com/localsend/localsend/releases/download/v${PV}/LocalSend-${PV}-linux-arm-64.deb )
"
S="${WORKDIR}"

LICENSE="MIT"
SLOT="0"
KEYWORDS="-* amd64 ~arm64"
RESTRICT="bindist mirror"

RDEPEND="
	dev-libs/atk
	dev-libs/glib:2
	dev-libs/libayatana-appindicator
	dev-libs/libdbusmenu[gtk3]
	media-libs/harfbuzz
	x11-libs/cairo
	x11-libs/gdk-pixbuf:2
	x11-libs/gtk+:3
	x11-libs/pango
	x11-misc/xdg-user-dirs
"

QA_PREBUILT="
	usr/share/localsend_app/localsend_app
	usr/share/localsend_app/lib/*.so
"

src_prepare() {
	default

	# Upstream sets the desktop entry "Version" key to the application
	# version (e.g. 1.17.0+58), which is not a valid Desktop Entry spec
	# version and fails desktop-file-validate. Drop the line.
	sed -i -e '/^Version=/d' usr/share/applications/localsend_app.desktop || die
}

src_install() {
	insinto /usr/share
	doins -r usr/share/localsend_app
	fperms +x /usr/share/localsend_app/localsend_app

	domenu usr/share/applications/localsend_app.desktop

	insinto /usr/share/icons
	doins -r usr/share/icons/hicolor

	# The .desktop file calls "localsend_app"; the Flutter binary resolves
	# its bundled data/ and lib/ via the real path, so a symlink is enough.
	dosym -r /usr/share/localsend_app/localsend_app /usr/bin/localsend_app
	dosym -r /usr/share/localsend_app/localsend_app /usr/bin/localsend
}
