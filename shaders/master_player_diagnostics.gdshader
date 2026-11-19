shader_type spatial;
render_mode unshaded;
#include "master_player_surface.gdshaderinc"

uniform int diagnostic_view = 1;
void fragment() {
    vec3 diffuse, n, emission;
    vec2 weights;
    float coverage;
    player_surface(UV, UV2, VIEW, mat3(TANGENT, BINORMAL, NORMAL), diffuse, n, emission, weights, coverage);
    if (coverage < 0.3333 && diagnostic_view != 33) { discard; }
    ALBEDO = diffuse;
    if (diagnostic_view == 30) { ALBEDO = vec3(weights.x); }
    else if (diagnostic_view == 31) { ALBEDO = vec3(weights.y); }
    else if (diagnostic_view == 32) { ALBEDO = emission; }
    else if (diagnostic_view == 33) { ALBEDO = vec3(coverage); }
}
