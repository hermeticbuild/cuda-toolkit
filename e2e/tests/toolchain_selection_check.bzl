"""Check the selected CUDA toolchain's executable versions and staged fatbinary."""

load("@bazel_lib//lib:copy_file.bzl", "COPY_FILE_TOOLCHAINS", "copy_file_action")

def _toolchain_selection_check_impl(ctx):
    toolkit = ctx.toolchains["@cuda_toolchain_types//cuda:toolchain_type"].cuda

    # Compare actual files, rather than version metadata on the provider.
    for tool in [toolkit.ptxas, toolkit.fatbinary]:
        if ctx.attr.expected_repository not in tool.path:
            fail("Expected {} tools, got {}".format(ctx.attr.expected_repository, tool.path))
    report = ctx.actions.declare_file(ctx.label.name + ".txt")
    ctx.actions.write(report, "\n".join([toolkit.ptxas.path, toolkit.fatbinary.path]) + "\n")

    # Fetching the tool from the tree fails if Clang cannot find it under --cuda-path.
    fatbinary = ctx.actions.declare_file(ctx.label.name + "/fatbinary")
    copy_file_action(ctx, toolkit.cuda_path, fatbinary, dir_path = "bin/fatbinary")
    return [DefaultInfo(files = depset([report, fatbinary]))]

toolchain_selection_check = rule(
    implementation = _toolchain_selection_check_impl,
    attrs = {
        "expected_repository": attr.string(mandatory = True),
    },
    toolchains = ["@cuda_toolchain_types//cuda:toolchain_type"] + COPY_FILE_TOOLCHAINS,
)
