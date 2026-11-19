shader_type spatial;
render_mode unshaded;
#include "master_rocks_surface.gdshaderinc"

uniform int diagnostic_view = 1;
void fragment() {
    vec3 diffuse, n, paint;
    float fade;
    rock_surface(UV, UV2, COLOR.r, diffuse, n, paint, fade);
    ALBEDO = diffuse;
    if (diagnostic_view == 30) { ALBEDO = paint; }
    else if (diagnostic_view == 31) { ALBEDO = n * 0.5 + 0.5; }
    else if (diagnostic_view == 32) { ALBEDO = vec3(fade); }
}
