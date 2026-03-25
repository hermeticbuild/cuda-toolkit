#include "smoke_test_common.h"

#include <curand.h>

int ExerciseCurandGenerate() {
  curandGenerator_t generator = nullptr;
  float* values = nullptr;

  curandStatus_t status = curandCreateGenerator(&generator, CURAND_RNG_PSEUDO_DEFAULT);
  if (status != CURAND_STATUS_SUCCESS) {
    return 1;
  }

  status = curandSetPseudoRandomGeneratorSeed(generator, 1234ULL);
  if (status != CURAND_STATUS_SUCCESS) {
    curandDestroyGenerator(generator);
    return 1;
  }

  status = curandGenerateUniform(generator, values, 16);
  curandDestroyGenerator(generator);
  return status == CURAND_STATUS_SUCCESS ? 0 : 1;
}

int main(int argc, char**) {
  return ShouldRunSmokeExample(argc) ? ExerciseCurandGenerate() : 0;
}
