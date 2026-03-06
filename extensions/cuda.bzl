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
    return parts and all([p.isdigit() for p in parts])

def _version_tags(mctx):
    root_tags = []
    all_tags = []
    for mod in mctx.modules:
        for tag in mod.tags.version:
            all_tags.append(tag)
            if mod.is_root:
                root_tags.append(tag)
    tags = root_tags if root_tags else all_tags
    if not tags:
        fail("cuda extension requires at least one version tag")
    return tags

def _version_repo_name(cuda_version):
    return "cuda{}".format(cuda_version.replace(".", "_"))

def _get_url_sha_from_version_map(version, version_to_url_sha, toolkit_name):
    url_sha = version_to_url_sha.get(version)
    if not url_sha:
        fail(
            ("Unsupported {toolkit_name} version '{version}'. " +
             "Supported versions: {supported}.").format(
                toolkit_name = toolkit_name,
                version = version,
                supported = sorted(version_to_url_sha.keys()),
            ),
        )
    return url_sha

def _json_from_url_future(mctx, url, sha256, output_path):
    return struct(
        output_path = output_path,
        token = mctx.download(
            url = [url],
            output = output_path,
            sha256 = sha256,
            block = False,
        ),
    )

def _read_downloaded_json(mctx, pending_download):
    pending_download.token.wait()
    return json.decode(mctx.read(pending_download.output_path))

def _cuda_impl(mctx):
    cuda_version_map = json.decode(mctx.read(_CUDA_REDIST_VERSIONS_JSON))
    cudnn_version_map = json.decode(mctx.read(_CUDNN_REDIST_VERSIONS_JSON))

    for tag in _version_tags(mctx):
        if not _is_valid_version(tag.cuda_version):
            fail("Invalid cuda_version '{}': expected digits separated by dots".format(tag.cuda_version))
        if not _is_valid_version(tag.cudnn_version):
            fail("Invalid cudnn_version '{}': expected digits separated by dots".format(tag.cudnn_version))
        cuda_umd_version = tag.cuda_umd_version or tag.cuda_version
        if not _is_valid_version(cuda_umd_version):
            fail("Invalid cuda_umd_version '{}': expected digits separated by dots".format(cuda_umd_version))

        cuda_redistributions_download = _json_from_url_future(
            mctx = mctx,
            url = cuda_redist_url,
            sha256 = cuda_redist_sha256,
            output_path = "redistrib_cuda_%s.json" % tag.cuda_version,
        )
        cuda_umd_redistributions_download = _json_from_url_future(
            mctx = mctx,
            url = cuda_umd_redist_url,
            sha256 = cuda_umd_redist_sha256,
            output_path = "redistrib_cuda_umd_%s.json" % cuda_umd_version,
        )
        cudnn_redistributions_download = _json_from_url_future(
            mctx = mctx,
            url = cudnn_redist_url,
            sha256 = cudnn_redist_sha256,
            output_path = "redistrib_cudnn_%s.json" % tag.cudnn_version,
        )

        cuda_redistributions = _read_downloaded_json(mctx, cuda_redistributions_download)
        cuda_umd_redistributions = _read_downloaded_json(mctx, cuda_umd_redistributions_download)
        cudnn_redistributions = _read_downloaded_json(mctx, cudnn_redistributions_download)

        cuda_proxy_data = cuda_redist_repositories(
            cuda_redistributions = dict(
                cuda_redistributions,
                nvidia_driver = cuda_umd_redistributions.get("nvidia_driver", {}),
            ),
            cuda_version = tag.cuda_version,
        )
        cudnn_proxy_data = cudnn_redist_repository(
            cudnn_redistributions = cudnn_redistributions,
            cuda_version = tag.cuda_version,
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
            repo_prefix = repo_name,
        )
        cudnn_proxy_data = cudnn_redist_repository(
            cudnn_redistributions = cudnn_redistributions,
            cuda_version = tag.cuda_version,
            repo_prefix = repo_name,
        )

        component_versions = dict(cuda_proxy_data["component_versions"])
        component_versions.update(cudnn_proxy_data["component_versions"])
        component_arches = dict(cuda_proxy_data["component_arches"])
        component_arches.update(cudnn_proxy_data["component_arches"])

        cuda_configure(
            name = repo_name,
            cuda_version = tag.cuda_version,
            component_versions = component_versions,
            component_arches = component_arches,
        )

    return mctx.extension_metadata(reproducible = True)

_version_tag = tag_class(
    attrs = {
        "cuda_version": attr.string(mandatory = True),
        "cudnn_version": attr.string(mandatory = True),
        "cuda_umd_version": attr.string(mandatory = False),
    },
)

cuda = module_extension(
    implementation = _cuda_impl,
    tag_classes = {"version": _version_tag},
)
