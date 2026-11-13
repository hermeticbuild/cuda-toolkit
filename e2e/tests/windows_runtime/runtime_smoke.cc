#include <cuda_runtime_api.h>
#include <windows.h>

#include <cstdio>
#include <string>

int main() {
    int version = 0;
    const cudaError_t status = cudaRuntimeGetVersion(&version);
    // The version query can initialize CUDA. Hosted Windows runners have no
    // usable NVIDIA driver, so the runtime may return cudaErrorInsufficientDriver.
    if (status != cudaErrorInsufficientDriver && (status != cudaSuccess || version <= 0)) {
        std::fprintf(stderr, "cudaRuntimeGetVersion: status %d, version %d\n", status, version);
        return 1;
    }

#ifdef EXPECT_CUDART_DLL
    // cudart.lib can try the driver-provided runtime first. Load the exact
    // DLL staged beside the executable to verify redistribution packaging.
    wchar_t executable[MAX_PATH];
    const DWORD length = GetModuleFileNameW(nullptr, executable, MAX_PATH);
    if (length == 0 || length == MAX_PATH) {
        std::fprintf(stderr, "Could not locate the test executable\n");
        return 1;
    }
    std::wstring dll_path(executable, length);
    dll_path.resize(dll_path.find_last_of(L"\\/") + 1);
    dll_path += L"cudart64_13.dll";
    const HMODULE dll = LoadLibraryW(dll_path.c_str());
    if (dll == nullptr) {
        std::fprintf(stderr, "Could not load the staged cudart DLL: %lu\n", GetLastError());
        return 1;
    }
    FreeLibrary(dll);
#else
    if (GetModuleHandleW(L"cudart64_13.dll") != nullptr) {
        std::fprintf(stderr, "Static cudart unexpectedly loaded the cudart DLL\n");
        return 1;
    }
#endif
    return 0;
}
