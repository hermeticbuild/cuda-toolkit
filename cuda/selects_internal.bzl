load("@bazel_skylib//lib:selects.bzl", "selects")
load("@cuda_toolkit//cuda:versions_helper.bzl", "compare_versions")

def _sanitize_version(version):
    return version.replace(".", "_").replace("-", "_")

def _match_version_prefix(version, version_expr):
    expr_parts = version_expr.split(".")
    version_parts = version.split(".")
    if len(expr_parts) > len(version_parts):
        return False
    return version_parts[:len(expr_parts)] == expr_parts

def _version_matches_clause(version, clause):
    clause = clause.strip()
    if not clause:
        return True

    for operator in [">=", "<=", ">", "<"]:
        if clause.startswith(operator):
            return compare_versions(version, clause[len(operator):].strip(), operator)

    return _match_version_prefix(version, clause)

def expand_cuda_conditions(cuda_versions, version_expr):
    clauses = []
    for clause in version_expr.split(","):
        clause = clause.strip()
        if clause:
            clauses.append(clause)

    labels = []
    for version in cuda_versions:
        matches = True
        for clause in clauses:
            if not _version_matches_clause(version, clause):
                matches = False
                break
        if matches:
            labels.append("//:is_cuda_{}".format(_sanitize_version(version)))
    return tuple(labels)

def if_cuda_version(cuda_versions, version_expr, if_true, if_false = []):
    labels = expand_cuda_conditions(cuda_versions, version_expr)
    if not labels:
        return if_false
    return selects.with_or({
        labels: if_true,
        "//conditions:default": if_false,
    })
