shader_type spatial;
render_mode cull_disabled, diffuse_lambert, specular_disabled;
#include "master_world_masked_surface.gdshaderinc"

void fragment() {
    vec2 primary = UV * p_Diff_UVMod.xy;
    if (masked_coverage(primary) < 0.3333) { discard; }
    vec3 diffuse, n, emission;
    masked_surface(UV, primary, diffuse, n, emission);
    ALBEDO = diffuse;
    if (sw_Normal) { NORMAL = normalize(mat3(TANGENT, BINORMAL, NORMAL) * (n * vec3(1.0, -1.0, 1.0))); }
    EMISSION = emission;
    ROUGHNESS = 1.0;
    SPECULAR = 0.0;
}
