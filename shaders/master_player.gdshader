shader_type spatial;
render_mode diffuse_lambert, specular_disabled;
#include "master_player_surface.gdshaderinc"

void fragment() {
    vec3 diffuse, n, emission;
    vec2 weights;
    float coverage;
    player_surface(UV, UV2, VIEW, mat3(TANGENT, BINORMAL, NORMAL), diffuse, n, emission, weights, coverage);
    if (coverage < 0.3333) { discard; }
    NORMAL = normalize(mat3(TANGENT, BINORMAL, NORMAL) * (n * vec3(1.0, -1.0, 1.0)));
    ALBEDO = diffuse;
    EMISSION = emission;
    ROUGHNESS = 1.0;
    SPECULAR = 0.0;
}
