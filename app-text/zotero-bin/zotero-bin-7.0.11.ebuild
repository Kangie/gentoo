# Copyright 1999-2025 Gentoo Authors
# Distributed under the terms of the GNU General Public License v2

EAPI=8

inherit desktop xdg

DESCRIPTION="Helps you collect, organize, cite, and share your research sources"
HOMEPAGE="https://www.zotero.org"
SRC_URI="
	amd64? ( https://www.zotero.org/download/client/dl?channel=release&platform=linux-x86_64&version=${PV} -> ${P}-amd64.tar.bz2 )
	x86? ( https://www.zotero.org/download/client/dl?channel=release&platform=linux-i686&version=${PV} -> ${P}-x86.tar.bz2 )
"
S="${WORKDIR}"

LICENSE="AGPL-3"
SLOT="0"
KEYWORDS="-* amd64 ~x86"

RDEPEND="
	app-accessibility/at-spi2-core
	dev-libs/dbus-glib
	dev-libs/glib
	dev-libs/nspr
	dev-libs/nss
	media-libs/alsa-lib
	media-libs/fontconfig
	media-libs/freetype
	sys-apps/dbus
	sys-libs/glibc
	x11-libs/cairo
	x11-libs/gdk-pixbuf
	x11-libs/gtk+:3
	x11-libs/libX11
	x11-libs/libxcb
	x11-libs/libXcomposite
	x11-libs/libXcursor
	x11-libs/libXdamage
	x11-libs/libXext
	x11-libs/libXfixes
	x11-libs/libXi
	x11-libs/libXrandr
	x11-libs/libXrender
	x11-libs/libXtst
	x11-libs/pango
"

QA_PREBUILT="opt/zotero/*"

src_prepare() {
	if use amd64; then
		cd Zotero_linux-x86_64 || die
	elif use x86; then
		cd Zotero_linux-i686 || die
	fi

	# disable auto-update
	sed -i -e 's#URL=.*#URL=#' app/application.ini || die

	# fix desktop-file
	sed -i -e 's#^Exec=.*#Exec=zotero -url %U#' zotero.desktop || die
	sed -i -e 's#Icon=zotero.*#Icon=zotero#' zotero.desktop || die

	default
}

src_install() {
	if use amd64; then
		cd Zotero_linux-x86_64 || die
	elif use x86; then
		cd Zotero_linux-i686 || die
	fi

	dodir opt/zotero
	cp -a * "${ED}/opt/zotero" || die

	dosym ../../opt/zotero/zotero usr/bin/zotero

	domenu zotero.desktop

	for size in 32 64 128; do
		newicon -s ${size} icons/icon${size}.png zotero.png
	done
}
