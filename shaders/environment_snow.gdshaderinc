uniform bool sw_EnableSnowOnTop = false;
uniform sampler2D fixed_snow_noise : source_color, repeat_enable;
uniform bool has_fixed_snow_noise = false;
uniform sampler2D p_SnowDiffuse : source_color, repeat_enable;
uniform vec4 p_SnowColor = vec4(1.0);
uniform vec4 p_SnowAmount = vec4(1.0);
uniform float p_SnowUVScale = 1.0;
uniform float p_SnowNoiseUVScale = 1.0;
#include "res://shaders/environment_projection.gdshaderinc"

vec3 environment_channels(vec4 texel, vec4 channels) {
    if (all(equal(channels, vec4(1.0, 1.0, 1.0, 0.0)))) { return texel.rgb; }
    return vec3(dot(texel, channels));
}

vec3 projected_snow(vec3 diffuse, vec3 slope_normal, vec4 channels, vec2 noise_mod) {
    vec3 up = tangent_up / max(length(tangent_up), 0.000001);
    float slope = clamp(dot(up, slope_normal * p_SnowAmount.rgb), 0.0, 1.0);
    float w = clamp(100.0 * pow(slope, 25.0), 0.0, 1.0);
    vec4 noise = texture(fixed_snow_noise, position_ue_cm.xy * (0.003 * p_SnowNoiseUVScale));
    vec3 weights = noise_blend(w, environment_channels(noise, channels), noise_mod);
    return mix(diffuse, texture(p_SnowDiffuse, position_ue_cm.xy * (0.0003 * p_SnowUVScale)).rgb * p_SnowColor.rgb, weights);
}
