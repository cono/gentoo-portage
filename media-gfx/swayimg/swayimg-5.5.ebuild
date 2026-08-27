# Copyright 2026 Gentoo Authors
# Distributed under the terms of the GNU General Public License v2

EAPI=8

inherit bash-completion-r1 meson xdg

DESCRIPTION="Fully customizable image viewer for Wayland and DRM with Lua scripting"
HOMEPAGE="https://github.com/artemsen/swayimg"
SRC_URI="https://github.com/artemsen/${PN}/archive/refs/tags/v${PV}.tar.gz -> ${P}.tar.gz"

# The bundled src/external/{json,luabridge} headers are MIT as well
LICENSE="MIT"
SLOT="0"
KEYWORDS="amd64"
IUSE="avif drm +exif exr +gif heif +jpeg jpeg2k +jpegxl +png raw sixel +svg test +tiff +wayland +webp"
REQUIRED_USE="|| ( drm wayland )"
RESTRICT="!test? ( test )"

RDEPEND="
	dev-lang/luajit:2=
	media-libs/fontconfig:1.0
	media-libs/freetype:2
	x11-libs/libxkbcommon
	avif? ( >=media-libs/libavif-1.0:= )
	drm? ( x11-libs/libdrm )
	exif? ( media-gfx/exiv2:= )
	exr? ( >=media-libs/openexr-3.4:= )
	gif? ( media-libs/giflib:= )
	heif? ( media-libs/libheif:= )
	jpeg? ( media-libs/libjpeg-turbo:= )
	jpeg2k? ( media-libs/openjpeg:2= )
	jpegxl? ( media-libs/libjxl:= )
	png? ( media-libs/libpng:0= )
	raw? ( media-libs/libraw:= )
	sixel? ( media-libs/libsixel )
	svg? ( >=gnome-base/librsvg-2.46:2 )
	tiff? ( media-libs/tiff:= )
	wayland? ( dev-libs/wayland )
	webp? ( media-libs/libwebp:= )
"
DEPEND="
	${RDEPEND}
	test? ( dev-cpp/gtest )
	wayland? ( >=dev-libs/wayland-protocols-1.35 )
"
BDEPEND="
	virtual/pkgconfig
	wayland? ( dev-util/wayland-scanner )
"

DOCS=( CONFIG.md README.md TIPS.md USAGE.md )

src_configure() {
	local emesonargs=(
		# without this meson calls git describe, which fails on a tarball
		-Dversion="${PV}"

		$(meson_feature avif)
		$(meson_feature drm)
		$(meson_feature exif)
		$(meson_feature exr)
		$(meson_feature gif)
		$(meson_feature heif)
		$(meson_feature jpeg)
		$(meson_feature jpeg2k jp2)
		$(meson_feature jpegxl jxl)
		$(meson_feature png)
		$(meson_feature raw)
		$(meson_feature sixel)
		$(meson_feature svg)
		$(meson_feature test tests)
		$(meson_feature tiff)
		$(meson_feature wayland)
		$(meson_feature webp)
		-Dcompositor=$(usex wayland enabled disabled)

		# handled by the eclasses / DOCS below
		-Dbash=disabled
		-Dzsh=disabled
		-Ddoc=false
		-Dlicense=false

		-Ddesktop=true
		-Dluameta=true
		-Dman=true
	)

	meson_src_configure
}

src_install() {
	meson_src_install

	newbashcomp extra/bash.completion "${PN}"

	insinto /usr/share/zsh/site-functions
	newins extra/zsh.completion "_${PN}"
}
