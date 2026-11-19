uniform sampler2D p_Diffuse : source_color, hint_default_white, repeat_enable;
uniform sampler2D p_DiffuseB : source_color, hint_default_white, repeat_enable;
#include "res://shaders/environment_palette_glow.gdshaderinc"
uniform sampler2D p_Normal : hint_normal, repeat_enable;
uniform sampler2D p_NormalB : hint_normal, repeat_enable;
uniform sampler2D p_VertexPaintNoise : source_color, hint_default_black, repeat_enable;
uniform sampler2D p_emissive : source_color, hint_default_white, repeat_enable;
uniform sampler2D P_SimpleReflect : source_color, hint_default_white, repeat_enable;
uniform vec4 p_Diff_UVMod = vec4(1.0);
uniform vec4 p_DiffMod = vec4(1.0);
uniform vec4 p_NormalMod = vec4(1.0);
uniform vec4 p_VertexPaintDifMod = vec4(1.0);
uniform vec4 p_EmissiveScale = vec4(1.0);
uniform vec4 P_SimpleReflectOffset = vec4(0.5, 0.5, 0.0, 1.0);
uniform float p_VertexNoiseMod = 8.0;
uniform vec4 chan_EmissiveMask = vec4(1.0, 0.0, 0.0, 0.0);
uniform bool sw_Emissive = false;
uniform bool sw_Normal = false;
uniform bool sw_SimpleReflect = false;
uniform bool sw_UV2 = false;
uniform bool sw_VertexPaint = false;
#include "res://shaders/environment_snow.gdshaderinc"
uniform vec4 p_VertexPaintNoiseMod = vec4(10.0, -1.0, 0.0, 1.0);

// Single-component keys replicate one channel. The RGB key keeps all three.
vec3 world_emissive_mask(vec4 texel) {
    if (all(equal(chan_EmissiveMask, vec4(1.0, 1.0, 1.0, 0.0)))) { return texel.rgb; }
    if (dot(chan_EmissiveMask, vec4(1.0)) == 1.0) { return vec3(dot(texel, chan_EmissiveMask)); }
    return vec3(0.0);
}

void world_surface(vec2 uv, vec2 uv2, float vertex_red, vec3 view, mat3 basis,
                   out vec3 diffuse, out vec3 normal_ue, out vec3 emission, out vec3 paint_weight) {
    vec2 primary = (sw_UV2 ? uv2 : uv) * p_Diff_UVMod.xy;
    vec2 secondary = uv * p_Diff_UVMod.zw;
    vec3 raw_diffuse = texture(p_Diffuse, primary).rgb;
    diffuse = raw_diffuse;
    paint_weight = vec3(0.0);
    if (sw_VertexPaint) {
        vec3 noise = texture(p_VertexPaintNoise, uv * p_VertexNoiseMod).rgb;
        paint_weight = clamp(vertex_red + (1.0 - abs(2.0 * vertex_red - 1.0)) * (6.0 * noise - 1.0), 0.0, 1.0);
        diffuse = mix(diffuse, texture(p_DiffuseB, secondary).rgb * p_VertexPaintDifMod.rgb, paint_weight);
    }
    diffuse *= p_DiffMod.rgb;
    normal_ue = vec3(0.0, 0.0, 1.0);
    vec3 slope_normal = normal_ue;
    if (sw_Normal) {
        vec3 n = texture(p_Normal, primary).rgb * 2.0 - 1.0;
        if (sw_VertexPaint) { n = mix(n, texture(p_NormalB, secondary).rgb * 2.0 - 1.0, paint_weight); }
        n *= p_NormalMod.rgb;
        slope_normal = n;
        if (dot(n, n) > 0.0) { normal_ue = normalize(n); }
    }
    if (sw_SimpleReflect) {
        vec3 camera_ue = normalize(view * basis) * vec3(1.0, -1.0, 1.0);
        vec2 lookup = reflect(-camera_ue, normal_ue).xy + P_SimpleReflectOffset.xy;
        diffuse += texture(P_SimpleReflect, lookup).rgb;
    }
    vec3 glow_base = diffuse;
    if (sw_Colorize) { diffuse *= environment_tint(uv, vec4(0.0, 1.0, 0.0, 1.0)); }
    if (sw_EnableSnowOnTop && has_fixed_snow_noise) {
        diffuse = projected_snow(diffuse, slope_normal, vec4(0.0, 0.0, 1.0, 0.0), p_VertexPaintNoiseMod.xy);
    }
    emission = vec3(0.0);
    if (sw_Emissive) {
        vec3 mask = world_emissive_mask(texture(p_emissive, uv));
        emission = raw_diffuse * p_EmissiveScale.rgb * mask;
    }
    if (sw_Glow && has_fixed_glow_noise) {
        emission += environment_glow(position_ue_cm.xy, uv.y, glow_base);
    }
    emission = min(vec3(4.0), emission);
}
