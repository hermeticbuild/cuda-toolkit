#include "smoke_test_common.h"

#include <nvJitLink.h>

#include <cstddef>
#include <cstring>

int ExerciseNvJitLink() {
  static constexpr const char* kPtx = R"(
.version 8.0
.target sm_80
.address_size 64

.visible .entry noop_kernel() {
  ret;
}
)";
  const char* options[] = {"-arch=sm_80"};

  nvJitLinkHandle handle = nullptr;
  nvJitLinkResult status = nvJitLinkCreate(&handle, 1, options);
  if (status != NVJITLINK_SUCCESS) {
    return 1;
  }

  status = nvJitLinkAddData(
      handle,
      NVJITLINK_INPUT_PTX,
      const_cast<char*>(kPtx),
      std::strlen(kPtx),
      "noop_kernel.ptx");
  if (status != NVJITLINK_SUCCESS) {
    nvJitLinkDestroy(&handle);
    return 1;
  }

  status = nvJitLinkComplete(handle);
  if (status != NVJITLINK_SUCCESS) {
    nvJitLinkDestroy(&handle);
    return 1;
  }

  std::size_t cubin_size = 0;
  status = nvJitLinkGetLinkedCubinSize(handle, &cubin_size);
  nvJitLinkDestroy(&handle);
  return status == NVJITLINK_SUCCESS && cubin_size > 0 ? 0 : 1;
}

int main(int argc, char**) {
  return ShouldRunSmokeExample(argc) ? ExerciseNvJitLink() : 0;
}
