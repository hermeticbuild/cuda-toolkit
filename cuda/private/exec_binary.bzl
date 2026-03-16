"""Rule to force a binary to run in the exec configuration."""

def _exec_binary_impl(ctx):
    """Implementation of exec_binary rule."""
    binary = ctx.executable.actual
    output = ctx.outputs.executable
    
    # Create a symlink to the binary
    ctx.actions.symlink(
        output = output,
        target_file = binary,
    )
    
    return [
        DefaultInfo(
            executable = output,
            runfiles = ctx.runfiles(files = [binary]),
        ),
    ]

exec_binary = rule(
    implementation = _exec_binary_impl,
    attrs = {
        "actual": attr.label(
            executable = True,
            cfg = "exec",
            mandatory = True,
            doc = "The binary to force into exec configuration",
        ),
    },
    executable = True,
    doc = "Forces a binary to run in the exec configuration and symlinks it as output.",
)
