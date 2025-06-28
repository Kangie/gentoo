# Copyright 2025 Gentoo Authors
# Distributed under the terms of the GNU General Public License v2

EAPI=8

: ${ESBUILD_VENDOR_TARBALL:=1}

inherit go-module

DESCRIPTION="A modern, extremely fast, JavaScript and CSS bundler and minifier"
HOMEPAGE="https://esbuild.github.io/"
SRC_URI="https://github.com/evanw/esbuild/archive/v${PV}.tar.gz -> ${P}.tar.gz"
if [[ ${ESBUILD_VENDOR_TARBALL} -eq 1 ]]; then
	SRC_URI+=" https://deps.gentoo.zip/dev-util/esbuild/esbuild-${PV}-vendor.tar.xz"
fi

LICENSE="MIT"
SLOT="${PV}"
KEYWORDS="~amd64 ~arm64"

src_compile() {
	# Build using vendored dependencies instead of Makefile
	ego build -mod=vendor -v -ldflags="-s -w" ./cmd/esbuild
}

src_install() {
	newbin esbuild esbuild-${PV}
}
