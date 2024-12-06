# Copyright 2024 Gentoo Authors
# Distributed under the terms of the GNU General Public License v2

EAPI=8

DISTUTILS_USE_PEP517=setuptools
PYTHON_COMPAT=( python3_13 )

inherit distutils-r1 pypi

DESCRIPTION="Replacement for the PEP-594 \"dead battery\" sunau module"
HOMEPAGE="
	https://pypi.org/project/standard-sunau/
"

LICENSE="PSF-2"
SLOT="0"
KEYWORDS="~amd64"

RESTRICT="test" # Relies on cpython/blob/3.13/Lib/test/audiotests.py

distutils_enable_tests pytest
