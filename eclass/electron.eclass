# Copyright 2025 Gentoo Authors
# Distributed under the terms of the GNU General Public License v2

# This eclass provides helper functions for packages that build against Electron

case ${EAPI} in
	8) ;;
	*) die "${ECLASS}: EAPI ${EAPI:-0} not supported" ;;
esac

if [[ -z ${_ELECTRON_ECLASS} ]]; then
_ELECTRON_ECLASS=1

# @ECLASS_VARIABLE: _ELECTRON_ABI_MAP
# @INTERNAL
# @DESCRIPTION:
# Map of Electron slots (ABI versions) to their real version.
declare -A -g -r _ELECTRON_ABI_MAP=(
	[135]=36
)

# @ECLASS_VARIABLE: _ELECTRON_ABI_ORDERED
# @INTERNAL
# @DESCRIPTION:
# Array of Electron ABI versions (slots), newest first.
# available at https://github.com/nodejs/node/blob/main/doc/abi_version_registry.json
declare -a -g -r _ELECTRON_ABI_ORDERED=(
	135
)

# @ECLASS_VARIABLE: ELECTRON_MAX_ABI
# @DEFAULT_UNSET
# @DESCRIPTION:
# Highest Electron slot supported by the package. Needs to be set before
# electron_pkg_setup is called. If unset, no upper bound is assumed.

# @ECLASS_VARIABLE: ELECTRON_MIN_ABI
# @DEFAULT_UNSET
# @DESCRIPTION:
# Lowest Electron slot supported by the package. Needs to be set before
# electron_pkg_setup is called. If unset, no lower bound is assumed.

# @ECLASS_VARIABLE: ELECTRON_SLOT
# @OUTPUT_VARIABLE
# @DESCRIPTION:
# The selected Electron slot for building, from the range defined by
# ELECTRON_MAX_VER and ELECTRON_MIN_VER. This is set by electron_pkg_setup.

# @ECLASS_VARIABLE: ELECTRON_TYPE
# @OUTPUT_VARIABLE
# @DESCRIPTION:
# The selected Electron type for building, either 'source' or 'binary'.
# This is set by electron_pkg_setup.

# @ECLASS_VARIABLE: ELECTRON_DEPEND
# @OUTPUT_VARIABLE
# @DESCRIPTION:
# This is an eclass-generated Electron dependency string, filtered by
# ELECTRON_MAX_VER and ELECTRON_MIN_VER.

# @ECLASS_VARIABLE: ELECTRON_OPTIONAL
# @DEFAULT_UNSET
# @DESCRIPTION:
# If set to a non-empty value, the Electron dependency will not be added
# to BDEPEND. This is useful for packages that need to gate electron behind
# certain USE themselves.

# @ECLASS_VARIABLE: ELECTRON_NATIVE_MODULES
# @DEFAULT_UNSET
# @DESCRIPTION:
# If set to a non-empty value eclass-generated dependencies will include slot rebuild operators

# @ECLASS_VARIABLE: ELECTRON_REQ_USE
# @DEFAULT_UNSET
# @DESCRIPTION:
# Additional USE-dependencies to be added to the Electron dependency.

# @FUNCTION: _electron_set_globals
# @INTERNAL
# @DESCRIPTION:
# Set up Electron dependency string based on version constraints.
_electron_set_globals() {
	local usedep="${ELECTRON_REQ_USE+[${ELECTRON_REQ_USE}]}"
	local slot_operator='*'
	local electron_dep=()

	if [[ -n ${ELECTRON_NATIVE_MODULES} ]]; then
		slot_operator="="
	fi

	electron_dep=( "|| (" )

	# If we don't have a max version, we can be more flexible
	if [[ -z "${ELECTRON_MAX_VER}" ]]; then
		electron_dep+=(
			">=dev-util/electron-bin-${ELECTRON_MIN_VER:-30}:${slot_operator}${usedep}"
			">=dev-util/electron-${ELECTRON_MIN_VER:-30}:${slot_operator}${usedep}"
		)
	else
		# Depend on each slot between ELECTRON_MIN_VER and ELECTRON_MAX_VER
		local slot
		for slot in "${_ELECTRON_ABI_ORDERED[@]}"; do
			if [[ -n ${ELECTRON_MIN_VER} && ${slot} -lt ${ELECTRON_MIN_VER} ]]; then
				continue
			fi
			if [[ -n ${ELECTRON_MAX_VER} && ${slot} -gt ${ELECTRON_MAX_VER} ]]; then
				continue
			fi
			electron_dep+=(
				"dev-util/electron-bin:${slot}${usedep}"
				"dev-util/electron:${slot}${usedep}"
			)
		done
	fi
	electron_dep+=( ")" )
	ELECTRON_DEPEND="${electron_dep[*]}"

	readonly ELECTRON_DEPEND
	if [[ -z ${ELECTRON_OPTIONAL} ]]; then
		BDEPEND="${ELECTRON_DEPEND}"
		RDEPEND="${ELECTRON_DEPEND}"
	fi
}
_electron_set_globals
unset -f _electron_set_globals

# @FUNCTION: electron_build_native_modules
# @DESCRIPTION:
# Rebuild Node native modules against the Electron version specified by ELECTRON_SLOT.
# This function should be called in src_compile if native modules.
electron_build_native_modules() {
	if [[ -z ${_ELECTRON_PKG_SETUP} ]]; then
		die "electron_pkg_setup must be called before ${FUNCNAME}"
	fi
	local node_include_dir
	case ${ELECTRON_TYPE} in
		source)
			node_include_dir="${EPREFIX}/usr/include/electron/${ELECTRON_ABI_MAP[${ELECTRON_SLOT}]}"
			;;
		binary)
			node_include_dir="${EPREFIX}/opt/include/electron/${ELECTRON_ABI_MAP[${ELECTRON_SLOT}]}"
			;;
		*)
			die "Invalid ELECTRON_TYPE: ${ELECTRON_TYPE}"
			;;
	esac
	# Use Electron's ability to masquerade as nodejs to build native modules against itself.
	# https://www.electronjs.org/docs/latest/tutorial/using-native-node-modules#manually-building-for-a-custom-build-of-electron
	PATH="${ELECTRON_DIR}:${PATH}" "${EPREFIX}"/usr/$(get_libdir)/node_modules/npm/bin/npm rebuild --verbose \
		--foreground-scripts --nodedir="${node_include_dir}" ||
			die "Failed to rebuild native modules against Electron ${ELECTRON_SLOT} (${ELECTRON_TYPE})"
}

# @FUNCTION: electron_check_native_modules
# @DESCRIPTION:
# Check that native modules are properly linked and can be loaded by Electron.
# This function should be called in src_test.
electron_check_native_modules() {

	if [[ -z ${_ELECTRON_PKG_SETUP} ]]; then
		die "electron_pkg_setup must be called before ${FUNCNAME}"
	fi

	# 1. Detect underlinking (missing dependencies)
	# 2. Detect accidental linking to libuv which must not be used (Electron exports its own incompatible version)
	# 3. Actually load each module

	einfo "Checking native modules for proper linking and compatibility..."

	# Check for undefined symbols (except NAPI and libuv which are expected)
	find "${ED}" -type f -name '*.node' -print0 | \
		xargs -0 -I{} sh -c 'ldd -d -r "{}" 2>&1 | grep "^undefined symbol" | grep -v "napi_" | grep -v "uv_" && exit 1 || true' || \
		die "Found undefined symbols in native modules"

	# Check that native modules don't link against system libuv (Electron provides its own)
	find "${ED}" -type f -name '*.node' -print0 | \
		xargs -0 -I{} sh -c 'objdump -p "{}" | grep -F libuv.so && exit 1 || true' || \
		die "Native modules incorrectly linked against system libuv"

	# Test that each module can actually be loaded by Electron
	find "${ED}" -type f -name '*.node' -print0 | \
		xargs -0 -I{} env ELECTRON_RUN_AS_NODE=1 "${ELECTRON}" -e 'require("{}")' || \
		die "Native modules failed to load in Electron"
}

# @FUNCTION: electron_detect_native_modules
# @DESCRIPTION:
# Detect native modules in node_modules and rebuild them against the Electron version specified by ELECTRON_SLOT.
# This function should be called in src_compile
electron_detect_native_modules() {
	if [[ -z ${_ELECTRON_PKG_SETUP} ]]; then
		die "electron_pkg_setup must be called before ${FUNCNAME}"
	fi
	if [[ ! -d node_modules ]]; then
		einfo "No node_modules directory found, skipping native module detection."
		return 0
	fi
	# Detect native modules in the current directory and rebuild them against Electron.
	# This is useful for packages that have native modules in their source tree.
	local modules
	modules=$(find node_modules -type f -name "*.node" 2>/dev/null | grep -v "obj\.target")
	if [[ -z ${modules} ]]; then
		einfo "No native modules found in node_modules."
		return 0
	fi

	electron_build_native_modules || die "Failed to detect native modules"
}

# @FUNCTION: _get_electron_slot
# @INTERNAL
# @DESCRIPTION:
# Find the newest Electron install that is acceptable for the package,
# and export its version (i.e. SLOT) and type (source or bin[ary])
# as ELECTRON_SLOT and ELECTRON_TYPE.
_get_electron_slot() {
	local slot acceptable_slots=()

	# Find all acceptable slots
	for slot in "${_ELECTRON_ABI_ORDERED[@]}"; do
		if [[ -n ${ELECTRON_MIN_VER} && ${slot} -lt ${ELECTRON_MIN_VER} ]]; then
			continue
		fi
		if [[ -n ${ELECTRON_MAX_VER} && ${slot} -gt ${ELECTRON_MAX_VER} ]]; then
			continue
		fi

		einfo "Checking for Electron slot ${slot}..."
		# Check if electron-bin or electron is actually installed
		if has_version "dev-util/electron-bin:${slot}" || has_version "dev-util/electron:${slot}"; then
			acceptable_slots+=( "${slot}" )
		fi
	done

	if [[ ${#acceptable_slots[@]} -eq 0 ]]; then
		local requirement_msg=""
		[[ -n ${ELECTRON_MAX_VER} ]] && requirement_msg+="<= ${ELECTRON_MAX_VER} "
		[[ -n ${ELECTRON_MIN_VER} ]] && requirement_msg+=">= ${ELECTRON_MIN_VER} "
		requirement_msg="${requirement_msg% }"
		die "No Electron matching requirements${requirement_msg:+ (${requirement_msg})} found installed!"
	fi

	# Use the newest acceptable slot
	ELECTRON_SLOT="${acceptable_slots[0]}"

	# Prefer source over binary if both are available
	if has_version "dev-util/electron:${ELECTRON_SLOT}"; then
		ELECTRON_TYPE="source"
	elif has_version "dev-util/electron-bin:${ELECTRON_SLOT}"; then
		ELECTRON_TYPE="binary"
	else
		die "No Electron package found for slot ${ELECTRON_SLOT}"
	fi
}

# @FUNCTION: get_electron_path
# @USAGE: slot electron_type
# @DESCRIPTION:
# Given arguments of slot and electron_type, return an appropriate path
# for the Electron install. The electron_type should be either "source"
# or "binary". If the electron_type is not one of these, the function
# will die.
get_electron_path() {
	local slot="${1}"
	local electron_type="${2}"

	if [[ ${#} -ne 2 ]]; then
		die "${FUNCNAME}: invalid number of arguments"
	fi

	case ${electron_type} in
		source) echo "/usr/$(get_libdir)/electron/${_ELECTRON_ABI_MAP[$slot]}/";;
		binary) echo "/opt/electron/electron-${_ELECTRON_ABI_MAP[$slot]}/";;
		*) die "${FUNCNAME}: invalid electron_type=${electron_type}";;
	esac
}

# @FUNCTION: get_electron_prefix
# @DESCRIPTION:
# Find the newest Electron install that is acceptable for the package,
# and print an absolute path to it. If both -bin and regular Electron
# are installed, the regular Electron is preferred.
get_electron_prefix() {
	_get_electron_slot
	get_electron_path "${ELECTRON_SLOT}" "${ELECTRON_TYPE}"
}

electron_builder_bail_after_building() {
	if [[ -z ${_ELECTRON_PKG_SETUP} ]]; then
		die "electron_pkg_setup must be called before ${FUNCNAME}"
	fi

	cat <<-EOF > "${S}/gentoo-config.js"
// Load the original configuration from the project's package.json
const originalConfig = require('./package.json').build;

// Define the new configuration by merging the original our hook
const newConfig = {
...originalConfig, // Spread the original config first
afterPack: (context) => {
	console.log('✅ afterAsar hook triggered from external process.');
	console.log('app.asar created at: ${S}/dist/linux-unpacked/resources/app.asar');

	console.log('Build process will now terminate as requested.');
	process.exit(0); // Success code
},
};

// Export the new configuration
module.exports = newConfig;
EOF
	einfo "Created ${S}/esbuild-gentoo-config.js to bail out after building asar"
	return 0
	
}

# @FUNCTION: electron_pkg_setup
# @DESCRIPTION:
# Find and set up the appropriate Electron installation for the package.
# Sets ELECTRON_SLOT and ELECTRON_TYPE variables and exports ELECTRON.
#
# The highest acceptable Electron slot can be set in the ELECTRON_MAX_VER variable.
# If it is unset or empty, any slot is acceptable.
#
# The lowest acceptable Electron slot can be set in the ELECTRON_MIN_VER variable.
# If it is unset or empty, any slot is acceptable.
#
# The function is a no-op when installing a binary package.
electron_pkg_setup() {
	if [[ ${MERGE_TYPE} != binary ]]; then
		_get_electron_slot even
		local path=$(get_electron_path "${ELECTRON_SLOT}" "${ELECTRON_TYPE}")
		case ${ELECTRON_TYPE} in
			source) ELECTRON="${EPREFIX}${path}electron";;
			binary) ELECTRON="${EPREFIX}${path}electron";;
		esac
		export ELECTRON
		export ELECTRON_DIR="${EPREFIX}${path}"
		local electron_version
		electron_version=$(${ELECTRON} --version | sed 's/^v//')
		export ELECTRON_VERSION="${electron_version}"
		# Probably not required, but let's make sure no part of the build process tries to download Electron binaries
		export ELECTRON_SKIP_BINARY_DOWNLOAD=1
		export _ELECTRON_PKG_SETUP=1
		einfo "Using Electron ${ELECTRON_SLOT} (${ELECTRON_TYPE})"

		# There are a bunch of environment variables that we now need to set so that electron-builder, npm, & friends
		# can find the Electron installation and build against it (etc).
		# Use the system electron-builder
		export USE_SYSTEM_APP_BUILDER=true
		export ELECTRON_OVERRIDE_DIST_PATH="${EPREFIX}/usr/bin"
		export ELECTRON_CACHE="${S}/vendor/cache/electron"
		export ELECTRON_BUILDER_CACHE="${S}/vendor/cache/electron-builder"

		# Yes, these are canonically lowercase envvars. Thanks npm!
		if [[ "${ELECTRON_TYPE}" == "source" ]]; then
			export npm_config_nodedir="${EPREFIX}/include/electron/${ELECTRON_VERSION%%.*}/node"
		else
			export npm_config_nodedir="${ELECTRON_DIR}/include"
		fi
		# Additional npm config for native modules
		export npm_config_target="${ELECTRON_VERSION}"
		export npm_config_disturl="https://electronjs.org/headers"
		export npm_config_runtime="electron"
		export npm_config_build_from_source=true
		export npm_config_cache="${S}/vendor/cache/npm"

	fi
}

# @FUNCTION: electron_src_prepare
# @DESCRIPTION:
# Prepare the package for building against Electron. This function should be called in src_prepare.
electron_src_prepare() {

	default_src_prepare

	if [[ -z ${_ELECTRON_PKG_SETUP} ]]; then
		die "electron_pkg_setup must be called before ${FUNCNAME}"
	fi

	# We vendor our node_modules anyway, so we can patch the electron version to match the one we are building against.
	sed -i "s/\"electron\": \".*\"/\"electron\": \"${ELECTRON_VERSION}\"/" package.json || die
	einfo "Patched electron version in package.json"
}

# @FUNCTION: electron_src_compile
# @DESCRIPTION:
# Compile the package against Electron. This function should be called in src_compile.
# This function will also detect and rebuild native modules.
electron_src_compile() {
	if [[ -z ${_ELECTRON_PKG_SETUP} ]]; then
		die "electron_pkg_setup must be called before ${FUNCNAME}"
	fi

	electron_detect_native_modules

	default_src_compile
}

fi

EXPORT_FUNCTIONS pkg_setup src_prepare src_compile
