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

def sort_versions(versions):
    ordered_versions = []
    for version in versions:
        insert_at = len(ordered_versions)
        for i, existing_version in enumerate(ordered_versions):
            if compare_versions(version, existing_version, "<"):
                insert_at = i
                break
        ordered_versions.insert(insert_at, version)
    return ordered_versions

def max_version(versions):
    ordered_versions = sort_versions(versions)
    if not ordered_versions:
        fail("Expected at least one version")
    return ordered_versions[-1]

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
