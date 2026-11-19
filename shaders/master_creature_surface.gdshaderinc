uniform sampler2D p_Diffuse : source_color, hint_default_white, repeat_enable;
uniform sampler2D p_Normal : hint_normal, repeat_enable;
#include "res://shaders/character_palette.gdshaderinc"
uniform sampler2D p_CustomPattern : source_color, hint_default_white, repeat_enable;
uniform sampler2D fixed_death : source_color, repeat_enable;
uniform bool has_fixed_death = false;
uniform samplerCube fixed_fog : source_color;
uniform bool has_fixed_fog = false;
uniform float P_DeathsValue = 0.0;
uniform vec4 p_ElementalDeathColor = vec4(1.0);
uniform float p_fade = 1.0;
uniform vec4 p_DissolveColor = vec4(1.0);
uniform vec4 p_EmissiveScale = vec4(1.0);
uniform bool P_MuscleFatSwitch = false;
uniform vec4 p_MuscleFat = vec4(0.0, 0.0, 0.0, 1.0);
uniform bool P_PatternSwitch = true;
uniform vec4 mp_PatternSelect = vec4(1.0, 0.0, 0.0, 0.0);
uniform vec4 p_PatternScalePosition = vec4(1.0, 1.0, 0.0, 0.0);
uniform float p_UVChannelSelect = 0.0;
uniform float p_PatternInvert = 0.0;
uniform float p_PatternIntensity = 0.0;
uniform vec4 p_PatternColor = vec4(0.5, 0.5, 0.5, 2.0);

void vertex() {
    if (P_MuscleFatSwitch) { VERTEX += NORMAL * (dot(COLOR.rg, p_MuscleFat.xy) * 0.01); }
}

void creature_surface(vec2 uv, vec2 uv2, vec3 view, mat3 basis, out vec3 diffuse, out vec3 n, out vec3 emission, out vec3 pattern, out float clip_value) {
    vec3 raw = texture(p_Diffuse, uv).rgb;
    n = texture(p_Normal, uv).rgb * 2.0 - 1.0;
    n = dot(n, n) > 0.0 ? normalize(n) : vec3(0.0, 0.0, 1.0);
    vec3 tones, abc;
    vec3 tint = character_palette(uv, tones, abc);
    pattern = vec3(0.0);
    if (P_PatternSwitch) {
        vec2 coords = mix(uv, 2.0 * uv2, p_UVChannelSelect) * p_PatternScalePosition.xy + p_PatternScalePosition.zw;
        vec4 texel = texture(p_CustomPattern, coords);
        vec3 selected = all(equal(mp_PatternSelect, vec4(1.0, 1.0, 1.0, 0.0))) ? texel.rgb : vec3(dot(texel, mp_PatternSelect));
        pattern = clamp(mix(selected, vec3(1.0) - selected, p_PatternInvert) * p_PatternIntensity, 0.0, 1.0);
        tint = mix(tint, p_PatternColor.rgb, pattern);
    }
    diffuse = raw * tint;
    emission = raw * tones.b * p_EmissiveScale.rgb;
    clip_value = 1.0;
    if (has_fixed_death) {
        vec4 death = texture(fixed_death, uv);
        if (has_fixed_fog && P_DeathsValue != 0.0) {
            vec3 camera_ue = normalize(view * basis) * vec3(1.0, -1.0, 1.0);
            vec3 fog = texture(fixed_fog, reflect(-camera_ue, n)).rgb;
            diffuse = mix(diffuse, (death.rgb + fog) * p_ElementalDeathColor.rgb, P_DeathsValue);
        }
        float edge = 1.1 * p_fade - death.a;
        clip_value = clamp(edge + 0.3, 0.0, 1.0);
        emission += (1.0 - floor(edge + 0.92)) * p_DissolveColor.rgb;
    }
    emission = min(emission, vec3(4.0));
}
