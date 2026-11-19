// Shared Creature/NPC palette. Keep weights fractional and palette colors HDR.
uniform sampler2D p_Masks : source_color, hint_default_black, repeat_enable;
uniform vec4 p_ColorD = vec4(1.0);
uniform vec4 p_AColorMidtone = vec4(1.0);
uniform vec4 p_AColorHilight = vec4(1.0);
uniform vec4 p_AColorShadow = vec4(1.0);
uniform vec4 p_BColorMidtone = vec4(1.0);
uniform vec4 p_BColorHilight = vec4(1.0);
uniform vec4 p_BColorShadow = vec4(1.0);
uniform vec4 p_CColorMidtone = vec4(1.0);
uniform vec4 p_CColorHilight = vec4(1.0);
uniform vec4 p_CColorShadow = vec4(1.0);
uniform float p_HighlightsIntensity = 2.0;
uniform float p_ShadowsIntensity = 2.0;

vec3 character_palette(vec2 uv, out vec3 tones, out vec3 abc) {
    vec2 half_uv = uv * vec2(0.5, 1.0);
    tones = texture(p_Masks, half_uv).rgb;
    abc = texture(p_Masks, half_uv + vec2(0.5, 0.0)).rgb;
    vec2 hs = clamp(tones.rg * vec2(p_HighlightsIntensity, p_ShadowsIntensity), 0.0, 1.0);
    vec3 a = mix(mix(p_AColorMidtone.rgb, p_AColorHilight.rgb, hs.x), p_AColorShadow.rgb, hs.y);
    vec3 b = mix(mix(p_BColorMidtone.rgb, p_BColorHilight.rgb, hs.x), p_BColorShadow.rgb, hs.y);
    vec3 c = mix(mix(p_CColorMidtone.rgb, p_CColorHilight.rgb, hs.x), p_CColorShadow.rgb, hs.y);
    return mix(mix(mix(p_ColorD.rgb, a, abc.r), b, abc.g), c, abc.b);
}
