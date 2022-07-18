
#include <scopes.cuh>

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
    int16_t ireBright = rintf(y * ((float)100 / (float)219));
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

__device__ uint8_t alphaMultiplied(int val, uint8_t alpha)
{
    return (uint8_t)ceil(val * alpha / (double)255);
}

__host__ int getInputStride(Scope_input_frame_type_e inputType)
{
    switch (inputType)
    {
    case Scope_input_frame_type_e::bgra:
        return 4;
        break;

    case Scope_input_frame_type_e::uyvy:
        return 2;
        break;
    }
    return 0;
}

__global__ void kernelInputConversion(
    int srcWidth,
    int srcHeight,
    uint8_t *d_src,
    uint8_t *d_rgba,
    uint8_t *d_yuv,
    Scope_input_frame_type_e inputType)
{
    int pix = blockIdx.x * blockDim.x + threadIdx.x;
    if (pix >= srcWidth * srcHeight)
        return;

    int rgbaByte = pix * 4;
    int uyvyByte = pix * 2;
    int yuvPixByte = pix * 3;

    uint8_t r, g, b, a, y, u, v;

    if (inputType == Scope_input_frame_type_e::bgra)
    {
        // retreive r g b a
        b = d_src[rgbaByte];
        g = d_src[rgbaByte + 1];
        r = d_src[rgbaByte + 2];
        a = d_src[rgbaByte + 3];

        // premultiply alpha
        r = (uint8_t)(r * a / 255.0f);
        g = (uint8_t)(g * a / 255.0f);
        b = (uint8_t)(b * a / 255.0f);

        // calculate y u v
        y = clampUint8(16 + rint(r * 0.183 + g * 0.614 + b * 0.062));
        u = clampUint8(128 + rint(r * -0.101 + g * -0.339 + b * 0.439));
        v = clampUint8(128 + rint(r * 0.439 + g * -0.399 + b * -0.040));
    }
    if (inputType == Scope_input_frame_type_e::uyvy)
    {
        a = 255;
        // ret
        y = d_src[uyvyByte + 1];
        if (pix % 2 == 0)
        {
            u = d_src[uyvyByte];
            v = d_src[uyvyByte + 2];
        }
        else
        {
            v = d_src[uyvyByte];
            u = d_src[uyvyByte - 2];
        }

        int oY = y - 16;
        int oU = u - 128;
        int oV = v - 128;

        r = clampUint8((int)rint(1.164 * oY + 1.793 * oV));
        g = clampUint8((int)rint(1.164 * oY - 0.213 * oU - 0.533 * oV));
        b = clampUint8((int)rint(1.164 * oY + 2.112 * oU));
    }

    d_rgba[rgbaByte] = r;
    d_rgba[rgbaByte + 1] = g;
    d_rgba[rgbaByte + 2] = b;
    d_rgba[rgbaByte + 3] = a;

    d_yuv[yuvPixByte] = y;
    d_yuv[yuvPixByte + 1] = u;
    d_yuv[yuvPixByte + 2] = v;
}

__global__ void kernelScopes(
    int srcWidth,
    int srcHeight,
    uint8_t *d_rgba,
    uint8_t *d_yuv,
    uint8_t *d_wf,
    uint8_t *d_wfRgb,
    uint8_t *d_wfParade,
    uint8_t *d_vScope,
    uint8_t *d_falseC,
    uint8_t *d_yuvParade,
    //uint8_t *d_histogram,
    //int *d_histogram_data,
    uint8_t *d_blacklevel,
    int bright)
{

    int pix = blockIdx.x * blockDim.x + threadIdx.x;
    if (pix >= srcWidth * srcHeight)
        return;

    int pixByte = pix * 4;
    int yuvByte = pix * 3;

    int y = d_yuv[yuvByte] - 16;
    uint8_t u = d_yuv[yuvByte + 1];
    uint8_t v = d_yuv[yuvByte + 2];

    uint8_t r = d_rgba[pixByte];
    uint8_t g = d_rgba[pixByte + 1];
    uint8_t b = d_rgba[pixByte + 2];
    uint8_t a = d_rgba[pixByte + 3];

    // ========================
    // False Color
    // ========================

    if (d_falseC)
    {
        Color8_t fC = getFalseColor(y);
        d_falseC[pixByte] = (uint8_t)rintf(fC.r * a / 255.0f);
        d_falseC[pixByte + 1] = (uint8_t)rintf(fC.g * a / 255.0f);
        d_falseC[pixByte + 2] = (uint8_t)rintf(fC.b * a / 255.0f);
        d_falseC[pixByte + 3] = a;
    }

    // ========================
    // Luminance Scope
    // ========================

    // we can use that later
    int srcX = pix % srcWidth;
    int scopeX = minInt((int)rint(SW * (srcX / (double)srcWidth)), SW - 1);

    if (d_wf)
    {
        int scopeY = minInt((int)rint(SH * (1 - (y / 219.0))), SH - 1);
        int scopePix = (scopeX + scopeY * SW) * 4;
        if (scopePix >= 0 && scopePix < (SW * SH * 4) - 3)
        {
            // add brightness to the green byte of waveform
            atomicAddClamp(d_wf + scopePix + 1, (uint8_t)((float)bright * a / 255.0f));
            // set alpha of that pixel to source alpha only IF present value is smaller
            atomicSwapIfGreaterThan(d_wf + scopePix + 3, a);
        }
    }

    // ========================
    // RGB Scope
    // ========================

    int scopeRGBY[] = {
        minInt((int)rint(SH * (1 - (r / 255.0))), SH - 1),
        minInt((int)rint(SH * (1 - (g / 255.0))), SH - 1),
        minInt((int)rint(SH * (1 - (b / 255.0))), SH - 1)};

    if (d_wfRgb)
    {

        for (int i = 0; i < 3; i++)
        {
            int scopePix = (scopeX + scopeRGBY[i] * SW) * 4;
            if (scopePix >= 0 && scopePix < (SW * SH * 4) - 3)
            {
                // add brightness to the green byte of waveform
                atomicAddClamp(d_wfRgb + scopePix + i, (uint8_t)((float)bright * a / 255.0f));
                // set alpha of that pixel to source alpha only IF present value is smaller
                atomicSwapIfGreaterThan(d_wfRgb + scopePix + 3, a);
            }
        }
    }

    // ========================
    // RGB Parade Scope
    // ========================

    if (d_wfParade)
    {
        for (int i = 0; i < 3; i++)
        {
            int scopeXT = minInt((int)rint(STHIRD * (srcX / (double)srcWidth) + i * STHIRD), SW - 1);

            int scopePix = (scopeXT + scopeRGBY[i] * SW) * 4;

            if (scopePix >= 0 && scopePix < (SW * SH * 4) - 3)
            {
                // add brightness to the green byte of waveform
                atomicAddClamp(d_wfParade + scopePix + i, (uint8_t)((float)bright * a / 255.0f));
                // set alpha of that pixel to source alpha only IF present value is smaller
                atomicSwapIfGreaterThan(d_wfParade + scopePix + 3, a);
            }
        }
    }

    // ========================
    // Vector Scope
    // ========================

    if (d_vScope)
    {
        int scopeXU = minInt((int)rintf(SH * u / 255.0f), SH - 1);
        int scopeYV = minInt((int)rintf(SH * (1 - v / 255.0f)), SH - 1);
        int scopePixByte = (scopeYV * SH + scopeXU) * 4;
        if (scopePixByte >= 0 && scopePixByte < (SH * SH * 4) - 3)
        {
            atomicAddClamp(d_vScope + scopePixByte + 3, (uint8_t)ceil(bright * 4 * a / (double)255));
            uint8_t ca = d_vScope[scopePixByte + 3];

            atomicSwapIfGreaterThan(d_vScope + scopePixByte, (uint8_t)ceilf(r * a / 255.0f * ca / 255.0f));
            atomicSwapIfGreaterThan(d_vScope + scopePixByte + 1, (uint8_t)ceilf(g * a / 255.0f * ca / 255.0f));
            atomicSwapIfGreaterThan(d_vScope + scopePixByte + 2, (uint8_t)ceilf(b * a / 255.0f * ca / 255.0f));
        }
    }

    // ========================
    // YUV Parade
    // ========================

    if (d_yuvParade)
    {
        int scopeYUVY[] = {
            minInt((int)rintf(SH * (1 - ((y + 16) / 255.0f))), SH - 1),
            minInt((int)rintf(SH * (1 - (u / 255.0f))), SH - 1),
            minInt((int)rintf(SH * (1 - (v / 255.0f))), SH - 1)};

        for (int i = 0; i < 3; i++)
        {
            int scopeXT = minInt((int)rint(STHIRD * (srcX / (double)srcWidth) + i * STHIRD), SW - 1);

            int scopePix = (scopeXT + scopeYUVY[i] * SW) * 4;

            if (scopePix >= 0 && scopePix < (SW * SH * 4) - 3)
            {
                atomicAddClamp(d_yuvParade + scopePix + 3, alphaMultiplied(bright * 4, a));
                uint8_t currentAlpha = d_yuvParade[scopePix + 3];

                Color8_t c;

                switch (i)
                {
                case 0: // Y
                    c.r = 255;
                    c.g = 255;
                    c.b = 255;
                    break;
                case 1: // U
                    c.r = clampUint8((int)rintf(1.164f * (y - 16) + 1.793f * 0));
                    c.g = clampUint8((int)rintf(1.164f * (y - 16) - 0.213f * (u - 128) - 0.533 * 0));
                    c.b = clampUint8((int)rintf(1.164f * (y - 16) + 2.112f * (u - 128)));
                    break;
                case 2: // U
                    c.r = clampUint8((int)rintf(1.164f * (y - 16) + 1.793f * (v - 128)));
                    c.g = clampUint8((int)rintf(1.164f * (y - 16) - 0.213f * 0 - 0.533 * (v - 128)));
                    c.b = clampUint8((int)rintf(1.164f * (y - 16) + 2.112f * 0));
                    break;
                }

                atomicSwapIfGreaterThan(d_yuvParade + scopePix, (uint8_t)ceilf(c.r * a / 255.0f * currentAlpha / 255.0f));
                atomicSwapIfGreaterThan(d_yuvParade + scopePix + 1, (uint8_t)ceilf(c.g * a / 255.0f * currentAlpha / 255.0f));
                atomicSwapIfGreaterThan(d_yuvParade + scopePix + 2, (uint8_t)ceilf(c.b * a / 255.0f * currentAlpha / 255.0f));
            }
        }
    }

    // ========================
    // RGB Blacklevel Scope
    // ========================

    int scopeBlackRGBY[] = {
        minInt((int)rint(SH * (1 - (r / BLACKLEVEL))), SH - 1),
        minInt((int)rint(SH * (1 - (g / BLACKLEVEL))), SH - 1),
        minInt((int)rint(SH * (1 - (b / BLACKLEVEL))), SH - 1)};

    if (d_blacklevel)
    {

        for (int i = 0; i < 3; i++)
        {
            int yval = scopeBlackRGBY[i];
            if (yval >= SH || yval < 0)
                continue;
            for (int j = 0; j < 7; j++)
            {
                int scopePix = (scopeX + (yval + j) * SW) * 4;
                if (scopePix >= 0 && scopePix < (SW * SH * 4) - 3) // fill y
                {
                    // add brightness to the green byte of waveform
                    atomicAddClamp(d_blacklevel + scopePix + i, (uint8_t)((float)bright * a / 255.0f));
                    // set alpha of that pixel to source alpha only IF present value is smaller
                    atomicSwapIfGreaterThan(d_blacklevel + scopePix + 3, a);
                }
            }
        }
    }

}

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
    uint8_t *yuvParade,
    uint8_t *blacklevel,
    Scope_input_frame_type_e inputType)
{
    if (src == nullptr)
        return -1;

    if (inputType != Scope_input_frame_type_e::bgra && inputType != Scope_input_frame_type_e::uyvy)
        return -1;

    cudaEvent_t start, stop;
    cudaEventCreate(&start);
    cudaEventCreate(&stop);
    float millis = 0;

    uint8_t *d_src = nullptr,
            *d_rgba = nullptr,
            *d_yuv = nullptr,
            *d_wf = nullptr,
            *d_wfRgb = nullptr,
            *d_wfParade = nullptr,
            *d_yuvParade = nullptr,
            *d_blacklevel = nullptr,
            *d_vScope = nullptr,
            *d_falseC = nullptr;

    uint8_t bright = 1 + 4 * (1080 / srcHeight) * (1080 / srcHeight);

    // claculate necessary sizes
    int srcPixels = srcWidth * srcHeight;
    int inputStride = getInputStride(inputType);
    size_t srcSize = inputStride * srcPixels;
    size_t rgbaSize = 4 * srcPixels;
    size_t yuvSize = 3 * srcPixels;

    // allocate based on sizes
    cudaMalloc(&d_src, srcSize);
    cudaMalloc(&d_rgba, rgbaSize);
    cudaMalloc(&d_yuv, yuvSize);

    cudaMemcpy(d_src, src, srcSize, cudaMemcpyHostToDevice);

    // launch config for whole source image
    int blockWidth = THREADS;
    dim3 blockSize = dim3(blockWidth);
    dim3 gridSize = dim3((int)ceilf(srcPixels / (float)blockWidth));

    cudaEventRecord(start);

    kernelInputConversion<<<gridSize, blockSize>>>(srcWidth, srcHeight, d_src, d_rgba, d_yuv, inputType);

    // copy rgba output image from GPU to CPU
    cudaMemcpy(rgba, d_rgba, rgbaSize, cudaMemcpyDeviceToHost);
    cudaFree(d_src);
    // allocate only if required
    if (wf)
        cudaMalloc(&d_wf, SW * SH * 4);

    if (wfRgb)
        cudaMalloc(&d_wfRgb, SW * SH * 4);

    if (wfParade)
        cudaMalloc(&d_wfParade, SW * SH * 4);

    if (vScope)
        cudaMalloc(&d_vScope, SH * SH * 4);

    if (yuvParade)
        cudaMalloc(&d_yuvParade, SW * SH * 4);

    if (blacklevel)
        cudaMalloc(&d_blacklevel, SW * SH * 4);

    if (falseC)
        cudaMalloc(&d_falseC, rgbaSize);

    kernelScopes<<<gridSize, blockSize>>>(
        srcWidth,
        srcHeight,
        d_rgba,
        d_yuv,
        d_wf,
        d_wfRgb,
        d_wfParade,
        d_vScope,
        d_falseC,
        d_yuvParade,
        d_blacklevel,
        bright);

    cudaEventRecord(stop);
    cudaEventSynchronize(stop);
    cudaEventElapsedTime(&millis, start, stop);

    cudaFree(d_rgba);
    cudaFree(d_yuv);
    // copy if required
    if (wf)
    {
        cudaMemcpy(wf, d_wf, SW * SH * 4, cudaMemcpyDeviceToHost);
        cudaFree(d_wf);
    }
    if (wfRgb)
    {
        cudaMemcpy(wfRgb, d_wfRgb, SW * SH * 4, cudaMemcpyDeviceToHost);
        cudaFree(d_wfRgb);
    }
    if (wfParade)
    {
        cudaMemcpy(wfParade, d_wfParade, SW * SH * 4, cudaMemcpyDeviceToHost);
        cudaFree(d_wfParade);
    }
    if (yuvParade)
    {
        cudaMemcpy(yuvParade, d_yuvParade, SW * SH * 4, cudaMemcpyDeviceToHost);
        cudaFree(d_yuvParade);
    }
    if (blacklevel)
    {
        cudaMemcpy(blacklevel, d_blacklevel, SW * SH * 4, cudaMemcpyDeviceToHost);
        cudaFree(d_blacklevel);
    }
    if (vScope)
    {
        cudaMemcpy(vScope, d_vScope, SH * SH * 4, cudaMemcpyDeviceToHost);
        cudaFree(d_vScope);
    }
    if (falseC)
    {
        cudaMemcpy(falseC, d_falseC, rgbaSize, cudaMemcpyDeviceToHost);
        cudaFree(d_falseC);
    }

    return millis;
}

EXTERNC void getDeviceProperties(int *major, int *minor)
{
    cudaDeviceProp deviceProp;
    cudaGetDeviceProperties(&deviceProp, 0);
    major[0] = deviceProp.major;
    minor[0] = deviceProp.minor;
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
