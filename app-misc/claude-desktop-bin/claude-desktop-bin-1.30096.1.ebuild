# Copyright 2026 Gentoo Authors
# Distributed under the terms of the GNU General Public License v2

EAPI=8

inherit desktop linux-info pax-utils unpacker xdg

MY_PN="${PN%-bin}"
MY_URI="https://downloads.claude.ai/claude-desktop/apt/stable/pool/main/c/${MY_PN}"

DESCRIPTION="Desktop application for Claude.ai with Chat, Cowork and Claude Code"
HOMEPAGE="https://claude.ai/
	https://code.claude.com/docs/en/desktop-linux"
SRC_URI="
	amd64? ( ${MY_URI}/${MY_PN}_${PV}_amd64.deb )
	arm64? ( ${MY_URI}/${MY_PN}_${PV}_arm64.deb )
"
S="${WORKDIR}"

LICENSE="all-rights-reserved"
SLOT="0"
KEYWORDS="-* ~amd64 ~arm64"
IUSE="suid"
RESTRICT="bindist mirror strip"

# Upstream only publishes a .deb; the app bundles its own Electron 42, so the
# dependencies below are what that bundled Chromium links or dlopen()s.
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
	sys-apps/xdg-desktop-portal
	virtual/libudev
	x11-libs/cairo
	x11-libs/gdk-pixbuf:2
	x11-libs/gtk+:3
	x11-libs/libdrm
	x11-libs/libX11
	x11-libs/libXcomposite
	x11-libs/libXcursor
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

src_install() {
	# /opt rather than upstream's /usr/lib, per Gentoo policy for prebuilt
	# binaries (bug #720134). Nothing in the app hardcodes the install path;
	# Electron resolves resources relative to the real path of the binary.
	dodir /opt
	cp -a usr/lib/${MY_PN} "${ED}"/opt || die

	fperms 0755 /opt/${MY_PN}/${MY_PN}
	fperms 0755 /opt/${MY_PN}/chrome_crashpad_handler
	fperms 0755 /opt/${MY_PN}/resources/chrome-native-host
	fperms 0755 /opt/${MY_PN}/resources/cowork-linux-helper
	fperms $(usex suid 4755 0755) /opt/${MY_PN}/chrome-sandbox

	pax-mark m "${ED}"/opt/${MY_PN}/${MY_PN}

	# The desktop entry and the claude:// handler both exec "claude-desktop".
	dosym ../../opt/${MY_PN}/${MY_PN} /usr/bin/${MY_PN}

	# Keep upstream's filename: it matches the Wayland app_id / X11 WM_CLASS
	# ("com.anthropic.Claude"), so compositors group windows under this entry.
	domenu usr/share/applications/com.anthropic.Claude.desktop

	local size
	for size in 16 32 48 128 256; do
		doicon -s ${size} usr/share/icons/hicolor/${size}x${size}/apps/${MY_PN}.png
	done

	dodoc usr/share/doc/${MY_PN}/copyright
}

pkg_postinst() {
	xdg_pkg_postinst

	# CONFIG_USER_NS=y is necessary but not sufficient: an LSM or a sysctl can
	# still block unprivileged CLONE_NEWUSER at runtime, which pkg_setup cannot
	# see. Chromium then refuses to start rather than run unsandboxed.
	if ! use suid; then
		elog "The sandbox uses unprivileged user namespaces. If the app exits"
		elog "with \"No usable sandbox!\", check that both of these are nonzero:"
		elog "    sysctl user.max_user_namespaces kernel.unprivileged_userns_clone"
		elog "or re-emerge ${PN} with USE=suid to install the SUID helper instead."
		elog
	fi

	if [[ -z ${REPLACING_VERSIONS} ]]; then
		elog "Claude Desktop on Linux is upstream beta. Computer Use and"
		elog "dictation are not available; the Quick Entry global hotkey needs"
		elog "X11 or a GlobalShortcuts portal on Wayland."
		elog
		elog "Cowork's isolated-VM mode is gated off by upstream on Linux"
		elog "(\"startVM: VM not supported\"), so installing qemu/virtiofsd/edk2"
		elog "does not enable it. Cowork otherwise runs against the service."
		elog
		elog "MCP servers are configured in ~/.config/Claude/claude_desktop_config.json"
		elog
		elog "This package does NOT self-update and does not register Anthropic's"
		elog "apt repository. Update it with your regular @world upgrades."
	fi
}
