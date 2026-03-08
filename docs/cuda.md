<!-- Generated with Stardoc: http://skydoc.bazel.build -->

Unified CUDA module extension.

<a id="cuda"></a>

## cuda

<pre>
cuda = use_extension("@cuda_toolkit//extensions:cuda.bzl", "cuda")
cuda.configure(<a href="#cuda.configure-cuda_umd_version">cuda_umd_version</a>, <a href="#cuda.configure-cuda_version">cuda_version</a>, <a href="#cuda.configure-cudnn_version">cudnn_version</a>)
</pre>


**TAG CLASSES**

<a id="cuda.configure"></a>

### configure

**Attributes**

| Name  | Description | Type | Mandatory | Default |
| :------------- | :------------- | :------------- | :------------- | :------------- |
| <a id="cuda.configure-cuda_umd_version"></a>cuda_umd_version |  -   | String | optional |  `""`  |
| <a id="cuda.configure-cuda_version"></a>cuda_version |  -   | String | required |  |
| <a id="cuda.configure-cudnn_version"></a>cudnn_version |  -   | String | required |  |


