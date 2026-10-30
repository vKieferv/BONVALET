extends Control

# T-12: gráfica de TV de 2006: paralelogramo inclinado (−12°) con degradado cortado al 50%, sombra dura y
# texto en cursiva. También lleva los puntos de marca de D-40 (uno por rival que marca al jugador).

const SKEW := 0.2126   # tan(12°)
const SEMI_NOCHE := [Color(0.043, 0.067, 0.106, 0.92), Color(0.043, 0.067, 0.106, 0.92), Color(0.043, 0.067, 0.106, 0.92), Color(0.043, 0.067, 0.106, 0.92)]
const PLATA := [Color("#ffffff"), Color("#e2e6ec"), Color("#cdd3dc"), Color("#e0e4ea")]

var texto := ""
var tam := 16
var color_texto := Color.WHITE
var fondo: Array = SEMI_NOCHE     # [arriba, medio, corte, abajo]
var puntos := 0
var color_puntos := Color.WHITE
var borde := Color(0, 0, 0, 0)
var margen := 9.0


func _init() -> void:
    mouse_filter = Control.MOUSE_FILTER_IGNORE


func configurar(p_texto: String, p_tam: int, p_color: Color, p_fondo: Array, p_puntos := 0, p_color_puntos := Color.WHITE, p_borde := Color(0, 0, 0, 0)) -> void:
    texto = p_texto
    tam = maxi(Paleta.TEXTO_MIN, p_tam)
    color_texto = p_color
    fondo = p_fondo
    puntos = p_puntos
    color_puntos = p_color_puntos
    borde = p_borde
    size = medida()
    queue_redraw()


func medida() -> Vector2:
    var f := Paleta.letra("tv")
    var w := f.get_string_size(texto, HORIZONTAL_ALIGNMENT_LEFT, -1, tam).x
    var alto := f.get_height(tam) + 2.0
    if puntos > 0:
        w += 6.0 + puntos * (_radio_punto() * 2.0 + 4.0)
    return Vector2(w + margen * 2.0 + alto * SKEW, alto)


func _radio_punto() -> float:
    return tam * 0.32


func _draw() -> void:
    var s := size
    var dx := s.y * SKEW
    var sombra := PackedVector2Array([Vector2(dx, 3), Vector2(s.x, 3), Vector2(s.x - dx, s.y + 3), Vector2(0, s.y + 3)])
    draw_colored_polygon(sombra, Color(0, 0, 0, 0.55))
    var medio_y := s.y * 0.5
    var medio_dx := dx * 0.5
    draw_polygon(PackedVector2Array([Vector2(dx, 0), Vector2(s.x, 0), Vector2(s.x - medio_dx, medio_y), Vector2(medio_dx, medio_y)]),
            PackedColorArray([fondo[0], fondo[0], fondo[1], fondo[1]]))
    draw_polygon(PackedVector2Array([Vector2(medio_dx, medio_y), Vector2(s.x - medio_dx, medio_y), Vector2(s.x - dx, s.y), Vector2(0, s.y)]),
            PackedColorArray([fondo[2], fondo[2], fondo[3], fondo[3]]))
    if borde.a > 0.0:
        draw_polyline(PackedVector2Array([Vector2(dx, 0), Vector2(s.x, 0), Vector2(s.x - dx, s.y), Vector2(0, s.y), Vector2(dx, 0)]), borde, 2.0, true)
    var f := Paleta.letra("tv")
    var base := Vector2(margen + dx * 0.5, f.get_ascent(tam) + 1.0)
    draw_string(f, base + Vector2(0, 1.5), texto, HORIZONTAL_ALIGNMENT_LEFT, -1, tam, Color(0, 0, 0, 0.55))
    draw_string(f, base, texto, HORIZONTAL_ALIGNMENT_LEFT, -1, tam, color_texto)
    if puntos > 0:
        var r := _radio_punto()
        var x := base.x + f.get_string_size(texto, HORIZONTAL_ALIGNMENT_LEFT, -1, tam).x + 6.0 + r
        for i in puntos:
            draw_circle(Vector2(x, s.y * 0.5), r + 1.5, Color.WHITE, true, -1.0, true)
            draw_circle(Vector2(x, s.y * 0.5), r, color_puntos, true, -1.0, true)
            x += r * 2.0 + 4.0
