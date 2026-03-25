#include "smoke_test_common.h"

#include <cusparse.h>

#include <cstdint>

int ExerciseCusparseSpmv() {
  cusparseHandle_t handle = nullptr;
  cusparseSpMatDescr_t matrix = nullptr;
  cusparseDnVecDescr_t x = nullptr;
  cusparseDnVecDescr_t y = nullptr;
  std::int32_t row_offsets[3] = {0, 2, 4};
  std::int32_t column_indices[4] = {0, 1, 0, 1};
  float matrix_values[4] = {1.0f, 2.0f, 3.0f, 4.0f};
  float x_values[2] = {1.0f, 1.0f};
  float y_values[2] = {0.0f, 0.0f};
  float alpha = 1.0f;
  float beta = 0.0f;
  std::size_t workspace_size = 0;

  cusparseStatus_t status = cusparseCreate(&handle);
  if (status != CUSPARSE_STATUS_SUCCESS) {
    return 1;
  }

  status = cusparseCreateCsr(
      &matrix,
      2,
      2,
      4,
      row_offsets,
      column_indices,
      matrix_values,
      CUSPARSE_INDEX_32I,
      CUSPARSE_INDEX_32I,
      CUSPARSE_INDEX_BASE_ZERO,
      CUDA_R_32F);
  if (status != CUSPARSE_STATUS_SUCCESS) {
    cusparseDestroy(handle);
    return 1;
  }

  status = cusparseCreateDnVec(&x, 2, x_values, CUDA_R_32F);
  if (status != CUSPARSE_STATUS_SUCCESS) {
    cusparseDestroySpMat(matrix);
    cusparseDestroy(handle);
    return 1;
  }

  status = cusparseCreateDnVec(&y, 2, y_values, CUDA_R_32F);
  if (status != CUSPARSE_STATUS_SUCCESS) {
    cusparseDestroyDnVec(x);
    cusparseDestroySpMat(matrix);
    cusparseDestroy(handle);
    return 1;
  }

  status = cusparseSpMV_bufferSize(
      handle,
      CUSPARSE_OPERATION_NON_TRANSPOSE,
      &alpha,
      matrix,
      x,
      &beta,
      y,
      CUDA_R_32F,
      CUSPARSE_SPMV_ALG_DEFAULT,
      &workspace_size);

  cusparseDestroyDnVec(y);
  cusparseDestroyDnVec(x);
  cusparseDestroySpMat(matrix);
  cusparseDestroy(handle);
  (void)workspace_size;
  return status == CUSPARSE_STATUS_SUCCESS ? 0 : 1;
}

int main(int argc, char**) {
  return ShouldRunSmokeExample(argc) ? ExerciseCusparseSpmv() : 0;
}
