#include "res://shaders/character_palette.gdshaderinc"
uniform sampler2D p_Diffuse : source_color, hint_default_white, repeat_enable;
uniform sampler2D p_Normal : hint_normal, repeat_enable;
uniform vec4 p_MuscleFat = vec4(0.0, 0.0, 0.0, 1.0);
uniform vec4 p_HidePart = vec4(1.0, 1.0, 0.0, 0.0);
// White vertex colors would hide an entire unpainted stand-in on some NPC MICs.
instance uniform bool bl_no_vertex_weights = false;
varying vec4 npc_weights;

void vertex() {
    npc_weights = bl_no_vertex_weights ? vec4(0.0) : COLOR;
    VERTEX += NORMAL * (0.01 * dot(npc_weights.rg, p_MuscleFat.xy));
}

float npc_coverage() {
    vec2 parts = npc_weights.ba * p_HidePart.zw;
    return 1.0 - dot(parts, parts);
}

vec3 npc_normal(vec2 uv) {
    vec3 n = texture(p_Normal, uv).rgb * 2.0 - 1.0;
    return dot(n, n) > 0.0 ? normalize(n) : vec3(0.0, 0.0, 1.0);
}

vec3 npc_diffuse(vec2 uv, out vec3 abc) {
    vec3 tones;
    return 0.5 * texture(p_Diffuse, uv).rgb * character_palette(uv, tones, abc);
}
