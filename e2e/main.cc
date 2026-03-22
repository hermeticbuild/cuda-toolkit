#include <nvJitLink.h>
#include <nvml.h>
#include <nvrtc.h>
#include <nvtx3/nvToolsExt.h>

#if defined(CUDA_SMOKE_HAVE_CUDA_CRT)
#include <cublasLt.h>
#include <cublas_v2.h>
#include <cuda.h>
#include <cuda_profiler_api.h>
#include <cuda_runtime_api.h>
#include <cufft.h>
#include <cupti.h>
#include <curand.h>
#include <cusolverDn.h>
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

#if defined(CUDA_SMOKE_HAVE_CUDA_CRT)
  Use(&cuDriverGetVersion);
  Use(&cudaGetDeviceCount);
  Use(&cudaProfilerStart);
  Use(&cudaProfilerStop);
  Use(&cublasCreate);
  Use(&cublasLtCreate);
  Use(&cufftPlan1d);
  Use(&cuptiGetVersion);
  Use(&curandCreateGenerator);
  Use(&cusolverDnCreate);
  Use(&cusparseCreate);
  Use(&CudaCrtSmoke);
#endif

  return 0;
}
