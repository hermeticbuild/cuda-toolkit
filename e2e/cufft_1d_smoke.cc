#include "smoke_test_common.h"

#include <cufft.h>

int ExerciseCufft1d() {
  cufftHandle plan = 0;
  cufftComplex* data = nullptr;

  cufftResult status = cufftPlan1d(&plan, 8, CUFFT_C2C, 1);
  if (status != CUFFT_SUCCESS) {
    return 1;
  }

  status = cufftExecC2C(plan, data, data, CUFFT_FORWARD);
  cufftDestroy(plan);
  return status == CUFFT_SUCCESS ? 0 : 1;
}

int main(int argc, char**) {
  return ShouldRunSmokeExample(argc) ? ExerciseCufft1d() : 0;
}
