# Macros for building CUDA code.

load(":cuda_version.bzl", "CUDA_VERSION")

def if_cuda_newer_than(wanted_ver, if_true, if_false = []):
    """Tests if CUDA was enabled during the configured process and if the
    configured version is at least `wanted_ver`. `wanted_ver` needs
    to be provided as a string in the format `<major>_<minor>`.
    Example: `11_0`
    """

    wanted_major = int(wanted_ver.split("_")[0])
    wanted_minor = int(wanted_ver.split("_")[1])

    # Strip "64_" which appears in the CUDA version on Windows.
    configured_version = CUDA_VERSION.rsplit("_", 1)[-1]
    configured_version_parts = configured_version.split(".")

    # On Windows, the major and minor versions are concatenated without a period and the minor only contains one digit.
    if len(configured_version_parts) == 1:
        configured_version_parts = [configured_version[0:-1], configured_version[-1:]]

    configured_major = int(configured_version_parts[0])
    configured_minor = int(configured_version_parts[1])

    if (wanted_major, wanted_minor) <= (configured_major, configured_minor):
        return if_true
    return if_false

def if_version_equal_or_lower_than(lib_version, dist_version, if_true, if_false = []):
    if not lib_version:
        return if_false
    if tuple([int(x) for x in lib_version.split(".")]) <= tuple([
        int(x)
        for x in dist_version.split(".")
    ]):
        return if_true
    return if_false

def if_version_equal_or_greater_than(
        lib_version,
        dist_version,
        if_true,
        if_false = []):
    if not lib_version:
        return if_false
    if tuple([int(x) for x in lib_version.split(".")]) >= tuple([
        int(x)
        for x in dist_version.split(".")
    ]):
        return if_true
    return if_false

# Constructs rpath linker flags for use with nvidia wheel-packaged libs
# avaialble from PyPI.
def cuda_rpath_flags(relpath):
    return select({
        "@cuda_sdk//common:enable_cuda_rpath": [
            "-Wl,-rpath='$$ORIGIN/../../" + relpath + "'",
            "-Wl,-rpath='$$ORIGIN/../" + relpath + "'",
        ],
        "//conditions:default": [],
    })

def cuda_lib_header_prefix(major_version, wanted_major_version, new_header_prefix, old_header_prefix):
    if not major_version:
        return old_header_prefix
    return new_header_prefix if int(major_version) >= wanted_major_version else old_header_prefix
