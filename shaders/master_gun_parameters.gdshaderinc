group_uniforms Atlas;
uniform sampler2D p_Diffuse : source_color, filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D p_Masks : filter_linear_mipmap_anisotropic, repeat_enable;
// Never hint_normal: blue stores emissive, not normal Z.
uniform sampler2D p_NormalScopesEmissive : filter_linear_mipmap_anisotropic, repeat_enable;
uniform vec4 p_WeapClassSelect = vec4(1.0, 0.0, 0.0, 0.0);

group_uniforms Palette_A;
uniform vec4 p_AColorHilight : source_color = vec4(1.0);
uniform vec4 p_AColorMidtone : source_color = vec4(1.0);
uniform vec4 p_AColorShadow : source_color = vec4(1.0);
group_uniforms Palette_B;
uniform vec4 p_BColorHilight : source_color = vec4(1.0);
uniform vec4 p_BColorMidtone : source_color = vec4(1.0);
uniform vec4 p_BColorShadow : source_color = vec4(1.0);
group_uniforms Palette_C;
uniform vec4 p_CColorHilight : source_color = vec4(1.0);
uniform vec4 p_CColorMidtone : source_color = vec4(1.0);
uniform vec4 p_CColorShadow : source_color = vec4(1.0);
group_uniforms Palette_Tones;
uniform vec4 p_DColor : source_color = vec4(1.0);
uniform float p_HighlightsIntensity = 2.0;
uniform float p_ShadowsIntensity = 2.0;

group_uniforms Pattern;
uniform sampler2D p_Pattern : source_color, filter_linear_mipmap_anisotropic, repeat_enable;
uniform vec4 p_PatternColor : source_color = vec4(1.0);
uniform vec4 p_PatternScalePosition = vec4(1.0, 1.0, 0.0, 0.0);
uniform vec4 p_PatternChannelScale = vec4(0.0);
uniform vec4 p_PatternChannel = vec4(1.0, 0.0, 0.0, 0.0);
uniform float p_ReplacePattern = 0.0;

group_uniforms Decal;
// The cooked no-decal stub has zero RGB and alpha. An opaque fallback
// would cover the paint when full-color decals use alpha for coverage.
uniform sampler2D p_Decal : source_color, hint_default_transparent, filter_linear_mipmap_anisotropic, repeat_disable;
uniform vec4 p_DecalColor : source_color = vec4(1.0);
uniform vec4 p_DecalScalePosition = vec4(1.0, 1.0, 0.0, 0.0);
uniform vec4 p_DecalChannel = vec4(1.0);
// GPU binding alias only: UE has BOTH a vector and a static mask named
// p_DecalChannel. The MIC/UI store the original name in separate categories.
uniform vec4 p_DecalChannelStaticMask = vec4(1.0, 1.0, 1.0, 0.0);
uniform float p_DecalRotate = 0.0;
uniform float p_ReplaceDecal = 0.0;
uniform float p_UseFullColorDecal = 1.0;
uniform bool sw_FlipDecalOnRightSide = false;

group_uniforms Reflection;
uniform vec4 p_ReflectionChannelScale = vec4(1.0);
uniform vec4 p_ReflectColor : source_color = vec4(1.0);
uniform float p_ReflectColorScale = 1.0;
uniform sampler2D P_SimpleReflect : source_color, hint_default_black, filter_linear_mipmap, repeat_enable;

group_uniforms Emissive;
uniform vec4 p_EmissiveColor : source_color = vec4(0.0, 0.0, 0.0, 1.0);
uniform float p_EmissiveScale = 1.0;
uniform float p_DigiStruct = 0.0;
uniform vec4 p_DigiStructColor : source_color = vec4(0.399341, 1.158091, 1.828227, 1.0);

float selected_channel(vec4 sample_value, vec4 mask) {
    return clamp(dot(sample_value, mask), 0.0, 1.0);
}
float diffuse_gray(vec2 uv) {
    return selected_channel(texture(p_Diffuse, uv), p_WeapClassSelect);
}
vec2 tone_masks(vec2 uv) {
    return texture(p_Masks, uv * vec2(1.0, 0.5)).rg;
}
vec3 packed_zones(vec2 uv) {
    return texture(p_Masks, uv * vec2(1.0, 0.5) + vec2(0.0, 0.5)).rgb;
}
vec4 material_zones(vec3 abc) {
    // Equivalent to mixing D -> A -> B -> C in that order.
    vec3 inv = 1.0 - abc;
    return vec4(abc.r * inv.g * inv.b, abc.g * inv.b, abc.b, inv.r * inv.g * inv.b);
}
vec3 palette(vec3 high, vec3 mid, vec3 shadow, vec2 hs) {
    vec3 color = mix(mid, high, clamp(hs.x * p_HighlightsIntensity, 0.0, 1.0));
    return mix(color, shadow, clamp(hs.y * p_ShadowsIntensity, 0.0, 1.0));
}
vec3 selected_color(vec4 sample_value, vec4 mask) {
    // A UE component mask selects components. It does NOT sum RGB into opacity.
    // Single-channel output broadcasts as a scalar. RGB output retains color.
    vec3 result = vec3(0.0);
    int count = 0;
    for (int component = 0; component < 4; component++) {
        if (mask[component] > 0.5) {
            if (count < 3) { result[count] = sample_value[component]; }
            count++;
        }
    }
    if (count == 1) { result = vec3(result.r); }
    return result;
}
vec3 gun_tangent_normal(vec2 rg) {
    vec2 xy = rg * 2.0 - 1.0;
    float z = sqrt(max(1.0 - dot(xy, xy), 0.0));
    return normalize(vec3(xy, 0.8 * z));
}
float zone_coverage(vec3 abc, vec4 scale) {
    vec3 weighted = abc * scale.rgb;
    return clamp(dot(weighted, weighted), 0.0, 1.0);
}
vec3 reflection_diffuse(vec3 abc, vec3 paint, vec3 normal_ue,
                        vec3 view, mat3 tangent_to_view, vec3 object_position) {
    // Project the camera direction into the mesh basis, undoing the port's
    // bitangent sign convention. The lookup uses raw tangent reflection XY.
    vec3 camera_ue = normalize(view * tangent_to_view) * vec3(1.0, -1.0, 1.0);
    vec2 reflected = reflect(-camera_ue, normal_ue).xy;
    // Use the preview node origin as a proxy for UE3 primitive bounds center.
    // The preview uses meters and Y-up, the game uses centimeters and Z-up.
    vec2 phase = fract(vec2(object_position.x, -object_position.z) * 0.1);
    vec3 lookup = texture(P_SimpleReflect, reflected + phase).rgb;
    return lookup * p_ReflectColor.rgb * zone_coverage(abc, p_ReflectionChannelScale)
         * mix(vec3(1.0), paint, p_ReflectColorScale);
}
vec2 placed_decal_uv(vec2 decoration_uv) {
    vec2 centered = decoration_uv + p_DecalScalePosition.zw - vec2(0.5);
    float angle = p_DecalRotate * 3.1415901184;
    vec2 rotated = mat2(vec2(cos(angle), sin(angle)), vec2(-sin(angle), cos(angle))) * centered;
    vec2 duv = rotated * p_DecalScalePosition.xy + vec2(0.5);
    // Preview-only side test. The cooked flip permutation instead uses a
    // local transform of the skinned tangent basis, not the sign of UV2.
    if (sw_FlipDecalOnRightSide && decoration_uv.x < 0.0) { duv.x = 1.0 - duv.x; }
    return duv;
}
vec3 decal_coverage(vec4 decal, vec3 selected, vec3 abc) {
    return mix(selected, vec3(decal.a), p_UseFullColorDecal) * zone_coverage(abc, p_DecalChannel);
}
vec3 overlay(vec3 paint, vec3 ink, vec3 coverage, float replace) {
    vec3 multiply_result = paint * mix(vec3(1.0), ink, coverage);
    vec3 replace_result = mix(paint, ink, coverage);
    return mix(multiply_result, replace_result, replace);
}
vec3 painted_surface(vec2 uv, vec2 decoration_uv, float gray, vec3 abc) {
    vec4 zones = material_zones(abc);
    vec2 hs = tone_masks(uv);
    vec3 tint = zones.r * palette(p_AColorHilight.rgb, p_AColorMidtone.rgb, p_AColorShadow.rgb, hs)
              + zones.g * palette(p_BColorHilight.rgb, p_BColorMidtone.rgb, p_BColorShadow.rgb, hs)
              + zones.b * palette(p_CColorHilight.rgb, p_CColorMidtone.rgb, p_CColorShadow.rgb, hs)
              + zones.a * p_DColor.rgb;
    vec2 pattern_uv = decoration_uv * p_PatternScalePosition.xy + p_PatternScalePosition.zw;
    vec3 pattern_ink = selected_color(texture(p_Pattern, pattern_uv), p_PatternChannel) * p_PatternColor.rgb;
    vec3 paint = overlay(tint, pattern_ink, vec3(zone_coverage(abc, p_PatternChannelScale)), p_ReplacePattern);

    vec4 decal = texture(p_Decal, placed_decal_uv(decoration_uv));
    vec3 selected = selected_color(decal, p_DecalChannelStaticMask);
    vec3 ink = mix(vec3(1.0), selected, p_UseFullColorDecal) * p_DecalColor.rgb;
    return gray * overlay(paint, ink, decal_coverage(decal, selected, abc), p_ReplaceDecal);
}
