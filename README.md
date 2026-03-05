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
    host_platform = "amd64",
    target_platform = "amd64",
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
- `host_platform` and `target_platform` are required and drive deterministic repo
  selection. Supported values are `amd64`, `aarch64`, `tegra-aarch64`.
- `@cuda//cuda:build_defs.bzl` and `@cuda//cuda:BUILD`
  are static files from `//cuda`.
