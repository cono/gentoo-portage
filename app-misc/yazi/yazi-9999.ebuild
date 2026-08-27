# Copyright 2026 Gentoo Authors
# Distributed under the terms of the GNU General Public License v2

EAPI=8

RUST_MIN_VER="1.95.0"

inherit bash-completion-r1 cargo desktop git-r3 optfeature xdg

DESCRIPTION="Blazing fast terminal file manager written in Rust, based on async I/O"
HOMEPAGE="
	https://yazi-rs.github.io
	https://github.com/sxyazi/yazi
"
EGIT_REPO_URI="https://github.com/sxyazi/${PN}.git"

LICENSE="MIT"
# Dependent crate licenses; the live branch may pull in others
LICENSE+="
	Apache-2.0 BSD Boost-1.0 BlueOak-1.0.0 CC0-1.0 CDLA-Permissive-2.0
	ISC MIT MPL-2.0 Unicode-3.0 ZLIB
"
SLOT="0"
# Nightly/live builds are hardmasked (**) on purpose
KEYWORDS=""

# Lua 5.5 is not packaged in Gentoo yet, so mlua's vendored copy is used
# (yazi-fm's default "vendored-lua" feature).

RDEPEND="sys-apps/file"

DOCS=( CHANGELOG.md README.md )

QA_FLAGS_IGNORED="usr/bin/ya usr/bin/yazi"

src_unpack() {
	git-r3_src_unpack
	cargo_live_src_unpack
}

src_configure() {
	# Make the yazi-boot/yazi-cli build scripts emit shell completions
	export YAZI_GEN_COMPLETIONS=1

	cargo_src_configure
}

src_install() {
	cargo_src_install --path yazi-fm
	cargo_src_install --path yazi-cli

	einstalldocs

	domenu assets/yazi.desktop
	newicon assets/logo.png yazi.png

	newbashcomp yazi-boot/completions/yazi.bash yazi
	newbashcomp yazi-cli/completions/ya.bash ya

	insinto /usr/share/zsh/site-functions
	doins yazi-boot/completions/_yazi yazi-cli/completions/_ya

	insinto /usr/share/fish/vendor_completions.d
	doins yazi-boot/completions/yazi.fish yazi-cli/completions/ya.fish
}

pkg_postinst() {
	xdg_pkg_postinst

	optfeature "video thumbnails and metadata" media-video/ffmpeg
	optfeature "PDF previews" "app-text/poppler[utils]"
	optfeature "AVIF/HEIF/JXL image and font previews" media-gfx/imagemagick
	optfeature "JSON previews" app-misc/jq
	optfeature "archive previews and extraction" app-arch/7zip
	optfeature "file searching with the search command" sys-apps/ripgrep
	optfeature "interactive filtering with the filter command" app-shells/fzf
	optfeature "directory jumping with the cd command" app-shells/zoxide
	optfeature "image previews without a graphics protocol" media-gfx/chafa
	optfeature "image previews via Ueberzug++" media-gfx/ueberzugpp
	optfeature "clipboard support under X11" x11-misc/xclip
	optfeature "clipboard support under Wayland" gui-apps/wl-clipboard
}
