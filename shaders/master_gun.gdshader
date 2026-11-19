shader_type spatial;
// The observed cooked map has no material-driven direct specular color.
render_mode diffuse_lambert, specular_disabled;
#include "res://shaders/master_gun_parameters.gdshaderinc"

void fragment() {
    vec3 abc = packed_zones(UV);
    float gray = diffuse_gray(UV);
    vec3 paint = painted_surface(UV, UV2, gray, abc);
    vec3 ne = texture(p_NormalScopesEmissive, UV).rgb;
    vec3 normal_ue = gun_tangent_normal(ne.rg);
    vec3 reflection = reflection_diffuse(abc, paint, normal_ue, VIEW,
                                         mat3(TANGENT, BINORMAL, NORMAL), NODE_POSITION_WORLD);
    // The cooked material adds the fake reflection to diffuse before lighting.
    ALBEDO = max((paint + reflection) * 0.4, vec3(0.0));
    NORMAL_MAP = normal_ue * vec3(1.0, -1.0, 1.0) * 0.5 + 0.5;
    NORMAL_MAP_DEPTH = 1.0;
    SPECULAR = 0.0;
    // The base pass thresholds the original class gray rather than fading paint.
    float digistruct = step(2.02 - 1.1 * p_DigiStruct, gray);
    EMISSION = min(ne.b * p_EmissiveColor.rgb * p_EmissiveScale
                  + digistruct * p_DigiStructColor.rgb, vec3(4.0));
}

void light() {
    float ndotl = max(dot(NORMAL, LIGHT), 0.0);
    DIFFUSE_LIGHT += ndotl * ATTENUATION * LIGHT_COLOR / PI;
}
