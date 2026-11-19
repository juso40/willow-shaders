shader_type spatial;
render_mode unshaded, cull_back;
#include "master_npc_surface.gdshaderinc"

uniform int diagnostic_view = 1;
void fragment() {
    float coverage = npc_coverage();
    if (coverage < 0.3333 && diagnostic_view != 33) { discard; }
    vec3 abc;
    ALBEDO = npc_diffuse(UV, abc);
    if (diagnostic_view == 30) { ALBEDO = abc; }
    else if (diagnostic_view == 31) { ALBEDO = npc_normal(UV) * 0.5 + 0.5; }
    else if (diagnostic_view == 32) { ALBEDO = vec3(npc_weights.rg, 0.0); }
    else if (diagnostic_view == 33) { ALBEDO = vec3(clamp(coverage, 0.0, 1.0)); }
}
