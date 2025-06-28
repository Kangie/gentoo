# Copyright 1999-2025 Gentoo Authors
# Distributed under the terms of the GNU General Public License v2

EAPI=8

inherit cargo cmake electron python-any-r1

DESCRIPTION="libsignal contains platform-agnostic APIs used by the official Signal clients and servers."
HOMEPAGE="https://signal.org/"
SRC_URI="https://github.com/signalapp/libsignal/archive/refs/tags/v${PV}.tar.gz -> ${P}.tar.gz"

LICENSE="AGPL-3.0"
SLOT="0"
KEYWORDS="~amd64 ~arm64"

# Build-time dependencies that need to be binary compatible with the system
# being built (CHOST). These include libraries that we link against.
# The below is valid if the same run-time depends are required to compile.
#DEPEND="${RDEPEND}"

# Build-time dependencies that are executed during the emerge process, and
# only need to be present in the native build system (CBUILD). Example:
#BDEPEND="virtual/pkgconfig"

# Refer to the SUSE spec if in doubt
# https://build.opensuse.org/projects/network:im:signal/packages/libsignal/files/libsignal.spec

pkg_setup() {
	# Use CFLAGS from the environment, not whatever rust thinks is apprapriate
	export CRATE_CC_NO_DEFAULTS=1
	# Ensure cmake gets the RelWithDebInfo profile
	export CARGO_PROFILE_RELEASE_DEBUG=2
	# make cmake louder?
	export VERBOSE=1
	export V=1
	# make `ring crate` output build log
	export CC_ENABLE_DEBUG_OUTPUT=1
}

# The following src_configure function is implemented as default by portage, so
# you only need to call it if you need a different behaviour.
#src_configure() {
	# Most open-source packages use GNU autoconf for configuration.
	# The default, quickest (and preferred) way of running configure is:
	#econf
	#
	# You could use something similar to the following lines to
	# configure your package before compilation.  The "|| die" portion
	# at the end will stop the build process if the command fails.
	# You should use this at the end of critical commands in the build
	# process.  (Hint: Most commands are critical, that is, the build
	# process should abort if they aren't successful.)
	#./configure \
	#	--host=${CHOST} \
	#	--prefix=/usr \
	#	--infodir=/usr/share/info \
	#	--mandir=/usr/share/man || die
	# Note the use of --infodir and --mandir, above. This is to make
	# this package FHS 2.2-compliant.  For more information, see
	#   https://wiki.linuxfoundation.org/lsb/fhs
#}

# The following src_compile function is implemented as default by portage, so
# you only need to call it, if you need different behaviour.
#src_compile() {
	# emake is a script that calls the standard GNU make with parallel
	# building options for speedier builds (especially on SMP systems).
	# Try emake first.  It might not work for some packages, because
	# some makefiles have bugs related to parallelism, in these cases,
	# use emake -j1 to limit make to a single process.  The -j1 is a
	# visual clue to others that the makefiles have bugs that have been
	# worked around.

	#emake
#}


src_test() {
	# TODO: We probably hove to modify this, it's mostly from the suse spec.
	# detect underlinking — compare electron_check_native_modules in the electron eclass
	! ldd -d -r node_modules/@signalapp/libsignal-client/build/Release/*.node | \
		grep    '^undefined symbol' | \
		grep -v '^undefined symbol: napi_' | \
		grep -v '^undefined symbol: uv_'

	# Sanity check that we did not mistakenly link system openssl instead of boringssl
	# since they have the same name and a similar set of exported symbols
	objdump -p node_modules/@signalapp/libsignal-client/build/Release/*.node > ${T}/objdump
	cat ${T}/objdump
	! grep -F libcrypto ${T}/objdump
	! grep -F libssl ${T}/objdump
}

src_install() {
	#It does not actually matter what the library is named as long as it's in the correct directory
	install -pvDm755 target/release/libsignal_node.so \
	${D}/usr/libexec/signal-desktop/node_modules/@signalapp/libsignal-client/build/Release/signal_node.node
}
