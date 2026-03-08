# Copyright 2024 The TensorFlow Authors. All rights reserved.
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#    http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.

"""Hermetic CUDA redistribution utilities."""

CUDA_REDIST_PATH_PREFIX = "https://developer.download.nvidia.com/compute/cuda/redist/"
CUDNN_REDIST_PATH_PREFIX = "https://developer.download.nvidia.com/compute/cudnn/redist/"

# PTX version compatibility w/ Clang & ptxas
PTX_VERSION_DICT = {
    # llc -march=nvptx64 -mcpu=help 2>&1 | grep ptx | sort -V | tail -n 1`
    "clang": {
        "14": "7.5",
        "15": "7.5",
        "16": "7.8",
        "17": "8.1",
        "18": "8.3",
        "19": "8.5",
        "20": "8.7",
        "21": "8.8",
    },
    # https://docs.nvidia.com/cuda/parallel-thread-execution/index.html#release-notes
    "cuda": {
        "11.8": "7.8",
        "12.1": "8.1",
        "12.2": "8.2",
        "12.3": "8.3",
        "12.4": "8.4",
        "12.5": "8.5",
        "12.6": "8.5",
        "12.8": "8.7",
        "12.9": "8.8",
        "13.0": "9.0",
        "13.1": "9.1",
    },
}

REDIST_VERSIONS_TO_BUILD_DEFS = {
    "nvidia_driver": {
        "package_name": "cuda_driver",
        "version_to_template": {
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
    "cuda_nccl": {
        "package_name": "cuda_nccl",
        "version_to_template": {
            "2": "//gpu/nccl:cuda_nccl.BUILD.tpl",
        },
    },
    "cudnn": {
        "package_name": "cuda_cudnn",
        "version_to_template": {
            "10": "//cuda/build_defs:cuda_cudnn.BUILD.bazel",
            "9": "//cuda/build_defs:cuda_cudnn.BUILD.bazel",
            "8": "//cuda/build_defs:cuda_cudnn8.BUILD.bazel",
        },
    },
    "libcublas": {
        "package_name": "cuda_cublas",
        "version_to_template": {
            "13": "//cuda/build_defs:cuda_cublas.BUILD.bazel",
            "12": "//cuda/build_defs:cuda_cublas.BUILD.bazel",
            "11": "//cuda/build_defs:cuda_cublas.BUILD.bazel",
        },
    },
    "cuda_cudart": {
        "package_name": "cuda_cudart",
        "version_to_template": {
            "13": "//cuda/build_defs:cuda_cudart.BUILD.bazel",
            "12": "//cuda/build_defs:cuda_cudart.BUILD.bazel",
            "11": "//cuda/build_defs:cuda_cudart.BUILD.bazel",
        },
    },
    "libcufft": {
        "package_name": "cuda_cufft",
        "version_to_template": {
            "13": "//cuda/build_defs:cuda_cufft.BUILD.bazel",
            "12": "//cuda/build_defs:cuda_cufft.BUILD.bazel",
            "11": "//cuda/build_defs:cuda_cufft.BUILD.bazel",
            "10": "//cuda/build_defs:cuda_cufft.BUILD.bazel",
        },
    },
    "cuda_cupti": {
        "package_name": "cuda_cupti",
        "version_to_template": {
            "13": "//cuda/build_defs:cuda_cupti.BUILD.bazel",
            "12": "//cuda/build_defs:cuda_cupti.BUILD.bazel",
            "11": "//cuda/build_defs:cuda_cupti.BUILD.bazel",
        },
    },
    "libcurand": {
        "package_name": "cuda_curand",
        "version_to_template": {
            "10": "//cuda/build_defs:cuda_curand.BUILD.bazel",
        },
    },
    "libcusolver": {
        "package_name": "cuda_cusolver",
        "version_to_template": {
            "12": "//cuda/build_defs:cuda_cusolver.BUILD.bazel",
            "11": "//cuda/build_defs:cuda_cusolver.BUILD.bazel",
        },
    },
    "libcusparse": {
        "package_name": "cuda_cusparse",
        "version_to_template": {
            "13": "//cuda/build_defs:cuda_cusparse.BUILD.bazel",
            "12": "//cuda/build_defs:cuda_cusparse.BUILD.bazel",
            "11": "//cuda/build_defs:cuda_cusparse.BUILD.bazel",
        },
    },
    "libnvjitlink": {
        "package_name": "cuda_nvjitlink",
        "version_to_template": {
            "13": "//cuda/build_defs:cuda_nvjitlink.BUILD.bazel",
            "12": "//cuda/build_defs:cuda_nvjitlink.BUILD.bazel",
        },
    },
    "cuda_nvrtc": {
        "package_name": "cuda_nvrtc",
        "version_to_template": {
            "13": "//cuda/build_defs:cuda_nvrtc.BUILD.bazel",
            "12": "//cuda/build_defs:cuda_nvrtc.BUILD.bazel",
            "11": "//cuda/build_defs:cuda_nvrtc.BUILD.bazel",
        },
    },
    "cuda_cccl": {
        "package_name": "cuda_cccl",
        "version_to_template": {
            "any": "//cuda/build_defs:cuda_cccl.BUILD.bazel",
        },
    },
    "cuda_crt": {
        "package_name": "cuda_crt",
        "version_to_template": {
            "any": "//cuda/build_defs:cuda_crt.BUILD.bazel",
        },
    },
    "cuda_nvcc": {
        "package_name": "cuda_nvcc",
        "version_to_template": {
            "any": "//cuda/build_defs:cuda_nvcc.BUILD.bazel",
        },
    },
    "libnvvm": {
        "package_name": "cuda_nvvm",
        "version_to_template": {
            "any": "//cuda/build_defs:cuda_nvvm.BUILD.bazel",
        },
    },
    "cuda_nvdisasm": {
        "package_name": "cuda_nvdisasm",
        "version_to_template": {
            "any": "//cuda/build_defs:cuda_nvdisasm.BUILD.bazel",
        },
    },
    "cuda_nvml_dev": {
        "package_name": "cuda_nvml",
        "version_to_template": {
            "13": "//cuda/build_defs:cuda_nvml.BUILD.bazel",
            "12": "//cuda/build_defs:cuda_nvml.BUILD.bazel",
            "11": "//cuda/build_defs:cuda_nvml.BUILD.bazel",
        },
    },
    "cuda_nvprune": {
        "package_name": "cuda_nvprune",
        "version_to_template": {
            "any": "//cuda/build_defs:cuda_nvprune.BUILD.bazel",
        },
    },
    "cuda_profiler_api": {
        "package_name": "cuda_profiler_api",
        "version_to_template": {
            "any": "//cuda/build_defs:cuda_profiler.BUILD.bazel",
        },
    },
    "cuda_nvtx": {
        "package_name": "cuda_nvtx",
        "version_to_template": {
            "any": "//cuda/build_defs:cuda_nvtx.BUILD.bazel",
        },
    },
}
