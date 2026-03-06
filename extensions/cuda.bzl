"""Unified CUDA module extension."""

load(
    "//cuda:cuda_configure.bzl",
    "cuda_configure",
)
load(
    "//cuda:cuda_redist_repositories.bzl",
    "cuda_redist_repositories",
    "cudnn_redist_repository",
)

_CUDA_REDIST_VERSIONS_JSON = Label("//cuda:cuda_redist_versions.json")
_CUDNN_REDIST_VERSIONS_JSON = Label("//cuda:cudnn_redist_versions.json")

def _is_valid_version(version):
    parts = version.split(".")
    return len(parts) > 0 and all([p.isdigit() for p in parts])

def _single_config_tag(mctx):
    latest_tag = None
    root_latest_tag = None
    for mod in mctx.modules:
        for tag in mod.tags.configure:
            latest_tag = tag
            if mod.is_root:
                root_latest_tag = tag

    if root_latest_tag:
        return root_latest_tag
    if latest_tag:
        return latest_tag

    fail("cuda extension requires at least one configure tag")

def _get_url_sha_from_version_map(version, version_to_url_sha, toolkit_name):
    if version not in version_to_url_sha:
        fail(
            ("Unsupported {toolkit_name} version '{version}'. " +
             "Supported versions: {supported}.").format(
                toolkit_name = toolkit_name,
                version = version,
                supported = sorted(version_to_url_sha.keys()),
            ),
        )
    return version_to_url_sha[version]

def _load_json_from_url(mctx, url, sha256, output_path):
    mctx.download(
        url = [url],
        output = output_path,
        sha256 = sha256,
    )
    return json.decode(mctx.read(output_path))

def _cuda_impl(mctx):
    tag = _single_config_tag(mctx)
    if not _is_valid_version(tag.cuda_version):
        fail("Invalid cuda_version '{}': expected digits separated by dots".format(tag.cuda_version))
    if not _is_valid_version(tag.cudnn_version):
        fail("Invalid cudnn_version '{}': expected digits separated by dots".format(tag.cudnn_version))
    cuda_umd_version = tag.cuda_umd_version or tag.cuda_version
    if not _is_valid_version(cuda_umd_version):
        fail("Invalid cuda_umd_version '{}': expected digits separated by dots".format(cuda_umd_version))

    cuda_version_map = json.decode(mctx.read(_CUDA_REDIST_VERSIONS_JSON))
    cudnn_version_map = json.decode(mctx.read(_CUDNN_REDIST_VERSIONS_JSON))

    (cuda_redist_url, cuda_redist_sha256) = _get_url_sha_from_version_map(
        version = tag.cuda_version,
        version_to_url_sha = cuda_version_map,
        toolkit_name = "CUDA",
    )
    (cuda_umd_redist_url, cuda_umd_redist_sha256) = _get_url_sha_from_version_map(
        version = cuda_umd_version,
        version_to_url_sha = cuda_version_map,
        toolkit_name = "CUDA_UMD",
    )
    (cudnn_redist_url, cudnn_redist_sha256) = _get_url_sha_from_version_map(
        version = tag.cudnn_version,
        version_to_url_sha = cudnn_version_map,
        toolkit_name = "CUDNN",
    )

    cuda_redistributions = _load_json_from_url(
        mctx = mctx,
        url = cuda_redist_url,
        sha256 = cuda_redist_sha256,
        output_path = "redistrib_cuda_{}.json".format(tag.cuda_version),
    )
    cuda_umd_redistributions = _load_json_from_url(
        mctx = mctx,
        url = cuda_umd_redist_url,
        sha256 = cuda_umd_redist_sha256,
        output_path = "redistrib_cuda_umd_{}.json".format(cuda_umd_version),
    )
    cuda_redistributions = dict(
        cuda_redistributions,
        nvidia_driver = cuda_umd_redistributions.get("nvidia_driver", {}),
    )
    cudnn_redistributions = _load_json_from_url(
        mctx = mctx,
        url = cudnn_redist_url,
        sha256 = cudnn_redist_sha256,
        output_path = "redistrib_cudnn_{}.json".format(tag.cudnn_version),
    )

    cuda_proxy_data = cuda_redist_repositories(
        cuda_redistributions = cuda_redistributions,
        cuda_version = tag.cuda_version,
    )
    cudnn_proxy_data = cudnn_redist_repository(
        cudnn_redistributions = cudnn_redistributions,
        cuda_version = tag.cuda_version,
    )

    component_versions = dict(cuda_proxy_data["component_versions"])
    component_versions.update(cudnn_proxy_data["component_versions"])
    component_arches = dict(cuda_proxy_data["component_arches"])
    component_arches.update(cudnn_proxy_data["component_arches"])

    cuda_configure(
        name = "cuda",
        cuda_version = tag.cuda_version,
        component_versions = component_versions,
        component_arches = component_arches,
    )

    return mctx.extension_metadata(reproducible = True)

_configure_tag = tag_class(
    attrs = {
        "cuda_version": attr.string(mandatory = True),
        "cudnn_version": attr.string(mandatory = True),
        "cuda_umd_version": attr.string(mandatory = False),
    },
)

cuda = module_extension(
    implementation = _cuda_impl,
    tag_classes = {"configure": _configure_tag},
)
