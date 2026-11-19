shader_type spatial;
render_mode unshaded;
// Master_Gun reconstruction diagnostics, not exported game parameters.
#include "res://shaders/master_gun_parameters.gdshaderinc"
uniform int diagnostic_view = 30;

void fragment() {
    vec3 abc = packed_zones(UV);
    vec4 zones = material_zones(abc);
    float gray = diffuse_gray(UV);
    vec3 debug = vec3(gray);
    if (diagnostic_view == 1) { debug = painted_surface(UV, UV2, gray, abc); }
    else if (diagnostic_view == 31) { debug = abc; }
    else if (diagnostic_view >= 32 && diagnostic_view <= 35) { debug = vec3(zones[diagnostic_view - 32]); }
    else if (diagnostic_view == 36) { debug = vec3(tone_masks(UV).r); }
    else if (diagnostic_view == 37) { debug = vec3(tone_masks(UV).g); }
    else if (diagnostic_view == 38) { debug = gun_tangent_normal(texture(p_NormalScopesEmissive, UV).rg) * 0.5 + 0.5; }
    else if (diagnostic_view == 39) { debug = vec3(texture(p_NormalScopesEmissive, UV).b); }
    else if (diagnostic_view == 40) { debug = vec3(zone_coverage(abc, p_PatternChannelScale)); }
    else if (diagnostic_view == 41) {
        vec2 uv = UV2 * p_PatternScalePosition.xy + p_PatternScalePosition.zw;
        debug = selected_color(texture(p_Pattern, uv), p_PatternChannel) * p_PatternColor.rgb;
    } else if (diagnostic_view == 42) { debug = vec3(zone_coverage(abc, p_ReflectionChannelScale)); }
    else if (diagnostic_view == 43) {
        vec2 cell = floor(clamp(UV, vec2(0.0), vec2(0.9999)) * vec2(3.0, 2.0));
        debug = vec3((cell.x + 1.0) / 3.0, cell.y * 0.7 + 0.15, 0.35);
    } else if (diagnostic_view == 44) {
        vec4 decal = texture(p_Decal, placed_decal_uv(UV2));
        debug = decal_coverage(decal, selected_color(decal, p_DecalChannelStaticMask), abc);
    } else if (diagnostic_view == 45) {
        vec3 normal_ue = gun_tangent_normal(texture(p_NormalScopesEmissive, UV).rg);
        vec3 paint = painted_surface(UV, UV2, gray, abc);
        debug = reflection_diffuse(abc, paint, normal_ue, VIEW,
                                   mat3(TANGENT, BINORMAL, NORMAL), NODE_POSITION_WORLD);
    }
    ALBEDO = debug;
}
