"""Hermetic cuDNN redistribution utilities."""

CUDNN_REDIST_PATH_PREFIX = "https://developer.download.nvidia.com/compute/cudnn/redist/"

CUDNN_VERSION_TO_TEMPLATE = {
    "8": "//cuda/build_defs:cuda_cudnn8.BUILD.bazel",
    "9": "//cuda/build_defs:cuda_cudnn.BUILD.bazel",
}

CUDNN_COMPONENTS_REGISTRY = {
    "cudnn": {
        "repo_name": "cuda_cudnn",
        "soname_libraries_by_version": {
            "8": [
                "libcudnn",
                "libcudnn_adv_infer",
                "libcudnn_adv_train",
                "libcudnn_cnn_infer",
                "libcudnn_cnn_train",
                "libcudnn_ops_infer",
                "libcudnn_ops_train",
            ],
            "9": [
                "libcudnn",
                "libcudnn_adv",
                "libcudnn_cnn",
                "libcudnn_engines_precompiled",
                "libcudnn_engines_runtime_compiled",
                "libcudnn_graph",
                "libcudnn_heuristic",
                "libcudnn_ops",
            ],
        },
        "version_to_template": CUDNN_VERSION_TO_TEMPLATE,
    },
}
