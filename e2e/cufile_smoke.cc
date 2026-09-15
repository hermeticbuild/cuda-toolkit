#include <cufile.h>

#include "smoke_test_common.h"

int ExerciseCuFileGetVersion() {
  int version = 0;
  CUfileError_t status = cuFileGetVersion(&version);
  return status.err == CU_FILE_SUCCESS && version > 0 ? 0 : 1;
}

int main(int argc, char**) {
  return ShouldRunSmokeExample(argc) ? ExerciseCuFileGetVersion() : 0;
}
