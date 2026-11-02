// Procedural sky: gradient driven by time of day, sun glow and disc, moon,
// twinkling stars, fbm cloud layer whose coverage follows the weather, and
// lightning flashes. Colours come from Lua so fog and sky stay in sync.
shader_type sky;

uniform vec3 zenith_color = vec3(0.08, 0.25, 0.62);
uniform vec3 horizon_color = vec3(0.45, 0.62, 0.90);
uniform vec3 sun_direction = vec3(0.0, 0.5, 0.8);
uniform vec3 sun_color = vec3(1.0, 0.9, 0.8);
uniform vec3 moon_direction = vec3(0.0, -0.5, -0.8);
uniform vec3 cloud_lit = vec3(1.0, 1.0, 1.0);
uniform vec3 cloud_shade = vec3(0.5, 0.55, 0.6);
uniform float night = 0.0;
uniform float cloud_cover = 0.3;
uniform float sky_time = 0.0;
uniform float flash = 0.0;
uniform float exposure = 1.0;

float hash12(vec2 p) {
    vec3 p3 = fract(vec3(p.x, p.y, p.x) * 0.1031);
    p3 += dot(p3, p3.yzx + 33.33);
    return fract((p3.x + p3.y) * p3.z);
}

float hash13(vec3 p) {
    vec3 p3 = fract(p * 0.1031);
    p3 += dot(p3, p3.zyx + 31.32);
    return fract((p3.x + p3.y) * p3.z);
}

float value_noise(vec2 p) {
    vec2 i = floor(p);
    vec2 f = fract(p);
    vec2 u = f * f * (3.0 - 2.0 * f);
    return mix(mix(hash12(i), hash12(i + vec2(1.0, 0.0)), u.x),
               mix(hash12(i + vec2(0.0, 1.0)), hash12(i + vec2(1.0, 1.0)), u.x), u.y);
}

float fbm(vec2 p) {
    float v = 0.0;
    float a = 0.5;
    for (int i = 0; i < 5; i++) {
        v += a * value_noise(p);
        p = p * 2.03 + vec2(17.1, 9.2);
        a *= 0.5;
    }
    return v;
}

void sky() {
    vec3 d = normalize(EYEDIR);
    vec3 sd = normalize(sun_direction);
    float up = max(d.y, 0.0);
    vec3 col = mix(horizon_color, zenith_color, pow(up, 0.45));
    if (d.y < 0.0) {
        col = horizon_color * mix(1.0, 0.4, clamp(-d.y * 4.0, 0.0, 1.0));
    }

    float mu = max(dot(d, sd), 0.0);
    float sun_visible = smoothstep(-0.10, 0.02, sd.y);
    float clear = 1.0 - cloud_cover;
    // Mie-like forward glow; stays visible through thin clouds.
    col += sun_color * (pow(mu, 6.0) * 0.30 + pow(mu, 48.0) * 0.55) * sun_visible * (0.25 + 0.75 * clear);
    // The sun disc is left out of environment captures (as UE does): the sun light already lights
    // the scene directly, and a 45x hot spot would only add noise to the prefiltered reflections.
    if (!AT_CUBEMAP_PASS) {
        col += sun_color * smoothstep(0.99935, 0.99965, mu) * 45.0 * sun_visible * clear;
    }

    // Stars and moon fade in at night and hide behind clouds.
    if (night > 0.001 && d.y > 0.0) {
        vec3 sp = d * 240.0;
        vec3 cell = floor(sp);
        float h = hash13(cell);
        float star = step(0.9972, h) * smoothstep(0.45, 0.0, length(fract(sp) - 0.5));
        float twinkle = 0.55 + 0.45 * sin(sky_time * 3.1 + h * 511.0);
        col += vec3(0.85, 0.92, 1.0) * star * twinkle * night * 4.0 * clear * smoothstep(0.0, 0.2, d.y);
    }
    float mm = max(dot(d, normalize(moon_direction)), 0.0);
    col += vec3(0.80, 0.86, 1.0) * (smoothstep(0.99945, 0.99965, mm) * 8.0 + pow(mm, 40.0) * 0.12)
        * night * (0.15 + 0.85 * clear);

    // Cloud layer projected onto a flat plane above the viewer.
    if (d.y > 0.0) {
        vec2 cp = d.xz / (d.y + 0.07) * 1.1 + vec2(sky_time * 0.010, sky_time * 0.004);
        float n = fbm(cp);
        float threshold = mix(0.64, 0.12, cloud_cover);
        float c = smoothstep(threshold, threshold + 0.22, n);
        float thick = smoothstep(threshold, threshold + 0.45, fbm(cp * 1.9 + vec2(3.1, 5.3)));
        vec3 cloud = mix(cloud_lit, cloud_shade, thick);
        cloud += sun_color * pow(mu, 5.0) * (1.0 - thick) * 0.8 * sun_visible;
        col = mix(col, cloud, c * smoothstep(0.0, 0.10, d.y));
        col += vec3(0.75, 0.80, 1.0) * flash * (0.25 + 1.6 * c);
    } else {
        col += vec3(0.75, 0.80, 1.0) * flash * 0.25;
    }

    COLOR = col * exposure;
    ALPHA = 1.0;
}
