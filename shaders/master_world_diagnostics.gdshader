shader_type spatial;
render_mode unshaded;
#include "master_world_surface.gdshaderinc"

uniform int diagnostic_view = 1;

void fragment() {
    vec3 diffuse, n, emission, weight;
    world_surface(UV, UV2, COLOR.r, VIEW, mat3(TANGENT, BINORMAL, NORMAL), diffuse, n, emission, weight);
    ALBEDO = diffuse;
    if (diagnostic_view == 30) { ALBEDO = weight; }
    else if (diagnostic_view == 31) { ALBEDO = n * 0.5 + 0.5; }
    else if (diagnostic_view == 32) { ALBEDO = emission; }
}
