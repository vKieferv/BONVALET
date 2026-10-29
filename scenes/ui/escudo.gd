class_name Escudo
extends Control

# Escudo generado (D-35): una forma y un dibujo que salen del id del club (siempre los mismos para ese
# club, en cualquier partida) pintados con sus dos colores (primary_color y secondary_color de
# teams_chile_2006.json). Nunca es el escudo real del club.

const FORMAS := 5    # clásico, francés, redondo, corona, óvalo
const DIBUJOS := 6   # mitad, franja, banda, bastones, cabrío, jefe

var team_id := ""
var primario := Color.WHITE
var secundario := Color.BLACK


static func crear(team: Dictionary, alto: float) -> Escudo:
    var e := Escudo.new()
    e.custom_minimum_size = Vector2(alto * 44.0 / 52.0, alto)
    e.size = e.custom_minimum_size
    e.mouse_filter = Control.MOUSE_FILTER_IGNORE
    e.set_club(team)
    return e


func set_club(team: Dictionary) -> void:
    team_id = String(team.get("id", ""))
    primario = Color.html(String(team.get("primary_color", "#FFFFFF")))
    secundario = Color.html(String(team.get("secondary_color", "#000000")))
    tooltip_text = String(team.get("name", ""))
    queue_redraw()


func _draw() -> void:
    dibujar(self, Rect2(Vector2.ZERO, size), team_id, primario, secundario)


# Forma y dibujo del escudo de un club: [forma, dibujo], deterministas desde su id.
static func diseno(id: String) -> Array:
    var h := absi(id.hash())
    return [h % FORMAS, (h / FORMAS) % DIBUJOS]


static func dibujar(ci: CanvasItem, rect: Rect2, id: String, p: Color, s: Color) -> void:
    var caja := Vector2(44, 52)
    var k := minf(rect.size.x / caja.x, rect.size.y / caja.y)
    ci.draw_set_transform(rect.get_center() - caja * k / 2.0, 0.0, Vector2(k, k))
    var d := diseno(id)
    var forma := _forma(d[0])
    var detalle := s
    if s.is_equal_approx(p):
        detalle = p.darkened(0.35) if p.get_luminance() > 0.4 else p.lightened(0.45)
    ci.draw_colored_polygon(forma, p)
    for parte in _dibujo(d[1]):
        for poly in Geometry2D.intersect_polygons(forma, parte):
            ci.draw_colored_polygon(poly, detalle)
    var borde := PackedVector2Array(forma)
    borde.append(forma[0])
    ci.draw_polyline(borde, Color(0.07, 0.07, 0.08, 0.9), maxf(1.6, 1.2 / k), true)
    ci.draw_set_transform(Vector2.ZERO)


static func _forma(i: int) -> PackedVector2Array:
    match i:
        1:   # francés
            return PackedVector2Array([Vector2(3, 3), Vector2(41, 3), Vector2(41, 34), Vector2(22, 49), Vector2(3, 34)])
        2:   # redondo
            var pts := Icono.arco(Vector2(22, 26), 21.0, 0.0, TAU, 40)
            pts.remove_at(pts.size() - 1)
            return pts
        3:   # corona
            var pts := PackedVector2Array([Vector2(3, 8), Vector2(12, 3), Vector2(22, 8), Vector2(32, 3), Vector2(41, 8)])
            pts.append_array(Icono.bezier(Vector2(41, 28), Vector2(41, 40), Vector2(22, 49), Vector2(22, 49)))
            pts.append_array(Icono.bezier(Vector2(22, 49), Vector2(22, 49), Vector2(3, 40), Vector2(3, 28)))
            return pts
        4:   # óvalo
            var pts := PackedVector2Array()
            for j in 40:
                var a := TAU * j / 40.0
                pts.append(Vector2(22, 26) + Vector2(cos(a) * 19.0, sin(a) * 23.0))
            return pts
        _:   # clásico
            var pts := PackedVector2Array([Vector2(3, 3), Vector2(41, 3)])
            pts.append_array(Icono.bezier(Vector2(41, 25), Vector2(41, 39), Vector2(22, 49), Vector2(22, 49)))
            pts.append_array(Icono.bezier(Vector2(22, 49), Vector2(22, 49), Vector2(3, 39), Vector2(3, 25)))
            return pts


static func _dibujo(i: int) -> Array:
    match i:
        1:   # franja horizontal
            return [PackedVector2Array([Vector2(-2, 18), Vector2(46, 18), Vector2(46, 29), Vector2(-2, 29)])]
        2:   # banda diagonal
            return [PackedVector2Array([Vector2(-4, 10), Vector2(8, -4), Vector2(48, 36), Vector2(36, 50)])]
        3:   # bastones (dos franjas verticales)
            return [PackedVector2Array([Vector2(9, -2), Vector2(16, -2), Vector2(16, 54), Vector2(9, 54)]),
                    PackedVector2Array([Vector2(28, -2), Vector2(35, -2), Vector2(35, 54), Vector2(28, 54)])]
        4:   # cabrío
            return [PackedVector2Array([Vector2(-2, 20), Vector2(22, 35), Vector2(46, 20), Vector2(46, 30),
                    Vector2(22, 45), Vector2(-2, 30)])]
        5:   # jefe (banda arriba)
            return [PackedVector2Array([Vector2(-2, -2), Vector2(46, -2), Vector2(46, 17), Vector2(-2, 17)])]
        _:   # mitad vertical
            return [PackedVector2Array([Vector2(22, -2), Vector2(46, -2), Vector2(46, 54), Vector2(22, 54)])]
