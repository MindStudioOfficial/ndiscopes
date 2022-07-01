#include <scopes_util.cuh>

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