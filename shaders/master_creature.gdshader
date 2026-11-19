shader_type spatial;
render_mode cull_disabled, diffuse_lambert, specular_disabled;
#include "master_creature_surface.gdshaderinc"

void fragment() {
    vec3 diffuse, n, emission, pattern;
    float coverage;
    creature_surface(UV, UV2, VIEW, mat3(TANGENT, BINORMAL, NORMAL), diffuse, n, emission, pattern, coverage);
    if (coverage < 0.3333) { discard; }
    ALBEDO = diffuse;
    NORMAL = normalize(mat3(TANGENT, BINORMAL, NORMAL) * (n * vec3(1.0, -1.0, 1.0)));
    EMISSION = emission;
    SPECULAR = 0.0;
    ROUGHNESS = 1.0;
}
