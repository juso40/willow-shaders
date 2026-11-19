shader_type spatial;
render_mode diffuse_lambert, specular_disabled;
#include "master_rocks_surface.gdshaderinc"

void fragment() {
    vec3 diffuse, n, paint;
    float fade;
    rock_surface(UV, UV2, COLOR.r, diffuse, n, paint, fade);
    ALBEDO = diffuse;
    NORMAL = normalize(mat3(TANGENT, BINORMAL, NORMAL) * (n * vec3(1.0, -1.0, 1.0)));
    SPECULAR = 0.0;
    ROUGHNESS = 1.0;
}
