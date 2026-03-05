"""Unified CUDA module extension."""

load(
    "//gpu/cuda:cuda_configure.bzl",
    "cuda_configure",
)
load(
    "//gpu/cuda:cuda_redist_repositories.bzl",
    "cuda_redist_repositories",
    "cudnn_redist_repository",
)
_CUDA_REDIST_VERSIONS_JSON = Label("//gpu/cuda:cuda_redist_versions.json")
_CUDNN_REDIST_VERSIONS_JSON = Label("//gpu/cuda:cudnn_redist_versions.json")

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

    fail("cuda_ext requires at least one configure tag")

def _load_json_from_version_map(mctx, version, version_to_url_sha, toolkit_name):
    if version not in version_to_url_sha:
        fail(
            ("Unsupported {toolkit_name} version '{version}'. " +
             "Supported versions: {supported}.").format(
                toolkit_name = toolkit_name,
                version = version,
                supported = sorted(version_to_url_sha.keys()),
            ),
        )
    (url, sha256) = version_to_url_sha[version]
    output_path = "redistrib_{toolkit_name}_{version}.json".format(
        toolkit_name = toolkit_name.lower(),
        version = version,
    )
    mctx.download(
        url = [url],
        output = output_path,
        sha256 = sha256,
    )
    return json.decode(mctx.read(output_path))

def _cuda_ext_impl(mctx):
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

    cuda_redistributions = _load_json_from_version_map(
        mctx = mctx,
        version = tag.cuda_version,
        version_to_url_sha = cuda_version_map,
        toolkit_name = "CUDA",
    )
    cuda_umd_redistributions = _load_json_from_version_map(
        mctx = mctx,
        version = cuda_umd_version,
        version_to_url_sha = cuda_version_map,
        toolkit_name = "CUDA_UMD",
    )
    cuda_redistributions = dict(
        cuda_redistributions,
        nvidia_driver = cuda_umd_redistributions.get("nvidia_driver", {}),
    )
    cudnn_redistributions = _load_json_from_version_map(
        mctx = mctx,
        version = tag.cudnn_version,
        version_to_url_sha = cudnn_version_map,
        toolkit_name = "CUDNN",
    )

    cuda_redist_repositories(
        cuda_redistributions = cuda_redistributions,
        cuda_version = tag.cuda_version,
        host_platform = tag.host_platform,
        target_platform = tag.target_platform,
    )
    cudnn_redist_repository(
        cudnn_redistributions = cudnn_redistributions,
        cuda_version = tag.cuda_version,
        target_platform = tag.target_platform,
    )

    cuda_configure(
        name = "cuda",
        cuda_version = tag.cuda_version,
    )
    
    return mctx.extension_metadata(reproducible = True)

_configure_tag = tag_class(
    attrs = {
        "cuda_version": attr.string(mandatory = True),
        "cudnn_version": attr.string(mandatory = True),
        "cuda_umd_version": attr.string(mandatory = False),
        "host_platform": attr.string(mandatory = True),
        "target_platform": attr.string(mandatory = True),
    },
)

cuda_ext = module_extension(
    implementation = _cuda_ext_impl,
    tag_classes = {"configure": _configure_tag},
)
