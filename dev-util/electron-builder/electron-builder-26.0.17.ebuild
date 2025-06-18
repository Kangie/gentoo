# Copyright 2025 Gentoo Authors
# Distributed under the terms of the GNU General Public License v2

EAPI=8

: ${ELECTRON_BUILDER_VENDOR_TARBALL:=1}

DESCRIPTION="Electron Builder"
HOMEPAGE="https://www.electron.build/"
SRC_URI="https://github.com/electron-userland/electron-builder/archive/refs/tags/v${PV}.tar.gz -> ${P}.tar.gz"
if [[ ${ELECTRON_BUILDER_VENDOR_TARBALL} == 1 ]]; then
	# Use the vendor version if available
	SRC_URI+=" https://deps.gentoo.zip/dev-build/electron/builder/${P}-vendor.tar.xz"
fi

LICENSE="MIT"
SLOT="0"
KEYWORDS="~amd64 ~arm64"

# Technically we could probably use electron-as-nodejs (and the eclass will add it to dependencies),
# but electron-builder is a tool that builds Electron apps, so it makes more sense to depend on nodejs.
BDEPEND="
	>=net-libs/nodejs-14.14
	>=dev-util/pnpm-9
"
RDEPEND="
	>=net-libs/nodejs-14.14
"

S="${WORKDIR}/electron-builder-${PV}"

src_prepare() {
	default

	# Remove packageManager field to prevent pnpm from trying to install itself
	sed -i '/\"packageManager\":/d' package.json || die "Failed to remove packageManager field"
}

src_compile() {
	# There's no output unless something goes wrong, so let's ensure that users know something is happening
	pushd packages/electron-builder || die "Failed to enter packages/electron-builder directory"
	einfo "Compiling electron-builder ..."
	pnpm compile || die "Compilation failed"
	popd || die "Failed to return to previous directory"
}

src_install() {
	# Install the binary
	dobin dist/bin/electron-builder

	# Install the CLI
	dosym /usr/bin/electron-builder /usr/bin/electron-builder-cli
}

src_test() {
	# Run the tests
	pnpm test-all || die "Tests failed"
}
