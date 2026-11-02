shader_type compute;
workgroup_size(8, 8, 1);

uniform int resolution = 256;
uniform float patch_length = 128.0;
uniform float elapsed = 0.0;
readonly buffer vec4 initial_spectrum[];
writeonly buffer vec4 height_dx[];
writeonly buffer vec4 dz[];

void compute() {
    ivec2 p = ivec2(GLOBAL_INVOCATION_ID.xy);
    int index = p.x + resolution * p.y;
    ivec2 opposite = (ivec2(resolution) - p) % resolution;
    vec2 a = initial_spectrum[index].xy;
    vec2 b = initial_spectrum[opposite.x + resolution * opposite.y].xy;
    vec2 frequency = vec2(p);
    if (p.x > resolution / 2) { frequency.x -= float(resolution); }
    if (p.y > resolution / 2) { frequency.y -= float(resolution); }
    vec2 k = frequency * (6.28318530718 / patch_length);
    float length_k = length(k);
    float phase = sqrt(9.81 * length_k) * elapsed;
    float c = cos(phase);
    float s = sin(phase);
    vec2 h = vec2((a.x + b.x) * c - (a.y + b.y) * s,
                  (a.x - b.x) * s + (a.y - b.y) * c);
    vec2 direction = k / max(length_k, 0.000001);
    vec2 minus_i_h = vec2(h.y, -h.x);
    height_dx[index] = vec4(h, minus_i_h * direction.x);
    dz[index] = vec4(minus_i_h * direction.y, 0.0, 0.0);
}
