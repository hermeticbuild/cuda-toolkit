"""Hermetic NCCL redistribution utilities.

NVIDIA does not publish redistrib manifests for NCCL, so the manifests
are hand-authored in this package, describing the official NCCL binary
archives hosted on developer.download.nvidia.com.
"""

NCCL_REDIST_PATH_PREFIX = "https://developer.download.nvidia.com/compute/redist/"

NCCL_VERSION_TO_MANIFEST = {
    "2.30.7": {
        "12.9": "//nccl:redistrib_2.30.7_cuda12.9.json",
        "13.3": "//nccl:redistrib_2.30.7_cuda13.3.json",
    },
}

def nccl_cuda_version(cuda_version):
    parts = cuda_version.split(".")
    if len(parts) < 2:
        fail("Expected CUDA major.minor version, got '{}'".format(cuda_version))
    return ".".join(parts[:2])

def get_nccl_manifest_label(nccl_version, cuda_version):
    cuda_version_to_manifest = NCCL_VERSION_TO_MANIFEST.get(nccl_version, {})
    return cuda_version_to_manifest.get(nccl_cuda_version(cuda_version))

NCCL_VERSION_TO_TEMPLATE = {
    "any": "//nccl/build_defs:nccl.BUILD.bazel",
}

NCCL_COMPONENTS_REGISTRY = {
    "libnccl": {
        "repo_name": "cuda_nccl",
        "version_to_template": NCCL_VERSION_TO_TEMPLATE,
    },
}
