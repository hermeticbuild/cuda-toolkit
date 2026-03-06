# CUDA Toolkit

<img width="320" height="320" alt="image" src="https://github.com/user-attachments/assets/1d816875-0282-4ac7-9405-0f53528f5495" />

## Project Overview

This repository provides the CUDA toolkit (CUDA, cuDNN, and related redistributions)
hermetically using Bazel.

It is meant to be consumed by other Bazel projects, notably rulesets and toolchains.

## Supported versions

Supported versions are defined in:
- `cuda/cuda_redist_versions.json`
- `cuda/cudnn_redist_versions.json`

## Supported platforms

CUDA components are typically published for these platforms:
- `linux-x86_64`
- `linux-sbsa`
- `windows-x86_64`

This module exposes each component through proxy subpackages:
- `@cuda//<component>`

These proxy targets are platform-aware and resolve to the correct concrete package for the active Bazel configuration.

For example, `@cuda//nvcc:ptxas` used from an attribute with `cfg = "exec"` resolves automatically to the appropriate execution-platform binary.

## Recommended usage

Example `MODULE.bazel` setup:

```starlark
cuda_ext = use_extension("//extensions:cuda.bzl", "cuda")
cuda_ext.version(
    cuda_version = "12.9.1",
    cudnn_version = "9.8.0",
    # Optional:
    # cuda_umd_version = "13.0.0",
)
use_repo(
    cuda_ext,
    cuda = "cuda12_9_1",
)
```

You can register multiple versions:

```starlark
cuda_ext.version(cuda_version = "12.8.1", cudnn_version = "9.16.0")
cuda_ext.version(cuda_version = "13.1.1", cudnn_version = "9.16.0")

use_repo(
    cuda_ext,
    cuda12 = "cuda12_8_1",
    cuda13 = "cuda13_1_1",
)
```

## CUDA tools toolchain (first implementation)

Each generated `@cuda<version>` repo also exposes toolchain targets in `//toolchain`.

The stable toolchain type is:
- `@cuda_toolkit//cuda/toolchain:cuda_tools_toolchain_type`

For a selected repo alias (for example `cuda = "cuda13_1_1"`), register:

```starlark
register_toolchains("@cuda//toolchain:cuda_tools_amd64_0")
```

Rules can consume it via:
- `ctx.toolchains["@cuda_toolkit//cuda/toolchain:cuda_tools_toolchain_type"].cuda_tools`

## Notes

- `cuda_umd_version` defaults to `cuda_version` when omitted.
- CUDA packages under `@cuda<version>//<redist>` are platform-resolving proxies. The selected concrete redistribution
  is chosen from the current Bazel configuration platform (including exec config).
- For local validation on non-Linux hosts, you can force Linux selection with
  `--platforms=//:platform_linux_amd64` or `--platforms=//:platform_linux_arm64`.

## License

This project is licensed under the MIT License.

Some files are derived from [rules_ml_toolchain](https://github.com/google-ml-infra/rules_ml_toolchain) licensed under the Apache License 2.0 and remain under that license.
