"""Hermetic NCCL redistribution utilities.

NVIDIA does not publish redistrib manifests for NCCL, so the manifests
are hand-authored in this package, describing the official NCCL binary
archives hosted on developer.download.nvidia.com.
"""

NCCL_REDIST_PATH_PREFIX = "https://developer.download.nvidia.com/compute/redist/"

NCCL_VERSION_TO_MANIFEST = {
    "2.30.7": "//nccl:redistrib_2.30.7.json",
}

NCCL_VERSION_TO_TEMPLATE = {
    "any": "//nccl/build_defs:nccl.BUILD.bazel",
}

NCCL_COMPONENTS_REGISTRY = {
    "libnccl": {
        "repo_name": "cuda_nccl",
        "version_to_template": NCCL_VERSION_TO_TEMPLATE,
    },
}
