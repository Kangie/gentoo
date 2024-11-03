# Copyright 1999-2024 Gentoo Authors
# Distributed under the terms of the GNU General Public License v2

# @ECLASS: rust.eclass
# @MAINTAINER:
# Matt Jolly <kangie@gentoo.org>
# @AUTHOR:
# Matt Jolly <kangie@gentoo.org>
# @SUPPORTED_EAPIS: 8
# @PROVIDES: rust-utils
# @BLURB: Utility functions to build against slotted Rust
# @DESCRIPTION:
# An eclass to reliably depend a Rust/LLVM combination for
# a given Rust (or LLVM) slot.
#
# 1. If required, set RUST_{MAX,MIN}_SLOT to the range of supported slots.
# 2. Use rust_gen_deps to add appropriate dependencies. (rust_gen_llvm_deps for LLVM)
# 3. Use rust_pkg_setup, get_rust_prefix or RUST_SLOT.

# Example use for a package supporting Rust 1.72.0 to 1.82.0:
# @CODE
#
# RUST_MAX_SLOT="1.82.0"
# RUST_MIN_SLOT="1.72.0"
#
# inherit meson rust
#
# BDEPEND="
#	$(rust_gen_deps)
# "
#
# # only if you need to define one explicitly
# pkg_setup() {
#	rust_pkg_setup
#	do-something-else
# }
# @CODE
#
# Example for a package needing Rust w/ a specific target:
# @CODE
# inherit meson rust
#
# RDEPEND="
#	$(rust_gen_deps)
# "
# DEPEND=${RDEPEND}
#
# rust_check_deps() {
#	has_version -d "dev-lang/rust:${RUST_SLOT}[profiler(-)]"
# }
# @CODE

case ${EAPI} in
	8) ;;
	*) die "${ECLASS}: EAPI ${EAPI:-0} not supported" ;;
esac

if [[ -z ${_RUST_ECLASS} ]]; then
_RUST_ECLASS=1

inherit llvm-utils

# == internal control knobs ==

# @ECLASS_VARIABLE: _RUST_KNOWN_SLOTS
# @INTERNAL
# @DESCRIPTION:
# Definitive list of Rust slots and the associated LLVM slot, newest first.
declare -A -g -r _RUST_KNOWN_SLOTS=(
	["1.82.0"]=19
	["1.81.0"]=18
	["1.80.1"]=18
	["1.79.0"]=18
	["1.77.1"]=17
	["1.75.0"]=17
	["1.74.1"]=17
	["1.71.1"]=16
)

# @ECLASS_VARIABLE: _RUST_OLDEST_SLOT
# @INTERNAL
# @DESCRIPTION:
# Oldest supported Rust slot.  This is used to automatically filter out
# unsupported LLVM_COMPAT values.
_RUST_OLDEST_SLOT="1.71.1"

# @ECLASS_VARIABLE: _LLVM_NEWEST_STABLE
# @INTERNAL
# @DESCRIPTION:
# The newest stable Rust version.  Versions newer than that won't
# be automatically enabled via USE defaults.
_RUST_NEWEST_STABLE="1.81.0"

# == control variables ==

# @ECLASS_VARIABLE: RUST_MAX_SLOT
# @DEFAULT_UNSET
# @DESCRIPTION:
# Highest Rust slot supported by the package. Needs to be set before
# rust_pkg_setup is called. If unset, no upper bound is assumed.

# @ECLASS_VARIABLE: RUST_MIN_SLOT
# @DEFAULT_UNSET
# @DESCRIPTION:
# Lowest Rust slot supported by the package. Needs to be set before
# rust_pkg_setup is called. If unset, no lower bound is assumed.

# @ECLASS_VARIABLE: RUST_ECLASS_SKIP_PKG_SETUP
# @INTERNAL
# @DESCRIPTION:
# If set to a non-empty value, rust_pkg_setup will not perform Rust version
# check, nor set PATH.

# == global metadata ==

# @ECLASS_VARIABLE: RUST_REQUIRED_USE
# @OUTPUT_VARIABLE
# @DESCRIPTION:
# An eclass-generated REQUIRED_USE string that enforces selecting
# exactly one slot.

# @ECLASS_VARIABLE: RUST_USEDEP
# @OUTPUT_VARIABLE
# @DESCRIPTION:
# An eclass-generated USE dependency string that can be applied to other
# packages using the same eclass, to enforce a Rust slot match.

_rust_set_globals() {
	debug-print-function ${FUNCNAME} "$@"

	# These aren't guaranteed to be set so we need to check for them
	if [[ -z ${RUST_MAX_SLOT} ]]; then
		local RUST_MAX_SLOT="0"
	fi
	if [[ -z ${RUST_MIN_SLOT} ]]; then
		local RUST_MIN_SLOT="0"
	fi

	if [[ ${RUST_MAX_SLOT} != "0" && ${RUST_MIN_SLOT} != "0" ]]; then
		if ! ver_test ${RUST_MAX_SLOT} -ge ${RUST_MIN_SLOT}; then
			die "RUST_MAX_SLOT must be greater than or equal to RUST_MIN_SLOT"
		fi
	fi

	# Make an array of slots that are acceptable so that we can leverage llvm-r1 logic
	local acceptable_slots=()
	local slot
	for slot in "${_RUST_KNOWN_SLOTS[@]}"; do
		if [[ ${RUST_MAX_SLOT} == "0" ]] || ver_test ${slot} -le ${RUST_MAX_SLOT}; then
			if [[ ${RUST_MIN_SLOT} == "0" ]] || ver_test ${slot} -ge ${RUST_MIN_SLOT}; then
				acceptable_slots+=( "${slot}" )
			fi
		fi
	done

	local stable=() testing=()
	for slot in "${acceptable_slots[@]}"; do
		if ver_test ${slot} -gt ${_RUST_NEWEST_STABLE} ; then
			testing+=( "${slot//./}" )
		elif [[ ${slot} -ge ${_RUST_OLDEST_SLOT} ]]; then
			stable+=( "${slot//./}" )
		fi
	done

	_RUST_SLOTS=( "${stable[@]}" "${testing[@]}" )
	if [[ ! ${_RUST_SLOTS[@]} ]]; then
		die "Check RUST_{MAX,MIN}_SLOT; no valid versions found (all older than ${_RUST_OLDEST_SLOT}?)"
	fi

	if [[ ${stable[@]} ]]; then
		# If there is at least one stable slot supported, then enable
		# the newest stable slot by default.
		IUSE="+rust_slot_${stable[-1]}"
		unset 'stable[-1]'
	else
		# Otherwise, enable the "oldest" ~arch slot.  We really only
		# expect a single ~arch version, so this primarily prevents
		# defaulting to non-keyworded slots.
		IUSE="+rust_slot_${testing[0]}"
		unset 'testing[0]'
	fi
	local nondefault=( "${stable[@]}" "${testing[@]}" )
	IUSE+=" ${nondefault[*]/#/rust_slot_}"

	local flags=( "${_RUST_SLOTS[@]/#/rust_slot_}" )
	RUST_REQUIRED_USE="^^ ( ${flags[*]} )"
	local usedep_flags=${flags[*]/%/(-)?}
	RUST_USEDEP=${usedep_flags// /,}
	readonly RUST_REQUIRED_USE RUST_USEDEP
}
_rust_set_globals
unset -f _rust_set_globals

# == metadata helpers ==

# @FUNCTION: rust_gen_deps
# @USAGE: <dependency>
# @DESCRIPTION:
# Output a dependency block, to all rust_slot_* USE flags.
# The dependency will match either sys-devel/rust:${RUST_SLOT}
# or sys-devel/rust-bin:${RUST_SLOT}.
#
# Example:
# @CODE
# DEPEND="
#   $(rust_gen_deps)
# @CODE
rust_gen_deps() {
	debug-print-function ${FUNCNAME} "$@"

	local slot
	local use_slot

	local RUST_DEPS=()

	for slot in "${_RUST_SLOTS[@]}"; do
		use_slot=${slot//./}

		RUST_DEPS+=( "rust_slot_${use_slot}? (" )
		RUST_DEPS+=( "|| ( dev-lang/rust:${slot} dev-lang/rust-bin:${slot} )" )
		RUST_DEPS+=( ")" )
	done
	echo "${RUST_DEPS[@]}"
}

# @FUNCTION: rust_gen_llvm_deps
# @USAGE: <slot>
# @DESCRIPTION:
# Output a dependency block for the appropriate Rust slot based on LLVM_SLOT passed
# as an argument. Call this within `llvm_gen_dep` to generate Rust dependencies for
# LLVM_COMPAT.
#
# Example:
# @CODE
# DEPEND="
#   $(llvm_gen_dep \"
#     sys_devel/clang:\${LLVM_SLOT}
#     $(rust_llvm_gen_deps \${LLVM_SLOT}\")
#   )"
rust_gen_llvm_deps() {
	debug-print-function ${FUNCNAME} "$@"

	local llvm_slot=${1}
	local slots=()
	# Get all keys that match the slot we were passed
	for slot in "${_RUST_SLOTS[@]}"; do
		if [[ ${_RUST_KNOWN_SLOTS[${slot}]} == ${llvm_slot} ]]; then
			slots+=( "${slot}" )
		fi
	done

	local RUST_DEPS=()
	local slot
	RUST_DEPS+=( "|| (" )
	for slot in "${slots[@]}"; do
		RUST_DEPS+=( "dev-lang/rust:${slot}[llvm_compat_${llvm_slot}]" )
		RUST_DEPS+=( "dev-lang/rust-bin:${slot}[llvm_compat_${llvm_slot}]" )
	done
	RUST_DEPS+=( ")" )

	echo "${RUST_DEPS[@]}"
}

# == ebuild helpers ==

# @FUNCTION: get_rust_slot
# @USAGE: [-b|-d]
# @DESCRIPTION:
# Find the newest Rust install that is acceptable for the package,
# and print its version number (.i.e SLOT) and type (source or bin[ary]).
#
# If -b is specified, the checks are performed relative to BROOT,
# and BROOT-path is returned.
#
# If -d is specified, the checks are performed relative to ESYSROOT,
# and ESYSROOT-path is returned. -d is the default.
#
# If <min_slot> or <max_slot> is non-zero, then only Rust versions that
# are not newer or older than the specified slot(s) will be considered.
# Otherwise, all Rust versions are be considered acceptable.
#
# If the `rust_check_deps()`` function is defined within the ebuild, it
# will be called to verify whether a particular slot is accepable.
# Within the function scope, RUST_SLOT and LLVM_SLOT will be defined.
#
# The function should return a true status if the slot is acceptable,
# false otherwise. If rust_check_deps() is not defined, the function
# defaults to checking whether a suitable Rust package is installed.
get_rust_slot() {
	debug-print-function ${FUNCNAME} "$@"

	local hv_switch=-d
	while [[ ${1} == -* ]]; do
		case ${1} in
			-b|-d) hv_switch=${3};;
			*) break;;
		esac
		shift
	done

	local max_slot min_slot
	if [[ -z ${RUST_MAX_SLOT} ]]; then
		max_slot="0"
	else
		max_slot=${RUST_MAX_SLOT}
	fi
	if [[ -z ${RUST_MIN_SLOT} ]]; then
		min_slot="0"
	else
		min_slot=${RUST_MIN_SLOT}
	fi
	local slot
	local llvm_slot

	# iterate over known slots, newest first
	for slot in "${_RUST_KNOWN_SLOTS[@]}"; do
		llvm_slot=${_RUST_KNOWN_SLOTS[${slot}]}
		# skip higher slots
		if [ ${max_slot} -ne 0 ]; then
			if [[ ${max_slot} == ${slot} ]]; then
				max_slot=
			else
				continue
			fi
		fi

		if declare -f rust_check_deps >/dev/null; then
			local RUST_SLOT=${slot}
			local LLVM_SLOT=${llvm_slot}
			rust_check_deps || continue
		else
			local rust_type
			# Check for an appropriate Rust version and its type.
			# Prefer the from-source version "because"
			if (has_version ${hv_switch} "dev-lang/rust:${slot}" ||
				has_version ${hv_switch} "dev-lang/rust-bin:${slot}"); then
				if has_version ${hv_switch} "dev-lang/rust:${slot}"; then
					rust_type="source"
				else
					rust_type="binary"
				fi
				echo ${slot}
				echo ${rust_type}
				return
			fi
		fi

		# We want to process the slot before escaping the loop if we've hit min_slot
		if [ "${min_slot}" -ne 0 ]; then
			if [[ ${slot} == "${min_slot}" ]]; then
				break
			fi
		fi

	done

	# max_slot should have been unset in the iteration
	if [[ -n ${max_slot} ]]; then
		die "${FUNCNAME}: invalid max_slot=${max_slot}"
	fi

	die "No Rust slot${1:+ <= ${1}} satisfying the package's dependencies found installed!"
}

# @FUNCTION: get_rust_prefix
# @USAGE: [-b|-d]
# @DESCRIPTION:
# Find the newest Rust install that is acceptable for the package,
# and print an absolute path to it. If both -bin and regular Rust
# are installed, the regular Rust is preferred.
#
# The options and behavior are the same as get_rust_slot.
get_rust_prefix() {
	debug-print-function ${FUNCNAME} "$@"

	local prefix=${ESYSROOT}
	[[ ${1} == -b ]] && prefix=${BROOT}

	local slot rust_type
	read -r slot rust_type <<< $(get_rust_slot "${@}")

	if [[ ${rust_type} == "source" ]]; then
		echo "${prefix}/usr/lib/rust/${slot}"
	else
		echo "${prefix}/opt/rust-bin-${slot}/"
	fi
}

# @FUNCTION: rust_prepend_path
# @USAGE: <slot> <type>
# @DESCRIPTION:
# Prepend the path to the specified Rust to PATH and re-export it.
rust_prepend_path() {
	debug-print-function ${FUNCNAME} "$@"

	[[ ${#} -ne 2 ]] && die "Usage: ${FUNCNAME} <slot> <type>"
	local slot=${1}

	local rust_path
	if [[ ${2} == "source" ]]; then
		rust_path=${ESYSROOT}/usr/lib/rust/${slot}/bin
	else
		rust_path=${ESYSROOT}/opt/rust-bin-${slot}/bin
	fi

	export PATH="${rust_path}:${PATH}"
}

# @FUNCTION: rust_pkg_setup
# @DESCRIPTION:
# Prepend the appropriate executable directory for the newest
# acceptable Rust slot to the PATH. If used with LLVM, an appropriate
# `llvm_pkg_setup` call should be made in addition to this function.
# For path determination logic, please see the get_rust_prefix documentation.
#
# The highest acceptable Rust slot can be set in LLVM_MAX_SLOT variable.
# If it is unset or empty, any slot is acceptable.
#
# The lowest acceptable Rust slot can be set in LLVM_MIN_SLOT variable.
# If it is unset or empty, any slot is acceptable.
#
# The PATH manipulation is only done for source builds. The function
# is a no-op when installing a binary package.
#
# If any other behavior is desired, the contents of the function
# should be inlined into the ebuild and modified as necessary.
rust_pkg_setup() {
	debug-print-function ${FUNCNAME} "$@"

	if [[ ${RUST_ECLASS_SKIP_PKG_SETUP} ]]; then
		return
	fi

	if [[ ${MERGE_TYPE} != binary ]]; then
		if [[ -z ${RUST_MAX_SLOT} ]]; then
			RUST_MAX_SLOT="0"
		fi
		if [[ -z ${RUST_MIN_SLOT} ]]; then
			RUST_MIN_SLOT="0"
		fi
		{ read -r RUST_SLOT; read -r RUST_TYPE; } <<< $(get_rust_slot "${RUST_MIN_SLOT}" "${RUST_MAX_SLOT}")
		rust_prepend_path "${RUST_SLOT}" "${RUST_TYPE}"
	fi
}

fi

EXPORT_FUNCTIONS pkg_setup
