#include <cudnn.h>

namespace {

template <typename T>
void Use(T value) {
  (void)value;
}

}  // namespace

int main() {
  Use(&cudnnGetVersion);
  Use(&cudnnCreate);
  Use(&cudnnDestroy);
  return 0;
}
