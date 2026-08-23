<!-- Generated with Stardoc: http://skydoc.bazel.build -->

Unified CUDA module extension.

<a id="cuda"></a>

## cuda

<pre>
cuda = use_extension("@cuda_toolkit//extensions:cuda.bzl", "cuda")
cuda.configure(<a href="#cuda.configure-name">name</a>, <a href="#cuda.configure-default_package_metadata">default_package_metadata</a>)
cuda.redist(<a href="#cuda.redist-name">name</a>, <a href="#cuda.redist-cudnn_version">cudnn_version</a>, <a href="#cuda.redist-nccl_version">nccl_version</a>, <a href="#cuda.redist-nvshmem_version">nvshmem_version</a>, <a href="#cuda.redist-version">version</a>)
</pre>


**TAG CLASSES**

<a id="cuda.configure"></a>

### configure

Configures settings shared by all generated CUDA repositories.

**Attributes**

| Name  | Description | Type | Mandatory | Default |
| :------------- | :------------- | :------------- | :------------- | :------------- |
| <a id="cuda.configure-name"></a>name |  Name of the global compatibility repository.   | <a href="https://bazel.build/concepts/labels#target-names">Name</a> | optional |  `"cuda"`  |
| <a id="cuda.configure-default_package_metadata"></a>default_package_metadata |  Metadata targets applied by default to packages in every generated repository.   | <a href="https://bazel.build/concepts/labels">List of labels</a> | optional |  `[]`  |

<a id="cuda.redist"></a>

### redist

**Attributes**

| Name  | Description | Type | Mandatory | Default |
| :------------- | :------------- | :------------- | :------------- | :------------- |
| <a id="cuda.redist-name"></a>name |  -   | <a href="https://bazel.build/concepts/labels#target-names">Name</a> | required |  |
| <a id="cuda.redist-cudnn_version"></a>cudnn_version |  -   | String | optional |  `""`  |
| <a id="cuda.redist-nccl_version"></a>nccl_version |  -   | String | optional |  `""`  |
| <a id="cuda.redist-nvshmem_version"></a>nvshmem_version |  -   | String | optional |  `""`  |
| <a id="cuda.redist-version"></a>version |  -   | String | required |  |


