#include <cuda_runtime_api.h>
#include <windows.h>

#include <cstdio>

int main() {
    int version = 0;
    const cudaError_t status = cudaRuntimeGetVersion(&version);
    // The version query can initialize CUDA. Hosted Windows runners have no
    // usable NVIDIA driver, so the runtime may return cudaErrorInsufficientDriver.
    if (status != cudaErrorInsufficientDriver && (status != cudaSuccess || version <= 0)) {
        std::fprintf(stderr, "cudaRuntimeGetVersion: status %d, version %d\n", status, version);
        return 1;
    }

    const bool dll_loaded = GetModuleHandleW(L"cudart64_13.dll") != nullptr;
#ifdef EXPECT_CUDART_DLL
    if (!dll_loaded) {
        std::fprintf(stderr, "Expected the redistributed cudart DLL to load\n");
        return 1;
    }
#else
    if (dll_loaded) {
        std::fprintf(stderr, "Static cudart unexpectedly loaded the cudart DLL\n");
        return 1;
    }
#endif
    return 0;
}
