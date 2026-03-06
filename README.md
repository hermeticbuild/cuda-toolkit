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

## Recommended usage

Example `MODULE.bazel` setup:

```starlark
cuda_ext = use_extension("//extensions:cuda.bzl", "cuda")
cuda_ext.configure(
    cuda_version = "12.9.1",
    cudnn_version = "9.8.0",
    # Optional:
    # cuda_umd_version = "13.0.0",
)
use_repo(
    cuda_ext,
    "cuda",
)
```

## Notes

- `cuda_umd_version` defaults to `cuda_version` when omitted.
- CUDA packages under `@cuda//<redist>` are platform-resolving proxies. The selected concrete redistribution
  is chosen from the current Bazel configuration platform (including exec config).
- For local validation on non-Linux hosts, you can force Linux selection with
  `--platforms=//:platform_linux_amd64` or `--platforms=//:platform_linux_arm64`.

## License

This project is licensed under the MIT License.

Some files are derived from [rules_ml_toolchain](https://github.com/google-ml-infra/rules_ml_toolchain) licensed under the Apache License 2.0 and remain under that license.
