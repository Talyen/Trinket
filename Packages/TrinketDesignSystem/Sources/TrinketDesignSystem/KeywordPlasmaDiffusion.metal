#include <metal_stdlib>
#include <SwiftUI/SwiftUI_Metal.h>
using namespace metal;

// MARK: - Viscous Liquid Plasma (High-Performance Half-Precision Fluid Shading)

[[ stitchable ]] half4 shaderLiquidPlasma(
    float2 position,
    half4 currentColor,
    float2 size,
    float time,
    half4 primaryColor,
    half4 secondaryColor,
    float2 focalCenter
) {
    // Half-precision coordinate calculation (maximizes ALU throughput on Apple GPUs)
    half2 uv = half2((position - focalCenter) / min(size.x, size.y));
    half dist = length(uv);

    // Fast trigonometric SIMD for 4 fluid charge center offsets
    half ht = half(time);
    half2 c1 = half2(fast::sin(ht * 0.30h) * 0.65h, fast::cos(ht * 0.36h) * 0.58h);
    half2 c2 = half2(fast::cos(ht * 0.25h + 1.5h) * 0.70h, fast::sin(ht * 0.32h + 1.0h) * 0.62h);
    half2 c3 = half2(fast::sin(ht * 0.34h + 3.2h) * 0.68h, fast::cos(ht * 0.28h + 2.4h) * 0.60h);
    half2 c4 = half2(fast::cos(ht * 0.26h + 4.8h) * 0.62h, fast::sin(ht * 0.35h + 4.0h) * 0.65h);

    // Squared distance evaluations using fast half2 dot products
    half2 d1 = uv - c1;
    half2 d2 = uv - c2;
    half2 d3 = uv - c3;
    half2 d4 = uv - c4;

    half f1 = 1.0h / (1.0h + dot(d1, d1) * 2.2h);
    half f2 = 1.0h / (1.0h + dot(d2, d2) * 2.2h);
    half f3 = 1.0h / (1.0h + dot(d3, d3) * 2.2h);
    half f4 = 1.0h / (1.0h + dot(d4, d4) * 2.2h);

    half field = (f1 + f2 + f3 + f4) * 0.25h;

    // Fast harmonic wave perturbation without expensive noise loops
    half wave = fast::sin(uv.x * 2.0h + ht * 0.12h) * fast::cos(uv.y * 2.0h - ht * 0.15h) * 0.10h;
    half fluid = fast::clamp(field + wave, 0.0h, 1.0h);

    // Smooth cubic Hermite interpolation
    half smoothFluid = fluid * fluid * (3.0h - 2.0h * fluid);

    // Soft global radial dispersion
    half radialFalloff = 1.0h / (1.0h + dist * dist * 1.4h);

    half4 color = mix(primaryColor, secondaryColor, fast::clamp(smoothFluid * 1.2h, 0.0h, 1.0h));

    // Screen-space micro-dither to eliminate 8-bit banding
    half noiseDither = half((fract(sin(dot(position, float2(12.9898, 78.233))) * 43758.5453) - 0.5) / 255.0);

    half alpha = fast::clamp(smoothFluid * radialFalloff * 0.18h + noiseDither, 0.0h, 0.22h);

    return half4(color.rgb * alpha, alpha);
}

inline half4 liquidPlasmaAura(
    float2 position,
    float2 size,
    float time,
    half4 primaryColor,
    half4 secondaryColor,
    float2 focalCenter,
    half phase
) {
    half2 uv = half2((position - focalCenter) / min(size.x, size.y));
    half dist = length(uv);
    half ht = half(time) + phase;

    half2 c1 = half2(fast::sin(ht * 0.30h) * 0.34h, fast::cos(ht * 0.36h) * 0.25h);
    half2 c2 = half2(fast::cos(ht * 0.25h + 1.5h) * 0.38h, fast::sin(ht * 0.32h + 1.0h) * 0.28h);
    half2 c3 = half2(fast::sin(ht * 0.34h + 3.2h) * 0.30h, fast::cos(ht * 0.28h + 2.4h) * 0.26h);

    half2 d1 = uv - c1;
    half2 d2 = uv - c2;
    half2 d3 = uv - c3;

    half field = (
        1.0h / (1.0h + dot(d1, d1) * 2.4h)
        + 1.0h / (1.0h + dot(d2, d2) * 2.4h)
        + 1.0h / (1.0h + dot(d3, d3) * 2.4h)
    ) / 3.0h;
    half wave = fast::sin(uv.x * 2.2h + ht * 0.12h) * fast::cos(uv.y * 2.0h - ht * 0.15h) * 0.08h;
    half fluid = fast::clamp(field + wave, 0.0h, 1.0h);
    half smoothFluid = fluid * fluid * (3.0h - 2.0h * fluid);
    half radialFalloff = 1.0h / (1.0h + dist * dist * 1.8h);
    half intensity = fast::clamp(smoothFluid * radialFalloff * 0.16h, 0.0h, 0.14h);
    half4 color = mix(primaryColor, secondaryColor, fast::clamp(smoothFluid * 1.2h, 0.0h, 1.0h));

    return half4(color.rgb * intensity, intensity);
}

[[ stitchable ]] half4 shaderDualLiquidPlasma(
    float2 position,
    half4 currentColor,
    float2 size,
    float time,
    float sourceCount,
    half4 firstPrimaryColor,
    half4 firstSecondaryColor,
    float2 firstFocalCenter,
    half4 secondPrimaryColor,
    half4 secondSecondaryColor,
    float2 secondFocalCenter
) {
    half4 first = liquidPlasmaAura(
        position,
        size,
        time,
        firstPrimaryColor,
        firstSecondaryColor,
        firstFocalCenter,
        0.0h
    );
    half4 second = sourceCount > 1.0f
        ? liquidPlasmaAura(
            position,
            size,
            time,
            secondPrimaryColor,
            secondSecondaryColor,
            secondFocalCenter,
            2.35h
        )
        : half4(0.0h);

    half rawAlpha = first.a + second.a;
    half dither = half((fract(sin(dot(position, float2(12.9898, 78.233))) * 43758.5453) - 0.5) / 255.0);
    half alpha = fast::clamp(rawAlpha + dither, 0.0h, 0.28h);
    half alphaScale = rawAlpha > 0.0h ? alpha / rawAlpha : 0.0h;

    return half4((first.rgb + second.rgb) * alphaScale, alpha);
}
