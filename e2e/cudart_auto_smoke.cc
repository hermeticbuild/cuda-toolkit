#include <cuda_runtime_api.h>

int main() {
    int version = 0;
    return cudaRuntimeGetVersion(&version);
}
