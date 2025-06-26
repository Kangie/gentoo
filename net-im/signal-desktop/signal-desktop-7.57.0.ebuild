# Copyright 2025 Gentoo Authors
# Distributed under the terms of the GNU General Public License v2

# We need to be able to run `ebuild` commands before the vendor tarball is
# generated (i.e. to generate the tarball programmatically).
: ${SIGNAL_VENDOR_TARBALL:=1}

EAPI=8

#inherit autotools

DESCRIPTION="The Signal desktop client, but from source"

HOMEPAGE="https://www.signal.org/"

# kangie-gentoo-scripts/signal-desktop-vendor.sh
SRC_URI="https://github.com/signalapp/Signal-Desktop/archive/refs/tags/v${PV}.tar.gz -> ${P}.tar.gz"
if [[ ${SIGNAL_VENDOR_TARBALL} == 1 ]]; then
	SRC_URI+=" https://deps.gentoo.zip/net-im/signal-desktop/signal-desktop-vendor-${PV}.tar.xz"
fi

S="${WORKDIR}/Signal-Desktop-${PV}"

LICENSE="AGPL-3.0"
SLOT="0"
KEYWORDS="~amd64 ~arm64"
IUSE="bindist X wayland"

# HEIF support is patent encumbered; disable it for bindist builds.
RESTRICT="!bindist? ( bindist )"

#RDEPEND=""
#DEPEND="${RDEPEND}"
BDEPEND="dev-build/esbuild"

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

# The following src_install function is implemented as default by portage, so
# you only need to call it, if you need different behaviour.
#src_install() {
	# You must *personally verify* that this trick doesn't install
	# anything outside of DESTDIR; do this by reading and
	# understanding the install part of the Makefiles.
	# This is the preferred way to install.
	#emake DESTDIR="${D}" install

	# When you hit a failure with emake, do not just use make. It is
	# better to fix the Makefiles to allow proper parallelization.
	# If you fail with that, use "emake -j1", it's still better than make.

	# For Makefiles that don't make proper use of DESTDIR, setting
	# prefix is often an alternative.  However if you do this, then
	# you also need to specify mandir and infodir, since they were
	# passed to ./configure as absolute paths (overriding the prefix
	# setting).
	#emake \
	#	prefix="${D}"/usr \
	#	mandir="${D}"/usr/share/man \
	#	infodir="${D}"/usr/share/info \
	#	libdir="${D}"/usr/$(get_libdir) \
	#	install
	# Again, verify the Makefiles!  We don't want anything falling
	# outside of ${D}.
#}
