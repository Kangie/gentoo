# Copyright 2025 Gentoo Authors
# Distributed under the terms of the GNU General Public License v2

EAPI=8

# chromium-tools vendor-vesktop
: ${VESKTOP_VENDOR_TARBALL=1}

inherit electron

SRC_URI="https://codeload.github.com/Vencord/Vesktop/tar.gz/refs/tags/v${PV} -> ${P}.tar.gz"
if [[ ${VESKTOP_VENDOR_TARBALL} -eq 1 ]]; then
    SRC_URI+=" https://deps.gentoo.zip/net-im/vesktop/${P}-vendor.tar.xz"
fi
S="${WORKDIR}/Vesktop-${PV}"
DESCRIPTION="A Discord client with a focus on performance and customisability"
HOMEPAGE="https://vencord.dev/"

LICENSE="GPL-3"
SLOT=0
KEYWORDS="~amd64 ~arm64"

BDEPEND="
	dev-util/pnpm
	dev-util/esbuild
"

src_prepare() {
	electron_src_prepare

	# Remove electron from dependencies to avoid downloading
	sed -i '/\"electron\":/d' package.json || die

	# Remove packageManager field to prevent pnpm from trying to install itself
	sed -i '/\"packageManager\":/d' package.json || die

	# https://github.com/evanw/esbuild/blob/f4159a7b823cd5fe2217da2c30e8873d2f319667/CHANGELOG-2023.md?plain=1#L3359
	sed -i 's|/usr/bin/esbuild|/usr/bin/dont-blacklist-system-bins|' node_modules/esbuild/install.js node_modules/esbuild/lib/main.js || die
	# Don't blame upstream when things go sideways...
	sed -i -e 's|binaryVersion|false) { //|' node_modules/esbuild/lib/main.js || die
}

src_compile() {
	export ESBUILD_BINARY_PATH="${EPREFIX}/usr/bin/esbuild"
	# No output for a little while
	einfo "Transpiling Vesktop sources ..."
	# package:dir target, slightly customised
	pnpm build || die "failed to build Vesktop"
	# Use the bundled electron-builder script
	# --dir stops after building app.asar so we can install that and then make an electron wrapper
	./node_modules/.bin/electron-builder --dir \
		-c.electronDist="${ELECTRON_DIR}" \
		-c.electronVersion="${ELECTRON_VERSION}" || die "Failed to package electron asar"
}

src_install() {
	# install the app.asar
	insinto "/usr/$(get_libdir)/vesktop"
	doins dist/linux-unpacked/resources/app.asar

	newicon -s 256 "${S}/app.asar.unpacked/assets/icon.png" vesktop.png
	newicon "${S}/app.asar.unpacked/assets/icon.png" vesktop.png

	make_desktop_entry "${EPREFIX}/usr/bin/electron-${ELECTRON_VERSION%%.*} /usr/$(get_libdir)/vesktop/app.asar" \
		"Vesktop" \
		"${EPREFIX}/usr/share/icons/hicolor/256x256/apps/vesktop.png" \
		"Network;Chat;"

	einstalldocs
}
