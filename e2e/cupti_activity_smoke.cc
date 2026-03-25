#include "smoke_test_common.h"

#include <cupti.h>

int ExerciseCuptiActivity() {
  CUptiResult status = cuptiActivityEnable(CUPTI_ACTIVITY_KIND_KERNEL);
  if (status != CUPTI_SUCCESS) {
    return 1;
  }

  status = cuptiActivityDisable(CUPTI_ACTIVITY_KIND_KERNEL);
  return status == CUPTI_SUCCESS ? 0 : 1;
}

int main(int argc, char**) {
  return ShouldRunSmokeExample(argc) ? ExerciseCuptiActivity() : 0;
}
