#include "cuda_runtime.h"
#include "device_launch_parameters.h"

#ifdef __cplusplus
#define EXTERNC extern "C" __declspec(dllexport)
#else
#define EXTERNC
#endif

#define THREADS 192
#define SW 580
#define STHIRD 193.3333282F
#define SH 256

#include <math.h>
#include <stdint.h>
#include <iostream>

typedef struct Color8
{
    uint8_t r, g, b, a;
} Color8_t;

typedef enum Scope_input_frame_type_e
{
    uyvy,
    bgra,
    uyva,
    bgrx,
} Scope_input_frame_type_e;

EXTERNC float renderScopes(
    int srcWidth,
    int srcHeight,
    uint8_t *src,
    uint8_t *rgba,
    uint8_t *wf,
    uint8_t *wfRgb,
    uint8_t *wfParade,
    uint8_t *vScope,
    uint8_t *falseC,
    Scope_input_frame_type_e inputType);


