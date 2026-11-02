// Dark studio infinity cove. A broad glow sits on the wall behind the upper body and a light pool
// spreads across the floor behind the feet. The contact shadow is a separate patch; see
// StudioContact.shader.
shader_type spatial;
render_mode unshaded, cull_disabled;

// Multiplies the whole stage; see Studio:SetBackdrop.
uniform vec4 backdrop_tint = vec4(1.0);

// Palette in sRGB: the unlit corners, the wall glow and the floor pool added on top.
const vec3 BASE = vec3(0.141, 0.141, 0.192);
const vec3 WALL_GLOW = vec3(0.31, 0.30, 0.34);
const vec3 FLOOR_GLOW = vec3(0.25, 0.25, 0.28);
// The glows are laid out in the mesh UV: U is metres across the stage and V is metres along the
// surface from the middle of the curved corner, up the wall positive and out across the floor
// negative. The surface bends smoothly, so a glow crossing the corner shows no edge.
// Each glow: centre V, and radius across, towards the top of the wall and towards the camera.
const float WALL_GLOW_CENTER = 1.0;
const vec3 WALL_GLOW_SIZE = vec3(2.0, 1.6, 1.4);
const float FLOOR_GLOW_CENTER = -1.6;
const vec3 FLOOR_GLOW_SIZE = vec3(2.3, 1.1, 1.6);

// One glow on the unrolled stage surface, with different radii on either side of its centre.
float glow(vec2 uv, float centre, vec3 size) {
    float d = uv.y - centre;
    vec2 q = vec2(uv.x / size.x, d / (d > 0.0 ? size.y : size.z));
    return exp(-dot(q, q));
}

void fragment() {
    vec3 color = BASE + WALL_GLOW * glow(UV, WALL_GLOW_CENTER, WALL_GLOW_SIZE)
        + FLOOR_GLOW * glow(UV, FLOOR_GLOW_CENTER, FLOOR_GLOW_SIZE);
    ALBEDO = pow(color, vec3(2.2)) * backdrop_tint.rgb;
}
