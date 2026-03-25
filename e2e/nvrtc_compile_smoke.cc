#include "smoke_test_common.h"

#include <nvrtc.h>

#include <cstddef>

int ExerciseNvrtcCompile() {
  static constexpr const char* kProgram = R"(
extern "C" __global__ void saxpy(const float* x, float* y, float alpha) {
  int i = blockIdx.x * blockDim.x + threadIdx.x;
  y[i] = alpha * x[i] + y[i];
}
)";
  const char* options[] = {"--gpu-architecture=sm_80"};

  nvrtcProgram program = nullptr;
  nvrtcResult status = nvrtcCreateProgram(&program, kProgram, "saxpy.cu", 0, nullptr, nullptr);
  if (status != NVRTC_SUCCESS) {
    return 1;
  }

  status = nvrtcCompileProgram(program, 1, options);
  if (status != NVRTC_SUCCESS) {
    nvrtcDestroyProgram(&program);
    return 1;
  }

  std::size_t ptx_size = 0;
  status = nvrtcGetPTXSize(program, &ptx_size);
  nvrtcDestroyProgram(&program);
  return status == NVRTC_SUCCESS && ptx_size > 0 ? 0 : 1;
}

int main(int argc, char**) {
  return ShouldRunSmokeExample(argc) ? ExerciseNvrtcCompile() : 0;
}
