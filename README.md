# Bazel CUDA Toolkit

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
cuda_ext = use_extension("//extensions:cuda.bzl", "cuda_ext")
cuda_ext.configure(
    cuda_version = "12.9.1",
    cudnn_version = "9.8.0",
    # Optional:
    # cuda_umd_version = "13.0.0",
)
use_repo(
    cuda_ext,
    "cuda",
    "cuda_cccl",
    "cuda_crt",
    "cuda_cublas",
    "cuda_cudart",
    "cuda_cudnn",
    "cuda_cufft",
    "cuda_cupti",
    "cuda_curand",
    "cuda_cusolver",
    "cuda_cusparse",
    "cuda_driver",
    "cuda_nvcc",
    "cuda_nvdisasm",
    "cuda_nvjitlink",
    "cuda_nvml",
    "cuda_nvrtc",
    "cuda_nvtx",
    "cuda_nvvm",
    "cuda_profiler_api",
)
```

## Notes

- `cuda_umd_version` defaults to `cuda_version` when omitted.
- CUDA repos are platform-resolving proxies. The selected concrete redistribution
  is chosen from the current Bazel configuration platform (including exec config).
- For local validation on non-Linux hosts, you can force Linux selection with
  `--platforms=//:platform_linux_amd64` or `--platforms=//:platform_linux_arm64`.
- `@cuda//cuda:build_defs.bzl` and `@cuda//cuda:BUILD`
  are static files from `//cuda`.

## Origin

This project was originally derived from [rules_ml_toolchain](https://github.com/google-ml-infra/rules_ml_toolchain),
licensed under the Apache License 2.0.

The codebase has been extensively rewritten and extended.
Only small portions of the original implementation remain.

See the LICENSE file for license details and original copyright notices.
