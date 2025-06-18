# Copyright 2025 Gentoo Authors
# Distributed under the terms of the GNU General Public License v2

EAPI=8

: ${APP_BUILDER_VENDOR_TARBALL:=1}

inherit go-module

DESCRIPTION="Generic helper tool to build apps into a distributable format"
HOMEPAGE="https://github.com/develar/app-builder"
SRC_URI="https://github.com/develar/app-builder/archive/refs/tags/v${PV}.tar.gz -> ${P}.tar.gz"
if [[ ${APP_BUILDER_VENDOR_TARBALL} == 1 ]]; then
	SRC_URI+=" https://deps.gentoo.zip/dev-util/app-builder/${P}-vendor.tar.xz"
fi

LICENSE="MIT"
SLOT="0"
KEYWORDS="~amd64 ~arm64"

RESTRICT="test" # TODO: Tests involve running `npm`, `pnpm`, `yarn` over test directories.

src_compile() {
	go build -o app-builder
}

src_install() {
	dobin app-builder
}
