#include "smoke_test_common.h"

#include <nvtx3/nvToolsExt.h>

int ExerciseNvtxRange() {
  nvtxRangePushA("cuda-toolkit-e2e");
  volatile int sum = 0;
  for (int i = 0; i < 4; ++i) {
    sum += i;
  }
  nvtxRangePop();
  return sum == 6 ? 0 : 1;
}

int main(int argc, char**) {
  return ShouldRunSmokeExample(argc) ? ExerciseNvtxRange() : 0;
}
