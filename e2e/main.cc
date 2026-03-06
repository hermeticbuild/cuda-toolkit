#include <cublasLt.h>
#include <cublas_v2.h>
#include <cuda_runtime_api.h>
#include <cudnn.h>
#include <cufft.h>
#include <curand.h>

int main() {
  auto *sym_cudaGetDeviceCount = &cudaGetDeviceCount;
  auto *sym_cublasCreate = &cublasCreate;
  auto *sym_cublasLtCreate = &cublasLtCreate;
  auto *sym_cudnnCreate = &cudnnCreate;
  auto *sym_cufftPlan1d = &cufftPlan1d;
  auto *sym_curandCreateGenerator = &curandCreateGenerator;

  (void)sym_cudaGetDeviceCount;
  (void)sym_cublasCreate;
  (void)sym_cublasLtCreate;
  (void)sym_cudnnCreate;
  (void)sym_cufftPlan1d;
  (void)sym_curandCreateGenerator;
  return 0;
}
