#include "res://shaders/environment_snow.gdshaderinc"

uniform sampler2D p_Diffuse : source_color, hint_default_white, repeat_enable;
uniform sampler2D p_DiffuseFade : source_color, hint_default_white, repeat_enable;
uniform sampler2D p_DiffuseVertexPaint : source_color, hint_default_white, repeat_enable;
uniform sampler2D p_VertexPaintNoise : source_color, hint_default_black, repeat_enable;
uniform sampler2D p_Normal : hint_normal, repeat_enable;
uniform sampler2D p_NormalB : hint_normal, repeat_enable;
uniform vec4 p_Diff_UVMod = vec4(1.0);
uniform vec4 p_Normal_UVMod = vec4(1.0);
uniform vec4 p_DiffMod = vec4(1.0);
uniform vec4 p_NormalMod = vec4(1.0);
uniform vec4 p_DiffuseFadeUVMod = vec4(1.0, 1.0, 0.0, 1.0);
uniform vec4 p_DiffuseFadeMod = vec4(1.0);
uniform vec4 p_VertexPaintDifMod = vec4(1.0);
uniform vec4 p_VertexPaintNoiseMod = vec4(6.0, -1.0, 0.0, 1.0);
uniform vec4 p_VertexPaintNoiseChan = vec4(0.0, 0.0, 1.0, 0.0);
uniform float p_VertexNoiseUVMod = 8.0;
uniform float p_FadeWidth = 0.0003;
uniform float p_FadeHeight = -1.1;
uniform bool sw_VertexPaint = false;
uniform bool sw_UV2 = false;
uniform bool sw_HeightFade = false;

void rock_surface(vec2 uv, vec2 uv2, float vertex_red, out vec3 diffuse, out vec3 n, out vec3 paint, out float fade) {
    vec2 primary = sw_UV2 ? uv2 : uv;
    diffuse = texture(p_Diffuse, primary * p_Diff_UVMod.xy).rgb;
    vec3 decoded = texture(p_Normal, primary * p_Normal_UVMod.xy).rgb * 2.0 - 1.0;
    fade = 0.0;
    if (sw_HeightFade) {
        fade = clamp(position_ue_cm.z * p_FadeWidth + p_FadeHeight, 0.0, 1.0);
        diffuse = mix(diffuse, texture(p_DiffuseFade, uv * p_DiffuseFadeUVMod.xy).rgb * p_DiffuseFadeMod.rgb, fade);
    }
    paint = vec3(0.0);
    if (sw_VertexPaint) {
        vec4 noise = texture(p_VertexPaintNoise, uv * p_VertexNoiseUVMod);
        paint = noise_blend(vertex_red, environment_channels(noise, p_VertexPaintNoiseChan), p_VertexPaintNoiseMod.xy);

        decoded = mix(decoded, texture(p_NormalB, primary * p_Normal_UVMod.zw).rgb * 2.0 - 1.0, paint);
        diffuse = mix(diffuse, texture(p_DiffuseVertexPaint, uv * p_Diff_UVMod.zw).rgb * p_VertexPaintDifMod.rgb, paint);
    }
    n = decoded * p_NormalMod.rgb;
    n = dot(n, n) > 0.0 ? normalize(n) : vec3(0.0, 0.0, 1.0);
    diffuse *= p_DiffMod.rgb;
    if (sw_EnableSnowOnTop && has_fixed_snow_noise) {
        diffuse = projected_snow(diffuse, decoded, p_VertexPaintNoiseChan, p_VertexPaintNoiseMod.xy);
    }
}
