# Copyright 1999-2024 Gentoo Authors
# Distributed under the terms of the GNU General Public License v2

EAPI=7

inherit toolchain-funcs

DESCRIPTION="A non-intrusive real-time ANSI color wrapper for common unix-based commands"
HOMEPAGE="http://cwrapper.sourceforge.net/"
SRC_URI="https://downloads.sourceforge.net/cwrapper/${P}.tar.bz2"

LICENSE="GPL-2"
SLOT="0"
KEYWORDS="amd64 x86"

PATCHES=(
	"${FILESDIR}"/${PV}-ldflags.patch
	"${FILESDIR}"/${PV}-path.patch
	"${FILESDIR}"/${PV}-collision.patch
	"${FILESDIR}"/${PV}-format-security.patch
)

src_configure() {
	tc-export CC
	econf
}

src_compile() {
	emake local
}

src_install() {
	insinto /usr/share/cw
	doins etc/*

	exeinto /usr/libexec/cw
	doexe def/*

	doman man/cwu*
	newman man/cw.* color-wrapper
	dodoc CHANGES CONTRIB INSTALL README PLATFORM doc/README*

	dobin bin/{cwu,colorcfg}
	# app-misc/color currently conflicts; hopefully 'colors' is safe
	newbin bin/color colors
	# media-radio/unixcw currently conflicts;
	newbin bin/cw color-wrapper
}

pkg_postinst() {
	ebegin "Updating definition files"
	cwu /usr/libexec/cw /usr/bin/color-wrapper # >/dev/null
	eend $?

	elog "To enable color-wrapper, as your user, run:"
	elog "  colorcfg [1|2|3]"
	elog "to add relevant environment variables to your ~/.bash_profile"
	elog "Run colorcfg without options to see what [1|2|3] means."
	elog
	elog "After sourcing your ~/.bash_profile, commands for which definitions"
	elog "are provided should have colored output."
	elog
	elog "To enable/disable colored output, run: 'colors [on|off]'."
}
