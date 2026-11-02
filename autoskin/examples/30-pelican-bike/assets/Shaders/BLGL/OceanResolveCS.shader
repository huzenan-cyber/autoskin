shader_type compute;
workgroup_size(8, 8, 1);

uniform int resolution = 256;
uniform float patch_length = 128.0;
uniform float choppiness = 1.2;
uniform float height_scale = 1.0;
readonly buffer vec4 spatial_hx[];
readonly buffer vec4 spatial_z[];
uniform writeonly image2D displacement_map : format_rgba32f;
uniform writeonly image2D normal_map : format_rgba32f;

vec3 displacement_at(ivec2 p) {
    ivec2 wrapped = (p + ivec2(resolution)) % resolution;
    int i = wrapped.x + resolution * wrapped.y;
    vec4 hx = spatial_hx[i];
    return vec3(hx.z * choppiness, hx.x, spatial_z[i].x * choppiness) * height_scale;
}

void compute() {
    ivec2 p = ivec2(GLOBAL_INVOCATION_ID.xy);
    float step_size = patch_length / float(resolution);
    vec3 tx = vec3(2.0 * step_size, 0.0, 0.0) + displacement_at(p + ivec2(1, 0)) - displacement_at(p - ivec2(1, 0));
    vec3 tz = vec3(0.0, 0.0, 2.0 * step_size) + displacement_at(p + ivec2(0, 1)) - displacement_at(p - ivec2(0, 1));
    vec3 normal = normalize(cross(tz, tx));
    float compression = clamp(1.0 - (tx.x * tz.z - tx.z * tz.x) / (4.0 * step_size * step_size), 0.0, 1.0);
    imageStore(displacement_map, p, vec4(displacement_at(p), compression));
    imageStore(normal_map, p, vec4(normal, 1.0));
}
