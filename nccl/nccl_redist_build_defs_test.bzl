"""Tests for NCCL redistribution selection."""

load("@bazel_skylib//lib:unittest.bzl", "asserts", "unittest")
load(":nccl_redist_build_defs.bzl", "get_nccl_redist")

_NCCL_REDISTRIBUTIONS = {
    "2.27.7": {
        "13": {
            "archives": {
                "linux-sbsa": {
                    "relative_path": "nccl/v2.27.7/nccl_2.27.7-1+cuda13.0_aarch64.txz",
                },
                "linux-x86_64": {
                    "relative_path": "nccl/v2.27.7/nccl_2.27.7-1+cuda13.0_x86_64.txz",
                },
            },
            "built_with_cuda": "13.0",
            "compatible_cuda": ["13.0", "13.1", "13.2", "13.3"],
        },
    },
    "2.31.2": {
        "12": {
            "archives": {
                "linux-sbsa": {
                    "relative_path": "nccl/v2.31.2/nccl-nccl-stable-cuda-12-linux-sbsa-2.31.2-cuda12.9.tar.gz",
                },
                "linux-x86_64": {
                    "relative_path": "nccl/v2.31.2/nccl-nccl-stable-cuda-12-linux-x86_64-2.31.2-cuda12.9.tar.gz",
                },
            },
            "built_with_cuda": "12.9",
            "compatible_cuda": ["12.8", "12.9"],
        },
    },
    "2.32.3": {
        "12": {
            "archives": {
                "linux-sbsa": {
                    "relative_path": "nccl/v2.32.2/nccl-nccl-stable-cuda-12-linux-sbsa-2.32.3-cuda12.9.tar.gz",
                },
                "linux-x86_64": {
                    "relative_path": "nccl/v2.32.2/nccl-nccl-stable-cuda-12-linux-x86_64-2.32.3-cuda12.9.tar.gz",
                },
            },
            "built_with_cuda": "12.9",
            "compatible_cuda": ["12.8", "12.9"],
        },
        "13": {
            "archives": {
                "linux-sbsa": {
                    "relative_path": "nccl/v2.32.2/nccl-nccl-stable-cuda-13-linux-sbsa-2.32.3-cuda13.4.tar.gz",
                },
                "linux-x86_64": {
                    "relative_path": "nccl/v2.32.2/nccl-nccl-stable-cuda-13-linux-x86_64-2.32.3-cuda13.4.tar.gz",
                },
            },
            "built_with_cuda": "13.4",
            "compatible_cuda": ["13.0", "13.1", "13.2", "13.3", "13.4"],
        },
    },
}

def _nccl_redist_selection_test_impl(ctx):
    env = unittest.begin(ctx)

    cuda_13_redist = get_nccl_redist(_NCCL_REDISTRIBUTIONS, "2.27.7", "13.3.1")
    asserts.equals(
        env,
        "nccl/v2.27.7/nccl_2.27.7-1+cuda13.0_x86_64.txz",
        cuda_13_redist["libnccl"]["linux-x86_64"]["relative_path"],
    )
    latest_redist = get_nccl_redist(_NCCL_REDISTRIBUTIONS, "2.31.2", "12.8.1")
    asserts.equals(
        env,
        "nccl/v2.31.2/nccl-nccl-stable-cuda-12-linux-x86_64-2.31.2-cuda12.9.tar.gz",
        latest_redist["libnccl"]["linux-x86_64"]["relative_path"],
    )
    stale_directory_redist = get_nccl_redist(_NCCL_REDISTRIBUTIONS, "2.32.3", "12.8.1")
    asserts.equals(
        env,
        "nccl/v2.32.2/nccl-nccl-stable-cuda-12-linux-x86_64-2.32.3-cuda12.9.tar.gz",
        stale_directory_redist["libnccl"]["linux-x86_64"]["relative_path"],
    )
    cuda_13_4_redist = get_nccl_redist(_NCCL_REDISTRIBUTIONS, "2.32.3", "13.4.1")
    for platform in ["linux-sbsa", "linux-x86_64"]:
        asserts.equals(
            env,
            "nccl/v2.32.2/nccl-nccl-stable-cuda-13-{}-2.32.3-cuda13.4.tar.gz".format(platform),
            cuda_13_4_redist["libnccl"][platform]["relative_path"],
        )

    return unittest.end(env)

_nccl_redist_selection_test = unittest.make(_nccl_redist_selection_test_impl)

def nccl_redist_build_defs_test_suite(name):
    unittest.suite(
        name,
        _nccl_redist_selection_test,
    )
