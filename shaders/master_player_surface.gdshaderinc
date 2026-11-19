uniform sampler2D p_Diffuse : source_color, hint_default_white, repeat_enable;
uniform sampler2D p_Masks : source_color, hint_default_black, repeat_enable;
uniform sampler2D p_Normal : hint_normal, repeat_enable;
uniform sampler2D p_Pattern : source_color, hint_default_white, repeat_enable;
uniform sampler2D p_Decal : source_color, hint_default_transparent, repeat_enable;
uniform sampler2D P_SimpleReflect : source_color, hint_default_black, repeat_enable;
uniform sampler2D fixed_power_fire : source_color, repeat_enable;
uniform bool has_fixed_power_fire = false;
uniform sampler2D fixed_transition_lut : source_color, repeat_enable;
uniform bool has_fixed_transition_lut = false;
uniform sampler2D fixed_hologram : source_color, repeat_enable;
uniform bool has_fixed_hologram = false;
uniform bool sw_EnableHologram = false;
uniform float p_Hologram_Enable = 0.0;
uniform float p_DigiStructEnable = 0.0;
uniform float p_DigistructToggle = 0.0;
uniform float p_ColorStructEnable = 0.0;
uniform vec4 p_DigiStructColor = vec4(0.2, 1.0, 3.0, 1.0);
// Preview primitive bounds: mesh-local center and enclosing radius in meters.
instance uniform vec4 bl_player_bounds = vec4(0.0);
uniform bool sw_AsassinHead = false;
uniform vec4 p_ReflectColor = vec4(1.0);
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
uniform vec4 p_PatternScalePosition = vec4(1.0, 1.0, 0.0, 0.0);
uniform vec4 p_DecalScalePosition = vec4(1.0, 1.0, 0.0, 0.0);
uniform vec4 p_PatternColor = vec4(1.0);
uniform vec4 p_DecalColor = vec4(1.0);
uniform vec4 p_PatternChannelScale = vec4(1.0, 1.0, 1.0, 0.0);
uniform vec4 p_DecalChannelScale = vec4(1.0, 1.0, 1.0, 0.0);
uniform float p_PatternIntensity = 0.0;
uniform float p_DecalIntensity = 0.0;
uniform float p_PatternRotation = 0.0;
uniform vec4 p_EmissiveColor = vec4(0.023174, 9.047319, 1.309347, 1.0);
uniform vec4 p_PowerEmissiveColor = vec4(0.0, 14.554461, 20.0, 0.0);
uniform float p_EnablePowerEmissive = 0.0;
// Editor-only fallback for stand-in shapes. Never applied to imported meshes.
uniform bool bl_primitive_uv = false;
varying vec2 pattern_coords;
varying vec2 height_radius_cm;
void vertex() {
    pattern_coords = bl_primitive_uv ? UV : CUSTOM0.xy;
    mat3 model = mat3(MODEL_MATRIX);
    float scale = max(length(model[0]), max(length(model[1]), length(model[2])));
    height_radius_cm = 100.0 * vec2((model * (VERTEX - bl_player_bounds.xyz)).y, bl_player_bounds.w * scale);
}

float player_weight(vec3 abc, vec3 scale, float intensity) {
    vec3 zones = abc * scale;
    return clamp(dot(zones, zones) * intensity, 0.0, 1.0);
}

void player_surface(vec2 uv, vec2 uv2, vec3 view, mat3 basis, out vec3 diffuse, out vec3 n, out vec3 emission, out vec2 weights, out float coverage) {
    coverage = 1.0;
    vec3 raw = texture(p_Diffuse, uv).rgb;
    vec3 decoded = texture(p_Normal, uv).rgb * 2.0 - 1.0;
    n = decoded;
    n = dot(n, n) > 0.0 ? normalize(n) : vec3(0.0, 0.0, 1.0);
    vec2 half_uv = uv * vec2(0.5, 1.0);
    vec2 hs = clamp(texture(p_Masks, half_uv).rg * vec2(p_HighlightsIntensity, p_ShadowsIntensity), 0.0, 1.0);
    vec3 abc = texture(p_Masks, half_uv + vec2(0.5, 0.0)).rgb;
    vec3 a = mix(mix(p_AColorMidtone.rgb, p_AColorHilight.rgb, hs.x), p_AColorShadow.rgb, hs.y);
    vec3 b = mix(mix(p_BColorMidtone.rgb, p_BColorHilight.rgb, hs.x), p_BColorShadow.rgb, hs.y);
    vec3 c = mix(mix(p_CColorMidtone.rgb, p_CColorHilight.rgb, hs.x), p_CColorShadow.rgb, hs.y);
    vec3 tint = mix(mix(mix(vec3(1.0), a, abc.r), b, abc.g), c, abc.b);
    float angle = 3.1415901184 * p_PatternRotation;
    vec2 rotated = mat2(vec2(cos(angle), sin(angle)), vec2(-sin(angle), cos(angle))) * (pattern_coords - 0.5);
    vec2 pattern_uv = (rotated + p_PatternScalePosition.zw + 0.5) * p_PatternScalePosition.xy;
    weights.x = player_weight(abc, p_PatternChannelScale.rgb, p_PatternIntensity);
    tint = mix(tint, texture(p_Pattern, pattern_uv).rgb * p_PatternColor.rgb, weights.x);
    vec2 decal_uv = ((bl_primitive_uv ? uv : uv2) + p_DecalScalePosition.zw - 0.5) * p_DecalScalePosition.xy + 0.5;
    vec4 decal = texture(p_Decal, decal_uv);
    weights.y = player_weight(abc, p_DecalChannelScale.rgb, p_DecalIntensity) * decal.a;
    diffuse = raw * mix(tint, decal.rgb * p_DecalColor.rgb, weights.y);
    if (sw_AsassinHead) {
        vec3 camera_ue = normalize(view * basis) * vec3(1.0, -1.0, 1.0);
        vec2 lookup = reflect(-camera_ue, n).xy * vec2(2.0, 0.5);
        diffuse += raw * abc.r * texture(P_SimpleReflect, lookup).r * p_ReflectColor.rgb * pow(max(camera_ue.z, 0.0), 4.0);
    }
    diffuse *= 0.5;
    float ordinary = texture(p_Masks, uv * 0.5).b;
    emission = ordinary * p_EmissiveColor.rgb;
    if (has_fixed_power_fire && p_EnablePowerEmissive != 0.0) {
        float power = texture(p_Masks, uv * 0.5 + vec2(0.0, 0.5)).b;
        float fire = texture(fixed_power_fire, uv * 0.6 + fract(TIME * vec2(0.003334, -0.033333))).r;
        emission += power * (1.0 - fire * fire) * p_PowerEmissiveColor.rgb * p_EnablePowerEmissive;
    }
    emission *= raw;
    if (sw_EnableHologram && has_fixed_hologram) {
        vec3 camera_ue = normalize(view * basis) * vec3(1.0, -1.0, 1.0);
        float facing = dot(decoded, camera_ue);
        float rim = facing < 0.0 ? 1.0 : abs(1.0 - facing);
        float scan = texture(fixed_hologram, uv + vec2(0.0, fract(-TIME))).g;
        emission += vec3(0.0, 3.0, 4.0) * scan * pow(rim, 5.0) * p_Hologram_Enable;
    }
    if (has_fixed_transition_lut && p_DigistructToggle != 0.0) {
        float phase = fract(-0.2 * p_DigiStructEnable);
        float lut = texture(fixed_transition_lut, uv).r;
        float sweep = clamp(lut * height_radius_cm.x + (2.0 * phase - 1.0) * height_radius_cm.y * 0.2, 0.0, 1.0);
        float amount = p_DigistructToggle * sweep;
        coverage = mix(1.0 - amount, 1.0, p_ColorStructEnable);
        diffuse = mix(diffuse, raw, amount * p_ColorStructEnable);
        if (!sw_EnableHologram) { emission += amount * p_DigiStructColor.rgb; }
    }
    emission = min(emission * (1.0 - p_ColorStructEnable), vec3(4.0));
}
