// Project Godot world coordinates into UE horizontal axes and centimeters.
varying vec3 position_ue_cm;
varying vec3 tangent_up;

void vertex() {
    vec3 pos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
    position_ue_cm = vec3(pos.x, -pos.z, pos.y) * 100.0;
    tangent_up = (vec3(0.0, 1.0, 0.0) * MODEL_NORMAL_MATRIX) * mat3(TANGENT, -BINORMAL, NORMAL);
}

vec3 noise_blend(float base, vec3 noise, vec2 mod_xy) {
    return clamp(base + (1.0 - abs(2.0 * base - 1.0)) * (noise * mod_xy.x + mod_xy.y), 0.0, 1.0);
}
