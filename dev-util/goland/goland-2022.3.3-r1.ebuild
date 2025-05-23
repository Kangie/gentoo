# Copyright 1999-2025 Gentoo Authors
# Distributed under the terms of the GNU General Public License v2

EAPI=7

inherit desktop eapi9-ver wrapper

DESCRIPTION="Golang IDE by JetBrains"
HOMEPAGE="https://www.jetbrains.com/go"
SRC_URI="
	amd64? ( https://download.jetbrains.com/go/${P}.tar.gz )
	arm64? ( https://download.jetbrains.com/go/${P}-aarch64.tar.gz )
"

SLOT="0"
KEYWORDS="~amd64 ~arm64"

LICENSE="|| ( JetBrains-business JetBrains-classroom JetBrains-educational JetBrains-individual )
	Apache-2.0
	BSD
	CC0-1.0
	CDDL
	CDDL-1.1
	EPL-1.0
	GPL-2
	GPL-2-with-classpath-exception
	ISC
	LGPL-2.1
	LGPL-3
	MIT
	MPL-1.1
	OFL-1.1
	ZLIB
"

RESTRICT="bindist mirror"

QA_PREBUILT="opt/${P}/*"

S="${WORKDIR}/GoLand-${PV}"

RDEPEND="
	virtual/jdk
	dev-lang/go
"

src_install() {
	local dir="/opt/${P}"

	insinto "${dir}"
	doins -r *
	fperms 755 "${dir}"/bin/{format.sh,goland.sh,inspect.sh,ltedit.sh,remote-dev-server.sh,restart.py,fsnotifier,repair}
	fperms 755 "${dir}"/jbr/bin/{java,javac,javadoc,jcmd,jdb,jfr,jhsdb,jinfo,jmap,jps,jrunscript,jstack,jstat,keytool,rmiregistry,serialver}
	fperms 755 "${dir}"/jbr/lib/{chrome-sandbox,jcef_helper,jexec,jspawnhelper}
	fperms 755 "${dir}"/plugins/go-plugin/lib/dlv/linux/dlv

	make_wrapper "${PN}" "${dir}/bin/${PN}.sh"
	newicon "bin/${PN}.png" "${PN}.png"
	make_desktop_entry "${PN}" "goland" "${PN}" "Development;IDE;"
}

pkg_postinst() {
	if [[ -z "${REPLACING_VERSIONS}" ]]; then
			# This is a new installation, so:
			echo
			elog "It is strongly recommended to increase the inotify watch limit"
			elog "to at least 524288. You can achieve this e.g. by calling"
			elog "echo \"fs.inotify.max_user_watches = 524288\" > /etc/sysctl.d/30-idea-inotify-watches.conf"
			elog "and reloading with \"sysctl --system\" (and restarting the IDE)."
			elog "For details see:"
			elog "    https://confluence.jetbrains.com/display/IDEADEV/Inotify+Watches+Limit"
	fi

	if ver_replacing -lt "2019.3-r1"; then
		# This revbump requires user interaction.
		echo
		ewarn "Previous versions configured fs.inotify.max_user_watches without user interaction."
		ewarn "Since version 2019.3-r1 you need to do so manually, e.g. by calling"
		ewarn "echo \"fs.inotify.max_user_watches = 524288\" > /etc/sysctl.d/30-idea-inotify-watches.conf"
		ewarn "and reloading with \"sysctl --system\" (and restarting the IDE)."
		ewarn "For details see:"
		ewarn "    https://confluence.jetbrains.com/display/IDEADEV/Inotify+Watches+Limit"
	fi
}
