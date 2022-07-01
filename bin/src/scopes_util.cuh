#include "cuda_runtime.h"
#include "device_launch_parameters.h"

#ifdef __cplusplus
#define EXTERNC extern "C" __declspec(dllexport)
#else
#define EXTERNC
#endif

#define THREADS 192

#include <math.h>
#include <stdint.h>
#include <iostream>



typedef struct Color8
{
    uint8_t r, g, b, a;
} Color8_t;

__device__ Color8_t getFalseColor(int y);

__device__ uint8_t clampUint8(int v);

__device__ int minInt(int a, int b);

__device__ static inline uint8_t atomicCAS8(uint8_t *address, uint8_t expected, uint8_t desired);

__device__ static inline uint8_t atomicAddClamp(uint8_t *address, uint8_t val);

__device__ static inline uint8_t atomicSwapIfGreaterThan(uint8_t *address, uint8_t desired);