"""Hermetic cuSPARSELt redistribution utilities."""

CUSPARSELT_REDIST_PATH_PREFIX = "https://developer.download.nvidia.com/compute/cusparselt/redist/"

CUSPARSELT_VERSION_TO_TEMPLATE = {
    "0": "//cusparselt/build_defs:cusparselt.BUILD.bazel",
}

CUSPARSELT_COMPONENTS_REGISTRY = {
    "libcusparse_lt": {
        "repo_name": "cuda_cusparselt",
        "version_to_template": CUSPARSELT_VERSION_TO_TEMPLATE,
    },
}
