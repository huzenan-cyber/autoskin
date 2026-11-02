// Soft contact shadow and faint sheen under each planted foot, drawn on a small floor patch over
// the stage so only the pixels around the feet pay for them; see Studio:SetContactPoints.
shader_type spatial;
render_mode unshaded, blend_premul_alpha, cull_disabled;

// Same multiplier as the stage; see Studio:SetBackdrop.
uniform vec4 backdrop_tint = vec4(1.0);
// World positions of each heel and toe on the sole.
uniform vec3 left_heel = vec3(-0.1, 0.0, 0.0);
uniform vec3 left_toe = vec3(-0.1, 0.0, 0.15);
uniform vec3 right_heel = vec3(0.1, 0.0, 0.0);
uniform vec3 right_toe = vec3(0.1, 0.0, 0.15);

// Sheen added in linear color: an sRGB lift of (0.07, 0.07, 0.075) on the floor under the feet,
// where the stage's 2.2 gamma roughly halves it.
const vec3 FOOT_SHEEN = vec3(0.035, 0.035, 0.0375);
// Heights in metres at which the sheen and the shadow have faded out.
const float SHEEN_FADE_HEIGHT = 0.15;
const float SHADOW_FADE_HEIGHT = 0.25;
// Sheen radius, and shadow radius when planted and when fully lifted, in metres.
const float SHEEN_RADIUS = 0.22;
const vec2 SHADOW_RADIUS = vec2(0.06, 0.16);
// Darkening at the centre of a planted foot's shadow.
const float SHADOW_STRENGTH = 0.5;

// Distance from point p to segment ab.
float segment_distance(vec2 p, vec2 a, vec2 b) {
    vec2 ab = b - a;
    float t = clamp(dot(p - a, ab) / max(dot(ab, ab), 0.0001), 0.0, 1.0);
    return length(p - a - ab * t);
}

// Darkening under one foot; it fades and spreads as the foot lifts.
float foot_shadow(vec2 p, vec3 heel, vec3 toe) {
    float lift = clamp(min(heel.y, toe.y) / SHADOW_FADE_HEIGHT, 0.0, 1.0);
    float d = segment_distance(p, heel.xz, toe.xz) / mix(SHADOW_RADIUS.x, SHADOW_RADIUS.y, lift);
    return exp(-d * d) * SHADOW_STRENGTH * (1.0 - lift);
}

// A faint glossy sheen around a planted foot, standing in for its reflection in the floor.
float foot_sheen(vec2 p, vec3 heel, vec3 toe) {
    float lift = clamp(min(heel.y, toe.y) / SHEEN_FADE_HEIGHT, 0.0, 1.0);
    float d = segment_distance(p, heel.xz, toe.xz) / SHEEN_RADIUS;
    return exp(-d * d) * (1.0 - lift);
}

void fragment() {
    vec2 p = VERTEX.xz;
    float sheen = max(foot_sheen(p, left_heel, left_toe), foot_sheen(p, right_heel, right_toe));
    float shadow = max(foot_shadow(p, left_heel, left_toe), foot_shadow(p, right_heel, right_toe));
    // The stage darkens in sRGB, which is the factor raised to 2.2 in linear. Premultiplied
    // blending then gives (floor + sheen) * keep.
    float keep = pow(1.0 - shadow, 2.2);
    ALBEDO = FOOT_SHEEN * sheen * keep * backdrop_tint.rgb;
    ALPHA = 1.0 - keep;
}
