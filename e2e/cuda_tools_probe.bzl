def _cuda_tools_probe_impl(ctx):
    cuda_tools = ctx.toolchains["@cuda_toolkit//cuda/toolchain:cuda_tools_toolchain_type"].cuda_tools
    output = ctx.actions.declare_file(ctx.label.name + ".txt")
    ptxas_probe = ctx.actions.declare_file(ctx.label.name + "_ptxas_probe.txt")
    fatbinary_probe = ctx.actions.declare_file(ctx.label.name + "_fatbinary_probe.txt")

    ctx.actions.run_shell(
        outputs = [ptxas_probe],
        tools = [cuda_tools.ptxas],
        command = "\"$1\" >\"$2\" 2>&1 || true",
        arguments = [cuda_tools.ptxas.path, ptxas_probe.path],
        mnemonic = "CudaPtxasProbe",
    )
    ctx.actions.run_shell(
        outputs = [fatbinary_probe],
        tools = [cuda_tools.fatbinary],
        command = "\"$1\" >\"$2\" 2>&1 || true",
        arguments = [cuda_tools.fatbinary.path, fatbinary_probe.path],
        mnemonic = "CudaFatbinaryProbe",
    )

    ctx.actions.write(
        output = output,
        content = "\n".join([
            "ptxas={}".format(cuda_tools.ptxas.path),
            "fatbinary={}".format(cuda_tools.fatbinary.path),
            "cuda_path_directory_info={}".format(cuda_tools.cuda_path),
        ]) + "\n",
    )
    return [DefaultInfo(files = depset([output, ptxas_probe, fatbinary_probe]))]

cuda_tools_probe = rule(
    implementation = _cuda_tools_probe_impl,
    toolchains = ["@cuda_toolkit//cuda/toolchain:cuda_tools_toolchain_type"],
)
