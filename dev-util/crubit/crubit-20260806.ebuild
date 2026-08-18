# Copyright 1999-2026 Gentoo Authors
# Distributed under the terms of the GNU General Public License v2

EAPI=8

CRATES="
	aho-corasick@1.1.4
	anstream@1.0.0
	anstyle-parse@1.0.0
	anstyle-query@1.1.5
	anstyle-wincon@3.0.11
	anstyle@1.0.14
	anyhow@1.0.104
	autocfg@1.5.1
	base64@0.22.1
	bitflags@2.13.1
	camino@1.2.4
	cargo-platform@0.3.3
	cargo_metadata@0.23.1
	cfg-if@1.0.4
	clap-cargo@0.18.3
	clap@4.6.4
	clap_builder@4.6.2
	clap_derive@4.6.4
	clap_lex@1.1.0
	colorchoice@1.0.5
	either@1.16.0
	errno@0.3.14
	fastrand@2.5.0
	flagset@0.4.7
	getrandom@0.4.3
	googletest@0.14.3
	googletest_macro@0.14.3
	heck@0.5.0
	indenter@0.3.4
	is_terminal_polyfill@1.70.2
	itertools@0.13.0
	itoa@1.0.18
	libc@0.2.189
	linux-raw-sys@0.12.1
	memchr@2.8.3
	num-traits@0.2.19
	once_cell@1.21.4
	once_cell_polyfill@1.70.2
	phf@0.11.3
	phf_generator@0.11.3
	phf_macros@0.11.3
	phf_shared@0.11.3
	proc-macro2@1.0.107
	quote@1.0.47
	r-efi@6.0.0
	rand@0.8.7
	rand_core@0.6.4
	regex-automata@0.4.16
	regex-syntax@0.8.11
	regex@1.13.1
	rustix@1.1.4
	rustversion@1.0.23
	semver@1.0.28
	serde@1.0.229
	serde_core@1.0.229
	serde_derive@1.0.229
	serde_json@1.0.151
	siphasher@1.0.3
	static_assertions@1.1.0
	strsim@0.11.1
	syn@2.0.119
	syn@3.0.3
	tempfile@3.27.0
	thiserror-impl@2.0.19
	thiserror@2.0.19
	unicode-ident@1.0.24
	utf8parse@0.2.2
	windows-link@0.2.1
	windows-sys@0.61.2
	zmij@1.0.23
"

LLVM_COMPAT=( 22 )
RUST_MIN_VER=1.97.0
RUST_NEEDS_LLVM="most certainly"
RUST_REQ_USE="rustc-dev,rust-src"

inherit cargo llvm-r1

DESCRIPTION="Crubit is a tool for interop between C++ and Rust"
HOMEPAGE="https://github.com/google/crubit"

MY_COMMIT=0e0a26dc95c4f2b190831dcecf950e480d5413f9
SRC_URI="https://github.com/google/crubit/archive/${MY_COMMIT}.tar.gz -> ${P}.tar.gz
	${CARGO_CRATE_URIS}
"
S="${WORKDIR}/${PN}-${MY_COMMIT}"

IUSE="${LLVM_REQUIRED_USE}"

LICENSE=""
# Crates
LICENSE+=" Apache-2.0 MIT Unicode-3.0"
SLOT="0"
KEYWORDS="~amd64"

QA_PRESTRIPPED="/usr/bin/cc_bindings_from_rs"

pkg_setup() {
	llvm-r1_pkg_setup
	rust_pkg_setup
}

src_compile() {
	export RUSTC_BOOTSTRAP=1 # `#![feature]` may not be used on the stable release channel
	# Crubit expects to be built with Google's env, we need to tell it where to find LLVM/Rust libs it's linked to.
	local rust_libdir="$(get_rust_prefix)/lib"
	local llvm_libdir="$(get_llvm_prefix)/$(get_libdir)"
	export RUSTFLAGS="${RUSTFLAGS} -C link-arg=-L${llvm_libdir}"
	export RUSTFLAGS="${RUSTFLAGS} -C link-arg=-Wl,-rpath=${llvm_libdir} -C link-arg=-Wl,-rpath=${rust_libdir}"
	# Will probably also need rs_bindings_from_cc, which is a cpp app built with bazel...
	cargo_src_compile --package cc_bindings_from_rs
}

src_install() {
	dobin target/release/cc_bindings_from_rs
}
