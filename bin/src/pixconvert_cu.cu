#include "cuda_runtime.h"
#include "device_launch_parameters.h"
#include <math.h>
#include <stdint.h>
#include <iostream>

//#include "pixconvert_cu.h"

#ifdef __cplusplus
#define EXTERNC extern "C" __declspec(dllexport)
#else
#define EXTERNC
#endif

#define THREADS 256

EXTERNC int add(int a, int b)
{
    return a + b;
}

__device__ uint8_t clampUint8(int v)
{
    if (v > 255)
        return 255;
    if (v < 0)
        return 0;
    return (uint8_t)v;
}

__device__ int minInt(int a, int b)
{
    if (a > b)
        return b;
    return a;
}

__global__ void kernelUyvyRGBA(uint8_t *d_src, uint8_t *d_dest, int pixcount)
{
    int pix = blockIdx.x * blockDim.x + threadIdx.x;

    if (pix >= pixcount)
        return;
    int i = pix * 2;

    int y, u, v;
    y = d_src[i + 1] - 16;

    if (pix % 2 == 0)
    {
        u = d_src[i];
        v = d_src[i + 2];
    }
    else
    {
        v = d_src[i];
        u = d_src[i - 2];
    }
    u -= 128;
    v -= 128;

    uint8_t r = clampUint8((int)roundf(1.164 * y + 1.596 * v));
    uint8_t g = clampUint8((int)roundf(1.164 * y - 0.392 * u - 0.813 * v));
    uint8_t b = clampUint8((int)roundf(1.164 * y + 2.017 * u));

    int offset = pix * 4;
    d_dest[offset] = r;
    d_dest[offset + 1] = g;
    d_dest[offset + 2] = b;
    d_dest[offset + 3] = 255;
}

EXTERNC void uyvyToRGBA(int width, int height, uint8_t *src, uint8_t *dest)
{
    uint8_t *d_src;
    uint8_t *d_dest;
    size_t srcSize = sizeof(uint8_t) * width * height * 2;
    size_t destSize = sizeof(uint8_t) * width * height * 4;
    int pixcount = width * height;

    cudaMalloc(&d_src, srcSize);
    cudaMemcpy(d_src, src, srcSize, cudaMemcpyHostToDevice);

    cudaMalloc(&d_dest, destSize);
    int blockCount = (int)ceil(pixcount / (double)THREADS);

    kernelUyvyRGBA<<<blockCount, THREADS>>>(d_src, d_dest, pixcount);
    cudaDeviceSynchronize();

    cudaMemcpy(dest, d_dest, destSize, cudaMemcpyDeviceToHost);

    cudaFree(d_src);
    cudaFree(d_dest);
}

__global__ void kernelUyvyYUV(uint8_t *d_src, uint8_t *d_dest, int pixcount)
{
    int pix = blockIdx.x * blockDim.x + threadIdx.x;

    if (pix >= pixcount)
        return;
    int i = pix * 2;

    uint8_t y, u, v;
    y = d_src[i + 1];

    if (pix % 2 == 0)
    {
        u = d_src[i];
        v = d_src[i + 2];
    }
    else
    {
        v = d_src[i];
        u = d_src[i - 2];
    }

    int o = pix * 4;
    d_dest[o] = y;
    d_dest[o + 1] = u;
    d_dest[o + 2] = v;
}

EXTERNC void uyvyToYUV(int width, int height, uint8_t *src, uint8_t *dest)
{
    uint8_t *d_src;
    uint8_t *d_dest;
    int pixcount = width * height;                    // pixels
    size_t srcSize = sizeof(uint8_t) * pixcount * 2;  // pixels * 2 Bytes UY/VY
    size_t destSize = sizeof(uint8_t) * pixcount * 3; // pixels * 3 Bytes YUV

    cudaMalloc(&d_src, srcSize);
    cudaMemcpy(d_src, src, srcSize, cudaMemcpyHostToDevice); // SRC CPU -> GPU
    cudaMalloc(&d_dest, destSize);

    int blockCount = (int)ceil(pixcount / (double)THREADS);

    kernelUyvyYUV<<<blockCount, THREADS>>>(d_src, d_dest, pixcount);
    cudaDeviceSynchronize();

    cudaMemcpy(dest, d_dest, destSize, cudaMemcpyDeviceToHost); // DEST GPU -> CPU

    cudaFree(d_src);
    cudaFree(d_dest);
}

__global__ void kernelFillRgba(uint8_t r, uint8_t g, uint8_t b, uint8_t a, uint8_t *d_dest, int pixcount)
{
    int pix = blockIdx.x * blockDim.x + threadIdx.x;
    if (pix >= pixcount)
        return;
    int pixb = pix * 4;
    d_dest[pixb] = r;
    d_dest[pixb + 1] = g;
    d_dest[pixb + 2] = b;
    d_dest[pixb + 3] = a;
}

__global__ void kernelRgbaToWaveform(int srcWidth, int srcHeight, int wfWidth, int wfHeight, int pixcount, uint8_t *d_src, uint8_t *d_dest)
{
    int pix = blockIdx.x * blockDim.x + threadIdx.x;
    if (pix >= pixcount)
        return;
    int pixb = pix * 4;
    float b = sqrtf(0.299 * powf(d_src[pixb], 2) + 0.587 * powf(d_src[pixb + 1], 2) + 0.114 * powf(d_src[pixb + 2], 2));

    int x = pix % srcWidth;
    int ox = (int)floor(wfWidth * (x / (double)srcWidth));
    int oy = (int)floor(wfHeight * (1 - (b / (double)255)));

    int destI = 4 * (oy * wfWidth + ox);
    if (destI >= 0 && destI < (wfWidth * wfHeight * 4) - 3)
    {
        d_dest[destI + 1] = clampUint8(d_dest[destI + 1] + 10);
        d_dest[destI + 3] = clampUint8(d_dest[destI + 3] + 1);
    }
}

EXTERNC void rgbaToWaveform(int srcWidth, int srcHeight, uint8_t *src, int wfWidth, int wfHeight, uint8_t *dest)
{
    int pixcount = srcWidth * srcHeight;
    int srcSize = 4 * pixcount;

    int wfpixcount = wfWidth * wfHeight;
    int destSize = 4 * wfpixcount;

    uint8_t *d_src;
    uint8_t *d_dest;

    cudaMalloc(&d_src, srcSize);
    cudaMalloc(&d_dest, destSize);

    cudaMemcpy(d_src, src, srcSize, cudaMemcpyHostToDevice);

    // int blockCount = (int)ceil(wfpixcount / (double)THREADS);
    // kernelFillRgba<<<blockCount, THREADS>>>(0, 0, 0, 128, d_dest, wfpixcount);
    // cudaDeviceSynchronize();

    int blockCount = (int)ceil(pixcount / (double)THREADS);
    kernelRgbaToWaveform<<<blockCount, THREADS>>>(srcWidth, srcHeight, wfWidth, wfHeight, pixcount, d_src, d_dest);
    cudaDeviceSynchronize();

    cudaMemcpy(dest, d_dest, destSize, cudaMemcpyDeviceToHost);

    cudaFree(d_src);
    cudaFree(d_dest);
}

/*
__device__ static inline uint8_t atomicAdd2(uint8_t* address, uint8_t val) {
    size_t long_address_modulo = (size_t) address & 3;
    auto* base_address = (unsigned int*) ((uint8_t*) address - long_address_modulo);
    unsigned int long_val = (unsigned int) val << (8 * long_address_modulo);
    unsigned int long_old = atomicAdd(base_address, long_val);

    if (long_address_modulo == 3) {
        // the first 8 bits of long_val represent the char value,
        // hence the first 8 bits of long_old represent its previous value.
        return (uint8_t) (long_old >> 24);
    } else {
        // bits that represent the char value within long_val
        unsigned int mask = 0x000000ff << (8 * long_address_modulo);
        unsigned int masked_old = long_old & mask;
        // isolate the bits that represent the char value within long_old, add the long_val to that,
        // then re-isolate by excluding bits that represent the char value
        unsigned int overflow = (masked_old + long_val) & ~mask;
        if (overflow) {
            atomicSub(base_address, overflow);
        }
        return (uint8_t) (masked_old >> 8 * long_address_modulo);
    }
}
*/
__global__ void kernelUyvyScopes(int srcWidth, int srcHeight, int scopeWidth, int scopeHeight, int pixcount, uint8_t *d_src, uint8_t *d_dest, uint8_t *d_wf, uint8_t *d_wfRgb, uint8_t *d_wfParade, uint8_t *d_vScope)
{
    int pix = blockIdx.x * blockDim.x + threadIdx.x;
    if (pix >= pixcount)
        return;
    int pixb = pix * 2;

    // get YUV
    uint8_t y, u, v;
    y = d_src[pixb + 1];
    if (pix % 2 == 0)
    {
        u = d_src[pixb];
        v = d_src[pixb + 2];
    }
    else
    {
        v = d_src[pixb];
        u = d_src[pixb - 2];
    }

    // from [https://web.archive.org/web/20180423091842/http://www.equasys.de/colorconversion.html]

    // calculate RGB
    int oY = y - 16;
    int oU = u - 128;
    int oV = v - 128;

    uint8_t r = clampUint8((int)round(1.164 * oY + 1.793 * oV));
    uint8_t g = clampUint8((int)round(1.164 * oY - 0.213 * oU - 0.533 * oV));
    uint8_t b = clampUint8((int)round(1.164 * oY + 2.112 * oU));

    // write RGB to d_dest
    int offset = pix * 4;
    d_dest[offset] = r;
    d_dest[offset + 1] = g;
    d_dest[offset + 2] = b;
    d_dest[offset + 3] = 255;

    // make wF
    int x = pix % srcWidth;
    int ox = minInt((int)round(scopeWidth * (x / (double)srcWidth)), scopeWidth - 1);
    int oy = minInt((int)round(scopeHeight * (1 - (y / (double)255))), scopeHeight - 1);

    int destI = 4 * (oy * scopeWidth + ox);
    if (destI >= 0 && destI < (scopeWidth * scopeHeight * 4) - 3)
    {

        d_wf[destI + 1] = clampUint8(d_wf[destI + 1] + 10);
        d_wf[destI + 3] = 255;
    }

    // make wFRGB
    int or = minInt((int)round(scopeHeight * (1 - (r / (double)255))), scopeHeight - 1);
    int og = minInt((int)round(scopeHeight * (1 - (g / (double)255))), scopeHeight - 1);
    int ob = minInt((int)round(scopeHeight * (1 - (b / (double)255))), scopeHeight - 1);

    int destR = 4 * (or *scopeWidth + ox);
    if (destR >= 0 && destR < (scopeWidth * scopeHeight * 4) - 4)
    {
        d_wfRgb[destR] = clampUint8(d_wfRgb[destR] + 10);
        d_wfRgb[destR + 3] = 255;
    }
    int destG = 4 * (og * scopeWidth + ox);
    if (destG >= 0 && destG < (scopeWidth * scopeHeight * 4) - 3)
    {
        d_wfRgb[destG + 1] = clampUint8(d_wfRgb[destG + 1] + 10);
        d_wfRgb[destG + 3] = 255;
    }
    int destB = 4 * (ob * scopeWidth + ox);
    if (destB >= 0 && destB < (scopeWidth * scopeHeight * 4) - 2)
    {
        d_wfRgb[destB + 2] = clampUint8(d_wfRgb[destB + 2] + 10);
        d_wfRgb[destB + 3] = 255;
    }

    double third = (scopeWidth / (double)3);
    ox = (int)round(third * (x / (double)srcWidth));

    destR = 4 * (or *scopeWidth + ox);
    destG = 4 * (og * scopeWidth + (ox + (int)floor(third)));
    destB = 4 * (ob * scopeWidth + (ox + 2 * (int)floor(third)));

    if (destR >= 0 && destR < (scopeWidth * scopeHeight * 4) - 4)
    {
        d_wfParade[destR] = clampUint8(d_wfParade[destR] + 10);

        d_wfParade[destR + 3] = 255;
    }

    if (destG >= 0 && destG < (scopeWidth * scopeHeight * 4) - 3)
    {
        d_wfParade[destG + 1] = clampUint8(d_wfParade[destG + 1] + 10);
        d_wfParade[destG + 3] = 255;
    }

    if (destB >= 0 && destB < (scopeWidth * scopeHeight * 4) - 2)
    {
        d_wfParade[destB + 2] = clampUint8(d_wfParade[destB + 2] + 10);
        d_wfParade[destB + 3] = 255;
    }
    ox = minInt((int)round(scopeHeight * (u / (double)255)), scopeHeight - 1);
    oy = minInt((int)round(scopeHeight * (1 - (v / (double)255))), scopeHeight - 1);
    destI = 4 * (oy * scopeHeight + ox);
    if (destI >= 0 && destI < (scopeHeight * scopeHeight * 4))
    {
        d_vScope[destI + 1] = clampUint8(d_vScope[destI + 1] + 10);
        d_vScope[destI + 3] = 255;
    }
}

EXTERNC void uyvyToScopes(int srcWidth, int srcHeight, uint8_t *src, uint8_t *dest, int scopeWidth, int scopeHeight, uint8_t *wf, uint8_t *wfRgb, uint8_t *wfParade, uint8_t *vScope)
{
    int pixcount = srcWidth * srcHeight;
    int srcSize = 2 * pixcount;
    int destSize = 4 * pixcount;
    int scopePixcount = scopeWidth * scopeHeight;
    int scopeSize = 4 * scopePixcount;
    int vscopeSize = 4 * scopeHeight * scopeHeight;

    uint8_t *d_src;
    uint8_t *d_dest;
    uint8_t *d_wf;
    uint8_t *d_wfRgb;
    uint8_t *d_wfParade;
    uint8_t *d_vScope;

    cudaMalloc(&d_src, srcSize);
    cudaMalloc(&d_dest, destSize);

    cudaMalloc(&d_wf, scopeSize);
    cudaMalloc(&d_wfRgb, scopeSize);
    cudaMalloc(&d_wfParade, scopeSize);
    cudaMalloc(&d_vScope, vscopeSize);

    cudaMemcpy(d_src, src, srcSize, cudaMemcpyHostToDevice);

    int blockCount = (int)ceil(pixcount / (double)THREADS);
    kernelUyvyScopes<<<blockCount, THREADS>>>(srcWidth, srcHeight, scopeWidth, scopeHeight, pixcount, d_src, d_dest, d_wf, d_wfRgb, d_wfParade, d_vScope);
    cudaDeviceSynchronize();

    cudaMemcpy(dest, d_dest, destSize, cudaMemcpyDeviceToHost);
    cudaMemcpy(wf, d_wf, scopeSize, cudaMemcpyDeviceToHost);
    cudaMemcpy(wfRgb, d_wfRgb, scopeSize, cudaMemcpyDeviceToHost);
    cudaMemcpy(wfParade, d_wfParade, scopeSize, cudaMemcpyDeviceToHost);
    cudaMemcpy(vScope, d_vScope, vscopeSize, cudaMemcpyDeviceToHost);

    cudaFree(d_src);
    cudaFree(d_dest);
    cudaFree(d_wf);
    cudaFree(d_wfRgb);
    cudaFree(d_wfParade);
    cudaFree(d_vScope);
}

EXTERNC void getDeviceProperties(int *major, int *minor)
{
    cudaDeviceProp deviceProp;
    cudaGetDeviceProperties(&deviceProp, 0);
    major[0] = deviceProp.major;
    minor[0] = deviceProp.minor;
}

__global__ void kernelBGRAScopes(int srcWidth, int srcHeight, int scopeWidth, int scopeHeight, int pixcount, uint8_t *d_src, uint8_t *d_dest, uint8_t *d_wf, uint8_t *d_wfRgb, uint8_t *d_wfParade, uint8_t *d_vScope)
{
    int pix = blockIdx.x * blockDim.x + threadIdx.x;
    if (pix >= pixcount)
        return;
    int pixb = pix * 4;

    uint8_t b, g, r, a;
    b = d_src[pixb];
    g = d_src[pixb + 1];
    r = d_src[pixb + 2];
    a = d_src[pixb + 3];

    float y, u, v;
    y = 16 + (r * 0.183 + g * 0.614 + b * 0.062);
    u = 128 + (r * -0.101 + g * -0.339 + b * 0.439);
    v = 128 + (r * 0.439 + g * -0.399 + b * -0.040);

    d_dest[pixb] = r;
    d_dest[pixb + 1] = g;
    d_dest[pixb + 2] = b;
    d_dest[pixb + 3] = a;

    int x = pix % srcWidth;
    int ox = minInt((int)round(scopeWidth * (x / (float)srcWidth)), scopeWidth - 1);
    int oy = minInt((int)roundf(scopeHeight * (1 - (y / (float)255))), scopeHeight - 1);

    int destI = 4*(oy*scopeWidth+ox);
    if(destI>=0 && destI<(scopeWidth*scopeHeight*4)-3) {
        d_wf[destI+1] = clampUint8(d_wf[destI+1]+10);
        d_wf[destI+3] = 255;
    }

    // make wFRGB
    int or = minInt((int)round(scopeHeight * (1 - (r / (float)255))), scopeHeight - 1);
    int og = minInt((int)round(scopeHeight * (1 - (g / (float)255))), scopeHeight - 1);
    int ob = minInt((int)round(scopeHeight * (1 - (b / (float)255))), scopeHeight - 1);

    int destR = 4 * (or *scopeWidth + ox);
    if (destR >= 0 && destR < (scopeWidth * scopeHeight * 4) - 4)
    {
        d_wfRgb[destR] = clampUint8(d_wfRgb[destR] + 10);
        d_wfRgb[destR + 3] = 255;
    }
    int destG = 4 * (og * scopeWidth + ox);
    if (destG >= 0 && destG < (scopeWidth * scopeHeight * 4) - 3)
    {
        d_wfRgb[destG + 1] = clampUint8(d_wfRgb[destG + 1] + 10);
        d_wfRgb[destG + 3] = 255;
    }
    int destB = 4 * (ob * scopeWidth + ox);
    if (destB >= 0 && destB < (scopeWidth * scopeHeight * 4) - 2)
    {
        d_wfRgb[destB + 2] = clampUint8(d_wfRgb[destB + 2] + 10);
        d_wfRgb[destB + 3] = 255;
    }

    double third = (scopeWidth / (float)3);
    ox = (int)round(third * (x / (float)srcWidth));

    destR = 4 * (or *scopeWidth + ox);
    destG = 4 * (og * scopeWidth + (ox + (int)floor(third)));
    destB = 4 * (ob * scopeWidth + (ox + 2 * (int)floor(third)));

    if (destR >= 0 && destR < (scopeWidth * scopeHeight * 4) - 4)
    {
        d_wfParade[destR] = clampUint8(d_wfParade[destR] + 10);

        d_wfParade[destR + 3] = 255;
    }

    if (destG >= 0 && destG < (scopeWidth * scopeHeight * 4) - 3)
    {
        d_wfParade[destG + 1] = clampUint8(d_wfParade[destG + 1] + 10);
        d_wfParade[destG + 3] = 255;
    }

    if (destB >= 0 && destB < (scopeWidth * scopeHeight * 4) - 2)
    {
        d_wfParade[destB + 2] = clampUint8(d_wfParade[destB + 2] + 10);
        d_wfParade[destB + 3] = 255;
    }
    ox = minInt((int)roundf(scopeHeight * (u / (float)255)), scopeHeight - 1);
    oy = minInt((int)roundf(scopeHeight * (1 - (v / (float)255))), scopeHeight - 1);
    destI = 4 * (oy * scopeHeight + ox);
    if (destI >= 0 && destI < (scopeHeight * scopeHeight * 4))
    {
        d_vScope[destI + 1] = clampUint8(d_vScope[destI + 1] + 10);
        d_vScope[destI + 3] = 255;
    }
}

EXTERNC void bgraToScopes(int srcWidth, int srcHeight, uint8_t *src, uint8_t *dest, int scopeWidth, int scopeHeight, uint8_t *wf, uint8_t *wfRgb, uint8_t *wfParade, uint8_t *vScope)
{
    int pixcount = srcWidth * srcHeight;
    int srcSize = 4 * pixcount;
    int scopePixcount = scopeWidth * scopeHeight;
    int scopeSize = 4 * scopePixcount;
    int vscopeSize = 4 * scopeHeight * scopeHeight;

    uint8_t *d_src;
    uint8_t *d_dest;
    uint8_t *d_wf;
    uint8_t *d_wfRgb;
    uint8_t *d_wfParade;
    uint8_t *d_vScope;

    cudaMalloc(&d_src, srcSize);
    cudaMalloc(&d_dest, srcSize);

    cudaMalloc(&d_wf, scopeSize);
    cudaMalloc(&d_wfRgb, scopeSize);
    cudaMalloc(&d_wfParade, scopeSize);
    cudaMalloc(&d_vScope, vscopeSize);

    cudaMemcpy(d_src, src, srcSize, cudaMemcpyHostToDevice);

    int blockCount = (int)ceil(pixcount / (double)THREADS);
    kernelBGRAScopes<<<blockCount, THREADS>>>(srcWidth, srcHeight, scopeWidth, scopeHeight, pixcount, d_src, d_dest, d_wf, d_wfRgb, d_wfParade, d_vScope);
    cudaDeviceSynchronize();

    cudaMemcpy(dest, d_dest, srcSize, cudaMemcpyDeviceToHost);
    cudaMemcpy(wf, d_wf, scopeSize, cudaMemcpyDeviceToHost);
    cudaMemcpy(wfRgb, d_wfRgb, scopeSize, cudaMemcpyDeviceToHost);
    cudaMemcpy(wfParade, d_wfParade, scopeSize, cudaMemcpyDeviceToHost);
    cudaMemcpy(vScope, d_vScope, vscopeSize, cudaMemcpyDeviceToHost);

    cudaFree(d_src);
    cudaFree(d_dest);
    cudaFree(d_wf);
    cudaFree(d_wfRgb);
    cudaFree(d_wfParade);
    cudaFree(d_vScope);
}
int main()
{
    int width = 1920;
    int height = 1080;
    uint8_t *pUYVY = (uint8_t *)calloc(width * height * 2, sizeof(uint8_t));
    memset(pUYVY, 200, width * height * 2);

    uint8_t *pRGBA = (uint8_t *)calloc(width * height * 4, sizeof(uint8_t));
    memset(pRGBA, 128, width * height * 4);

    int wfWidth = 580;
    int wfHeight = 256;
    uint8_t *pWF = (uint8_t *)calloc(wfHeight * wfWidth * 4, sizeof(uint8_t));
    uint8_t *pWFRgb = (uint8_t *)calloc(wfHeight * wfWidth * 4, sizeof(uint8_t));
    uint8_t *pWFParade = (uint8_t *)calloc(wfHeight * wfWidth * 4, sizeof(uint8_t));
    uint8_t *pvScope = (uint8_t *)calloc(wfHeight * wfHeight * 4, sizeof(uint8_t));
    uyvyToScopes(width, height, pUYVY, pRGBA, wfWidth, wfHeight, pWF, pWFRgb, pWFParade, pvScope);

    free(pUYVY);
    free(pRGBA);
    free(pWF);
    free(pWFRgb);
    free(pWFParade);
    free(pvScope);
}