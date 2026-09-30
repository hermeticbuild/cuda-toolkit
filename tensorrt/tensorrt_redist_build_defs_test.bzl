"""Tests for TensorRT redistribution selection."""

load("@bazel_skylib//lib:unittest.bzl", "asserts", "unittest")
load(":tensorrt_redist_build_defs.bzl", "get_tensorrt_redist")

_TENSORRT_REDISTRIBUTIONS = {
    "10.16.0": {
        "12": {
            "archives": {
                "linux-x86_64": {
                    "relative_path": "10.16.0/tars/TensorRT-10.16.0.72.Linux.x86_64-gnu.cuda-12.9.tar.gz",
                },
            },
            "built_with_cuda": "12.9",
            "compatible_cuda": ["12.8", "12.9"],
            "full_version": "10.16.0.72",
        },
        "13": {
            "archives": {
                "linux-sbsa": {
                    "relative_path": "10.16.0/tars/TensorRT-10.16.0.72.Linux.aarch64-gnu.cuda-13.2.tar.gz",
                },
                "linux-x86_64": {
                    "relative_path": "10.16.0/tars/TensorRT-10.16.0.72.Linux.x86_64-gnu.cuda-13.2.tar.gz",
                },
            },
            "built_with_cuda": "13.2",
            "compatible_cuda": ["13.0", "13.1", "13.2", "13.3"],
            "full_version": "10.16.0.72",
        },
    },
}

def _tensorrt_redist_selection_test_impl(ctx):
    env = unittest.begin(ctx)

    cuda_13_redist = get_tensorrt_redist(_TENSORRT_REDISTRIBUTIONS, "10.16.0", "13.3.1")
    asserts.equals(
        env,
        "10.16.0/tars/TensorRT-10.16.0.72.Linux.x86_64-gnu.cuda-13.2.tar.gz",
        cuda_13_redist["tensorrt"]["linux-x86_64"]["relative_path"],
    )
    asserts.equals(env, "10.16.0.72", cuda_13_redist["tensorrt"]["version"])

    # The cuda-12 build of 10.16.0 is published for linux-x86_64 only.
    cuda_12_redist = get_tensorrt_redist(_TENSORRT_REDISTRIBUTIONS, "10.16.0", "12.8.1")
    asserts.equals(
        env,
        "10.16.0/tars/TensorRT-10.16.0.72.Linux.x86_64-gnu.cuda-12.9.tar.gz",
        cuda_12_redist["tensorrt"]["linux-x86_64"]["relative_path"],
    )
    asserts.false(env, "linux-sbsa" in cuda_12_redist["tensorrt"])

    return unittest.end(env)

_tensorrt_redist_selection_test = unittest.make(_tensorrt_redist_selection_test_impl)

def tensorrt_redist_build_defs_test_suite(name):
    unittest.suite(
        name,
        _tensorrt_redist_selection_test,
    )
