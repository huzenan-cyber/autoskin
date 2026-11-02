// Deferred PBR ocean surface driven by the GPU FFT displacement / normal maps.
// The mesh is a unit plane on an identity node; the vertex stage remaps it to a
// camera-centred grid whose spacing grows with distance (dense near, sparse far).
shader_type spatial;
render_mode shading_model_pbr, cull_disabled;

uniform highp sampler2D displacement_map : filter_nearest, repeat_enable;
uniform highp sampler2D normal_map : filter_nearest, repeat_enable;

uniform vec3 ocean_center = vec3(0.0);       // snapped camera x/z, y = sea level
uniform float patch_length = 128.0;          // FFT patch size in meters
uniform float inner_extent = 128.0;          // linear part of the grid mapping
uniform float ocean_extent = 2400.0;         // half size of the whole grid
uniform vec3 water_color = vec3(0.004, 0.022, 0.034);
uniform vec3 scatter_color = vec3(0.02, 0.16, 0.13);
uniform vec3 sun_direction = vec3(0.0, 0.5, 0.8);   // toward the main light
uniform vec3 sun_radiance = vec3(1.0);              // main light colour * intensity
uniform float foam_threshold = 0.42;
uniform float rain = 0.0;
uniform float time_s = 0.0;

varying vec2 ocean_xz;
varying float ocean_fade;

// RGBA32F cannot be linearly filtered on every compute-capable GPU.
// Interpolate explicit texel reads and wrap both neighbours across the FFT patch edges.
vec4 sample_ocean(sampler2D data_map, vec2 uv) {
    ivec2 size = textureSize(data_map, 0);
    vec2 position = fract(uv) * vec2(size) - vec2(0.5);
    vec2 weight = fract(position);
    ivec2 p0 = (ivec2(floor(position)) + size) % size;
    ivec2 p1 = (p0 + ivec2(1)) % size;
    return mix(mix(texelFetch(data_map, p0, 0), texelFetch(data_map, ivec2(p1.x, p0.y), 0), weight.x),
        mix(texelFetch(data_map, ivec2(p0.x, p1.y), 0), texelFetch(data_map, p1, 0), weight.x), weight.y);
}

vec2 grid_to_world(vec2 s) {
    vec2 a = abs(s);
    vec2 a2 = a * a;
    return sign(s) * (inner_extent * a + (ocean_extent - inner_extent) * a2 * a2);
}

float hash12(vec2 p) {
    vec3 p3 = fract(vec3(p.x, p.y, p.x) * 0.1031);
    p3 += dot(p3, p3.yzx + 33.33);
    return fract((p3.x + p3.y) * p3.z);
}

// Gradient of expanding rain-drop rings inside one cell layer.
vec2 ripple_gradient(vec2 p, float t) {
    vec2 cell = floor(p);
    vec2 f = fract(p) - 0.5;
    float h = hash12(cell);
    float phase = fract(t * 1.4 + h);
    vec2 center = (vec2(hash12(cell + 17.13), hash12(cell + 41.71)) - 0.5) * 0.35;
    vec2 d = f - center;
    float r = length(d);
    float ring = r - phase * 0.42;
    float envelope = exp(-ring * ring * 300.0) * (1.0 - phase);
    float slope = cos(ring * 48.0) * envelope;
    return d / max(r, 0.0001) * slope;
}

void vertex() {
    vec2 xz = ocean_center.xz + grid_to_world(VERTEX.xy * 2.0);
    float dist = length(xz - CAMERA_POSITION_WORLD.xz);
    float fade = 1.0 - smoothstep(220.0, 900.0, dist);
    vec3 d = sample_ocean(displacement_map, xz / patch_length + vec2(0.5 / 256.0)).xyz;
    VERTEX = vec3(xz.x, ocean_center.y, xz.y) + d * fade;
    NORMAL = vec3(0.0, 1.0, 0.0);
    ocean_xz = xz;
    ocean_fade = fade;
}

void fragment() {
    vec2 uv = ocean_xz / patch_length + vec2(0.5 / 256.0);
    vec4 disp = sample_ocean(displacement_map, uv);
    vec3 n0 = sample_ocean(normal_map, uv).xyz;
    vec3 n1 = sample_ocean(normal_map, uv * 3.37 + vec2(0.371, 0.713)).xyz;
    vec3 n2 = sample_ocean(normal_map, uv * 0.271 + vec2(0.13, 0.57)).xyz;

    float dist = length(VERTEX - CAMERA_POSITION_WORLD);
    // Slopes add linearly; the large octave keeps the far field from tiling.
    vec2 slope = n0.xz / max(n0.y, 0.05) * ocean_fade
        + n1.xz / max(n1.y, 0.05) * 0.30
        + n2.xz / max(n2.y, 0.05) * 0.55;
    slope *= mix(1.0, 0.45, smoothstep(60.0, 700.0, dist));

    if (rain > 0.001) {
        vec2 g = ripple_gradient(ocean_xz * 1.7, time_s)
            + ripple_gradient(ocean_xz * 2.9 + vec2(3.1, 7.7), time_s * 1.13);
        slope += g * (0.35 * rain * (1.0 - smoothstep(10.0, 60.0, dist)));
    }
    vec3 n = normalize(vec3(slope.x, 1.0, slope.y));

    float foam = smoothstep(foam_threshold, foam_threshold + 0.35, disp.w) * ocean_fade;
    foam *= 0.55 + 0.45 * hash12(floor(ocean_xz * 6.0));

    // Cheap subsurface transmission: crests lit from behind glow green-blue.
    vec3 v = normalize(CAMERA_POSITION_WORLD - VERTEX);
    float crest = clamp((VERTEX.y - ocean_center.y) * 0.35 + 0.35, 0.0, 1.0);
    vec3 l = normalize(sun_direction);
    float back = pow(clamp(dot(v, -vec3(l.x, 0.35 * l.y, l.z)), 0.0, 1.0), 4.0);
    float wrap = clamp(dot(n, l) * 0.5 + 0.5, 0.0, 1.0);
    vec3 sss = scatter_color * sun_radiance * crest * (back * 1.6 + wrap * 0.15);

    NORMAL = n;
    ALBEDO = mix(water_color, vec3(0.82, 0.86, 0.86), foam);
    ROUGHNESS = mix(0.03 + rain * 0.05, 0.6, foam);
    METALLIC = 0.0;
    SPECULAR = mix(0.25, 0.5, foam);
    AO = 1.0;
    EMISSION = sss * (1.0 - foam);
}
