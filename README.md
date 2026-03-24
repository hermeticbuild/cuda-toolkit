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
- `cudnn/cudnn_redist_versions.json`
- `nvshmem/nvshmem_redist_versions.json`

## Supported platforms

CUDA components are typically published for these platforms:
- `linux-x86_64`
- `linux-sbsa`

This module exposes each component through proxy subpackages:
- `@cuda//<component>`

These proxy targets are platform-aware and resolve to the correct concrete package for the active Bazel configuration.

For example, `@cuda//nvcc:ptxas` used from an attribute with `cfg = "exec"` resolves automatically to the appropriate execution-platform binary.

## Recommended usage

Example `MODULE.bazel` setup:

```starlark
cuda_ext = use_extension("@cuda_toolkit//extensions:cuda.bzl", "cuda")

cuda_ext.redist(
    name = "cuda_12_9_1",
    version = "12.9.1",
    cudnn_version = "8.9.7",
    nvshmem_version = "3.3.24",
)

use_repo(cuda_ext, "cuda")
```

## Notes

- CUDA versions are registered explicitly with `cuda_ext.redist(...)`.
- cuDNN and NVSHMEM versions, when used, are pinned on the same `cuda_ext.redist(...)` tag.
- CUDA packages under `@cuda//<components>` are platform-resolving proxies. The selected concrete redistribution
  is chosen from the current Bazel configuration platform (including exec config).
- For local validation on non-Linux hosts, you can force Linux selection with
  `--platforms=//:platform_linux_amd64` or `--platforms=//:platform_linux_arm64`.

## License

This project is licensed under the MIT License.
