"""Hermetic CUDA redistribution utilities."""

CUDA_REDIST_PATH_PREFIX = "https://developer.download.nvidia.com/compute/cuda/redist/"

COMPONENTS_REGISTRY = {
    "nvidia_driver": {
        "repo_name": "cuda_driver",
        "version_to_template": {
            "595": "//cuda/build_defs:cuda_driver.BUILD.bazel",
            "590": "//cuda/build_defs:cuda_driver.BUILD.bazel",
            "580": "//cuda/build_defs:cuda_driver.BUILD.bazel",
            "575": "//cuda/build_defs:cuda_driver.BUILD.bazel",
            "570": "//cuda/build_defs:cuda_driver.BUILD.bazel",
            "560": "//cuda/build_defs:cuda_driver.BUILD.bazel",
            "555": "//cuda/build_defs:cuda_driver.BUILD.bazel",
            "550": "//cuda/build_defs:cuda_driver.BUILD.bazel",
            "545": "//cuda/build_defs:cuda_driver.BUILD.bazel",
            "535": "//cuda/build_defs:cuda_driver.BUILD.bazel",
            "530": "//cuda/build_defs:cuda_driver.BUILD.bazel",
            "520": "//cuda/build_defs:cuda_driver.BUILD.bazel",
        },
    },
    "libcublas": {
        "repo_name": "cuda_cublas",
        "version_to_template": {
            "13": "//cuda/build_defs:cuda_cublas.BUILD.bazel",
            "12": "//cuda/build_defs:cuda_cublas.BUILD.bazel",
            "11": "//cuda/build_defs:cuda_cublas.BUILD.bazel",
        },
    },
    "cuda_cudart": {
        "repo_name": "cuda_cudart",
        "version_to_template": {
            "13": "//cuda/build_defs:cuda_cudart.BUILD.bazel",
            "12": "//cuda/build_defs:cuda_cudart.BUILD.bazel",
            "11": "//cuda/build_defs:cuda_cudart.BUILD.bazel",
        },
    },
    "libcufft": {
        "repo_name": "cuda_cufft",
        "version_to_template": {
            "13": "//cuda/build_defs:cuda_cufft.BUILD.bazel",
            "12": "//cuda/build_defs:cuda_cufft.BUILD.bazel",
            "11": "//cuda/build_defs:cuda_cufft.BUILD.bazel",
            "10": "//cuda/build_defs:cuda_cufft.BUILD.bazel",
        },
    },
    "cuda_cupti": {
        "repo_name": "cuda_cupti",
        "version_to_template": {
            "13": "//cuda/build_defs:cuda_cupti.BUILD.bazel",
            "12": "//cuda/build_defs:cuda_cupti.BUILD.bazel",
            "11": "//cuda/build_defs:cuda_cupti.BUILD.bazel",
        },
    },
    "libcurand": {
        "repo_name": "cuda_curand",
        "version_to_template": {
            "10": "//cuda/build_defs:cuda_curand.BUILD.bazel",
        },
    },
    "libcusolver": {
        "repo_name": "cuda_cusolver",
        "version_to_template": {
            "12": "//cuda/build_defs:cuda_cusolver.BUILD.bazel",
            "11": "//cuda/build_defs:cuda_cusolver.BUILD.bazel",
        },
    },
    "libcusparse": {
        "repo_name": "cuda_cusparse",
        "version_to_template": {
            "13": "//cuda/build_defs:cuda_cusparse.BUILD.bazel",
            "12": "//cuda/build_defs:cuda_cusparse.BUILD.bazel",
            "11": "//cuda/build_defs:cuda_cusparse.BUILD.bazel",
        },
    },
    "libnvjitlink": {
        "repo_name": "cuda_nvjitlink",
        "version_to_template": {
            "13": "//cuda/build_defs:cuda_nvjitlink.BUILD.bazel",
            "12": "//cuda/build_defs:cuda_nvjitlink.BUILD.bazel",
        },
    },
    "cuda_nvrtc": {
        "repo_name": "cuda_nvrtc",
        "version_to_template": {
            "13": "//cuda/build_defs:cuda_nvrtc.BUILD.bazel",
            "12": "//cuda/build_defs:cuda_nvrtc.BUILD.bazel",
            "11": "//cuda/build_defs:cuda_nvrtc.BUILD.bazel",
        },
    },
    "cuda_cccl": {
        "repo_name": "cuda_cccl",
        "version_to_template": {
            "any": "//cuda/build_defs:cuda_cccl.BUILD.bazel",
        },
    },
    "cuda_compat": {
        "repo_name": "cuda_compat",
        "version_to_template": {
            "any": "//cuda/build_defs:cuda_compat.BUILD.bazel",
        },
    },
    "cuda_crt": {
        "repo_name": "cuda_crt",
        "version_to_template": {
            "any": "//cuda/build_defs:cuda_crt.BUILD.bazel",
        },
    },
    "cuda_nvcc": {
        "repo_name": "cuda_nvcc",
        "version_to_template": {
            "any": "//cuda/build_defs:cuda_nvcc.BUILD.bazel",
        },
    },
    "libnvvm": {
        "repo_name": "cuda_nvvm",
        "version_to_template": {
            "any": "//cuda/build_defs:cuda_nvvm.BUILD.bazel",
        },
    },
    "cuda_nvdisasm": {
        "repo_name": "cuda_nvdisasm",
        "version_to_template": {
            "any": "//cuda/build_defs:cuda_nvdisasm.BUILD.bazel",
        },
    },
    "cuda_nvml_dev": {
        "repo_name": "cuda_nvml",
        "version_to_template": {
            "13": "//cuda/build_defs:cuda_nvml.BUILD.bazel",
            "12": "//cuda/build_defs:cuda_nvml.BUILD.bazel",
            "11": "//cuda/build_defs:cuda_nvml.BUILD.bazel",
        },
    },
    "cuda_nvprune": {
        "repo_name": "cuda_nvprune",
        "version_to_template": {
            "any": "//cuda/build_defs:cuda_nvprune.BUILD.bazel",
        },
    },
    "cuda_profiler_api": {
        "repo_name": "cuda_profiler_api",
        "version_to_template": {
            "any": "//cuda/build_defs:cuda_profiler.BUILD.bazel",
        },
    },
    "cuda_nvtx": {
        "repo_name": "cuda_nvtx",
        "version_to_template": {
            "any": "//cuda/build_defs:cuda_nvtx.BUILD.bazel",
        },
    },
}
