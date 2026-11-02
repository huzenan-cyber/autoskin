shader_type compute;
workgroup_size(8, 8, 1);

uniform int resolution = 256;
uniform float patch_length = 512.0;
uniform float repeat_period = 1000.0;
uniform float elapsed = 0.0;
readonly buffer vec4 initial_spectrum[];
writeonly buffer vec4 height_dx[];
writeonly buffer vec4 dz[];

void compute() {
    ivec2 p = ivec2(GLOBAL_INVOCATION_ID.xy);
    int band = int(GLOBAL_INVOCATION_ID.z);
    int offset = band * resolution * resolution;
    int index = offset + p.x + resolution * p.y;
    ivec2 opposite = (ivec2(resolution) - p) % resolution;
    vec2 a = initial_spectrum[index].xy;
    vec2 b = initial_spectrum[offset + opposite.x + resolution * opposite.y].xy;
    vec2 frequency = vec2(p);
    if (p.x > resolution / 2) { frequency.x -= float(resolution); }
    if (p.y > resolution / 2) { frequency.y -= float(resolution); }
    float band_length = patch_length * pow(0.25, float(band));
    vec2 k = frequency * (6.28318530718 / band_length);
    float length_k = length(k);
    float base = 6.28318530718 / repeat_period;
    float phase = floor(sqrt(9.81 * length_k) / base) * base * elapsed;
    float c = cos(phase);
    float s = sin(phase);
    vec2 h = vec2((a.x + b.x) * c - (a.y + b.y) * s,
                  (a.x - b.x) * s + (a.y - b.y) * c);
    vec2 direction = k / max(length_k, 0.000001);
    // With the positive inverse-FFT exponent, +i*k_hat*H compresses crests.
    vec2 i_h = vec2(-h.y, h.x);
    height_dx[index] = vec4(h, i_h * direction.x);
    dz[index] = vec4(i_h * direction.y, 0.0, 0.0);
}
