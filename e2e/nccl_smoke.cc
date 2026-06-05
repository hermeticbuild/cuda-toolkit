#include "smoke_test_common.h"

#include <nccl.h>

int main() {
  int version = 0;
  ncclResult_t status = ncclGetVersion(&version);
  return status == ncclSuccess && version > 0 ? 0 : 1;
}
