# Copyright 1999-2024 Gentoo Authors
# Distributed under the terms of the GNU General Public License v2

EAPI=8

inherit latex-package

DESCRIPTION="LaTeX package for source code syntax highlighting"
HOMEPAGE="https://github.com/gpoore/minted/"
SRC_URI="https://github.com/gpoore/${PN}/archive/v${PV}.tar.gz
	-> ${P}.tar.gz"
S="${WORKDIR}"/${P}/source

LICENSE="|| ( BSD LPPL-1.3 )"
SLOT="0"
KEYWORDS="~alpha amd64 arm arm64 hppa ~ia64 ~loong ~mips ppc ppc64 ~riscv ~s390 sparc x86"
IUSE="doc"

RDEPEND="
	dev-python/pygments
	dev-texlive/texlive-latexextra
"
BDEPEND="
	doc? (
		dev-texlive/texlive-fontsextra
		dev-texlive/texlive-latexextra
	)
"

DOCS=( ../CHANGES.md ../README.md )

src_prepare() {
	default

	rm "${S}"/${PN}.pdf || die
}

src_install() {
	LATEX_DOC_ARGUMENTS="-shell-escape"

	latex-package_src_install

	use doc && latex-package_src_doinstall pdf
}
