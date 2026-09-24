#include <nvjpeg.h>

int main() {
  int major = 0;
  return nvjpegGetProperty(MAJOR_VERSION, &major) == NVJPEG_STATUS_SUCCESS &&
                 major == NVJPEG_VER_MAJOR
             ? 0
             : 1;
}
