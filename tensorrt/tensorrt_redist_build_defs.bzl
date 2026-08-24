"""Hermetic TensorRT redistribution utilities.

NVIDIA publishes no redistrib manifests for TensorRT, so the checked-in
catalog in tensorrt_redist_versions.json is generated -- and every archive
verified -- with `bazel run //tools/tensorrt:update_redists`, describing the
official TensorRT GA tarballs hosted on developer.download.nvidia.com.

TensorRT is distributed under the NVIDIA TensorRT Supplement to the NVIDIA
Software License Agreement, not under the regular CUDA toolkit EULA.
"""

TENSORRT_REDIST_PATH_PREFIX = "https://developer.download.nvidia.com/compute/machine-learning/tensorrt/"

def get_tensorrt_redist(tensorrt_redistributions, tensorrt_version, cuda_version):
    # NVIDIA builds each TensorRT release once per CUDA major and documents it
    # as compatible with that CUDA major line only (support matrix: "Built
    # with CUDA Toolkit 13.2. Compatible with CUDA 13.x versions only."). The
    # generated catalog keeps the exact build minor and the explicitly
    # supported consumer minors separate so selection never relies on an
    # implicit fallback.
    cuda_parts = cuda_version.split(".")
    if len(cuda_parts) < 2:
        fail("Expected CUDA major.minor version, got '{}'".format(cuda_version))
    cuda_major = cuda_parts[0]
    cuda_minor = ".".join(cuda_parts[:2])
    version_redist = tensorrt_redistributions.get(tensorrt_version)
    if not version_redist:
        fail(
            "Unsupported TensorRT version '{}'. Supported versions: {}.".format(
                tensorrt_version,
                sorted(tensorrt_redistributions.keys()),
            ),
        )

    cuda_family = version_redist.get(cuda_major)
    if not cuda_family:
        fail(
            ("TensorRT version '{tensorrt_version}' is unavailable for CUDA {cuda_version}. " +
             "Supported CUDA major versions: {supported}.").format(
                tensorrt_version = tensorrt_version,
                cuda_version = cuda_version,
                supported = sorted(version_redist.keys()),
            ),
        )
    if cuda_minor not in cuda_family["compatible_cuda"]:
        fail(
            ("TensorRT version '{tensorrt_version}' is unavailable for CUDA {cuda_version}. " +
             "Supported CUDA versions in the CUDA {cuda_major} family: {supported}.").format(
                tensorrt_version = tensorrt_version,
                cuda_version = cuda_minor,
                cuda_major = cuda_major,
                supported = cuda_family["compatible_cuda"],
            ),
        )

    package = {
        "name": "NVIDIA TensorRT",
        "license": "NVIDIA TensorRT Supplement to the NVIDIA Software License Agreement",
        "version": cuda_family["full_version"],
    }

    # NVIDIA does not publish a Linux sbsa tarball for every TensorRT CUDA
    # build (for example the 10.16.0 cuda-12 build is x86_64 only), so copy
    # exactly the platforms the catalog records.
    for platform, archive in cuda_family["archives"].items():
        package[platform] = archive
    return {"tensorrt": package}

TENSORRT_VERSION_TO_TEMPLATE = {
    "any": "//tensorrt/build_defs:tensorrt.BUILD.bazel",
}

TENSORRT_COMPONENTS_REGISTRY = {
    "tensorrt": {
        "repo_name": "cuda_tensorrt",
        "version_to_template": TENSORRT_VERSION_TO_TEMPLATE,
    },
}
