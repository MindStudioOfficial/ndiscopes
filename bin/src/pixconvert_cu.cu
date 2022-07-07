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

#define THREADS 192

typedef struct Color8
{
    uint8_t r, g, b, a;
} Color8_t;

__device__ Color8_t falseColors[] = {
    {80, 39, 81, 255},    // -7 bis 2
    {9, 101, 150, 255},   // 2 bis 8
    {18, 133, 152, 255},  // 8 bis 15
    {66, 163, 169, 255},  // 15 bis 24
    {133, 133, 133, 255}, // 24 bis 43
    {98, 185, 70, 255},   // 43 bis 47
    {159, 159, 159, 255}, // 47 bis 54
    {236, 181, 188, 255}, // 54 bis 58
    {209, 209, 209, 255}, // 58 bis 77
    {240, 231, 140, 255}, // 77 bis 84
    {255, 255, 1, 255},   // 84 bis 93
    {255, 139, 0, 255},   // 93 bis 100
    {255, 0, 0, 255},     // 100 bis 109
};

__device__ Color8_t getFalseColor(int y)
{
    int16_t ireBright = round(y * ((double)100 / (double)219));
    uint8_t i = 0;
    if (ireBright >= 2)
        i = 1;
    if (ireBright >= 8)
        i = 2;
    if (ireBright >= 15)
        i = 3;
    if (ireBright >= 24)
        i = 4;
    if (ireBright >= 43)
        i = 5;
    if (ireBright >= 47)
        i = 6;
    if (ireBright >= 54)
        i = 7;
    if (ireBright >= 58)
        i = 8;
    if (ireBright >= 77)
        i = 9;
    if (ireBright >= 84)
        i = 10;
    if (ireBright >= 93)
        i = 11;
    if (ireBright >= 100)
        i = 12;

    return falseColors[i];
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

__device__ static inline uint8_t atomicCAS8(uint8_t *address, uint8_t expected, uint8_t desired)
{
    size_t long_address_modulo = (size_t)address & 3;
    auto *base_address = (unsigned int *)((uint8_t *)address - long_address_modulo);
    unsigned int selectors[] = {0x3214, 0x3240, 0x3410, 0x4210};

    unsigned int sel = selectors[long_address_modulo];
    unsigned int long_old, long_assumed, long_val, replacement;
    uint8_t old;

    long_val = (unsigned int)desired;
    long_old = *base_address;
    do
    {
        long_assumed = long_old;
        replacement = __byte_perm(long_old, long_val, sel);
        long_old = atomicCAS(base_address, long_assumed, replacement);
        old = (uint8_t)((long_old >> (long_address_modulo * 8)) & 0x000000ff);
    } while (expected == old && long_assumed != long_old);

    return old;
}

__device__ static inline uint8_t atomicAddClamp(uint8_t *address, uint8_t val)
{
    uint8_t old = *address; // get value at address
    uint8_t expected;
    do
    {
        // save previous value at address to check if it got changed in between atomics later
        expected = old;
        // update the old value with the actual value at that address before the addition
        // sets value at address to val + the expected value at address
        // fails if expected is no longer the value at that address because another thread has changed it
        old = atomicCAS8(address, expected, clampUint8((int)val + (int)expected));
        // if expected > old the addition has failed because another thread added something in between and we need to try again
    } while (expected > old);
    return old;
}

__device__ static inline uint8_t atomicSwapIfGreaterThan(uint8_t *address, uint8_t desired)
{
    uint8_t old = *address; // get the value at address
    uint8_t expected;
    do
    {
        expected = old;
        // abort if expected is already bigger
        if (expected >= desired)
            return;
        // swap if desired is greater than expected
        old = atomicCAS8(address, expected, desired);
        // if swap fails because another thread changed the value in the meantime repeat
    } while (expected != old);
}

__global__ void kernelUyvyScopes(int srcWidth, int srcHeight, int scopeWidth, int scopeHeight, int pixcount, uint8_t *d_src, uint8_t *d_dest, uint8_t *d_wf, uint8_t *d_wfRgb, uint8_t *d_wfParade, uint8_t *d_vScope, uint8_t *d_falseC, uint8_t bright)
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

    //* WF
    int x = pix % srcWidth;
    int ox = minInt((int)round(scopeWidth * (x / (double)srcWidth)), scopeWidth - 1);
    int oy = minInt((int)round(scopeHeight * (1 - ((y - 16) / (double)220))), scopeHeight - 1);

    int destI = 4 * (oy * scopeWidth + ox);
    if (destI >= 0 && destI < (scopeWidth * scopeHeight * 4) - 3)
    {

        atomicAddClamp(d_wf + destI + 1, bright);
        d_wf[destI + 3] = 255;
    }

    //* WFRGB
    int or = minInt((int)round(scopeHeight * (1 - (r / (double)255))), scopeHeight - 1);
    int og = minInt((int)round(scopeHeight * (1 - (g / (double)255))), scopeHeight - 1);
    int ob = minInt((int)round(scopeHeight * (1 - (b / (double)255))), scopeHeight - 1);

    int destR = 4 * (or *scopeWidth + ox);
    if (destR >= 0 && destR < (scopeWidth * scopeHeight * 4) - 4)
    {
        atomicAddClamp(d_wfRgb + destR, bright);
        d_wfRgb[destR + 3] = 255;
    }
    int destG = 4 * (og * scopeWidth + ox);
    if (destG >= 0 && destG < (scopeWidth * scopeHeight * 4) - 3)
    {
        atomicAddClamp(d_wfRgb + destG + 1, bright);
        d_wfRgb[destG + 3] = 255;
    }
    int destB = 4 * (ob * scopeWidth + ox);
    if (destB >= 0 && destB < (scopeWidth * scopeHeight * 4) - 2)
    {
        atomicAddClamp(d_wfRgb + destB + 2, bright);
        d_wfRgb[destB + 3] = 255;
    }

    //* WF PARADE
    double third = (scopeWidth / (double)3);
    ox = (int)round(third * (x / (double)srcWidth));

    destR = 4 * (or *scopeWidth + ox);
    destG = 4 * (og * scopeWidth + (ox + (int)floor(third)));
    destB = 4 * (ob * scopeWidth + (ox + 2 * (int)floor(third)));

    if (destR >= 0 && destR < (scopeWidth * scopeHeight * 4) - 4)
    {
        // d_wfParade[destR] = clampUint8(d_wfParade[destR] + 10);
        atomicAddClamp(d_wfParade + destR, bright);
        d_wfParade[destR + 3] = 255;
    }

    if (destG >= 0 && destG < (scopeWidth * scopeHeight * 4) - 3)
    {
        // d_wfParade[destG + 1] = clampUint8(d_wfParade[destG + 1] + 10);
        atomicAddClamp(d_wfParade + destG + 1, bright);
        d_wfParade[destG + 3] = 255;
    }

    if (destB >= 0 && destB < (scopeWidth * scopeHeight * 4) - 2)
    {
        // d_wfParade[destB + 2] = clampUint8(d_wfParade[destB + 2] + 10);
        atomicAddClamp(d_wfParade + destB + 2, bright);
        d_wfParade[destB + 3] = 255;
    }

    //* VSCOPE
    ox = minInt((int)round(scopeHeight * (u / (double)255)), scopeHeight - 1);
    oy = minInt((int)round(scopeHeight * (1 - (v / (double)255))), scopeHeight - 1);
    destI = 4 * (oy * scopeHeight + ox);
    if (destI >= 0 && destI < (scopeHeight * scopeHeight * 4))
    {
        // r g b is multiplied with current alpha value
        uint8_t a = d_vScope[destI + 3];

        atomicSwapIfGreaterThan(d_vScope + destI, (uint8_t)ceil(r * a / (double)255));
        atomicSwapIfGreaterThan(d_vScope + destI + 1, (uint8_t)ceil(g * a / (double)255));
        atomicSwapIfGreaterThan(d_vScope + destI + 2, (uint8_t)ceil(b * a / (double)255));

        atomicAddClamp(d_vScope + destI + 3, bright * 2);
    }
    // calculate false color value

    Color8_t fC = getFalseColor(oY);
    d_falseC[offset] = fC.r;
    d_falseC[offset + 1] = fC.g;
    d_falseC[offset + 2] = fC.b;
    d_falseC[offset + 3] = 255;
}

EXTERNC void uyvyToScopes(int srcWidth, int srcHeight, uint8_t *src, uint8_t *dest, int scopeWidth, int scopeHeight, uint8_t *wf, uint8_t *wfRgb, uint8_t *wfParade, uint8_t *vScope, uint8_t *falseC)
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
    uint8_t *d_falseC;

    uint8_t bright = 1 + 4 * (1080 / srcHeight) * (1080 / srcHeight);

    cudaMalloc(&d_src, srcSize);
    cudaMalloc(&d_dest, destSize);

    cudaMalloc(&d_wf, scopeSize);
    cudaMalloc(&d_wfRgb, scopeSize);
    cudaMalloc(&d_wfParade, scopeSize);
    cudaMalloc(&d_vScope, vscopeSize);
    cudaMalloc(&d_falseC, destSize);

    cudaMemcpy(d_src, src, srcSize, cudaMemcpyHostToDevice);

    int blockCount = (int)ceil(pixcount / (double)THREADS);
    kernelUyvyScopes<<<blockCount, THREADS>>>(srcWidth, srcHeight, scopeWidth, scopeHeight, pixcount, d_src, d_dest, d_wf, d_wfRgb, d_wfParade, d_vScope, d_falseC, bright);
    cudaDeviceSynchronize();

    cudaMemcpy(dest, d_dest, destSize, cudaMemcpyDeviceToHost);
    cudaMemcpy(wf, d_wf, scopeSize, cudaMemcpyDeviceToHost);
    cudaMemcpy(wfRgb, d_wfRgb, scopeSize, cudaMemcpyDeviceToHost);
    cudaMemcpy(wfParade, d_wfParade, scopeSize, cudaMemcpyDeviceToHost);
    cudaMemcpy(vScope, d_vScope, vscopeSize, cudaMemcpyDeviceToHost);
    cudaMemcpy(falseC, d_falseC, destSize, cudaMemcpyDeviceToHost);

    cudaFree(d_src);
    cudaFree(d_dest);
    cudaFree(d_wf);
    cudaFree(d_wfRgb);
    cudaFree(d_wfParade);
    cudaFree(d_vScope);
    cudaFree(d_falseC);
}

EXTERNC void getDeviceProperties(int *major, int *minor)
{
    cudaDeviceProp deviceProp;
    cudaGetDeviceProperties(&deviceProp, 0);
    major[0] = deviceProp.major;
    minor[0] = deviceProp.minor;
}

__global__ void kernelBGRAScopes(int srcWidth, int srcHeight, int scopeWidth, int scopeHeight, int pixcount, uint8_t *d_src, uint8_t *d_dest, uint8_t *d_wf, uint8_t *d_wfRgb, uint8_t *d_wfParade, uint8_t *d_vScope, uint8_t *d_falceC, uint8_t bright)
{
    // get 1D pixel index
    int pix = blockIdx.x * blockDim.x + threadIdx.x;
    if (pix >= pixcount)
        return;
    // get 1D byte index
    int pixb = pix * 4;

    // get r g b a values of this pixel
    uint8_t b, g, r, a;
    b = d_src[pixb];
    g = d_src[pixb + 1];
    r = d_src[pixb + 2];
    a = d_src[pixb + 3];

    // alpha is not premultiplied...
    r = (uint8_t)((double)r * a / (double)255);
    g = (uint8_t)((double)g * a / (double)255);
    b = (uint8_t)((double)b * a / (double)255);

    // calculate y u v values for this pixel
    float y, u, v;
    y = 16 + (r * 0.183 + g * 0.614 + b * 0.062);
    u = 128 + (r * -0.101 + g * -0.339 + b * 0.439);
    v = 128 + (r * 0.439 + g * -0.399 + b * -0.040);

    // copy pixel to image pixel
    d_dest[pixb] = r;
    d_dest[pixb + 1] = g;
    d_dest[pixb + 2] = b;
    d_dest[pixb + 3] = a;

    // get x position in source image
    int x = pix % srcWidth;
    // map x position to x position in destination scope
    int ox = minInt((int)round(scopeWidth * (x / (float)srcWidth)), scopeWidth - 1);
    // calculate y position from luminance (y)
    int oy = minInt((int)roundf(scopeHeight * (1 - ((y - 16) / (float)220))), scopeHeight - 1);

    int destI = 4 * (oy * scopeWidth + ox);
    if (destI >= 0 && destI < (scopeWidth * scopeHeight * 4) - 3)
    {
        // add brightness to the green byte of waveform
        atomicAddClamp(d_wf + destI + 1, (uint8_t)((double)bright * a / (double)255));
        // set alpha of that pixel to source alpha only IF present value is smaller
        atomicSwapIfGreaterThan(d_wf + destI + 3, a);
        // d_wf[destI + 3] = a;
    }

    // make wFRGB
    int or = minInt((int)round(scopeHeight * (1 - (r / (float)255))), scopeHeight - 1);
    int og = minInt((int)round(scopeHeight * (1 - (g / (float)255))), scopeHeight - 1);
    int ob = minInt((int)round(scopeHeight * (1 - (b / (float)255))), scopeHeight - 1);

    int destR = 4 * (or *scopeWidth + ox);
    if (destR >= 0 && destR < (scopeWidth * scopeHeight * 4) - 4)
    {
        // add brightness*alpha
        atomicAddClamp(d_wfRgb + destR, (uint8_t)((double)bright * a / (double)255));
        // set alpha of that pixel to source alpha only IF present value is smaller
        atomicSwapIfGreaterThan(d_wfRgb + destR + 3, a);
        // d_wfRgb[destR + 3] = a;
    }
    int destG = 4 * (og * scopeWidth + ox);
    if (destG >= 0 && destG < (scopeWidth * scopeHeight * 4) - 3)
    {
        atomicAddClamp(d_wfRgb + destG + 1, (uint8_t)((double)bright * a / (double)255));
        // set alpha of that pixel to source alpha only IF present value is smaller
        atomicSwapIfGreaterThan(d_wfRgb + destG + 3, a);
        // d_wfRgb[destG + 3] = a;
    }
    int destB = 4 * (ob * scopeWidth + ox);
    if (destB >= 0 && destB < (scopeWidth * scopeHeight * 4) - 2)
    {
        atomicAddClamp(d_wfRgb + destB + 2, (uint8_t)((double)bright * a / (double)255));
        // set alpha of that pixel to source alpha only IF present value is smaller
        atomicSwapIfGreaterThan(d_wfRgb + destB + 3, a);
        // d_wfRgb[destB + 3] = a;
    }

    double third = (scopeWidth / (float)3);
    ox = (int)round(third * (x / (float)srcWidth));

    destR = 4 * (or *scopeWidth + ox);
    destG = 4 * (og * scopeWidth + (ox + (int)floor(third)));
    destB = 4 * (ob * scopeWidth + (ox + 2 * (int)floor(third)));

    if (destR >= 0 && destR < (scopeWidth * scopeHeight * 4) - 4)
    {
        atomicAddClamp(d_wfParade + destR, (uint8_t)((double)bright * a / (double)255));
        // set alpha of that pixel to source alpha only IF present value is smaller
        atomicSwapIfGreaterThan(d_wfParade + destR + 3, a);
        // d_wfParade[destR + 3] = a;
    }

    if (destG >= 0 && destG < (scopeWidth * scopeHeight * 4) - 3)
    {
        atomicAddClamp(d_wfParade + destG + 1, (uint8_t)((double)bright * a / (double)255));
        // set alpha of that pixel to source alpha only IF present value is smaller
        atomicSwapIfGreaterThan(d_wfParade + destG + 3, a);
        // d_wfParade[destG + 3] = a;
    }

    if (destB >= 0 && destB < (scopeWidth * scopeHeight * 4) - 2)
    {
        atomicAddClamp(d_wfParade + destB + 2, (uint8_t)((double)bright * a / (double)255));
        // set alpha of that pixel to source alpha only IF present value is smaller
        atomicSwapIfGreaterThan(d_wfParade + destB + 3, a);
        // d_wfParade[destB + 3] = a;
    }
    ox = minInt((int)roundf(scopeHeight * (u / (float)255)), scopeHeight - 1);
    oy = minInt((int)roundf(scopeHeight * (1 - (v / (float)255))), scopeHeight - 1);
    destI = 4 * (oy * scopeHeight + ox);
    if (destI >= 0 && destI < (scopeHeight * scopeHeight * 4))
    {
        atomicAddClamp(d_vScope + destI + 3, (uint8_t)ceil(bright * 4 * a / (double)255));
        uint8_t ca = d_vScope[destI + 3];

        atomicSwapIfGreaterThan(d_vScope + destI, (uint8_t)ceil(r * a / (double)255 * ca / (double)255));
        atomicSwapIfGreaterThan(d_vScope + destI + 1, (uint8_t)ceil(g * a / (double)255 * ca / (double)255));
        atomicSwapIfGreaterThan(d_vScope + destI + 2, (uint8_t)ceil(b * a / (double)255 * ca / (double)255));
    }

    Color8_t fC = getFalseColor(y - 16);
    d_falceC[pixb] = (uint8_t)((double)fC.r * a / (double)255);
    d_falceC[pixb + 1] = (uint8_t)((double)fC.g * a / (double)255);
    d_falceC[pixb + 2] = (uint8_t)((double)fC.b * a / (double)255);
    d_falceC[pixb + 3] = a;
}

EXTERNC void bgraToScopes(int srcWidth, int srcHeight, uint8_t *src, uint8_t *dest, int scopeWidth, int scopeHeight, uint8_t *wf, uint8_t *wfRgb, uint8_t *wfParade, uint8_t *vScope, uint8_t *falseC)
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
    uint8_t *d_falseC;

    uint8_t bright = 1 + 4 * (1080 / srcHeight) * (1080 / srcHeight);

    cudaMalloc(&d_src, srcSize);
    cudaMalloc(&d_dest, srcSize);

    cudaMalloc(&d_wf, scopeSize);
    cudaMalloc(&d_wfRgb, scopeSize);
    cudaMalloc(&d_wfParade, scopeSize);
    cudaMalloc(&d_vScope, vscopeSize);
    cudaMalloc(&d_falseC, srcSize);

    cudaMemcpy(d_src, src, srcSize, cudaMemcpyHostToDevice);

    int blockCount = (int)ceil(pixcount / (double)THREADS);
    kernelBGRAScopes<<<blockCount, THREADS>>>(srcWidth, srcHeight, scopeWidth, scopeHeight, pixcount, d_src, d_dest, d_wf, d_wfRgb, d_wfParade, d_vScope, d_falseC, bright);
    cudaDeviceSynchronize();

    cudaMemcpy(dest, d_dest, srcSize, cudaMemcpyDeviceToHost);
    cudaMemcpy(wf, d_wf, scopeSize, cudaMemcpyDeviceToHost);
    cudaMemcpy(wfRgb, d_wfRgb, scopeSize, cudaMemcpyDeviceToHost);
    cudaMemcpy(wfParade, d_wfParade, scopeSize, cudaMemcpyDeviceToHost);
    cudaMemcpy(vScope, d_vScope, vscopeSize, cudaMemcpyDeviceToHost);
    cudaMemcpy(falseC, d_falseC, srcSize, cudaMemcpyDeviceToHost);

    cudaFree(d_src);
    cudaFree(d_dest);
    cudaFree(d_wf);
    cudaFree(d_wfRgb);
    cudaFree(d_wfParade);
    cudaFree(d_vScope);
    cudaFree(d_falseC);
}

__global__ void kernelRectMaskFrame(int fWidth, int fHeight, int mLeft, int mTop, int mWidth, int mHeight, uint8_t *d_frame, int stride, int format)
{
    int pixcount = fWidth * fHeight;
    int pix = blockIdx.x * blockDim.x + threadIdx.x;
    if (pix >= pixcount)
        return;
    int x = pix % fWidth;
    int y = (int)floor(pix / (double)fWidth);
    if (x < mLeft || x > (mLeft + mWidth) || y < mTop || y > (mTop + mHeight))
    {
        if (format == 2) // BGRA
        {
            for (int i = 0; i < stride; i++)
            {
                d_frame[pix * stride + i] = 0;
            }
        }
        else if (format == 1) // UYVY
        {
            d_frame[pix * stride + 0] = 128;
            d_frame[pix * stride + 1] = 0;
        }
    }
}

EXTERNC void rectMaskFrame(int fWidth, int fHeight, int mLeft, int mTop, int mWidth, int mHeight, uint8_t *frame, int format)
{
    int stride;
    switch (format)
    {
    case 1: // UYVY
        stride = 2;
        break;
    case 2: // BGRA
        stride = 4;
        break;
    default:
        stride = 0;
        break;
    }
    int pixcount = fWidth * fHeight;
    int fSize = pixcount * stride;
    uint8_t *d_frame;
    cudaMalloc(&d_frame, fSize);
    cudaMemcpy(d_frame, frame, fSize, cudaMemcpyHostToDevice);

    int blockCount = (int)ceil(pixcount / (double)THREADS);

    kernelRectMaskFrame<<<blockCount, THREADS>>>(fWidth, fHeight, mLeft, mTop, mWidth, mHeight, d_frame, stride, format);
    cudaDeviceSynchronize();
    cudaMemcpy(frame, d_frame, fSize, cudaMemcpyDeviceToHost);
    cudaFree(d_frame);
}

__global__ void kernelThumbnailFromUyvy(uint8_t *d_src, int srcWidth, int srcHeight, uint8_t *d_tn, int tnWidth, int tnHeight)
{
    // calculate amount of pixels of destination
    int pixcount = tnWidth * tnHeight;
    // calculate index of current pixel in destination
    int pix = blockIdx.x * blockDim.x + threadIdx.x;
    // end if we are out of bounds
    if (pix >= pixcount)
        return;
    // get values of corresponding src pixel
    int x = pix % tnWidth;
    int y = (int)floor(pix / (double)tnWidth);
    int srcX = minInt((int)round(srcWidth * (x / (double)tnWidth)), srcWidth - 1);
    int srcY = minInt((int)round(srcHeight * (y / (double)tnHeight)), srcHeight - 1);

    // get pixel and byte index in ssource image
    int srcPix = srcX + srcY * srcWidth;
    int srcByte = srcPix * 2;

    // get YUV values at corresponding pixel
    int Y, U, V;
    Y = d_src[srcByte + 1] - 16;
    if (srcPix % 2 == 0)
    {
        U = d_src[srcByte];
        V = d_src[srcByte + 2];
    }
    else
    {
        V = d_src[srcByte];
        U = d_src[srcByte - 2];
    }
    U -= 128;
    V -= 128;

    // calculate RGB values from HDTV Conversion Matrix
    uint8_t r = clampUint8((int)roundf(1.164 * Y + 1.596 * V));
    uint8_t g = clampUint8((int)roundf(1.164 * Y - 0.392 * U - 0.813 * V));
    uint8_t b = clampUint8((int)roundf(1.164 * Y + 2.017 * U));

    // write RGBA data to destination
    int destByte = pix * 4;
    d_tn[destByte] = r;
    d_tn[destByte + 1] = g;
    d_tn[destByte + 2] = b;
    d_tn[destByte + 3] = 255;
}

EXTERNC void thumbnailFromUyvy(uint8_t *src, int srcWidth, int srcHeight, uint8_t *tn, int tnWidth, int tnHeight)
{
    // calculate the amount of pixels in the destination
    int tnPixcount = tnWidth * tnHeight;
    // calculate number of bytes for destination
    // tn will be in RGBA format, 4 bytes per pixel
    int tnSize = tnPixcount * 4;
    // printf("%d\n",tnSize);
    //  calculate the amount of pixels in source image
    int srcPixcount = srcWidth * srcHeight;
    // calculate the number of bytes for source
    // src is in uyvy format, 2 bytes per pixel
    int srcSize = srcPixcount * 2;
    // printf("%d\n",srcSize);
    //  create memory on GPU
    uint8_t *d_src;
    cudaMalloc(&d_src, srcSize);
    uint8_t *d_tn;
    cudaMalloc(&d_tn, tnSize);
    // copy source to GPU

    cudaMemcpy(d_src, src, srcSize, cudaMemcpyHostToDevice);
    // calculate the amount of blocks needed for blocks * threads/block = tnPixcount
    int blockCount = (int)ceil(tnPixcount / (double)THREADS);
    // call kernel for each thumbnail pixel
    kernelThumbnailFromUyvy<<<blockCount, THREADS>>>(d_src, srcWidth, srcHeight, d_tn, tnWidth, tnHeight);
    // wait for all threads to finish
    cudaDeviceSynchronize();
    // copy back data from GPU
    cudaMemcpy(tn, d_tn, tnSize, cudaMemcpyDeviceToHost);
    // free GPU memory
    cudaFree(d_src);
    cudaFree(d_tn);
}

__global__ void kernelThumbnailFromBgra(uint8_t *d_src, int srcWidth, int srcHeight, uint8_t *d_tn, int tnWidth, int tnHeight)
{
    // calculate amount of pixels of destination
    int pixcount = tnWidth * tnHeight;
    // calculate index of current pixel in destination
    int pix = blockIdx.x * blockDim.x + threadIdx.x;
    // end if we are out of bounds
    if (pix >= pixcount)
        return;
    // get values of corresponding src pixel
    int x = pix % tnWidth;
    int y = (int)floor(pix / (double)tnWidth);
    int srcX = minInt((int)round(srcWidth * (x / (double)tnWidth)), srcWidth - 1);
    int srcY = minInt((int)round(srcHeight * (y / (double)tnHeight)), srcHeight - 1);

    // get pixel and byte index in source image
    int srcPix = srcX + srcY * srcWidth;
    int srcByte = srcPix * 4;

    // write RGBA data to destination
    int destByte = pix * 4;
    d_tn[destByte] = d_src[srcByte + 2];     // R
    d_tn[destByte + 1] = d_src[srcByte + 1]; // G
    d_tn[destByte + 2] = d_src[srcByte];     // B
    d_tn[destByte + 3] = d_src[srcByte + 3]; // A
}

EXTERNC void thumbnailFromBgra(uint8_t *src, int srcWidth, int srcHeight, uint8_t *tn, int tnWidth, int tnHeight)
{
    // calculate the amount of pixels in the destination
    int tnPixcount = tnWidth * tnHeight;
    // calculate number of bytes for destination
    // tn will be in RGBA format, 4 bytes per pixel
    int tnSize = tnPixcount * 4;
    // printf("%d\n",tnSize);
    //  calculate the amount of pixels in source image
    int srcPixcount = srcWidth * srcHeight;
    // calculate the number of bytes for source
    // src is in bgra format, 4 bytes per pixel
    int srcSize = srcPixcount * 4;
    // printf("%d\n",srcSize);
    //  create memory on GPU
    uint8_t *d_src;
    cudaMalloc(&d_src, srcSize);
    uint8_t *d_tn;
    cudaMalloc(&d_tn, tnSize);
    // copy source to GPU

    cudaMemcpy(d_src, src, srcSize, cudaMemcpyHostToDevice);
    // calculate the amount of blocks needed for blocks * threads/block = tnPixcount
    int blockCount = (int)ceil(tnPixcount / (double)THREADS);
    // call kernel for each thumbnail pixel
    kernelThumbnailFromBgra<<<blockCount, THREADS>>>(d_src, srcWidth, srcHeight, d_tn, tnWidth, tnHeight);
    // wait for all threads to finish
    cudaDeviceSynchronize();
    // copy back data from GPU
    cudaMemcpy(tn, d_tn, tnSize, cudaMemcpyDeviceToHost);
    // free GPU memory
    cudaFree(d_src);
    cudaFree(d_tn);
}

int main()
{
    int width = 3840;
    int height = 2160;
    uint8_t *pUYVY = (uint8_t *)calloc(width * height * 2, sizeof(uint8_t));
    memset(pUYVY, 200, width * height * 2);

    uint8_t *pRGBA = (uint8_t *)calloc(width * height * 4, sizeof(uint8_t));
    memset(pRGBA, 128, width * height * 4);

    uint8_t *pFColor = (uint8_t *)calloc(width * height * 4, sizeof(uint8_t));

    int wfWidth = 580;
    int wfHeight = 256;
    uint8_t *pWF = (uint8_t *)calloc(wfHeight * wfWidth * 4, sizeof(uint8_t));
    uint8_t *pWFRgb = (uint8_t *)calloc(wfHeight * wfWidth * 4, sizeof(uint8_t));
    uint8_t *pWFParade = (uint8_t *)calloc(wfHeight * wfWidth * 4, sizeof(uint8_t));
    uint8_t *pvScope = (uint8_t *)calloc(wfHeight * wfHeight * 4, sizeof(uint8_t));
    uyvyToScopes(width, height, pUYVY, pRGBA, wfWidth, wfHeight, pWF, pWFRgb, pWFParade, pvScope, pFColor);
    printf("Done %d", pRGBA[0]);

    free(pUYVY);
    free(pRGBA);
    free(pWF);
    free(pWFRgb);
    free(pWFParade);
    free(pvScope);
    free(pFColor);
}