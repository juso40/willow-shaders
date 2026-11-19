shader_type spatial;
render_mode cull_disabled, unshaded;
#include "master_world_masked_surface.gdshaderinc"

uniform int diagnostic_view = 1;
void fragment() {
    vec2 primary = UV * p_Diff_UVMod.xy;
    float coverage = masked_coverage(primary);
    if (coverage < 0.3333 && diagnostic_view != 30) { discard; }
    vec3 diffuse, n, emission;
    masked_surface(UV, primary, diffuse, n, emission);
    ALBEDO = diffuse;
    if (diagnostic_view == 30) { ALBEDO = vec3(coverage); }
    else if (diagnostic_view == 31) { ALBEDO = n * 0.5 + 0.5; }
    else if (diagnostic_view == 32) { ALBEDO = emission; }
}
