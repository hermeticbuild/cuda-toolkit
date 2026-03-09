"""Unified CUDA module extension."""

load(
    "//cuda:cuda_component_proxy.bzl",
    "cuda_component_proxy",
)
load(
    "//cuda:cuda_redist_repositories.bzl",
    "cuda_redist_repositories",
    # "cudnn_redist_repository",
)

_CUDA_REDIST_VERSIONS_JSON = Label("//cuda:cuda_redist_versions.json")
_CUDNN_REDIST_VERSIONS_JSON = Label("//cuda:cudnn_redist_versions.json")

def _is_valid_version(version):
    parts = version.split(".")
    return parts and all([p.isdigit() for p in parts])

def _single_redist_tag(mctx):
    latest_tag = None
    root_latest_tag = None
    for mod in mctx.modules:
        for tag in mod.tags.redist:
            latest_tag = tag
            if mod.is_root:
                root_latest_tag = tag

    if root_latest_tag:
        return root_latest_tag
    if latest_tag:
        return latest_tag

    fail("cuda extension requires at least one redist tag")

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
    tag = _single_redist_tag(mctx)
    if not _is_valid_version(tag.version):
        fail("Invalid cuda_version '{}': expected digits separated by dots".format(tag.version))
        # if not _is_valid_version(tag.cudnn_version):
        #     fail("Invalid cudnn_version '{}': expected digits separated by dots".format(tag.cudnn_version))
        # cuda_umd_version = tag.cuda_umd_version or tag.version
        # if not _is_valid_version(cuda_umd_version):
        #     fail("Invalid cuda_umd_version '{}': expected digits separated by dots".format(cuda_umd_version))

    cuda_version_map = json.decode(mctx.read(_CUDA_REDIST_VERSIONS_JSON))
    # cudnn_version_map = json.decode(mctx.read(_CUDNN_REDIST_VERSIONS_JSON))

    (cuda_redist_url, cuda_redist_sha256) = _get_url_sha_from_version_map(
        version = tag.version,
        version_to_url_sha = cuda_version_map,
        toolkit_name = "CUDA",
    )
    # (cuda_umd_redist_url, cuda_umd_redist_sha256) = _get_url_sha_from_version_map(
    #     version = cuda_umd_version,
    #     version_to_url_sha = cuda_version_map,
    #     toolkit_name = "CUDA_UMD",
    # )
    # (cudnn_redist_url, cudnn_redist_sha256) = _get_url_sha_from_version_map(
    #     version = tag.cudnn_version,
    #     version_to_url_sha = cudnn_version_map,
    #     toolkit_name = "CUDNN",
    # )

    cuda_redistributions_download = _json_from_url_future(
        mctx = mctx,
        url = cuda_redist_url,
        sha256 = cuda_redist_sha256,
        output_path = "redistrib_cuda_%s.json" % tag.version,
    )
    # cuda_umd_redistributions_download = _json_from_url_future(
    #     mctx = mctx,
    #     url = cuda_umd_redist_url,
    #     sha256 = cuda_umd_redist_sha256,
    #     output_path = "redistrib_cuda_umd_%s.json" % cuda_umd_version,
    # )
    # cudnn_redistributions_download = _json_from_url_future(
    #     mctx = mctx,
    #     url = cudnn_redist_url,
    #     sha256 = cudnn_redist_sha256,
    #     output_path = "redistrib_cudnn_%s.json" % tag.cudnn_version,
    # )

    cuda_redistributions = _read_downloaded_json(mctx, cuda_redistributions_download)
    # cuda_umd_redistributions = _read_downloaded_json(mctx, cuda_umd_redistributions_download)
    # cudnn_redistributions = _read_downloaded_json(mctx, cudnn_redistributions_download)

    generated_repos = cuda_redist_repositories(
        redist = cuda_redistributions,
        # cuda_redistributions = dict(
        #     cuda_redistributions,
        #     nvidia_driver = cuda_umd_redistributions.get("nvidia_driver", {}),
        # ),
        cuda_version = tag.version,
    )
    # cudnn_proxy_data = cudnn_redist_repository(
    #     cudnn_redistributions = cudnn_redistributions,
    #     cuda_version = tag.cuda_version,
    # )

    component_proxy_specs = {}
    for generated in generated_repos:
        repo_name = generated["repo_name"]
        spec = component_proxy_specs.get(repo_name)
        if not spec:
            spec = {
                "repo_name": generated["repo_name"],
                "version": generated["version"],
                "targets": generated["targets"],
                "platform_repo_mappings": {},
            }
            component_proxy_specs[repo_name] = spec

        concrete_repo_name = generated["concrete_repo_name"]
        for platform in generated["platforms"]:
            existing = spec["platform_repo_mappings"].get(platform)
            spec["platform_repo_mappings"][platform] = concrete_repo_name

    for repo_name, spec in component_proxy_specs.items():
        cuda_component_proxy(
            name = repo_name,
            version = spec["version"],
            platform_repo_mappings = spec["platform_repo_mappings"],
            targets = spec["targets"],
        )

    return mctx.extension_metadata(reproducible = True)

# _configure_tag = tag_class(
#     attrs = {
#         "cuda_version": attr.string(mandatory = True),
#         "cudnn_version": attr.string(mandatory = True),
#         "cuda_umd_version": attr.string(mandatory = False),
#     },
# )

_redist = tag_class(
    attrs = {
        "name": attr.string(mandatory = True),
        "version": attr.string(mandatory = True),
    },
)

cuda = module_extension(
    implementation = _cuda_impl,
    tag_classes = {"redist": _redist},
)
