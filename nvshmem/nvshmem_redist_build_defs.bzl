"""Hermetic NVSHMEM redistribution utilities."""

NVSHMEM_REDIST_PATH_PREFIX = "https://developer.download.nvidia.com/compute/nvshmem/redist/"

NVSHMEM_VERSION_TO_TEMPLATE = {
    "3": "//nvshmem/build_defs:nvshmem.BUILD.bazel",
}

NVSHMEM_COMPONENTS_REGISTRY = {
    "libnvshmem": {
        "repo_name": "cuda_nvshmem",
        "version_to_template": NVSHMEM_VERSION_TO_TEMPLATE,
    },
}
