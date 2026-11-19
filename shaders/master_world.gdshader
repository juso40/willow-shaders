shader_type spatial;
render_mode diffuse_lambert, specular_disabled;
#include "master_world_surface.gdshaderinc"

void fragment() {
    vec3 diffuse, n, emission, weight;
    mat3 basis = mat3(TANGENT, BINORMAL, NORMAL);
    world_surface(UV, UV2, COLOR.r, VIEW, basis, diffuse, n, emission, weight);
    ALBEDO = diffuse;
    if (sw_Normal) { NORMAL = normalize(basis * (n * vec3(1.0, -1.0, 1.0))); }
    EMISSION = emission;
    SPECULAR = 0.0;
    ROUGHNESS = 1.0;
}
