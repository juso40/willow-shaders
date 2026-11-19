shader_type spatial;
render_mode diffuse_lambert, specular_disabled, cull_back;
#include "master_npc_surface.gdshaderinc"

void fragment() {
    if (npc_coverage() < 0.3333) { discard; }
    vec3 abc;
    ALBEDO = npc_diffuse(UV, abc);
    NORMAL = normalize(mat3(TANGENT, BINORMAL, NORMAL) * (npc_normal(UV) * vec3(1.0, -1.0, 1.0)));
    ROUGHNESS = 1.0;
    SPECULAR = 0.0;
}
