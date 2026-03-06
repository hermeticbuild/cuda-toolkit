"""CUDA tools toolchain definitions."""

load("@bazel_skylib//rules/directory:providers.bzl", "DirectoryInfo")

CudaToolsInfo = provider(
    doc = "CUDA binary tools and merged CUDA path tree.",
    fields = {
        "ptxas": "ptxas executable File",
        "fatbinary": "fatbinary executable File",
        "cuda_path": "DirectoryInfo provider for merged CUDA path tree",
    },
)

def _cuda_tools_toolchain_impl(ctx):
    ptxas_exec = ctx.attr.ptxas[DefaultInfo].files_to_run.executable
    fatbinary_exec = ctx.attr.fatbinary[DefaultInfo].files_to_run.executable
    if not ptxas_exec:
        fail("ptxas target '{}' is not executable".format(ctx.attr.ptxas.label))
    if not fatbinary_exec:
        fail("fatbinary target '{}' is not executable".format(ctx.attr.fatbinary.label))
    if DirectoryInfo not in ctx.attr.cuda_path:
        fail("cuda_path target '{}' does not provide DirectoryInfo".format(ctx.attr.cuda_path.label))

    return [
        platform_common.ToolchainInfo(
            cuda_tools = CudaToolsInfo(
                ptxas = ptxas_exec,
                fatbinary = fatbinary_exec,
                cuda_path = ctx.attr.cuda_path[DirectoryInfo],
            ),
        ),
    ]

cuda_tools_toolchain = rule(
    implementation = _cuda_tools_toolchain_impl,
    attrs = {
        "ptxas": attr.label(mandatory = True, allow_files = True, executable = True, cfg = "exec"),
        "fatbinary": attr.label(mandatory = True, allow_files = True, executable = True, cfg = "exec"),
        "cuda_path": attr.label(mandatory = True, providers = [DirectoryInfo], cfg = "exec"),
    },
)
