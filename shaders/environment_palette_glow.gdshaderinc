// Left-half highlight/shadow masks and right-half A/B/C zones on UV0.
uniform sampler2D p_Masks : source_color, hint_default_black, repeat_enable;
uniform float p_HighlightsIntensity = 2.0;
uniform float p_ShadowsIntensity = 2.0;
uniform vec4 p_AColorMidtone = vec4(1.0);
uniform vec4 p_AColorHilight = vec4(1.0);
uniform vec4 p_AColorShadow = vec4(1.0);
uniform vec4 p_BColorMidtone = vec4(1.0);
uniform vec4 p_BColorHilight = vec4(1.0);
uniform vec4 p_BColorShadow = vec4(1.0);
uniform vec4 p_CColorMidtone = vec4(1.0);
uniform vec4 p_CColorHilight = vec4(1.0);
uniform vec4 p_CColorShadow = vec4(1.0);
uniform bool sw_Colorize = false;
uniform bool sw_Glow = false;
uniform sampler2D fixed_glow_noise : source_color, repeat_enable;
uniform bool has_fixed_glow_noise = false;
uniform float p_GlowScale = 1.0;
uniform vec4 p_GlowColor = vec4(0.0, 3.0, 0.0, 1.0);

vec3 environment_tint(vec2 uv, vec4 limits) {
    vec2 half_uv = uv * vec2(0.5, 1.0);
    vec2 tones = texture(p_Masks, half_uv).rg * vec2(p_HighlightsIntensity, p_ShadowsIntensity);
    vec2 hs = min(max(tones, limits.xz), limits.yw);
    vec3 abc = texture(p_Masks, half_uv + vec2(0.5, 0.0)).rgb;
    vec3 a = mix(mix(p_AColorMidtone.rgb, p_AColorHilight.rgb, hs.x), p_AColorShadow.rgb, hs.y);
    vec3 b = mix(mix(p_BColorMidtone.rgb, p_BColorHilight.rgb, hs.x), p_BColorShadow.rgb, hs.y);
    vec3 c = mix(mix(p_CColorMidtone.rgb, p_CColorHilight.rgb, hs.x), p_CColorShadow.rgb, hs.y);
    return mix(mix(mix(vec3(1.0), a, abc.r), b, abc.g), c, abc.b);
}

vec3 environment_glow(vec2 world_xy_cm, float uv_y, vec3 modulated_diffuse) {
    float noise = texture(fixed_glow_noise, world_xy_cm * (0.0008 * p_GlowScale)).g;
    float phase = 8.0 * noise + 0.25 * uv_y + fract(TIME * 0.5);
    return modulated_diffuse * p_GlowColor.rgb * (p_GlowColor.a * (1.0 - sqrt(abs(sin(TAU * phase)))));
}
