#include <nvshmem_host.h>

#include "smoke_test_common.h"

int ExerciseNvshmemHostAlloc() {
  int current_pe = nvshmem_my_pe();
  int pe_count = nvshmem_n_pes();
  void* allocation = nvshmem_malloc(256);
  nvshmem_free(allocation);
  return current_pe >= 0 && pe_count >= 0 ? 0 : 1;
}

int main(int argc, char**) {
  return ShouldRunSmokeExample(argc) ? ExerciseNvshmemHostAlloc() : 0;
}
