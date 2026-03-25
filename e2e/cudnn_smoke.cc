#include <cudnn.h>

#include "smoke_test_common.h"

int ExerciseCudnnHandleLifecycle() {
  cudnnHandle_t handle = nullptr;
  cudnnTensorDescriptor_t tensor = nullptr;

  cudnnStatus_t status = cudnnCreate(&handle);
  if (status != CUDNN_STATUS_SUCCESS) {
    return 1;
  }

  status = cudnnCreateTensorDescriptor(&tensor);
  if (status != CUDNN_STATUS_SUCCESS) {
    cudnnDestroy(handle);
    return 1;
  }

  status = cudnnSetTensor4dDescriptor(tensor, CUDNN_TENSOR_NCHW, CUDNN_DATA_FLOAT, 1, 1, 4, 4);
  cudnnDestroyTensorDescriptor(tensor);
  cudnnDestroy(handle);
  return status == CUDNN_STATUS_SUCCESS ? 0 : 1;
}

int main(int argc, char**) {
  return ShouldRunSmokeExample(argc) ? ExerciseCudnnHandleLifecycle() : 0;
}
