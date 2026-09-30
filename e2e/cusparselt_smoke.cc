#include <cusparseLt.h>

#include "smoke_test_common.h"

int ExerciseCusparseLtGetVersion() {
  cusparseLtHandle_t handle;
  if (cusparseLtInit(&handle) != CUSPARSE_STATUS_SUCCESS) {
    return 1;
  }
  int version = 0;
  cusparseStatus_t status = cusparseLtGetVersion(&handle, &version);
  cusparseLtDestroy(&handle);
  return status == CUSPARSE_STATUS_SUCCESS && version > 0 ? 0 : 1;
}

int main(int argc, char**) {
  return ShouldRunSmokeExample(argc) ? ExerciseCusparseLtGetVersion() : 0;
}
