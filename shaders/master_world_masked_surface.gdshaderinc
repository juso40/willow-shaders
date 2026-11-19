// Master_WorldMasked local factory. Opacity is a scalar, even in the RGB/RGBA keys.
#include "res://shaders/environment_projection.gdshaderinc"
#include "res://shaders/environment_palette_glow.gdshaderinc"
uniform sampler2D p_Diffuse : source_color, hint_default_white, repeat_enable;
uniform sampler2D p_Masked : hint_default_white, repeat_enable;
uniform sampler2D p_Normal : hint_normal, repeat_enable;
uniform sampler2D p_emissive : source_color, hint_default_white, repeat_enable;
uniform sampler2D p_SnowDiffuse : source_color, hint_default_white, repeat_enable;
uniform sampler2D p_VertexPaintNoise : source_color, hint_default_black, repeat_enable;
uniform vec4 chan_OpacityMask = vec4(1.0, 0.0, 0.0, 0.0);
uniform vec4 chan_EmissiveMask = vec4(1.0, 0.0, 0.0, 0.0);
uniform vec4 p_Diff_UVMod = vec4(1.0);
uniform vec4 p_DiffMod_DiffPow = vec4(1.0);
uniform vec4 p_NormalMod = vec4(1.0);
uniform vec4 p_ClampMasks = vec4(0.0, 1.0, 0.0, 1.0);
uniform vec4 p_EmissiveScale = vec4(1.0);
uniform vec4 p_VertexPaintNoiseMod = vec4(10.0, -1.0, 0.0, 1.0);
uniform bool sw_Normal = false;
uniform bool sw_Emissive = false;
uniform bool sw_EnableSnowOnTop = false;

float masked_coverage(vec2 primary) {
    vec4 mask = texture(p_Masked, primary);
    if (chan_OpacityMask.r != 0.0) { return mask.r; }
    if (chan_OpacityMask.g != 0.0) { return mask.g; }
    if (chan_OpacityMask.b != 0.0) { return mask.b; }
    return mask.a * chan_OpacityMask.a;
}

void masked_surface(vec2 uv, vec2 primary, out vec3 diffuse, out vec3 n, out vec3 emission) {
    vec3 raw = texture(p_Diffuse, primary).rgb;
    vec3 modulated = raw * p_DiffMod_DiffPow.rgb;
    diffuse = modulated;
    n = vec3(0.0, 0.0, 1.0);
    if (sw_Normal) {
        vec3 decoded = (2.0 * texture(p_Normal, primary).rgb - 1.0) * p_NormalMod.rgb;
        if (dot(decoded, decoded) > 0.0) { n = normalize(decoded); }
    }
    if (sw_Colorize) { diffuse *= environment_tint(uv, p_ClampMasks); }
    if (sw_EnableSnowOnTop) {
        float slope = clamp(tangent_up.z / max(length(tangent_up), 0.000001), 0.0, 1.0);
        float base = clamp(300.0 * pow(slope, 25.0), 0.0, 1.0);
        float noise = texture(p_VertexPaintNoise, position_ue_cm.xy * 0.003).r;
        float weight = noise_blend(base, vec3(noise), p_VertexPaintNoiseMod.xy).x;
        diffuse = mix(diffuse, texture(p_SnowDiffuse, position_ue_cm.xy * 0.0003).rgb, weight);
    }
    emission = vec3(0.0);
    if (sw_Emissive) {
        vec4 texel = texture(p_emissive, uv);
        vec3 mask = all(equal(chan_EmissiveMask, vec4(1.0, 1.0, 1.0, 0.0))) ? texel.rgb : vec3(dot(texel, chan_EmissiveMask));
        emission = raw * p_EmissiveScale.rgb * p_EmissiveScale.a * mask;
    }
    if (sw_Glow && has_fixed_glow_noise) { emission += environment_glow(position_ue_cm.xy, uv.y, modulated); }
    emission = min(emission, vec3(4.0));
}
