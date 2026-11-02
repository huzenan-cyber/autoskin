shader_type spatial;
render_mode shading_model_water, cull_disabled, diffuse_lambert_wrap;

uniform sampler2D fft_previous : filter_linear, repeat_enable;
uniform sampler2D fft_display : filter_linear, repeat_enable;
uniform sampler2D fft_query : filter_linear, repeat_enable;
uniform float display_time = 0.0;
uniform float patch_length = 512.0;

#include "WaterSampling.shaderinc"

// Texture-free details keep all three author sampler slots available for the FFT snapshots.
float foam_hash(vec2 p) {
    vec3 q = fract(vec3(p.xyx) * 0.1031);
    q += dot(q, q.yzx + 33.33);
    return fract((q.x + q.y) * q.z);
}

// Return value and analytic gradient. Quintic interpolation keeps slopes smooth across cell boundaries.
vec3 detail_noise(vec2 p) {
    vec2 cell = floor(p);
    vec2 f = fract(p);
    vec2 blend = f * f * f * (f * (f * 6.0 - 15.0) + 10.0);
    vec2 gradient = 30.0 * f * f * (f - 1.0) * (f - 1.0);
    float a = foam_hash(cell);
    float b = foam_hash(cell + vec2(1.0, 0.0));
    float c = foam_hash(cell + vec2(0.0, 1.0));
    float d = foam_hash(cell + vec2(1.0));
    float cross_term = a - b - c + d;
    return vec3(a + (b - a) * blend.x + (c - a) * blend.y + cross_term * blend.x * blend.y,
                gradient * (vec2(b - a, c - a) + cross_term * blend.yx));
}

void vertex() {
    vec3 current = water_displacement(fft_display, VERTEX.xz);
    vec3 previous = water_displacement(fft_previous, VERTEX.xz);
    VERTEX += current;
    VELOCITY = current - previous;
    // Keep the rest-plane normal: water refraction uses its difference from the pixel normal.
}

void fragment() {
    vec2 position = UV * 128.0 - vec2(64.0);
    float footprint = max(length(dFdx(position)), length(dFdy(position)));
    vec4 derivatives = vec4(0.0);
    float cross_derivative = 0.0;
    float compression = 0.0;
    for (int band = 0; band < 4; ++band) {
        float texel_size = patch_length * pow(0.25, float(band)) / 256.0;
        // Remove unresolved slopes before shading. Near-camera detail comes from real short waves.
        float resolved = 1.0 - smoothstep(1.0, 4.0, footprint / texel_size);
        vec4 d = water_band(fft_display, position, band, 1);
        float cross_value = water_band(fft_display, position, band, 0).w;
        derivatives += d * resolved;
        cross_derivative += cross_value * resolved;
        float jacobian = (1.0 + d.z) * (1.0 + d.w) - cross_value * cross_value;
        float weight = band == 0 ? 1.0 : (band == 1 ? 0.7 : 0.25);
        compression += (1.0 - jacobian) * weight * resolved;
    }
    vec3 tx = vec3(1.0 + derivatives.z, derivatives.x, cross_derivative);
    vec3 tz = vec3(cross_derivative, derivatives.y, 1.0 + derivatives.w);
    vec3 wave_normal = normalize(cross(tz, tx));
    vec2 drift = position - vec2(0.12, 0.05) * display_time;
    float lace = detail_noise(drift * 2.2).x * 0.65 + detail_noise(drift * 7.1).x * 0.35;
    float cover = smoothstep(0.16, 0.5, compression);
    float whitecap = cover * smoothstep(0.28, 0.72, lace + cover * 0.25);
    float thickness = SCENE_DEPTH_WITHOUT_WATER - (VIEW_MATRIX * vec4(VERTEX, 1.0)).z;
    float shore = 1.0 - smoothstep(0.0, 0.4, thickness);
    float foam = max(whitecap, shore * smoothstep(0.35, 0.75, lace) * 0.65) * step(0.0, thickness);

    NORMAL = wave_normal;
    ALBEDO = vec3(0.76, 0.80, 0.78);
    ROUGHNESS = mix(0.14, 0.55, foam);
    SPECULAR = 0.25;
    ALPHA = foam * 0.8;
    WATER_ABSORPTION = vec3(0.30, 0.07, 0.025);
    WATER_SCATTERING = vec3(0.008, 0.025, 0.035);
    WATER_PHASE_G = 0.3;
}

void occlude_camera() {
    vec2 result = water_immersion(fft_query, CAMERA_POSITION_WORLD);
    CAMERA_OCCLUSION_VALID = result.y > 0.5;
    CAMERA_IMMERSION_DEPTH = result.x;
}

void waterline() {
    vec2 result = water_immersion(fft_display, WATERLINE_POSITION_WORLD);
    WATERLINE_VALID = result.y > 0.5;
    WATERLINE_IMMERSION_DEPTH = result.x;
}
