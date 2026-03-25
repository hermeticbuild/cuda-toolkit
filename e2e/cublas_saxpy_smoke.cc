#include "smoke_test_common.h"

#include <cublas_v2.h>

int ExerciseCublasSaxpy() {
  cublasHandle_t handle = nullptr;
  float alpha = 2.0f;
  float* x = nullptr;
  float* y = nullptr;

  cublasStatus_t status = cublasCreate(&handle);
  if (status != CUBLAS_STATUS_SUCCESS) {
    return 1;
  }

  status = cublasSaxpy(handle, 4, &alpha, x, 1, y, 1);
  cublasDestroy(handle);
  return status == CUBLAS_STATUS_SUCCESS ? 0 : 1;
}

int main(int argc, char**) {
  return ShouldRunSmokeExample(argc) ? ExerciseCublasSaxpy() : 0;
}
