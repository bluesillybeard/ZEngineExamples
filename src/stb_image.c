// Zig translate-c absolutely failes at translating stb_image.h into zig for the C import,
// SO as a workaround compile it as a separate object and link it later.
// This C file represents that separate object
#define STB_IMAGE_IMPLEMENTATION
#include "stb_image.h"
