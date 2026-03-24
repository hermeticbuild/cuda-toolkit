"""Unified CUDA module extension."""

load("//cuda:cuda_component_proxy.bzl", "cuda_component_proxy")
load("//cuda:cuda_redist_repository.bzl", "cuda_redist_repository")
load("//cuda:cuda_compat_repository.bzl", "cuda_compat_repository")
load("//cuda:cuda_redist_repositories.bzl", "cuda_redist_repositories")
load(
    "//cudnn:cudnn_redist_build_defs.bzl",
    "CUDNN_COMPONENTS_REGISTRY",
    "CUDNN_REDIST_PATH_PREFIX",
)
load(
    "//nvshmem:nvshmem_redist_build_defs.bzl",
    "NVSHMEM_COMPONENTS_REGISTRY",
    "NVSHMEM_REDIST_PATH_PREFIX",
)

_CUDA_REDIST_VERSIONS_JSON = Label("//cuda:cuda_redist_versions.json")
_CUDNN_REDIST_VERSIONS_JSON = Label("//cudnn:cudnn_redist_versions.json")
_NVSHMEM_REDIST_VERSIONS_JSON = Label("//nvshmem:nvshmem_redist_versions.json")

def _collect_redist_tags(mctx):
    all_tags = []
    root_tags = []
    for mod in mctx.modules:
        for tag in mod.tags.redist:
            all_tags.append(tag)
            if mod.is_root:
                root_tags.append(tag)

    tags = root_tags if root_tags else all_tags
    if not tags:
        fail("cuda extension requires at least one redist tag")
    return tags

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
    nvshmem_version_map = json.decode(mctx.read(_NVSHMEM_REDIST_VERSIONS_JSON))

    tags = _collect_redist_tags(mctx)

    seen_repo_names = {}
    versions = []

    pending_redistributions_by_version = {}
    versions_to_fetch = []
    redistributions_by_version = {}
    pending_cudnn_redistributions_by_version = {}
    cudnn_versions_to_fetch = []
    cudnn_redistributions_by_version = {}
    pending_nvshmem_redistributions_by_version = {}
    nvshmem_versions_to_fetch = []
    nvshmem_redistributions_by_version = {}
    for tag in tags:
        if tag.name == "cuda":
            fail("redist name 'cuda' is reserved for the global aggregated CUDA repository")

        if tag.name in seen_repo_names:
            fail("Duplicate redist name '{}'".format(tag.name))
        seen_repo_names[tag.name] = True
        versions.append(tag.version)

        if tag.version not in pending_redistributions_by_version:
            (cuda_redist_url, cuda_redist_sha256) = _get_url_sha_from_version_map(
                version = tag.version,
                version_to_url_sha = cuda_version_map,
                toolkit_name = "CUDA",
            )
            pending_redistributions_by_version[tag.version] = _json_from_url_future(
                mctx = mctx,
                url = cuda_redist_url,
                sha256 = cuda_redist_sha256,
                output_path = "redistrib_cuda_%s.json" % tag.version,
            )
            versions_to_fetch.append(tag.version)

        if tag.cudnn_version and tag.cudnn_version not in pending_cudnn_redistributions_by_version:
            (cudnn_redist_url, cudnn_redist_sha256) = _get_url_sha_from_version_map(
                version = tag.cudnn_version,
                version_to_url_sha = cudnn_version_map,
                toolkit_name = "cuDNN",
            )
            pending_cudnn_redistributions_by_version[tag.cudnn_version] = _json_from_url_future(
                mctx = mctx,
                url = cudnn_redist_url,
                sha256 = cudnn_redist_sha256,
                output_path = "redistrib_cudnn_%s.json" % tag.cudnn_version,
            )
            cudnn_versions_to_fetch.append(tag.cudnn_version)

        if tag.nvshmem_version and tag.nvshmem_version not in pending_nvshmem_redistributions_by_version:
            (nvshmem_redist_url, nvshmem_redist_sha256) = _get_url_sha_from_version_map(
                version = tag.nvshmem_version,
                version_to_url_sha = nvshmem_version_map,
                toolkit_name = "NVSHMEM",
            )
            pending_nvshmem_redistributions_by_version[tag.nvshmem_version] = _json_from_url_future(
                mctx = mctx,
                url = nvshmem_redist_url,
                sha256 = nvshmem_redist_sha256,
                output_path = "redistrib_nvshmem_%s.json" % tag.nvshmem_version,
            )
            nvshmem_versions_to_fetch.append(tag.nvshmem_version)

    for version in versions_to_fetch:
        redistributions_by_version[version] = _read_downloaded_json(
            mctx,
            pending_redistributions_by_version[version],
        )

    for version in cudnn_versions_to_fetch:
        cudnn_redistributions_by_version[version] = _read_downloaded_json(
            mctx,
            pending_cudnn_redistributions_by_version[version],
        )

    for version in nvshmem_versions_to_fetch:
        nvshmem_redistributions_by_version[version] = _read_downloaded_json(
            mctx,
            pending_nvshmem_redistributions_by_version[version],
        )

    for tag in tags:
        generated_repos = cuda_redist_repositories(
            redist = redistributions_by_version[tag.version],
            cuda_repo_name = tag.name,
            cuda_version = tag.version,
        )

        component_proxy_specs = {}
        for generated in generated_repos:
            repo_name = generated["component_repo_name"]
            spec = component_proxy_specs.get(repo_name)
            if not spec:
                spec = {
                    "version": generated["version"],
                    "targets": generated["targets"],
                    "platform_repo_mappings": {},
                }
                component_proxy_specs[repo_name] = spec
            spec["platform_repo_mappings"][generated["config_setting"]] = generated["concrete_repo_name"]

        if tag.cudnn_version:
            cudnn_redist = cudnn_redistributions_by_version[tag.cudnn_version]
            if "cudnn" not in cudnn_redist:
                fail("cuDNN manifest '{}' does not contain a 'cudnn' package".format(tag.cudnn_version))

            generated_cudnn_repos = cuda_redist_repositories(
                redist = {"cudnn": cudnn_redist["cudnn"]},
                cuda_repo_name = tag.name,
                cuda_version = tag.version,
                cuda_redist_path_prefix = CUDNN_REDIST_PATH_PREFIX,
                components_registry = CUDNN_COMPONENTS_REGISTRY,
            )
            if not generated_cudnn_repos:
                fail("cuDNN version '{}' did not generate any repositories for CUDA {}".format(tag.cudnn_version, tag.version))

            for generated in generated_cudnn_repos:
                repo_name = generated["component_repo_name"]
                spec = component_proxy_specs.get(repo_name)
                if not spec:
                    spec = {
                        "version": generated["version"],
                        "targets": generated["targets"],
                        "platform_repo_mappings": {},
                    }
                    component_proxy_specs[repo_name] = spec
                spec["platform_repo_mappings"][generated["config_setting"]] = generated["concrete_repo_name"]

        if tag.nvshmem_version:
            nvshmem_redist = nvshmem_redistributions_by_version[tag.nvshmem_version]
            if "libnvshmem" not in nvshmem_redist:
                fail("NVSHMEM manifest '{}' does not contain a 'libnvshmem' package".format(tag.nvshmem_version))

            generated_nvshmem_repos = cuda_redist_repositories(
                redist = {"libnvshmem": nvshmem_redist["libnvshmem"]},
                cuda_repo_name = tag.name,
                cuda_version = tag.version,
                cuda_redist_path_prefix = NVSHMEM_REDIST_PATH_PREFIX,
                components_registry = NVSHMEM_COMPONENTS_REGISTRY,
            )
            if not generated_nvshmem_repos:
                fail("NVSHMEM version '{}' did not generate any repositories for CUDA {}".format(tag.nvshmem_version, tag.version))

            for generated in generated_nvshmem_repos:
                repo_name = generated["component_repo_name"]
                spec = component_proxy_specs.get(repo_name)
                if not spec:
                    spec = {
                        "version": generated["version"],
                        "targets": generated["targets"],
                        "platform_repo_mappings": {},
                    }
                    component_proxy_specs[repo_name] = spec
                spec["platform_repo_mappings"][generated["config_setting"]] = generated["concrete_repo_name"]

        available_component_versions = {}
        available_component_mappings = {}
        for repo_name, spec in component_proxy_specs.items():
            component_proxy_repo_name = "{}__{}".format(tag.name, repo_name)

            # Re-exports targets from platform-specific repositories under a unified repository.
            cuda_component_proxy(
                name = component_proxy_repo_name,
                version = spec["version"],
                platform_repo_mappings = spec["platform_repo_mappings"],
                targets = spec["targets"],
            )
            available_component_versions[repo_name] = spec["version"]
            available_component_mappings[repo_name] = component_proxy_repo_name

        # Re-exports all unified repositories under a //<component> convenient package.
        cuda_redist_repository(
            name = tag.name,
            cuda_version = tag.version,
            available_component_mappings = available_component_mappings,
            available_component_versions = available_component_versions,
        )

    cuda_compat_repository(
        name = "cuda",
        available_cuda_versions = sorted(cuda_version_map.keys()),
        registered_cuda_versions = sorted(versions),
        version_to_redist_repo_name = {
            tag.version: tag.name
            for tag in tags
        },
    )

    return mctx.extension_metadata(reproducible = True)

_redist = tag_class(
    attrs = {
        "name": attr.string(mandatory = True),
        "version": attr.string(mandatory = True),
        "cudnn_version": attr.string(),
        "nvshmem_version": attr.string(),
    },
)

cuda = module_extension(
    implementation = _cuda_impl,
    tag_classes = {"redist": _redist},
)
