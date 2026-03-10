"""Helper functions for CUDA version comparison."""

# This is to be used by component packages for per-version differences.

def normalize_version_parts(version):
    parts = []
    for raw_part in version.split("."):
        if raw_part:
            parts.append(int(raw_part))

    if len(parts) > 3:
        fail("Unsupported CUDA version '{}'".format(version))
    if len(parts) == 1:
        return (parts[0], 0, 0)
    if len(parts) == 2:
        return (parts[0], parts[1], 0)
    if len(parts) == 3:
        return (parts[0], parts[1], parts[2])

    fail("Invalid CUDA version '{}'".format(version))

def compare_versions(lib_version, dist_version, operator):
    if not lib_version:
        return False
    lib_tuple = normalize_version_parts(lib_version)
    dist_tuple = normalize_version_parts(dist_version)

    if operator == "<=":
        return lib_tuple <= dist_tuple
    elif operator == ">=":
        return lib_tuple >= dist_tuple
    elif operator == ">":
        return lib_tuple > dist_tuple
    elif operator == "<":
        return lib_tuple < dist_tuple
    return False


def if_version_equal_or_lower_than(lib_version, dist_version, if_true, if_false = []):
    if compare_versions(lib_version, dist_version, "<="):
        return if_true
    return if_false

def if_version_equal_or_greater_than(lib_version, dist_version, if_true, if_false = []):
    if compare_versions(lib_version, dist_version, ">="):
        return if_true
    return if_false

def if_version_greater_than(lib_version, dist_version, if_true, if_false = []):
    if compare_versions(lib_version, dist_version, ">"):
        return if_true
    return if_false

def if_version_lower_than(lib_version, dist_version, if_true, if_false = []):
    if compare_versions(lib_version, dist_version, "<"):
        return if_true
    return if_false
