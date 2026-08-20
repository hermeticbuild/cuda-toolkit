#include <nccl.h>

#include "smoke_test_common.h"

int ExerciseNcclGetVersion() {
  int version = 0;
  ncclResult_t result = ncclGetVersion(&version);
  return result == ncclSuccess && version > 0 ? 0 : 1;
}

int main(int argc, char**) {
  return ShouldRunSmokeExample(argc) ? ExerciseNcclGetVersion() : 0;
}
