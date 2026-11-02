// GBuffer post-process for rain: darkens and smooths exposed surfaces before
// deferred lighting, and pools puddles on flat, upward-facing areas.
shader_type spatial;
render_mode gbuffer_postprocess;

uniform float wetness : hint_range(0.0, 1.0) = 0.0;
uniform float puddles : hint_range(0.0, 1.0) = 0.0;

float hash21(vec2 p) {
    vec3 h = fract(vec3(p.x, p.y, p.x) * 0.1031);
    h += dot(h, h.yzx + 33.33);
    return fract((h.x + h.y) * h.z);
}

float noise2(vec2 p) {
    vec2 cell = floor(p);
    vec2 f = fract(p);
    vec2 u = f * f * (3.0 - 2.0 * f);
    return mix(mix(hash21(cell), hash21(cell + vec2(1.0, 0.0)), u.x),
               mix(hash21(cell + vec2(0.0, 1.0)), hash21(cell + vec2(1.0, 1.0)), u.x), u.y);
}

void fragment() {
    if (wetness > 0.001 && (SHADING_MODEL == SHADING_MODEL_PBR || SHADING_MODEL == SHADING_MODEL_TOON)) {
        // Rain runs off vertical faces, so they only get half the effect.
        float facing = mix(0.5, 1.0, smoothstep(0.3, 0.9, NORMAL.y));
        float exposed = wetness * facing * RAIN_EXPOSURE;
        ALBEDO *= mix(1.0, 0.6, exposed);
        ROUGHNESS = mix(ROUGHNESS, min(ROUGHNESS, 0.18), exposed);

        float flat_up = smoothstep(0.92, 0.98, NORMAL.y) * step(1.5, VERTEX.y);
        if (puddles > 0.001 && flat_up > 0.0) {
            vec2 p = VERTEX.xz * 0.45;
            float field = noise2(p) * 0.65 + noise2(p * 2.3 + vec2(7.3, 19.1)) * 0.35;
            float threshold = 1.0 - 0.55 * puddles;
            float puddle = smoothstep(threshold, threshold + 0.06, field) * flat_up * wetness;
            ALBEDO *= mix(1.0, 0.7, puddle);
            ROUGHNESS = mix(ROUGHNESS, 0.03, puddle);
            METALLIC = mix(METALLIC, 0.0, puddle);
        }
    }
}
