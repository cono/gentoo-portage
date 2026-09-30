# Copyright 2026 Gentoo Authors
# Distributed under the terms of the GNU General Public License v2

EAPI=8

inherit desktop unpacker xdg

MY_PN="${PN%-bin}"

DESCRIPTION="A free GTD (Getting Things Done) to-do app that works offline"
HOMEPAGE="https://mindwtr.app/ https://github.com/dongdongbh/mindwtr"
SRC_URI="https://github.com/dongdongbh/${MY_PN}/releases/download/v${PV}/${MY_PN}_${PV}_amd64.deb"
S="${WORKDIR}"

LICENSE="AGPL-3"
SLOT="0"
KEYWORDS="-* ~amd64"
RESTRICT="mirror strip"

# Tauri app: a single Rust binary on top of the system WebKitGTK. The tray
# icon dlopen()s libayatana-appindicator3.
RDEPEND="
	dev-libs/glib:2
	dev-libs/libayatana-appindicator
	media-libs/alsa-lib
	net-libs/libsoup:3.0
	net-libs/webkit-gtk:4.1
	sys-devel/gcc
	x11-libs/cairo
	x11-libs/gdk-pixbuf:2
	x11-libs/gtk+:3
"

QA_PREBUILT="usr/bin/${MY_PN}"

src_install() {
	dobin usr/bin/${MY_PN}

	# Mindwtr.desktop is the visible menu entry; the NoDisplay mindwtr.desktop
	# only exists so Wayland compositors can match the app id to an icon.
	domenu usr/share/applications/{Mindwtr,${MY_PN}}.desktop

	local size
	for size in 32 128 512; do
		doicon -s ${size} usr/share/icons/hicolor/${size}x${size}/apps/${MY_PN}.png
	done
	insinto /usr/share/icons/hicolor/256x256@2/apps
	doins usr/share/icons/hicolor/256x256@2/apps/${MY_PN}.png
}
