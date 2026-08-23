<!-- Generated with Stardoc: http://skydoc.bazel.build -->

Unified CUDA module extension.

<a id="cuda"></a>

## cuda

<pre>
cuda = use_extension("@cuda_toolkit//extensions:cuda.bzl", "cuda")
cuda.redist(<a href="#cuda.redist-name">name</a>, <a href="#cuda.redist-cudnn_version">cudnn_version</a>, <a href="#cuda.redist-nccl_version">nccl_version</a>, <a href="#cuda.redist-nvshmem_version">nvshmem_version</a>, <a href="#cuda.redist-version">version</a>)
</pre>


**TAG CLASSES**

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


