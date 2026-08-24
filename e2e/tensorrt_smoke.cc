#include <NvInfer.h>

#include "smoke_test_common.h"

int ExerciseTensorRtGetInferLibVersion() {
  return getInferLibVersion() > 0 ? 0 : 1;
}

int main(int argc, char**) {
  return ShouldRunSmokeExample(argc) ? ExerciseTensorRtGetInferLibVersion() : 0;
}
