"""Tests for NCCL redistribution selection."""

load("@bazel_skylib//lib:unittest.bzl", "asserts", "unittest")
load(":nccl_redist_build_defs.bzl", "get_nccl_redist")
load(":nccl_redist_versions.bzl", "NCCL_REDISTRIBUTIONS")

def _nccl_redist_selection_test_impl(ctx):
    env = unittest.begin(ctx)

    expected_versions = [
        "2.25.1",
        "2.26.2",
        "2.26.5",
        "2.27.3",
        "2.27.5",
        "2.27.6",
        "2.27.7",
        "2.28.3",
        "2.28.7",
        "2.28.9",
        "2.29.2",
        "2.29.3",
        "2.29.7",
        "2.30.3",
        "2.30.4",
        "2.30.7",
        "2.31.2",
    ]
    asserts.equals(env, expected_versions, sorted(NCCL_REDISTRIBUTIONS.keys()))

    for nccl_version, cuda_families in NCCL_REDISTRIBUTIONS.items():
        for cuda_major, cuda_family in cuda_families.items():
            asserts.equals(env, cuda_major, cuda_family["built_with_cuda"].split(".")[0])
            for cuda_minor in cuda_family["compatible_cuda"]:
                asserts.equals(env, cuda_major, cuda_minor.split(".")[0])
                redist = get_nccl_redist(nccl_version, cuda_minor + ".0")
                asserts.equals(env, nccl_version, redist["libnccl"]["version"])
                for platform in ["linux-sbsa", "linux-x86_64"]:
                    archive = redist["libnccl"][platform]
                    asserts.equals(env, 64, len(archive["sha256"]))
                    asserts.equals(env, True, archive["strip_prefix"] != "")

    cuda_13_redist = get_nccl_redist("2.27.7", "13.3.1")
    asserts.equals(
        env,
        "nccl/v2.27.7/nccl_2.27.7-1+cuda13.0_x86_64.txz",
        cuda_13_redist["libnccl"]["linux-x86_64"]["relative_path"],
    )
    latest_redist = get_nccl_redist("2.31.2", "12.8.1")
    asserts.equals(
        env,
        "nccl/v2.31.2/nccl-nccl-stable-cuda-12-linux-x86_64-2.31.2-cuda12.9.tar.gz",
        latest_redist["libnccl"]["linux-x86_64"]["relative_path"],
    )

    return unittest.end(env)

_nccl_redist_selection_test = unittest.make(_nccl_redist_selection_test_impl)

def nccl_redist_build_defs_test_suite(name):
    unittest.suite(
        name,
        _nccl_redist_selection_test,
    )
