"""Unified CUDA module extension."""

load("//cuda:cuda_component_proxy.bzl", "cuda_component_proxy")
load("//cuda:cuda_redist_repository.bzl", "cuda_redist_repository")
load("//cuda:cuda_compat_repository.bzl", "cuda_compat_repository")
load("//cuda:cuda_redist_repositories.bzl", "cuda_redist_repositories")

_CUDA_REDIST_VERSIONS_JSON = Label("//cuda:cuda_redist_versions.json")

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

    tags = _collect_redist_tags(mctx)

    seen_repo_names = {}
    versions = []

    pending_redistributions_by_version = {}
    versions_to_fetch = []
    redistributions_by_version = {}
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

    for version in versions_to_fetch:
        redistributions_by_version[version] = _read_downloaded_json(
            mctx,
            pending_redistributions_by_version[version],
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
    },
)

cuda = module_extension(
    implementation = _cuda_impl,
    tag_classes = {"redist": _redist},
)
