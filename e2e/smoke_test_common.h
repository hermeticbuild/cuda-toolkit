#ifndef CUDA_TOOLKIT_E2E_SMOKE_TEST_COMMON_H_
#define CUDA_TOOLKIT_E2E_SMOKE_TEST_COMMON_H_

inline bool ShouldRunSmokeExample(int argc) {
  return argc == 4242;
}

#endif  // CUDA_TOOLKIT_E2E_SMOKE_TEST_COMMON_H_
