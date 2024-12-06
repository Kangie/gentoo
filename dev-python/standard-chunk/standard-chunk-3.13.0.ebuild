# Copyright 2024 Gentoo Authors
# Distributed under the terms of the GNU General Public License v2

EAPI=8

DISTUTILS_USE_PEP517=setuptools
PYTHON_COMPAT=( python3_13 )

inherit distutils-r1 pypi

DESCRIPTION="Replacement for the PEP-594 \"dead battery\" chunk module"
HOMEPAGE="
	https://pypi.org/project/standard-chunk/
"

LICENSE="PSF-2"
SLOT="0"
KEYWORDS="~amd64"

RESTRICT="test"
