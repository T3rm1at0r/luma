#include <metal_stdlib>
using namespace metal;

struct BackdropVertexOut {
    float4 position [[position]];
    float2 uv;
};

struct BackdropUniforms {
    float2 resolution;
    float time;
    float scheme; // 0 = dark plum, 1 = light cream
};

vertex BackdropVertexOut welcomeBackdropVertex(uint vid [[vertex_id]]) {
    const float2 positions[4] = {
        float2(-1.0, -1.0),
        float2( 1.0, -1.0),
        float2(-1.0,  1.0),
        float2( 1.0,  1.0),
    };
    BackdropVertexOut out;
    out.position = float4(positions[vid], 0.0, 1.0);
    out.uv = positions[vid] * 0.5 + 0.5;
    return out;
}

static float plasmaField(float2 p, float t) {
    float v = sin(p.x * 3.0 + t * 0.55);
    v += sin(p.y * 2.7 - t * 0.42);
    v += sin((p.x + p.y) * 1.9 + t * 0.38);
    float2 c = float2(sin(t * 0.27), cos(t * 0.31)) * 1.4;
    v += sin(length(p * 1.6 - c) * 4.2 - t * 0.65);
    return v * 0.25;
}

fragment float4 welcomeBackdropFragment(
    BackdropVertexOut in [[stage_in]],
    constant BackdropUniforms &u [[buffer(0)]]
) {
    float aspect = u.resolution.x / max(u.resolution.y, 1.0);
    float2 p = in.uv * 2.0 - 1.0;
    p.x *= aspect;

    float v = plasmaField(p, u.time);
    float n = v * 0.5 + 0.5;

    // IQ cosine palettes — low-amplitude cream→coral for light,
    // deep plum→coral→ember for dark.
    const float3 LIGHT_A = float3(0.965, 0.935, 0.905);
    const float3 LIGHT_B = float3(0.085, 0.110, 0.130);
    const float3 LIGHT_D = float3(0.00, 0.10, 0.22);

    const float3 DARK_A = float3(0.180, 0.105, 0.135);
    const float3 DARK_B = float3(0.520, 0.230, 0.205);
    const float3 DARK_D = float3(0.00, 0.14, 0.30);

    float3 lightColor = LIGHT_A + LIGHT_B * cos(6.28318 * (n + LIGHT_D));
    float3 darkColor  = DARK_A  + DARK_B  * cos(6.28318 * (n + DARK_D));

    // Soft scanline contour — quiet demoscene callback.
    float band = sin(v * 9.0 + u.time * 0.6);
    float contour = smoothstep(0.86, 1.0, band);
    lightColor -= contour * 0.020;
    darkColor  += contour * float3(0.060, 0.022, 0.018);

    // Travelling sine ripple, nudges plasma slightly so it doesn't loop visibly.
    float ripple = sin(p.x * 1.8 - p.y * 1.2 + u.time * 0.9) * 0.5 + 0.5;
    lightColor = mix(lightColor, lightColor * 0.985, ripple * 0.20);
    darkColor  = mix(darkColor,  darkColor  * 1.080, ripple * 0.22);

    // Tiny grain so flat regions never look dead.
    float grain = fract(sin(dot(in.uv * u.resolution, float2(12.9898, 78.233))) * 43758.5453);
    lightColor += (grain - 0.5) * 0.008;
    darkColor  += (grain - 0.5) * 0.014;

    // Editorial vignette.
    float vignette = smoothstep(1.70, 0.45, length(p * float2(0.85, 1.0)));
    lightColor *= mix(0.96, 1.0, vignette);
    darkColor  *= mix(0.55, 1.0, vignette);

    float3 color = mix(darkColor, lightColor, u.scheme);
    return float4(color, 1.0);
}
