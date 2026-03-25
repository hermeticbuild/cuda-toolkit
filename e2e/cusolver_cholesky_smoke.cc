#include "smoke_test_common.h"

#include <cusolverDn.h>

int ExerciseCusolverCholesky() {
  cusolverDnHandle_t handle = nullptr;
  float matrix[4] = {4.0f, 1.0f, 1.0f, 3.0f};
  float* workspace = nullptr;
  int info = 0;
  int workspace_size = 0;

  cusolverStatus_t status = cusolverDnCreate(&handle);
  if (status != CUSOLVER_STATUS_SUCCESS) {
    return 1;
  }

  status = cusolverDnSpotrf_bufferSize(
      handle,
      CUBLAS_FILL_MODE_LOWER,
      2,
      matrix,
      2,
      &workspace_size);
  if (status != CUSOLVER_STATUS_SUCCESS) {
    cusolverDnDestroy(handle);
    return 1;
  }

  status = cusolverDnSpotrf(
      handle,
      CUBLAS_FILL_MODE_LOWER,
      2,
      matrix,
      2,
      workspace,
      workspace_size,
      &info);
  cusolverDnDestroy(handle);
  return status == CUSOLVER_STATUS_SUCCESS ? 0 : 1;
}

int main(int argc, char**) {
  return ShouldRunSmokeExample(argc) ? ExerciseCusolverCholesky() : 0;
}
