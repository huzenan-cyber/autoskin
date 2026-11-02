shader_type compute;
workgroup_size(8, 8, 1);

uniform int resolution = 256;
uniform int span = 1;
uniform bool vertical = false;
readonly buffer vec4 source_hx[];
readonly buffer vec4 source_z[];
writeonly buffer vec4 target_hx[];
writeonly buffer vec4 target_z[];

vec2 complex_multiply(vec2 a, vec2 b) {
    return vec2(a.x * b.x - a.y * b.y, a.x * b.y + a.y * b.x);
}

void compute() {
    ivec2 p = ivec2(GLOBAL_INVOCATION_ID.xy);
    int coordinate = vertical ? p.y : p.x;
    int q = coordinate % (2 * span);
    int j = q % span;
    int a = (coordinate / (2 * span)) * span + j;
    int b = a + resolution / 2;
    int ia = vertical ? p.x + resolution * a : a + resolution * p.y;
    int ib = vertical ? p.x + resolution * b : b + resolution * p.y;
    float angle = 3.14159265359 * float(j) / float(span);
    vec2 twiddle = vec2(cos(angle), sin(angle));
    if (q >= span) { twiddle = -twiddle; }
    vec4 ah = source_hx[ia];
    vec4 bh = source_hx[ib];
    vec4 az = source_z[ia];
    vec4 bz = source_z[ib];
    int index = p.x + resolution * p.y;
    // Stockham autosort, normalized by two at each butterfly stage.
    target_hx[index] = 0.5 * (ah + vec4(complex_multiply(twiddle, bh.xy), complex_multiply(twiddle, bh.zw)));
    target_z[index] = 0.5 * (az + vec4(complex_multiply(twiddle, bz.xy), complex_multiply(twiddle, bz.zw)));
}
