"""Shared catalog for NVSHMEM proxy package generation."""

REPO_PUBLIC_TARGETS = {
    "nvshmem": [
        "nvshmem_host_shared_library",
        "nvshmem_device_static_library",
        "nvshmem",
        "header_list",
        "headers",
        "shared_library_files",
    ],
}
