shader_type spatial;
render_mode cull_back;

uniform vec4 base_color : source_color = vec4(0.8, 0.8, 0.8, 1.0);
uniform float roughness_value : hint_range(0.05, 1.0, 0.01) = 0.55;
uniform float metallic_value : hint_range(0.0, 1.0, 0.01) = 0.0;
uniform vec3 emission_color = vec3(0.0, 0.0, 0.0);
uniform float checker_scale : hint_range(0.0, 20.0, 0.1) = 0.0;

void fragment() {
    vec3 color = base_color.rgb;
    if (checker_scale > 0.0) {
        vec2 tile = floor(UV * checker_scale);
        float checker = mod(tile.x + tile.y, 2.0);
        color *= mix(0.72, 1.12, checker);
    }

    ALBEDO = color;
    ROUGHNESS = roughness_value;
    METALLIC = metallic_value;
    SPECULAR = 0.55;
    AO = 1.0;
    EMISSION = emission_color;
}

void light() {
    float ndotl = max(dot(NORMAL, LIGHT), 0.0);
    float wrapped = ndotl * 0.82 + 0.18;
    vec3 half_dir = normalize(LIGHT + VIEW);
    float spec = pow(max(dot(NORMAL, half_dir), 0.0), mix(96.0, 12.0, roughness_value));
    float metal_boost = mix(1.0, 1.65, metallic_value);

    DIFFUSE_LIGHT += ALBEDO * LIGHT_COLOR * ATTENUATION * wrapped;
    SPECULAR_LIGHT += LIGHT_COLOR * ATTENUATION * spec * SPECULAR_AMOUNT * metal_boost;
}
