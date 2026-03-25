#include "smoke_test_common.h"

#include <nvml.h>

int ExerciseNvmlQuery() {
  nvmlReturn_t status = nvmlInit_v2();
  if (status != NVML_SUCCESS) {
    return 1;
  }

  unsigned int device_count = 0;
  status = nvmlDeviceGetCount_v2(&device_count);
  nvmlShutdown();
  (void)device_count;
  return status == NVML_SUCCESS ? 0 : 1;
}

int main(int argc, char**) {
  return ShouldRunSmokeExample(argc) ? ExerciseNvmlQuery() : 0;
}
