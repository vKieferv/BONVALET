class_name Mesa
extends RefCounted

# Materiales de la mesa del DT (D-37) para armar la semana por código: madera, luz de la lámpara con
# penumbra, objetos (papeles y cosas que se tocan), timbres de tinta, cinta Dymo, plumón, chinchetas
# numeradas y cinta adhesiva. Nada de barras de app, tarjetas web ni etiquetas tipo píldora.

const MADERA_SHADER := """
shader_type canvas_item;
uniform vec2 tam = vec2(1280.0, 720.0);
uniform vec4 fondo : source_color = vec4(0.165, 0.106, 0.067, 1.0);
uniform vec4 veta : source_color = vec4(0.30, 0.18, 0.09, 1.0);
float h(vec2 p) { return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453); }
float n(vec2 p) {
    vec2 i = floor(p);
    vec2 f = fract(p);
    vec2 u = f * f * (3.0 - 2.0 * f);
    return mix(mix(h(i), h(i + vec2(1.0, 0.0)), u.x), mix(h(i + vec2(0.0, 1.0)), h(i + vec2(1.0, 1.0)), u.x), u.y);
}
float fbm(vec2 p) {
    float v = 0.0;
    float a = 0.5;
    for (int i = 0; i < 5; i++) { v += a * n(p); p *= 2.03; a *= 0.5; }
    return v;
}
void fragment() {
    vec2 p = UV * tam;
    float ondas = fbm(vec2(p.x * 0.0025, p.y * 0.018)) * 3.0;
    float grano = fbm(vec2(p.x * 0.008, p.y * 0.28 + ondas));
    float vetas = fbm(vec2(p.x * 0.004, p.y * 0.09 + ondas * 0.6));
    float t = clamp(grano * 0.8 + vetas * 0.5 - 0.25, 0.0, 1.0);
    COLOR = vec4(mix(fondo.rgb, veta.rgb * 1.3, t), 1.0);
}
"""

# Luz de la lámpara sobre lo que toca decidir (el resto queda en penumbra), viñeta y grano encima de todo.
const LAMPARA_SHADER := """
shader_type canvas_item;
uniform vec2 tam = vec2(1280.0, 720.0);
uniform vec4 foco = vec4(640.0, 360.0, 320.0, 240.0);
uniform float penumbra = 0.3;
uniform vec4 luz : source_color = vec4(1.0, 0.84, 0.59, 0.3);
float h(vec2 p) { return fract(sin(dot(p, vec2(12.9898, 78.233))) * 43758.5453); }
void fragment() {
    vec2 p = UV * tam;
    float r = length((p - foco.xy) / max(foco.zw, vec2(1.0)));
    float lit = 1.0 - smoothstep(0.6, 1.25, r);
    float vig = smoothstep(0.45, 0.95, length((UV - vec2(0.5)) * vec2(1.0, 0.9))) * 0.55;
    float sombra = max(penumbra * (1.0 - lit), vig);
    float g = h(floor(p)) - 0.5;
    COLOR = vec4(mix(vec3(0.0), luz.rgb, lit), clamp(sombra + lit * luz.a, 0.0, 1.0) + g * 0.06);
}
"""

static var _madera: Shader
static var _lampara: Shader


static func madera() -> ColorRect:
    if _madera == null:
        _madera = Shader.new()
        _madera.code = MADERA_SHADER
    var r := ColorRect.new()
    r.set_anchors_preset(Control.PRESET_FULL_RECT)
    r.mouse_filter = Control.MOUSE_FILTER_IGNORE
    var m := ShaderMaterial.new()
    m.shader = _madera
    m.set_shader_parameter("fondo", Paleta.MADERA)
    m.set_shader_parameter("veta", Paleta.MADERA_VETA)
    r.material = m
    r.resized.connect(func() -> void: m.set_shader_parameter("tam", r.size))
    return r


static func lampara() -> ColorRect:
    if _lampara == null:
        _lampara = Shader.new()
        _lampara.code = LAMPARA_SHADER
    var r := ColorRect.new()
    r.set_anchors_preset(Control.PRESET_FULL_RECT)
    r.mouse_filter = Control.MOUSE_FILTER_IGNORE
    var m := ShaderMaterial.new()
    m.shader = _lampara
    m.set_shader_parameter("luz", Paleta.LUZ_LAMPARA)
    r.material = m
    r.resized.connect(func() -> void: m.set_shader_parameter("tam", r.size))
    return r


# Mueve la luz de la lámpara a `rect` (coordenadas de la lámpara).
static func enfocar(lamp: ColorRect, rect: Rect2, animar: bool = true) -> void:
    var m := lamp.material as ShaderMaterial
    var to := Vector4(rect.get_center().x, rect.get_center().y, maxf(rect.size.x * 0.62, 120.0), maxf(rect.size.y * 0.62, 100.0))
    if not animar:
        m.set_shader_parameter("foco", to)
        return
    var from: Vector4 = m.get_shader_parameter("foco")
    lamp.create_tween().tween_method(func(v: Vector4) -> void: m.set_shader_parameter("foco", v), from, to, 0.35) \
            .set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)


# ------------------------------------------------------------------ Objetos

# Un objeto de la mesa: un botón sin estilo propio que se dibuja con `dibujo(boton)`. Sin `al_pulsar`
# no se aprieta, pero muestra su tooltip. Gira desde su centro.
static func objeto(rect: Rect2, grados: float, dibujo: Callable, al_pulsar: Callable = Callable()) -> Button:
    var b := Button.new()
    b.position = rect.position
    b.size = rect.size
    b.custom_minimum_size = rect.size
    b.pivot_offset = rect.size / 2.0
    b.rotation = deg_to_rad(grados)
    b.flat = true
    b.texture_repeat = CanvasItem.TEXTURE_REPEAT_ENABLED
    for state in ["normal", "hover", "pressed", "hover_pressed", "disabled", "focus"]:
        b.add_theme_stylebox_override(state, StyleBoxEmpty.new())
    if dibujo.is_valid():
        b.draw.connect(dibujo.bind(b))
    if al_pulsar.is_valid():
        b.pressed.connect(al_pulsar)
        # Se levanta un poco bajo el mouse, como un objeto que se toma de la mesa.
        b.mouse_entered.connect(func() -> void:
            if not b.disabled:
                b.create_tween().tween_property(b, "scale", Vector2(1.025, 1.025), 0.12))
        b.mouse_exited.connect(func() -> void: b.create_tween().tween_property(b, "scale", Vector2.ONE, 0.12))
        b.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
    else:
        b.mouse_filter = Control.MOUSE_FILTER_PASS
        b.focus_mode = Control.FOCUS_NONE
    return b


# ¿El objeto está bajo el mouse y se puede apretar? (para levantarlo un poco al dibujarlo)
static func encima(b: Button) -> bool:
    return b.is_hovered() and not b.disabled and b.pressed.get_connections().size() > 0


# Papel con su sombra y su grano.
static func papel(ci: CanvasItem, rect: Rect2, color: Color, sombra: Array = Paleta.SOMBRA_PAPEL, radio: int = 0) -> void:
    ci.draw_style_box(Paleta.caja(color, radio, sombra), rect)
    Paleta.dibujar_grano(ci, rect)


# Trozo de cinta adhesiva (centro, ángulo en grados, largo y ancho).
static func cinta_adhesiva(ci: CanvasItem, centro: Vector2, grados: float, largo: float = 104.0, ancho: float = 30.0) -> void:
    var pts := PackedVector2Array()
    for p in [Vector2(-0.48, -0.38), Vector2(0.49, -0.5), Vector2(0.5, -0.05), Vector2(0.47, 0.5), Vector2(-0.49, 0.4), Vector2(-0.5, -0.02)]:
        pts.append(centro + (Vector2(p.x * largo, p.y * ancho)).rotated(deg_to_rad(grados)))
    ci.draw_colored_polygon(pts, Paleta.CINTA_ADHESIVA)


# Borde inferior roto (hoja de calendario arrancada): polígono del papel con dientes abajo.
static func hoja_rota(rect: Rect2, dientes: int = 16) -> PackedVector2Array:
    var pts := PackedVector2Array([rect.position, Vector2(rect.end.x, rect.position.y)])
    for i in range(dientes, -1, -1):
        var x := rect.position.x + rect.size.x * float(i) / dientes
        var y := rect.end.y - (rect.size.y * (0.03 if i % 2 == 0 else 0.07))
        pts.append(Vector2(x, y))
    return pts


static func linea_punteada(ci: CanvasItem, desde: Vector2, hasta: Vector2, color: Color, ancho: float = 2.0, paso: float = 5.0) -> void:
    var largo := desde.distance_to(hasta)
    var n := int(largo / paso)
    for i in n:
        if i % 2 == 0:
            ci.draw_line(desde.lerp(hasta, float(i) / n), desde.lerp(hasta, float(i + 1) / n), color, ancho)


# ------------------------------------------------------------------ Tinta, plumón y Dymo

# Timbre de tinta: borde grueso del color de la tinta, ícono y texto, levemente girado.
static func timbre(texto: String, icono: String, color: Color, grados: float = -3.0, tam: int = 18) -> PanelContainer:
    var p := PanelContainer.new()
    var sb := StyleBoxFlat.new()
    sb.draw_center = false
    sb.set_border_width_all(3)
    sb.border_color = Color(color, 0.92)
    sb.content_margin_left = 8
    sb.content_margin_right = 8
    sb.content_margin_top = 1
    sb.content_margin_bottom = 1
    p.add_theme_stylebox_override("panel", sb)
    var row := HBoxContainer.new()
    row.add_theme_constant_override("separation", 6)
    p.add_child(row)
    if icono != "":
        var i := Icono.crear(icono, color, tam - 2)
        i.size_flags_vertical = Control.SIZE_SHRINK_CENTER
        row.add_child(i)
    if texto != "":
        row.add_child(Paleta.etiqueta(texto, "condensada_negra", tam, Color(color, 0.92)))
    p.rotation = deg_to_rad(grados)
    ignorar(p)
    p.resized.connect(func() -> void: p.pivot_offset = p.size / 2.0)
    return p


# Sello de goma grande y doble (CLÁUSULA, FIRMADO, ¡FUNA!...).
static func sello(texto: String, color: Color, grados: float = -8.0, tam: int = 15) -> Label:
    var l := Paleta.etiqueta(texto, "condensada_negra", tam, Color(color, 0.9), 1)
    var sb := StyleBoxFlat.new()
    sb.draw_center = false
    sb.set_border_width_all(3)
    sb.border_color = Color(color, 0.9)
    sb.content_margin_left = 8
    sb.content_margin_right = 8
    sb.content_margin_top = 2
    sb.content_margin_bottom = 2
    l.add_theme_stylebox_override("normal", sb)
    l.rotation = deg_to_rad(grados)
    l.resized.connect(func() -> void: l.pivot_offset = l.size / 2.0)
    return l


# Cinta Dymo: letras blancas en relieve sobre plástico negro (con un ícono opcional adelante).
static func dymo(texto: String, grados: float = -1.5, tam: int = 18, icono: String = "", color_icono: Color = Color.WHITE) -> Control:
    var p := PanelContainer.new()
    var sb := Paleta.caja(Paleta.DYMO, 0, [Color(0, 0, 0, 0.5), 4, 3])
    sb.content_margin_left = 12
    sb.content_margin_right = 12
    sb.content_margin_top = 3
    sb.content_margin_bottom = 3
    p.add_theme_stylebox_override("panel", sb)
    var row := HBoxContainer.new()
    row.add_theme_constant_override("separation", 6)
    p.add_child(row)
    if icono != "":
        var i := Icono.crear(icono, color_icono, tam - 2)
        i.size_flags_vertical = Control.SIZE_SHRINK_CENTER
        row.add_child(i)
    var l := Paleta.etiqueta(texto, "condensada_negra", tam, Paleta.DYMO_LETRA, 3)
    l.add_theme_color_override("font_shadow_color", Color(1, 1, 1, 0.22))
    l.add_theme_constant_override("shadow_offset_y", 1)
    l.add_theme_constant_override("shadow_offset_x", 0)
    row.add_child(l)
    p.rotation = deg_to_rad(grados)
    ignorar(p)
    p.resized.connect(func() -> void: p.pivot_offset = p.size / 2.0)
    return p


# Lo escrito a mano por el DT (Permanent Marker). Sobre la madera lleva una sombra para leerse.
static func plumon(texto: String, tam: int, color: Color, grados: float = -3.0, sobre_madera: bool = true) -> Label:
    var l := Paleta.etiqueta(texto, "plumon", tam, color)
    if sobre_madera:
        l.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.65))
        l.add_theme_constant_override("shadow_offset_y", 2)
        l.add_theme_constant_override("shadow_offset_x", 0)
    l.rotation = deg_to_rad(grados)
    return l


# Chincheta numerada (paso pendiente) o verde con ✓ (hecho), como un Control de 36×36.
static func chincheta(numero: int, hecho: bool = false, lado: float = 36.0) -> Control:
    var c := Control.new()
    c.size = Vector2(lado, lado)
    c.custom_minimum_size = c.size
    c.mouse_filter = Control.MOUSE_FILTER_IGNORE
    var colores: Array = Paleta.CHINCHETA_HECHO if hecho else Paleta.CHINCHETA
    c.draw.connect(func() -> void:
        var r := lado / 2.0
        c.draw_circle(Vector2(r, r + 4.0), r, Color(0, 0, 0, 0.45), true, -1.0, true)
        c.draw_texture_rect(Paleta.moneda(colores), Rect2(Vector2.ZERO, c.size), false)
        if hecho:
            Icono.dibujar(c, "check", Rect2(lado * 0.22, lado * 0.22, lado * 0.56, lado * 0.56), Color.WHITE))
    if not hecho:
        var l := Paleta.etiqueta(str(numero), "condensada_negra", 20, Color.WHITE)
        l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
        l.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
        l.size = c.size
        c.add_child(l)
    return c


# Que nada dentro de `n` capture el mouse (los clics llegan al objeto de la mesa).
static func ignorar(n: Node) -> void:
    if n is Control:
        (n as Control).mouse_filter = Control.MOUSE_FILTER_IGNORE
    for child in n.get_children():
        ignorar(child)


# Monto en millones con punto de miles, como en Chile: 9000 → "$9.000 M".
static func plata(m: float) -> String:
    var s := str(absi(roundi(m)))
    var out := ""
    while s.length() > 3:
        out = "." + s.substr(s.length() - 3) + out
        s = s.substr(0, s.length() - 3)
    return ("-$" if m < 0.0 else "$") + s + out + " M"


static func apellido(nombre: String) -> String:
    return nombre.get_slice(" ", nombre.get_slice_count(" ") - 1)


# Placa inclinada de las gráficas de TV de 2006 (letra cursiva sobre un paralelogramo de dos tonos).
static func placa_tv(texto: String, tam: int, fondo: Array, color: Color) -> Control:
    var c := Control.new()
    c.mouse_filter = Control.MOUSE_FILTER_IGNORE
    var l := Paleta.etiqueta(texto, "tv", tam, color, 1)
    var f := Paleta.letra("tv", 1)   # se mide con la letra: fuera del árbol las etiquetas aún no tienen tema
    var min := Vector2(f.get_string_size(texto, HORIZONTAL_ALIGNMENT_LEFT, -1, tam).x, f.get_height(tam))
    var pad := tam * 0.55
    c.size = Vector2(min.x + 2.0 * pad, min.y)
    c.custom_minimum_size = c.size
    l.position = Vector2(pad, 0)
    c.add_child(l)
    c.draw.connect(func() -> void:
        var s := c.size
        var o := tan(deg_to_rad(12.0)) * s.y / 2.0
        var mid := s.y / 2.0
        var top: Color = fondo[0]
        var bot: Color = fondo[fondo.size() - 1]
        if fondo.size() >= 4:
            c.draw_polygon(PackedVector2Array([Vector2(o, 0), Vector2(s.x + o, 0), Vector2(s.x, mid), Vector2(0, mid)]),
                    PackedColorArray([fondo[0], fondo[0], fondo[1], fondo[1]]))
            c.draw_polygon(PackedVector2Array([Vector2(0, mid), Vector2(s.x, mid), Vector2(s.x - o, s.y), Vector2(-o, s.y)]),
                    PackedColorArray([fondo[2], fondo[2], fondo[3], fondo[3]]))
        else:
            c.draw_polygon(PackedVector2Array([Vector2(o, 0), Vector2(s.x + o, 0), Vector2(s.x - o, s.y), Vector2(-o, s.y)]),
                    PackedColorArray([top, top, bot, bot])))
    return c


# Entrada al estadio (un botón con forma de ticket): talón con el número a la izquierda, encabezado
# chico y el texto grande del botón. Apagada, se ve desteñida.
static func entrada(rect: Rect2, grados: float, encabezado: String, texto: String, numero: String, tam: int,
        al_pulsar: Callable) -> Button:
    var b := Button.new()
    b.position = rect.position
    b.size = rect.size
    b.custom_minimum_size = rect.size
    b.pivot_offset = rect.size / 2.0
    b.rotation = deg_to_rad(grados)
    b.text = texto
    b.alignment = HORIZONTAL_ALIGNMENT_LEFT
    b.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
    var tinta := Color("#3b2418")
    Paleta.estilo_texto(b, "tv", tam, tinta)
    for state in ["font_hover_color", "font_pressed_color", "font_hover_pressed_color", "font_focus_color"]:
        b.add_theme_color_override(state, tinta)
    b.add_theme_color_override("font_disabled_color", Color(tinta, 0.55))
    var colores := {"normal": Color("#e9c3a6"), "hover": Color("#f3d3ba"), "pressed": Color("#dcb08f"),
        "hover_pressed": Color("#dcb08f"), "disabled": Color("#a99a8f")}
    for state in colores:
        var sb := Paleta.caja(colores[state], 2, Paleta.SOMBRA_PAPEL)
        sb.content_margin_left = 82
        sb.content_margin_right = 12
        sb.content_margin_top = 22
        sb.content_margin_bottom = 4
        b.add_theme_stylebox_override(state, sb)
    b.add_theme_stylebox_override("focus", StyleBoxEmpty.new())
    var head := Paleta.etiqueta(encabezado, "condensada", 14, tinta, 2)
    head.position = Vector2(82, 10)
    b.add_child(head)
    var num := Paleta.etiqueta(numero, "condensada_negra", 14, tinta, 1)
    num.size = Vector2(rect.size.y - 12.0, 20)
    num.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    num.pivot_offset = num.size / 2.0
    num.position = Vector2(33.0, rect.size.y / 2.0) - num.size / 2.0
    num.rotation = -PI / 2.0
    b.add_child(num)
    b.draw.connect(func() -> void:
        for i in range(4, int(b.size.y) - 4, 8):
            b.draw_line(Vector2(66, i), Vector2(66, i + 4), Color("#a6765a"), 3.0)
        if b.disabled:
            b.draw_rect(Rect2(Vector2.ZERO, b.size), Color(0.1, 0.07, 0.05, 0.18)))
    b.pressed.connect(al_pulsar)
    b.mouse_entered.connect(func() -> void:
        if not b.disabled:
            b.create_tween().tween_property(b, "scale", Vector2(1.03, 1.03), 0.12))
    b.mouse_exited.connect(func() -> void: b.create_tween().tween_property(b, "scale", Vector2.ONE, 0.12))
    return b
