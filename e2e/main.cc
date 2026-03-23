#include <nvJitLink.h>
#include <nvml.h>
#include <nvrtc.h>
#include <nvtx3/nvToolsExt.h>

#if defined(CUDA_SMOKE_HAVE_CUBLAS)
#include <cublasLt.h>
#include <cublas_v2.h>
#endif

#if defined(CUDA_SMOKE_HAVE_DRIVER_API)
#include <cuda.h>
#endif

#if defined(CUDA_SMOKE_HAVE_PROFILER_API)
#include <cuda_profiler_api.h>
#endif

#if defined(CUDA_SMOKE_HAVE_CUDART)
#include <cuda_runtime_api.h>
#endif

#if defined(CUDA_SMOKE_HAVE_CUFFT)
#include <cufft.h>
#endif

#if defined(CUDA_SMOKE_HAVE_CUPTI)
#include <cupti.h>
#endif

#if defined(CUDA_SMOKE_HAVE_CURAND)
#include <curand.h>
#endif

#if defined(CUDA_SMOKE_HAVE_CUSOLVER)
#include <cusolverDn.h>
#endif

#if defined(CUDA_SMOKE_HAVE_CUSPARSE)
#include <cusparse.h>
#endif

namespace {

template <typename T>
void Use(T value) {
  (void)value;
}

#if defined(CUDA_SMOKE_HAVE_CUDA_CRT)
__host__ __device__ int CudaCrtSmoke(int value) {
  return value;
}
#endif

}  // namespace

int main() {
#if defined(CUDA_SMOKE_HAVE_NVJITLINK)
  Use(&nvJitLinkVersion);
#endif

#if defined(CUDA_SMOKE_HAVE_NVML)
  Use(&nvmlInit_v2);
#endif

#if defined(CUDA_SMOKE_HAVE_NVRTC)
  Use(&nvrtcVersion);
#endif

  nvtxRangeId_t range_id = 0;
  Use(range_id);

#if defined(CUDA_SMOKE_HAVE_DRIVER_API)
  Use(&cuDriverGetVersion);
#endif

#if defined(CUDA_SMOKE_HAVE_CUDART)
  Use(&cudaGetDeviceCount);
#endif

#if defined(CUDA_SMOKE_HAVE_PROFILER_API)
  Use(&cudaProfilerStart);
  Use(&cudaProfilerStop);
#endif

#if defined(CUDA_SMOKE_HAVE_CUBLAS)
  Use(&cublasCreate);
  Use(&cublasLtCreate);
#endif

#if defined(CUDA_SMOKE_HAVE_CUFFT)
  Use(&cufftPlan1d);
#endif

#if defined(CUDA_SMOKE_HAVE_CUPTI)
  Use(&cuptiGetVersion);
#endif

#if defined(CUDA_SMOKE_HAVE_CURAND)
  Use(&curandCreateGenerator);
#endif

#if defined(CUDA_SMOKE_HAVE_CUSOLVER)
  Use(&cusolverDnCreate);
#endif

#if defined(CUDA_SMOKE_HAVE_CUSPARSE)
  Use(&cusparseCreate);
#endif

#if defined(CUDA_SMOKE_HAVE_CUDA_CRT)
  Use(&CudaCrtSmoke);
#endif

  return 0;
}
