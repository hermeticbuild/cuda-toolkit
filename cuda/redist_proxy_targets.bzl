"""Shared catalog for CUDA proxy package generation."""

PROXY_ARCH_CONDITIONS = {
    "amd64": ["@cuda_toolkit//:linux_amd64"],
    "aarch64": ["@cuda_toolkit//:linux_arm64"],
}

ARCH_REPO_SUFFIX = {
    "amd64": "amd64",
    "aarch64": "aarch64",
}

REPO_PUBLIC_TARGETS = {
    "cuda_cccl": ["header_list", "headers"],
    "cuda_crt": ["header_list", "headers_impl", "placeholder", "headers"],
    "cuda_cublas": ["cublas_shared_library", "cublasLt_shared_library", "cublas", "cublasLt", "header_list", "headers"],
    "cuda_cudart": ["static", "cuda_stub", "cudart_shared_library", "cuda_driver", "cudart", "header_list", "headers", "cuda_header"],
    "cuda_cudnn": [
        "cudnn_ops",
        "cudnn_cnn",
        "cudnn_adv",
        "cudnn_graph",
        "cudnn_engines_precompiled",
        "cudnn_engines_runtime_compiled",
        "cudnn_heuristic",
        "cudnn_main",
        "cudnn_ops_infer",
        "cudnn_cnn_infer",
        "cudnn_ops_train",
        "cudnn_cnn_train",
        "cudnn_adv_infer",
        "cudnn_adv_train",
        "cudnn",
        "header_list",
        "headers",
    ],
    "cuda_cufft": ["cufft_shared_library", "cufft", "header_list", "headers"],
    "cuda_cupti": ["cupti_shared_library", "cupti", "header_list", "headers"],
    "cuda_curand": ["curand_shared_library", "curand", "header_list", "headers"],
    "cuda_cusolver": ["cusolver_shared_library", "cusolver", "header_list", "headers"],
    "cuda_cusparse": ["cusparse_shared_library", "cusparse", "header_list", "headers"],
    "cuda_driver": [
        "driver_shared_library",
        "nvidia-ptxjitcompiler_shared_library",
        "libcuda_so_1",
        "libnvidia-ptxjitcompiler_so_1",
        "libcuda_so",
        "nvidia_driver",
        "nvidia_ptxjitcompiler",
        "include_cuda_umd_libs",
        "cuda_umd_libs",
    ],
    "cuda_nvcc": ["nvcc_directory", "libdevice", "nvlink", "fatbinary", "bin2c", "ptxas", "bin", "link_stub", "header_list", "headers"],
    "cuda_nvdisasm": ["nvdisasm"],
    "cuda_nvjitlink": ["nvjitlink_shared_library", "nvjitlink", "header_list", "headers"],
    "cuda_nvml": ["header_list", "headers", "nvidia-ml_stub", "nvml"],
    "cuda_nvprune": ["nvprune"],
    "cuda_nvrtc": ["nvrtc_main", "nvrtc_builtins", "nvrtc", "header_list", "headers"],
    "cuda_nvtx": ["header_list", "headers"],
    "cuda_nvvm": ["cicc", "libdevice"],
    "cuda_profiler_api": ["header_list", "headers"],
}
