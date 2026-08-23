"""Helpers for metadata shared by generated repositories."""

def write_repo_bazel(repository_ctx):
    """Writes repository-wide package metadata when it is configured."""
    if not repository_ctx.attr.default_package_metadata:
        return

    lines = [
        "repo(",
        "    default_package_metadata = [",
    ]
    for metadata in repository_ctx.attr.default_package_metadata:
        lines.append("        {},".format(repr(metadata)))
    lines.extend([
        "    ],",
        ")",
        "",
    ])
    repository_ctx.file("REPO.bazel", "\n".join(lines))
