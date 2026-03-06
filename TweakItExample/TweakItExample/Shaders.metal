//
//  Shaders.metal
//  TweakItDemo
//
//  Stitchable Metal shaders for SwiftUI .colorEffect().
//  Signature: half4 name(float2 position, half4 color, float2 size, ...params...)
//

#include <metal_stdlib>
using namespace metal;

// MARK: - Hash Functions

float hash21(float2 p) {
    p = fract(p * float2(123.34, 456.21));
    p += dot(p, p + 45.32);
    return fract(p.x * p.y);
}

float2 hash22(float2 p) {
    float3 a = fract(float3(p.xyx) * float3(0.1031, 0.1030, 0.0973));
    a += dot(a, a.yzx + 33.33);
    return fract((a.xx + a.yz) * a.zy);
}

// MARK: - Noise Functions

float valueNoise(float2 p) {
    float2 i = floor(p);
    float2 f = fract(p);
    f = f * f * (3.0 - 2.0 * f); // smoothstep

    float a = hash21(i);
    float b = hash21(i + float2(1.0, 0.0));
    float c = hash21(i + float2(0.0, 1.0));
    float d = hash21(i + float2(1.0, 1.0));

    return mix(mix(a, b, f.x), mix(c, d, f.x), f.y);
}

float fbm(float2 p, int octaves) {
    float value = 0.0;
    float amplitude = 0.5;
    float frequency = 1.0;

    for (int i = 0; i < octaves; i++) {
        value += amplitude * valueNoise(p * frequency);
        frequency *= 2.0;
        amplitude *= 0.5;
    }
    return value;
}

// MARK: - Cosine Palette

float3 cosPalette(float t, float3 a, float3 b, float3 c, float3 d) {
    return a + b * cos(6.28318 * (c * t + d));
}

// MARK: - Plasma Palettes

float3 plasmaPalette(float t, int paletteIndex) {
    // 0: lava, 1: ocean, 2: neon, 3: pastel, 4: mono
    if (paletteIndex == 0) {
        return cosPalette(t, float3(0.5, 0.2, 0.1), float3(0.5, 0.3, 0.2),
                          float3(1.0, 0.7, 0.4), float3(0.0, 0.15, 0.2));
    } else if (paletteIndex == 1) {
        return cosPalette(t, float3(0.1, 0.3, 0.5), float3(0.2, 0.3, 0.4),
                          float3(0.8, 1.0, 1.0), float3(0.0, 0.25, 0.5));
    } else if (paletteIndex == 2) {
        return cosPalette(t, float3(0.5, 0.5, 0.5), float3(0.5, 0.5, 0.5),
                          float3(1.0, 1.0, 1.0), float3(0.0, 0.33, 0.67));
    } else if (paletteIndex == 3) {
        return cosPalette(t, float3(0.7, 0.6, 0.7), float3(0.2, 0.2, 0.2),
                          float3(1.0, 1.0, 0.5), float3(0.0, 0.1, 0.2));
    } else {
        return cosPalette(t, float3(0.5, 0.5, 0.5), float3(0.5, 0.5, 0.5),
                          float3(1.0, 1.0, 1.0), float3(0.0, 0.0, 0.0));
    }
}

// MARK: - Aurora Palettes

float3 auroraPalette(float t, int paletteIndex) {
    // 0: arctic, 1: solar, 2: cosmic, 3: fire
    if (paletteIndex == 0) {
        return cosPalette(t, float3(0.1, 0.4, 0.3), float3(0.3, 0.4, 0.3),
                          float3(0.8, 1.0, 0.8), float3(0.0, 0.2, 0.3));
    } else if (paletteIndex == 1) {
        return cosPalette(t, float3(0.5, 0.3, 0.1), float3(0.5, 0.4, 0.2),
                          float3(1.0, 0.8, 0.5), float3(0.0, 0.1, 0.2));
    } else if (paletteIndex == 2) {
        return cosPalette(t, float3(0.3, 0.1, 0.4), float3(0.4, 0.3, 0.4),
                          float3(1.0, 0.8, 1.0), float3(0.2, 0.0, 0.3));
    } else {
        return cosPalette(t, float3(0.5, 0.1, 0.0), float3(0.5, 0.3, 0.2),
                          float3(1.0, 0.5, 0.3), float3(0.0, 0.1, 0.15));
    }
}

// MARK: - Marble Palettes

float3 marblePalette(float t, int paletteIndex) {
    // 0: marble, 1: ink, 2: oil, 3: candy
    if (paletteIndex == 0) {
        return cosPalette(t, float3(0.8, 0.8, 0.75), float3(0.15, 0.15, 0.15),
                          float3(1.0, 1.0, 1.0), float3(0.0, 0.05, 0.1));
    } else if (paletteIndex == 1) {
        return cosPalette(t, float3(0.1, 0.1, 0.25), float3(0.3, 0.3, 0.4),
                          float3(1.0, 1.0, 0.8), float3(0.0, 0.1, 0.2));
    } else if (paletteIndex == 2) {
        return cosPalette(t, float3(0.5, 0.5, 0.5), float3(0.5, 0.5, 0.5),
                          float3(1.0, 1.0, 1.0), float3(0.0, 0.1, 0.2));
    } else {
        return cosPalette(t, float3(0.7, 0.5, 0.6), float3(0.3, 0.3, 0.3),
                          float3(1.0, 0.8, 1.0), float3(0.0, 0.15, 0.3));
    }
}

// MARK: - Voronoi Palettes

float3 voronoiPalette(float t, int paletteIndex) {
    // 0: crystal, 1: neon, 2: earth, 3: mono
    if (paletteIndex == 0) {
        return cosPalette(t, float3(0.5, 0.6, 0.7), float3(0.2, 0.3, 0.3),
                          float3(0.8, 1.0, 1.0), float3(0.0, 0.1, 0.2));
    } else if (paletteIndex == 1) {
        return cosPalette(t, float3(0.5, 0.5, 0.5), float3(0.5, 0.5, 0.5),
                          float3(1.0, 1.0, 0.5), float3(0.8, 0.9, 0.3));
    } else if (paletteIndex == 2) {
        return cosPalette(t, float3(0.4, 0.35, 0.2), float3(0.2, 0.2, 0.15),
                          float3(1.0, 0.8, 0.6), float3(0.0, 0.1, 0.15));
    } else {
        return cosPalette(t, float3(0.5, 0.5, 0.5), float3(0.5, 0.5, 0.5),
                          float3(1.0, 1.0, 1.0), float3(0.0, 0.0, 0.0));
    }
}

// MARK: - Plasma Shader

[[ stitchable ]]
half4 plasma(float2 position, half4 color, float2 size,
             float time, float scale, float waveCountF, float distortion,
             float saturation, float brightness, float paletteIndexF) {

    int waveCount = int(waveCountF);
    int paletteIndex = int(paletteIndexF);

    float2 uv = position / size;
    float2 p = uv * scale;

    // Noise-warped UVs
    float2 warp = float2(
        valueNoise(p + float2(time * 0.3, 0.0)),
        valueNoise(p + float2(0.0, time * 0.3))
    );
    p += warp * distortion;

    // Sum sine waves at different angles
    float value = 0.0;
    for (int i = 0; i < waveCount; i++) {
        float angle = float(i) * 3.14159 / float(waveCount);
        float2 dir = float2(cos(angle), sin(angle));
        float freq = 2.0 + float(i) * 0.7;
        value += sin(dot(p, dir) * freq + time * (1.0 + float(i) * 0.2));
    }
    value /= float(max(waveCount, 1));
    value = value * 0.5 + 0.5; // normalize to 0-1

    float3 col = plasmaPalette(value, paletteIndex);

    // Apply saturation
    float gray = dot(col, float3(0.299, 0.587, 0.114));
    col = mix(float3(gray), col, saturation);
    col *= brightness * 2.0;

    return half4(half3(col), 1.0);
}

// MARK: - Aurora Shader

[[ stitchable ]]
half4 aurora(float2 position, half4 color, float2 size,
             float time, float amplitude, float layersF,
             float verticalCenter, float bandWidth, float auroraBrightness,
             float paletteIndexF, float starField) {

    int layers = int(layersF);
    int paletteIndex = int(paletteIndexF);

    float2 uv = position / size;
    float aspect = size.x / size.y;

    // Dark sky background
    float3 sky = float3(0.02, 0.02, 0.05);
    sky += float3(0.02, 0.01, 0.03) * (1.0 - uv.y); // slight horizon glow

    // Optional star field
    if (starField > 0.5) {
        float2 starUV = uv * float2(aspect * 80.0, 80.0);
        float2 starCell = floor(starUV);
        float starHash = hash21(starCell);
        if (starHash > 0.97) {
            float2 starPos = hash22(starCell);
            float dist = length(fract(starUV) - starPos);
            float twinkle = sin(time * 2.0 + starHash * 100.0) * 0.5 + 0.5;
            float star = smoothstep(0.05, 0.0, dist) * (0.5 + 0.5 * twinkle);
            sky += float3(star);
        }
    }

    float3 result = sky;

    // Aurora bands
    for (int i = 0; i < layers; i++) {
        float fi = float(i);
        float layerOffset = fi * 0.06;

        // Horizontal position with noise displacement
        float noiseX = valueNoise(float2(uv.x * 3.0 + fi * 1.7, time * 0.5 + fi * 0.3));
        float displacement = noiseX * amplitude;

        float center = verticalCenter + layerOffset + displacement;
        float dist = abs(uv.y - center);
        float band = smoothstep(bandWidth, 0.0, dist);
        band *= band; // sharper falloff

        // Color from palette, offset per layer
        float t = uv.x * 0.5 + fi * 0.25 + time * 0.1;
        float3 auroraColor = auroraPalette(t, paletteIndex);
        auroraColor *= auroraBrightness;

        // Opacity varies along x
        float xFade = valueNoise(float2(uv.x * 5.0 + fi * 2.0, time * 0.3));
        band *= 0.3 + 0.7 * xFade;

        result += auroraColor * band * (1.2 / float(layers));
    }

    return half4(half3(result), 1.0);
}

// MARK: - Marble Shader

[[ stitchable ]]
half4 marble(float2 position, half4 color, float2 size,
             float time, float turbulence, float octavesF,
             float displacement, float bandFrequency,
             float colorSeparation, float paletteIndexF) {

    int octaves = int(octavesF);
    int paletteIndex = int(paletteIndexF);

    float2 uv = position / size;
    float2 p = uv * 4.0;

    // First domain warp
    float2 warp1 = float2(
        fbm(p + float2(time * 0.1, 0.0), octaves),
        fbm(p + float2(5.2, 1.3 + time * 0.1), octaves)
    );

    // Second domain warp (warp the warp)
    float2 warp2 = float2(
        fbm(p + warp1 * displacement + float2(1.7, 9.2), octaves),
        fbm(p + warp1 * displacement + float2(8.3, 2.8), octaves)
    );

    float n = fbm(p + warp2 * turbulence, octaves);

    // Sine banding
    float banding = sin(n * bandFrequency + uv.x * 8.0 + time * 0.2);
    banding = banding * 0.5 + 0.5;

    // Color with separation per channel
    float3 col = float3(0.0);
    col.r = marblePalette(banding + colorSeparation, paletteIndex).r;
    col.g = marblePalette(banding, paletteIndex).g;
    col.b = marblePalette(banding - colorSeparation, paletteIndex).b;

    // Darken in warped valleys
    col *= 0.6 + 0.4 * n;

    return half4(half3(col), 1.0);
}

// MARK: - Voronoi Shader

[[ stitchable ]]
half4 voronoi(float2 position, half4 color, float2 size,
              float time, float cellDensity, float morphSpeed,
              float edgeWidth, float edgeGlow,
              float fillModeF, float paletteIndexF, float invert) {

    int fillMode = int(fillModeF);
    int paletteIndex = int(paletteIndexF);

    float2 uv = position / size;
    float aspect = size.x / size.y;
    float2 p = float2(uv.x * aspect, uv.y) * cellDensity;

    float2 cellID = floor(p);
    float2 cellUV = fract(p);

    float minDist1 = 10.0;
    float minDist2 = 10.0;
    float closestCellHash = 0.0;

    // Check 3x3 neighborhood
    for (int y = -1; y <= 1; y++) {
        for (int x = -1; x <= 1; x++) {
            float2 neighbor = float2(float(x), float(y));
            float2 neighborCell = cellID + neighbor;
            float2 randOffset = hash22(neighborCell);

            // Animate cell centers
            float2 center = neighbor + 0.5 + 0.4 * sin(time * morphSpeed + randOffset * 6.28318) - cellUV;

            float dist = length(center);
            if (dist < minDist1) {
                minDist2 = minDist1;
                minDist1 = dist;
                closestCellHash = hash21(neighborCell);
            } else if (dist < minDist2) {
                minDist2 = dist;
            }
        }
    }

    // Edge detection: difference between 1st and 2nd closest
    float edge = minDist2 - minDist1;
    float edgeMask = 1.0 - smoothstep(0.0, edgeWidth + 0.001, edge);

    // Fill color based on mode
    float3 fillColor;
    float t = closestCellHash;

    if (fillMode == 0) {
        // Solid: flat color per cell
        fillColor = voronoiPalette(t, paletteIndex);
    } else if (fillMode == 1) {
        // Gradient: darken toward edges
        fillColor = voronoiPalette(t, paletteIndex);
        fillColor *= 0.5 + 0.5 * (1.0 - minDist1);
    } else {
        // Wireframe: dark fill, bright edges only
        fillColor = float3(0.03);
    }

    // Edge glow
    float3 edgeColor = voronoiPalette(t + 0.5, paletteIndex) * edgeGlow;
    float3 result = mix(fillColor, edgeColor, edgeMask);

    if (invert > 0.5) {
        result = 1.0 - result;
    }

    return half4(half3(result), 1.0);
}

// MARK: - Film Grain

[[ stitchable ]]
half4 filmGrain(float2 position, half4 color, float2 size,
                float time, float amount, float grainSize, float animated) {

    float2 uv = position / grainSize;
    float seed = animated > 0.5 ? floor(time * 24.0) : 0.0;
    float noise = hash21(uv + seed);

    // Luminance-aware: more grain in midtones
    float lum = dot(float3(color.rgb), float3(0.299, 0.587, 0.114));
    float midtoneMask = 1.0 - abs(lum - 0.5) * 2.0;
    midtoneMask = 0.5 + 0.5 * midtoneMask;

    float grain = (noise - 0.5) * amount * midtoneMask;

    half3 result = color.rgb + half3(grain);
    return half4(result, color.a);
}

// MARK: - Vignette

[[ stitchable ]]
half4 vignette(float2 position, half4 color, float2 size,
               float strength, float radius) {

    float2 uv = position / size;
    float aspect = size.x / size.y;

    float2 centered = (uv - 0.5) * float2(aspect, 1.0);
    float dist = length(centered);

    float vig = smoothstep(radius, radius - 0.4, dist);
    vig = mix(1.0, vig, strength);

    return half4(color.rgb * half3(vig), color.a);
}
