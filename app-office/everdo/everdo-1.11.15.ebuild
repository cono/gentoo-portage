# Copyright 2026 Gentoo Authors
# Distributed under the terms of the GNU General Public License v2

EAPI=8

inherit desktop linux-info pax-utils unpacker xdg

MY_PN="Everdo"

DESCRIPTION="A productivity app for GTD (Getting Things Done)"
HOMEPAGE="https://everdo.net/"
SRC_URI="https://downloads.everdo.net/electron/${PN}_${PV}_amd64.deb"
S="${WORKDIR}"

LICENSE="all-rights-reserved"
SLOT="0"
KEYWORDS="-* ~amd64"
IUSE="suid"
RESTRICT="bindist mirror strip"

# Upstream only publishes an amd64 .deb (and an AppImage). The app bundles
# Electron 35; these are what that Chromium and the two native node modules
# link or dlopen().
RDEPEND="
	app-accessibility/at-spi2-core:2
	app-crypt/libsecret
	dev-libs/expat
	dev-libs/glib:2
	dev-libs/nspr
	dev-libs/nss
	media-libs/alsa-lib
	media-libs/mesa
	net-print/cups
	sys-apps/dbus
	sys-apps/util-linux
	virtual/libudev
	x11-libs/cairo
	x11-libs/gtk+:3
	x11-libs/libnotify
	x11-libs/libX11
	x11-libs/libXScrnSaver
	x11-libs/libXcomposite
	x11-libs/libXdamage
	x11-libs/libXext
	x11-libs/libXfixes
	x11-libs/libXrandr
	x11-libs/libXtst
	x11-libs/libxcb
	x11-libs/libxkbcommon
	x11-libs/pango
	x11-misc/xdg-utils
"

QA_PREBUILT="opt/${MY_PN}/*"

pkg_setup() {
	# Chromium needs unprivileged user namespaces for its namespace sandbox.
	# Without them it falls back to the SUID chrome-sandbox helper, which is
	# only installed with USE=suid.
	if ! use suid; then
		CONFIG_CHECK="~USER_NS"
		ERROR_USER_NS="CONFIG_USER_NS is required for the sandbox to work"
		ERROR_USER_NS+=" without the SUID helper. Enable it, or set USE=suid."
	fi
	linux-info_pkg_setup
}

src_prepare() {
	default

	# The AppArmor profile is only copied into place by the Debian postinst;
	# Gentoo does not use it.
	rm opt/${MY_PN}/resources/apparmor-profile || die
}

src_install() {
	# Keep upstream's /opt/Everdo: the desktop entry execs it by full path.
	dodir /opt
	cp -a opt/${MY_PN} "${ED}"/opt || die

	fperms 0755 /opt/${MY_PN}/${PN}
	fperms 0755 /opt/${MY_PN}/chrome_crashpad_handler
	fperms $(usex suid 4755 0755) /opt/${MY_PN}/chrome-sandbox

	pax-mark m "${ED}"/opt/${MY_PN}/${PN}

	dosym ../../opt/${MY_PN}/${PN} /usr/bin/${PN}

	domenu usr/share/applications/${PN}.desktop

	local size
	for size in 32 64 128 256 512 1024; do
		doicon -s ${size} usr/share/icons/hicolor/${size}x${size}/apps/${PN}.png
	done
}

pkg_postinst() {
	xdg_pkg_postinst

	if ! use suid; then
		elog "The sandbox uses unprivileged user namespaces. If the app exits"
		elog "with \"No usable sandbox!\", check that both of these are nonzero:"
		elog "    sysctl user.max_user_namespaces kernel.unprivileged_userns_clone"
		elog "or re-emerge ${PN} with USE=suid to install the SUID helper instead."
		elog
	fi

	if [[ -z ${REPLACING_VERSIONS} ]]; then
		elog "The free tier is limited to 5 projects and 2 areas; Everdo Pro"
		elog "(https://everdo.net/pricing/) unlocks them with a product key."
		elog
		elog "Ignore the built-in update notification: it targets the Debian"
		elog "package. Update ${PN} with your regular @world upgrades."
	fi
}
