"""Hermetic NCCL redistribution utilities."""

NCCL_REDIST_PATH_PREFIX = "https://developer.download.nvidia.com/compute/redist/"

def get_nccl_redist(nccl_redistributions, nccl_version, cuda_version):
    # NVIDIA publishes one NCCL archive stream per CUDA major. The generated
    # catalog keeps the exact build minor and the explicitly supported consumer
    # minors separate so selection never relies on an implicit fallback.
    cuda_parts = cuda_version.split(".")
    if len(cuda_parts) < 2:
        fail("Expected CUDA major.minor version, got '{}'".format(cuda_version))
    cuda_major = cuda_parts[0]
    cuda_minor = ".".join(cuda_parts[:2])
    version_redist = nccl_redistributions.get(nccl_version)
    if not version_redist:
        fail(
            "Unsupported NCCL version '{}'. Supported versions: {}.".format(
                nccl_version,
                sorted(nccl_redistributions.keys()),
            ),
        )

    cuda_family = version_redist.get(cuda_major)
    if not cuda_family:
        fail(
            ("NCCL version '{nccl_version}' is unavailable for CUDA {cuda_version}. " +
             "Supported CUDA major versions: {supported}.").format(
                nccl_version = nccl_version,
                cuda_version = cuda_version,
                supported = sorted(version_redist.keys()),
            ),
        )
    if cuda_minor not in cuda_family["compatible_cuda"]:
        fail(
            ("NCCL version '{nccl_version}' is unavailable for CUDA {cuda_version}. " +
             "Supported CUDA versions in the CUDA {cuda_major} family: {supported}.").format(
                nccl_version = nccl_version,
                cuda_version = cuda_minor,
                cuda_major = cuda_major,
                supported = cuda_family["compatible_cuda"],
            ),
        )

    return {
        "libnccl": {
            "name": "NVIDIA Collective Communications Library (NCCL)",
            "license": "Apache-2.0 AND BSD-3-Clause",
            "version": nccl_version,
            "linux-sbsa": cuda_family["archives"]["linux-sbsa"],
            "linux-x86_64": cuda_family["archives"]["linux-x86_64"],
        },
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
