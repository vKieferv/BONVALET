class_name FlowGlow
extends RefCounted

# Resplandor pulsante en los bordes de un ColorRect (efecto "fuego" del Modo Flow).
const CODE := """
shader_type canvas_item;
uniform vec4 glow_color : source_color = vec4(1.0, 0.45, 0.05, 1.0);
uniform float intensity = 1.0;
void fragment() {
    float d = min(min(UV.x, 1.0 - UV.x), min(UV.y, 1.0 - UV.y));
    float edge = smoothstep(0.22, 0.0, d);
    float pulse = 0.65 + 0.35 * sin(TIME * 6.0 + UV.y * 9.0);
    COLOR = vec4(glow_color.rgb, edge * pulse * intensity);
}
"""

static var _shader: Shader


static func make_material(color: Color, intensity: float = 1.0) -> ShaderMaterial:
    if _shader == null:
        _shader = Shader.new()
        _shader.code = CODE
    var m := ShaderMaterial.new()
    m.shader = _shader
    m.set_shader_parameter("glow_color", color)
    m.set_shader_parameter("intensity", intensity)
    return m
