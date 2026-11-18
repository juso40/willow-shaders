shader_type spatial;
render_mode unshaded, cull_disabled;

uniform int diagnostic_view = 10;
uniform sampler2D image : repeat_enable, filter_linear_mipmap;
uniform bool has_image = false;

void fragment() {
    vec2 uv = (diagnostic_view == 11 || diagnostic_view == 13) ? UV2 : UV;
    vec3 value = vec3(fract(uv), 0.0);
    if (diagnostic_view == 12 || diagnostic_view == 13) {
        vec2 cell = floor(uv * 8.0);
        value = vec3(mix(0.08, 0.85, mod(cell.x + cell.y, 2.0)));
    } else if (diagnostic_view == 14) { value = NORMAL * 0.5 + 0.5; }
    else if (diagnostic_view == 15) { value = TANGENT * 0.5 + 0.5; }
    else if (diagnostic_view == 16) { value = COLOR.rgb; }
    else if (diagnostic_view >= 20) {
        vec4 channels = has_image ? texture(image, UV) : vec4(0.0);
        value = channels.rgb;
        if (diagnostic_view > 20) { value = vec3(channels[clamp(diagnostic_view - 21, 0, 3)]); }
    }
    ALBEDO = value;
}
