"""Repository rule for hermetic CUDA configuration."""

def _cuda_configure_impl(repository_ctx):
    """Implementation of the cuda_configure repository rule."""

    cuda_version = repository_ctx.attr.cuda_version

    # Set up BUILD file for cuda/
    repository_ctx.symlink(
        repository_ctx.attr.build_defs_file,
        "cuda/build_defs.bzl",
    )

    repository_ctx.file(
        "cuda/cuda_version.bzl",
        "CUDA_VERSION = \"{}\"".format(cuda_version),
    )

    repository_ctx.symlink(
        repository_ctx.attr.cuda_build_file,
        "cuda/BUILD.bazel",
    )

    repository_ctx.file(
        "BUILD.bazel",
        "",
    )

cuda_configure = repository_rule(
    implementation = _cuda_configure_impl,
    attrs = {
        "cuda_version": attr.string(mandatory = True),
        "build_defs_file": attr.label(default = Label("//gpu/cuda:build_defs.bzl")),
        "cuda_build_file": attr.label(default = Label("//gpu/cuda:cuda.BUILD.bazel")),
    },
)
