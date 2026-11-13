#include <cuda_runtime_api.h>
#include <windows.h>

#include <cstdio>
#include <cstring>

int main() {
    // cudaRuntimeGetVersion may initialize CUDA and require an NVIDIA driver.
    const char* name = cudaGetErrorName(cudaErrorInvalidValue);
    if (name == nullptr || std::strcmp(name, "cudaErrorInvalidValue") != 0) {
        std::fprintf(stderr, "Unexpected CUDA error name: %s\n", name ? name : "(null)");
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
