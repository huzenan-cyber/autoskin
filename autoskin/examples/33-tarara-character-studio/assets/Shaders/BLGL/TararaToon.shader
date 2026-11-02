shader_type spatial;
// Tarara materials: the built-in Toon shading model with an albedo map, alpha cutout and dithered fading.
render_mode shading_model_toon, outline, cull_back;

uniform sampler2D albedo_map : source_color, filter_linear_mipmap, repeat_enable;
// Half-width of the light-to-shadow transition, in N dot L.
uniform float toon_softness : hint_range(0.001, 1.0, 0.001) = 0.035;
// 0 cloth and accessories, 1 hair, 2 skin, 3 face.
uniform float toon_area_type : hint_range(0.0, 3.0, 1.0) = 0.0;
// 1 is opaque; lower values fade the surface out by dithering.
uniform float dither_opacity : hint_range(0.0, 1.0, 0.01) = 1.0;

// Built-in Toon material parameters, read by the engine when declared.
uniform vec3 toon_shadow_hsv = vec3(0.0, 0.3, 0.82);
uniform vec4 toon_skin_shadow_tint = vec4(1.0, 0.337254902, 0.380392157, 1.0);
uniform vec4 toon_rim_color = vec4(1.0, 1.0, 1.0, 4.0);

void fragment() {
    vec4 texel = texture(albedo_map, UV);
    ALBEDO = texel.rgb;
    ALPHA = texel.a;
    ALPHA_SCISSOR_THRESHOLD = 0.3;
    TOON_RAMP = smoothstep(-toon_softness, toon_softness, dot(NORMAL, MAIN_LIGHT_DIRECTION));
    TOON_AREA_TYPE = toon_area_type;
    DITHER_OPACITY = dither_opacity;
}
