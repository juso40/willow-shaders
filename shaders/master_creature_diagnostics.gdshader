shader_type spatial;
render_mode cull_disabled, unshaded;
#include "master_creature_surface.gdshaderinc"

uniform int diagnostic_view = 1;
void fragment() {
    vec3 diffuse, n, emission, pattern;
    float coverage;
    creature_surface(UV, UV2, VIEW, mat3(TANGENT, BINORMAL, NORMAL), diffuse, n, emission, pattern, coverage);
    if (coverage < 0.3333 && diagnostic_view != 33) { discard; }
    ALBEDO = diffuse;
    if (diagnostic_view == 30) { ALBEDO = pattern; }
    else if (diagnostic_view == 31) { ALBEDO = n * 0.5 + 0.5; }
    else if (diagnostic_view == 32) { ALBEDO = emission; }
    else if (diagnostic_view == 33) { ALBEDO = vec3(coverage); }
    else if (diagnostic_view == 34) { ALBEDO = vec3(COLOR.rg, 0.0); }
}
