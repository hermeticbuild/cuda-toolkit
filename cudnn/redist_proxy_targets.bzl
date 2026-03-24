"""Shared catalog for cuDNN proxy package generation."""

REPO_PUBLIC_TARGETS = {
    "cudnn": [
        "cudnn_ops_infer",
        "cudnn_cnn_infer",
        "cudnn_ops_train",
        "cudnn_cnn_train",
        "cudnn_adv_infer",
        "cudnn_adv_train",
        "cudnn_ops",
        "cudnn_cnn",
        "cudnn_adv",
        "cudnn_graph",
        "cudnn_engines_precompiled",
        "cudnn_engines_runtime_compiled",
        "cudnn_heuristic",
        "cudnn_main",
        "cudnn",
        "header_list",
        "headers",
    ],
}
