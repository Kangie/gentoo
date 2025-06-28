# Copyright 1999-2025 Gentoo Authors
# Distributed under the terms of the GNU General Public License v2

EAPI=8

PYTHON_COMPAT=( python3_{11..13} )

declare -A GIT_CRATES=(
        [boring-sys]='https://github.com/signalapp/boring;bb42da53b3900aea1936d41decf9403f25c4259c;boring-%commit%/boring-sys'
        [boring]='https://github.com/signalapp/boring;bb42da53b3900aea1936d41decf9403f25c4259c;boring-%commit%/boring'
        [curve25519-dalek-derive]='https://github.com/signalapp/curve25519-dalek;7c6d34756355a3566a704da84dce7b1c039a6572;curve25519-dalek-%commit%/curve25519-dalek-derive'
        [curve25519-dalek]='https://github.com/signalapp/curve25519-dalek;7c6d34756355a3566a704da84dce7b1c039a6572;curve25519-dalek-%commit%/curve25519-dalek'
        [spqr]='https://github.com/signalapp/SparsePostQuantumRatchet;d6c10734689ec5844d09c1a054a288d36cde2adc;SparsePostQuantumRatchet-%commit%'
        [tokio-boring]='https://github.com/signalapp/boring;bb42da53b3900aea1936d41decf9403f25c4259c;boring-%commit%/tokio-boring'
)

inherit cargo python-any-r1

DESCRIPTION="libsignal contains platform-agnostic APIs used by the official Signal clients and servers."
HOMEPAGE="https://signal.org/"
SRC_URI="
	https://github.com/signalapp/libsignal/archive/refs/tags/v${PV}.tar.gz -> ${P}.tar.gz
	https://deps.gentoo.zip/net-im/libsignal/${P}-crates.tar.xz
"

LICENSE="AGPL-3.0"
SLOT="0"
KEYWORDS="~amd64 ~arm64"

# Build-time dependencies that need to be binary compatible with the system
# being built (CHOST). These include libraries that we link against.
# The below is valid if the same run-time depends are required to compile.
#DEPEND="${RDEPEND}"

BDEPEND="
	dev-build/cmake
	sys-devel/cargo-auditability
"

# Refer to the SUSE spec if in doubt
# https://build.opensuse.org/projects/network:im:signal/packages/libsignal/files/libsignal.spec

PATCHES=(
	# Patch build scriptt
	"${FILESDIR}"/${PN}-build_node_bridge-inject-options.patch
	# fix rust breaking gcc LTO
	#"${FILESDIR}"/${PN}-boringssl-sys-no-static.patch
	"${FILESDIR}"/${PN}-client-visibility-hidden.patch
	#"${FILESDIR}"/${PN}-cc-link-lib-no-static.patch
	#"${FILESDIR}"/${PN}-ring-no-static.patch
	# Tests	
	"${FILESDIR}"/${PN}-remove-message-backup-test.patch
	"${FILESDIR}"/${PN}-dns_lookup-test.patch
)

pkg_setup() {
	rust_pkg_setup
	python-any-r1_pkg_setup
	# Do we need to build against electron node?

	# Use CFLAGS from the environment, not whatever rust thinks is apprapriate
	export CRATE_CC_NO_DEFAULTS=1
	# Ensure cmake gets the RelWithDebInfo profile
	export CARGO_PROFILE_RELEASE_DEBUG=2
	# make cmake louder?
	export VERBOSE=1
	export V=1
	# make `ring crate` output build log
	export CC_ENABLE_DEBUG_OUTPUT=1
	# Disable incremental compilation
	export CARGO_INCREMENTAL=0
}

src_compile() {
	${EPYTHON} ./node/build_node_bridge.py --auditable --check
}


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

	${EPYTHON} ./node/build_node_bridge.py --check
}

src_install() {
	#It does not actually matter what the library is named as long as it's in the correct directory
	install -pvDm755 target/release/libsignal_node.so \
	${D}/usr/libexec/signal-desktop/node_modules/@signalapp/libsignal-client/build/Release/signal_node.node
}
