#include "smoke_test_common.h"

#include <cudnn.h>

#include <cstddef>

int ExerciseCudnnConvolutionDescriptors() {
  cudnnHandle_t handle = nullptr;
  cudnnTensorDescriptor_t x = nullptr;
  cudnnTensorDescriptor_t y = nullptr;
  cudnnFilterDescriptor_t w = nullptr;
  cudnnConvolutionDescriptor_t conv = nullptr;
  int out_n = 0;
  int out_c = 0;
  int out_h = 0;
  int out_w = 0;
  std::size_t workspace_size = 0;

  cudnnStatus_t status = cudnnCreate(&handle);
  if (status != CUDNN_STATUS_SUCCESS) {
    return 1;
  }

  status = cudnnCreateTensorDescriptor(&x);
  if (status != CUDNN_STATUS_SUCCESS) {
    cudnnDestroy(handle);
    return 1;
  }

  status = cudnnCreateTensorDescriptor(&y);
  if (status != CUDNN_STATUS_SUCCESS) {
    cudnnDestroyTensorDescriptor(x);
    cudnnDestroy(handle);
    return 1;
  }

  status = cudnnCreateFilterDescriptor(&w);
  if (status != CUDNN_STATUS_SUCCESS) {
    cudnnDestroyTensorDescriptor(y);
    cudnnDestroyTensorDescriptor(x);
    cudnnDestroy(handle);
    return 1;
  }

  status = cudnnCreateConvolutionDescriptor(&conv);
  if (status != CUDNN_STATUS_SUCCESS) {
    cudnnDestroyFilterDescriptor(w);
    cudnnDestroyTensorDescriptor(y);
    cudnnDestroyTensorDescriptor(x);
    cudnnDestroy(handle);
    return 1;
  }

  status = cudnnSetTensor4dDescriptor(x, CUDNN_TENSOR_NCHW, CUDNN_DATA_FLOAT, 1, 1, 4, 4);
  if (status == CUDNN_STATUS_SUCCESS) {
    status = cudnnSetFilter4dDescriptor(w, CUDNN_DATA_FLOAT, CUDNN_TENSOR_NCHW, 1, 1, 3, 3);
  }
  if (status == CUDNN_STATUS_SUCCESS) {
    status = cudnnSetConvolution2dDescriptor(conv, 0, 0, 1, 1, 1, 1, CUDNN_CROSS_CORRELATION, CUDNN_DATA_FLOAT);
  }
  if (status == CUDNN_STATUS_SUCCESS) {
    status = cudnnGetConvolution2dForwardOutputDim(conv, x, w, &out_n, &out_c, &out_h, &out_w);
  }
  if (status == CUDNN_STATUS_SUCCESS) {
    status = cudnnSetTensor4dDescriptor(y, CUDNN_TENSOR_NCHW, CUDNN_DATA_FLOAT, out_n, out_c, out_h, out_w);
  }
  if (status == CUDNN_STATUS_SUCCESS) {
    status = cudnnGetConvolutionForwardWorkspaceSize(
        handle,
        x,
        w,
        conv,
        y,
        CUDNN_CONVOLUTION_FWD_ALGO_IMPLICIT_PRECOMP_GEMM,
        &workspace_size);
  }

  cudnnDestroyConvolutionDescriptor(conv);
  cudnnDestroyFilterDescriptor(w);
  cudnnDestroyTensorDescriptor(y);
  cudnnDestroyTensorDescriptor(x);
  cudnnDestroy(handle);
  (void)workspace_size;
  return status == CUDNN_STATUS_SUCCESS ? 0 : 1;
}

int main(int argc, char**) {
  return ShouldRunSmokeExample(argc) ? ExerciseCudnnConvolutionDescriptors() : 0;
}
