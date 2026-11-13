#include <cuda_runtime_api.h>
#include <windows.h>

#include <cstdio>

int main() {
    int version = 0;
    const cudaError_t status = cudaRuntimeGetVersion(&version);
    if (status != cudaSuccess || version != CUDART_VERSION) {
        std::fprintf(stderr, "cudaRuntimeGetVersion: status %d, version %d, expected %d\n",
                     status, version, CUDART_VERSION);
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
