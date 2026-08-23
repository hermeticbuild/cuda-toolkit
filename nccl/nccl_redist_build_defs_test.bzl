"""Tests for NCCL redistribution selection."""

load("@bazel_skylib//lib:unittest.bzl", "asserts", "unittest")
load(":nccl_redist_build_defs.bzl", "get_nccl_manifest_label", "nccl_cuda_version")

def _nccl_manifest_selection_test_impl(ctx):
    env = unittest.begin(ctx)

    asserts.equals(env, "12.9", nccl_cuda_version("12.9.1"))
    asserts.equals(env, "13.3", nccl_cuda_version("13.3.1"))
    asserts.equals(
        env,
        "//nccl:redistrib_2.30.7_cuda12.9.json",
        get_nccl_manifest_label("2.30.7", "12.9.1"),
    )
    asserts.equals(
        env,
        "//nccl:redistrib_2.30.7_cuda13.3.json",
        get_nccl_manifest_label("2.30.7", "13.3.1"),
    )
    asserts.equals(env, None, get_nccl_manifest_label("2.30.7", "13.2.1"))
    asserts.equals(env, None, get_nccl_manifest_label("0.0.0", "13.3.1"))

    return unittest.end(env)

_nccl_manifest_selection_test = unittest.make(_nccl_manifest_selection_test_impl)

def nccl_redist_build_defs_test_suite(name):
    unittest.suite(
        name,
        _nccl_manifest_selection_test,
    )
