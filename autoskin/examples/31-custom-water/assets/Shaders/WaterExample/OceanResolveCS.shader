shader_type compute;
workgroup_size(8, 8, 1);

uniform int resolution = 256;
uniform float patch_length = 512.0;
uniform float choppiness = 1.4;
readonly buffer vec4 spatial_hx[];
readonly buffer vec4 spatial_z[];
uniform writeonly image2D displacement_map : format_rgba32f;

vec3 displacement_at(ivec2 p, int band) {
    ivec2 wrapped = (p + ivec2(resolution)) % resolution;
    int i = band * resolution * resolution + wrapped.x + resolution * wrapped.y;
    return vec3(spatial_hx[i].z * choppiness, spatial_hx[i].x, spatial_z[i].x * choppiness);
}

void compute() {
    ivec2 pixel = ivec2(GLOBAL_INVOCATION_ID.xy);
    int band = int(GLOBAL_INVOCATION_ID.z);
    int tile = resolution + 2;
    if (all(lessThan(pixel, ivec2(tile)))) {
        ivec2 p = (pixel + ivec2(resolution - 1)) % resolution;
        float derivative_scale = float(resolution) / (2.0 * patch_length * pow(0.25, float(band)));
        vec3 dx = (displacement_at(p + ivec2(1, 0), band) - displacement_at(p - ivec2(1, 0), band)) * derivative_scale;
        vec3 dz = (displacement_at(p + ivec2(0, 1), band) - displacement_at(p - ivec2(0, 1), band)) * derivative_scale;
        // Four columns, two rows; each tile has a periodic one-texel gutter for seam-free bilinear sampling.
        // The cross derivative is stored separately from the two height slopes and diagonal derivatives.
        ivec2 destination = pixel + ivec2(band * tile, 0);
        imageStore(displacement_map, destination, vec4(displacement_at(p, band), dz.x));
        imageStore(displacement_map, destination + ivec2(0, tile), vec4(dx.y, dz.y, dx.x, dz.z));
    }
}
