"""Hermetic cuDNN redistribution utilities."""

CUDNN_REDIST_PATH_PREFIX = "https://developer.download.nvidia.com/compute/cudnn/redist/"

CUDNN_VERSION_TO_TEMPLATE = {
    "8": "//cuda/build_defs:cuda_cudnn8.BUILD.bazel",
    "9": "//cuda/build_defs:cuda_cudnn.BUILD.bazel",
}
