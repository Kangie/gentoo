# Copyright 2025 Gentoo Authors
# Distributed under the terms of the GNU General Public License v2

EAPI=8

# chromium-tools vendor-vesktop
: ${VESKTOP_VENDOR_TARBALL=1}

ESBUILD_VERSION="0.25.2"

inherit desktop electron xdg-utils

DESCRIPTION="A Discord client with a focus on performance and customisability"
HOMEPAGE="https://vencord.dev/"
SRC_URI="https://codeload.github.com/Vencord/Vesktop/tar.gz/refs/tags/v${PV} -> ${P}.tar.gz"
if [[ ${VESKTOP_VENDOR_TARBALL} -eq 1 ]]; then
	SRC_URI+=" https://deps.gentoo.zip/net-im/vesktop/${P}-vendor.tar.xz"
fi
S="${WORKDIR}/Vesktop-${PV}"

LICENSE="GPL-3"
SLOT=0
KEYWORDS="~amd64 ~arm64"

BDEPEND="
	dev-util/pnpm
	~dev-util/esbuild-${ESBUILD_VERSION}
"

src_prepare() {
	electron_src_prepare

	# Remove packageManager field to prevent pnpm from trying to install itself
	sed -i '/\"packageManager\":/d' package.json || die

	generate_electron-builder_bailout_config
}

src_compile() {
	export ESBUILD_BINARY_PATH="${EPREFIX}/usr/bin/esbuild-${ESBUILD_VERSION}"
	# No output for a little while
	einfo "Transpiling Vesktop sources ..."
	# venmic is a native module and should be built here, but would require packaging a bunch of dependencies
	# and wrestling with `CPM` that I'm just not up for right now.
	# https://github.com/cpm-cmake/CPM.cmake?tab=readme-ov-file#cpm_use_local_packages
	# use venmic && electron_build_native_modules
	# package:dir target, slightly customised
	pnpm build || die "failed to build Vesktop"
	# Use the bundled electron-builder script.
	./node_modules/.bin/electron-builder --config "${ELECTRON_BUILDER_CONFIG}" \
		-c.electronDist="${ELECTRON_DIR}" \
		-c.electronVersion="${ELECTRON_VERSION}" || die "Failed to package electron asar"
}

src_install() {
	# install the app.asar
	insinto "/usr/$(get_libdir)/vesktop"
	doins dist/linux-unpacked/resources/app.asar

	newicon -s 256 "${S}/static/icon.png" vesktop.png

	make_desktop_entry "${EPREFIX}/usr/bin/electron-${ELECTRON_SLOT} /usr/$(get_libdir)/vesktop/app.asar" \
		"Vesktop" \
		"${EPREFIX}/usr/share/icons/hicolor/256x256/apps/vesktop.png" \
		"Network;Chat;"

	einstalldocs
}

pkg_postinst() {
	xdg_icon_cache_update
}

pkg_postrm() {
	xdg_icon_cache_update
}
