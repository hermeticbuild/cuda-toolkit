"""Analysis check for the selected CUDA toolchain's executable versions."""

def _toolchain_selection_check_impl(ctx):
    toolkit = ctx.toolchains["@cuda_toolchain_types//cuda:toolchain_type"].cuda

    # Compare actual files, rather than version metadata on the provider.
    for tool in [toolkit.ptxas, toolkit.fatbinary]:
        if ctx.attr.expected_repository not in tool.path:
            fail("Expected {} tools, got {}".format(ctx.attr.expected_repository, tool.path))
    report = ctx.actions.declare_file(ctx.label.name + ".txt")
    ctx.actions.write(report, "\n".join([toolkit.ptxas.path, toolkit.fatbinary.path]) + "\n")
    return [DefaultInfo(files = depset([report]))]

toolchain_selection_check = rule(
    implementation = _toolchain_selection_check_impl,
    attrs = {
        "expected_repository": attr.string(mandatory = True),
    },
    toolchains = ["@cuda_toolchain_types//cuda:toolchain_type"],
)
