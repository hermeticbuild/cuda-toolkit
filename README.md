# CUDA Toolkit

<img width="320" height="320" alt="image" src="https://github.com/user-attachments/assets/1d816875-0282-4ac7-9405-0f53528f5495" />

## Project Overview

This repository provides the CUDA toolkit (CUDA, cuDNN, and related redistributions)
hermetically using Bazel.

It is meant to be consumed by other Bazel projects, notably rulesets and toolchains.

This project had been started to address limitations of the `rules_cuda` module at the time it was started.
`rules_cuda` now provides the same cuda toolkit configuration, including its own toolchain while this module only provides the toolkit.

## Supported versions

Supported versions are defined in:
- `cuda/cuda_redist_versions.json`

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
cuda_ext.configure(
    cuda_version = "12.9.1",
)
use_repo(cuda_ext, "cuda")
```

## Notes

- `cuda_umd_version` defaults to `cuda_version` when omitted.
- CUDA packages under `@cuda//<components>` are platform-resolving proxies. The selected concrete redistribution
  is chosen from the current Bazel configuration platform (including exec config).
- For local validation on non-Linux hosts, you can force Linux selection with
  `--platforms=//:platform_linux_amd64` or `--platforms=//:platform_linux_arm64`.

## License

This project is licensed under the MIT License.

Some files are derived from [rules_ml_toolchain](https://github.com/google-ml-infra/rules_ml_toolchain) licensed under the Apache License 2.0 and remain under that license.
