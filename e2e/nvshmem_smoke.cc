#include <nvshmem_host.h>

namespace {

template <typename T>
void Use(T value) {
  (void)value;
}

}  // namespace

int main() {
  Use(&nvshmem_my_pe);
  Use(&nvshmem_n_pes);
  Use(&nvshmem_malloc);
  Use(&nvshmem_free);
  return 0;
}
