# CUDA Toolkit

## Goal

This repository exposes NVIDIA CUDA redistributions as hermetic Bazel targets.

Primary audience:
- downstream Bazel rulesets
- toolchains
- projects that need a stable Bazel-facing CUDA surface without depending on a host-installed toolkit

The goal is not to mirror NVIDIA archives 1:1 as a user-facing contract.
The goal is to provide stable Bazel labels for common CUDA functionality while hiding as much upstream packaging churn as possible inside this repository.

## Public Design

The consumer-facing model is:
- `@cuda//<component>:<target>` for component-scoped targets
- `@cuda//cuda:<target>` for curated aggregate targets and toolchain-facing helpers

Internally, the repository is layered:

1. versioned CUDA redist metadata is selected
2. concrete per-version, per-platform component repositories are generated
3. each component gets a platform-aware proxy repository
4. each registered CUDA version gets a stable per-version repository namespace
5. the global `@cuda` repository selects between registered versions through Bazel constraints

Consumers should depend on the stable proxy namespaces, not on concrete generated repositories.

## Philosophy

This repository defines backward compatibility at the Bazel target level, not at the NVIDIA archive-layout level.

That means:
- stable labels matter more than stable upstream file locations
- semantic continuity matters more than component ownership continuity
- vendor packaging churn should be absorbed here, not pushed onto downstream users

If NVIDIA moves a file, tool, header tree, or library from one component to another across CUDA releases, this repository should preserve the existing consumer-facing label when the meaning is still the same.

Typical compatibility work therefore happens by:
- remapping aggregate aliases
- changing which component provides a stable target
- adjusting per-component BUILD templates
- adding version-conditional logic inside templates

Examples already present in this repository:
- `libdevice` changes source component across CUDA generations, while `@cuda//cuda:libdevice` stays stable
- `nvptxcompiler` is surfaced through `nvcc` in older CUDA and through its own component in newer CUDA
- CCCL header layout changes in CUDA 13+, but the exported header targets stay conceptually stable

Downstream users should not need detailed knowledge of upstream redistribution churn just to depend on common CUDA functionality.

## Versions

Supported CUDA versions are pinned explicitly.

This repository supports registering multiple CUDA versions at once, then exposing one global `@cuda` namespace that resolves through version constraints.

Version handling principles:
- registered versions are explicit
- the highest registered version is the default when no CUDA version constraint is chosen
- version-aware branching belongs in this repository, close to the targets affected by the version difference
- broad version-family structure belongs in component/template selection
- fine-grained layout and target differences belong inside BUILD templates

Version-specific compatibility should prefer stable labels over version-specific label forks whenever semantics remain compatible.

## Components

This repository does not assume that every CUDA version exposes the same component set.

A component may:
- exist in one CUDA release and not another
- exist on one platform and not another
- move responsibilities to or from another component across releases
- keep the same name while changing its internal file layout

This is normal upstream behavior and this repository treats it as data, not as an error to hide.

### Optional Components

`@cuda//<component>` should be thought of as a stable namespace, not as a guarantee that every component is implemented for every registered CUDA version.

Important rule:
- a component not existing for a given CUDA version or platform is acceptable

When a component is absent upstream, this repository should not invent fake contents just to preserve a false sense of uniformity.

The compatibility contract is therefore:
- stable package naming where possible
- version- and platform-dependent availability
- explicit failure when a consumer asks for a target that the selected CUDA version genuinely does not provide

Absence is not automatically a bug.
It often reflects a real upstream difference between CUDA releases.

## Handling Files Moving Between Components

One of the main jobs of this repository is to handle files and capabilities that move between components across CUDA releases.

Rule:
- preserve the stable consumer-facing target when the capability is still the same

Only break or rename a public target when the semantics materially changed and keeping the old label would be misleading.

When files move between components:
- prefer remapping under the same public label
- keep the logic local to the affected template or aggregate alias
- avoid exposing NVIDIA’s internal reshuffling as a downstream migration burden
- document major semantic boundary changes in the repository, not in downstream build logic

In short:
- upstream component boundaries may drift
- this repository’s public surface should drift as little as possible

## Scope

Current scope is the CUDA redistribution model implemented by this repository.

The contract should describe what the code actually supports today, not aspirational future support.
Platform support, component support, and version support are all determined by the repository rules and registered metadata, and may legitimately differ across releases.

## Operational Map

Public surface:
- `@cuda//<component>:<target>`
- `@cuda//cuda:<target>`
- concrete generated repositories are internal; do not expose them in docs or examples

Key files:
- `extensions/cuda.bzl`: module extension entrypoint
- `cuda/cuda_redist_versions.json`: supported CUDA version pins
- `cudnn/cudnn_redist_versions.json`: supported cuDNN version pins
- `nvshmem/nvshmem_redist_versions.json`: supported NVSHMEM version pins
- `nccl/nccl_redist_versions.json`: generated NCCL archive metadata
- `nccl/update_redists.py`: NCCL catalog updater and archive verifier, run through `//tools/nccl:update_redists`
- `cuda/cuda_redist_build_defs.bzl`: CUDA component registry and template selection
- `cudnn/cudnn_redist_build_defs.bzl`: cuDNN component registry and template selection
- `nvshmem/nvshmem_redist_build_defs.bzl`: NVSHMEM component registry and template selection
- `nccl/nccl_redist_build_defs.bzl`: NCCL component registry and template selection
- `cuda/redist_proxy_targets.bzl`: stable public target catalog
- `cuda/build_defs/*.BUILD.bazel`: per-component generated repository templates
- `e2e/`: consumer-style validation module

## Change Rules

- Generated catalogs and cohesive follow-ups to an existing PR do not require a stack based on changed-line count alone.
- Maintenance-only Bazel tooling belongs under `//tools`. Use language-native rules, keep tool-only dependencies as Bzlmod dev dependencies, and do not load those rules from production packages.
- Preserve stable labels when upstream files move between components.
- Prefer remapping or aliasing over forcing downstream migrations.
- Do not invent fake components when upstream does not ship one.
- Keep broad version selection in registries; keep fine layout differences in BUILD templates.
- Add public targets through `redist_proxy_targets.bzl` plus matching templates.
- Public API changes require README/docs review.

## Verification

Fast check:
- `bazel build //...`

Consumer/e2e check:
- from `e2e/`: `bazel build //:all --platforms //:platform_linux_amd64_cuda_13_3_1`

CI matrix mirrors:
- `12_8_1`
- `12_9_1`
- `13_0_2`
- `13_1_1`
- `13_2_1`
- `13_3_1`

For compatibility-sensitive changes, run the relevant e2e platform for every affected CUDA major/minor.
