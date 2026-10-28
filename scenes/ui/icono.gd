class_name Icono
extends Control

# Íconos propios del juego (D-37), nunca emojis: PA (moneda), estamina (gota), robo (pelota que se
# escapa), fatiga (batería), acierto (mira), popularidad (megáfono), disciplina (tarjeta) y riesgo
# (dado), más los de uso general (✓, estrella, cruz médica). Las formas salen del tablero "Anatomía de
# la lámina e íconos" y se dibujan por código, así que se ven nítidas a cualquier tamaño.
# Icono.dibujar() también lo usan la lámina y la mesa para pintar sobre su propio CanvasItem, y
# Icono.jugada() dibuja la jugada de la ventana de cada lámina.

const FORMAS := ["pa", "gota", "robo", "bateria", "mira", "megafono", "tarjeta", "dado", "check", "estrella", "cruz"]

@export var forma := "gota":
    set(v):
        forma = v
        queue_redraw()
@export var color := Color.WHITE:
    set(v):
        color = v
        queue_redraw()
@export_range(0.0, 1.0) var nivel := 0.45:   # carga de la batería
    set(v):
        nivel = v
        queue_redraw()


static func crear(p_forma: String, p_color: Color, lado: float = 20.0) -> Icono:
    var i := Icono.new()
    i.forma = p_forma
    i.color = p_color
    i.custom_minimum_size = Vector2(lado * (1.25 if p_forma == "bateria" else 1.0), lado)
    i.size = i.custom_minimum_size
    i.mouse_filter = Control.MOUSE_FILTER_IGNORE
    return i


func _draw() -> void:
    dibujar(self, forma, Rect2(Vector2.ZERO, size), color, nivel)


# Dibuja un ícono en `rect` (se ajusta sin deformar y se centra). Las formas están en una caja de
# 16×16 (la batería, 20×16).
static func dibujar(ci: CanvasItem, p_forma: String, rect: Rect2, col: Color, p_nivel: float = 0.45) -> void:
    if p_forma == "pa":
        var lado := minf(rect.size.x, rect.size.y)
        var r := Rect2(rect.get_center() - Vector2(lado, lado) / 2.0, Vector2(lado, lado))
        ci.draw_texture_rect(Paleta.moneda(Paleta.MONEDA["normal"]), r, false)
        return
    var caja := Vector2(20, 16) if p_forma == "bateria" else (Vector2(24, 24) if p_forma == "cruz" else Vector2(16, 16))
    var s := minf(rect.size.x / caja.x, rect.size.y / caja.y)
    ci.draw_set_transform(rect.get_center() - caja * s / 2.0, 0.0, Vector2(s, s))
    var px := 1.0 / s   # un píxel de pantalla en unidades de la caja (bordes suaves)
    match p_forma:
        "gota":
            var pts := bezier(Vector2(8, 1.2), Vector2(8, 1.2), Vector2(2.8, 7.2), Vector2(2.8, 10.4))
            pts.append_array(arco(Vector2(8, 10.4), 5.2, PI, 0.0))
            pts.append_array(bezier(Vector2(13.2, 10.4), Vector2(13.2, 7.2), Vector2(8, 1.2), Vector2(8, 1.2)))
            relleno(ci, pts, col, px)
        "robo":
            ci.draw_arc(Vector2(10.5, 8), 4.8, 0.0, TAU, 32, col, 1.8, true)
            relleno(ci, PackedVector2Array([Vector2(10.5, 5.6), Vector2(12.7, 7.2), Vector2(11.9, 9.8),
                    Vector2(9.1, 9.8), Vector2(8.3, 7.2)]), col, px)
            for y in [5.0, 8.0, 11.0]:
                ci.draw_line(Vector2(0.8, y), Vector2(4.6 if y != 8.0 else 4.2, y), col, 1.7, true)
        "bateria":
            ci.draw_rect(Rect2(1, 3.5, 15, 9), col, false, 1.8, true)
            ci.draw_rect(Rect2(16.5, 6.2, 2.4, 3.6), col)
            ci.draw_rect(Rect2(3, 5.5, 11.0 * clampf(p_nivel, 0.0, 1.0), 5), col)
        "mira":
            ci.draw_arc(Vector2(8, 8), 5.6, 0.0, TAU, 32, col, 1.8, true)
            ci.draw_circle(Vector2(8, 8), 1.8, col, true, -1.0, true)
            for seg in [[Vector2(8, 0.6), Vector2(8, 3.6)], [Vector2(8, 12.4), Vector2(8, 15.4)],
                    [Vector2(0.6, 8), Vector2(3.6, 8)], [Vector2(12.4, 8), Vector2(15.4, 8)]]:
                ci.draw_line(seg[0], seg[1], col, 1.8, true)
        "megafono":
            relleno(ci, PackedVector2Array([Vector2(2, 6), Vector2(5, 6), Vector2(12, 2.5), Vector2(12, 13.5),
                    Vector2(5, 10), Vector2(2, 10)]), col, px)
            relleno(ci, PackedVector2Array([Vector2(4.5, 10), Vector2(6, 14.5), Vector2(8, 14.5), Vector2(7, 10)]), col, px)
            ci.draw_polyline(bezier(Vector2(13.8, 6), Vector2(14.8, 7.2), Vector2(14.8, 8.8), Vector2(13.8, 10)), col, 1.5, true)
        "tarjeta":
            var pts := PackedVector2Array()
            for p in [Vector2(4, 1.5), Vector2(12.5, 1.5), Vector2(12.5, 13.5), Vector2(4, 13.5)]:
                pts.append((p - Vector2(8, 8)).rotated(deg_to_rad(12.0)) + Vector2(8, 8))
            relleno(ci, pts, col, px)
        "dado":
            ci.draw_rect(Rect2(1.5, 1.5, 13, 13), col, false, 1.8, true)
            for c in [Vector2(5, 5), Vector2(8, 8), Vector2(11, 11)]:
                ci.draw_circle(c, 1.4, col, true, -1.0, true)
        "check":
            ci.draw_polyline(PackedVector2Array([Vector2(2.5, 8.5), Vector2(6.5, 12.5), Vector2(13.5, 4)]), col, 2.6, true)
        "estrella":
            var pts := PackedVector2Array()
            for i in 10:
                var r := 7.6 if i % 2 == 0 else 3.2
                var a := -PI / 2.0 + i * PI / 5.0
                pts.append(Vector2(8, 8.6) + Vector2(cos(a), sin(a)) * r)
            relleno(ci, pts, col, px)
        "cruz":
            relleno(ci, PackedVector2Array([Vector2(9, 2), Vector2(15, 2), Vector2(15, 9), Vector2(22, 9),
                    Vector2(22, 15), Vector2(15, 15), Vector2(15, 22), Vector2(9, 22), Vector2(9, 15),
                    Vector2(2, 15), Vector2(2, 9), Vector2(9, 9)]), col, px)
    ci.draw_set_transform(Vector2.ZERO)


# ------------------------------------------------------------------ Jugadas (ventana de la lámina)

# Dibujo de la jugada en `rect` (caja de 70×56). Las cartas con dibujo propio van por id; el resto,
# por el tipo de jugada.
static func jugada(ci: CanvasItem, c: Card, rect: Rect2, col: Color) -> void:
    var s := minf(rect.size.x / 70.0, rect.size.y / 56.0)
    ci.draw_set_transform(rect.get_center() - Vector2(70, 56) * s / 2.0, 0.0, Vector2(s, s))
    var px := 1.0 / s
    var w := 3.0
    var id := c.id
    if c.type == Card.Type.PENALTY:
        ci.draw_rect(Rect2(12, 16, 40, 24), col, false, w, true)
        ci.draw_rect(Rect2(53, 23, 5, 10), col)
        _cruz(ci, Vector2(32, 28), 7.0, col, w)
    elif id == "toque_toque":
        for p in [Vector2(10, 40), Vector2(35, 16), Vector2(60, 40)]:
            ci.draw_arc(p, 5, 0, TAU, 24, col, w, true)
        ci.draw_line(Vector2(14, 35), Vector2(30, 20), col, w, true)
        ci.draw_line(Vector2(40, 20), Vector2(56, 35), col, w, true)
        _punta(ci, [Vector2(24, 20), Vector2(31, 19), Vector2(29, 26)], col, w)
        _punta(ci, [Vector2(50, 35), Vector2(57, 36), Vector2(56, 29)], col, w)
    elif id == "pase_filtrado":
        var tenue := Color(col, col.a * 0.6)
        _guiones(ci, PackedVector2Array([Vector2(24, 4), Vector2(24, 52)]), tenue, 2.0, 3.0, 4.0)
        _guiones(ci, PackedVector2Array([Vector2(46, 4), Vector2(46, 52)]), tenue, 2.0, 3.0, 4.0)
        ci.draw_arc(Vector2(8, 42), 5, 0, TAU, 24, col, w, true)
        ci.draw_polyline(bezier(Vector2(14, 38), Vector2(30, 30), Vector2(40, 22), Vector2(58, 14)), col, w, true)
        _punta(ci, [Vector2(51, 10), Vector2(60, 13), Vector2(54, 21)], col, w)
    elif id == "tiro_lejano":
        ci.draw_polyline(PackedVector2Array([Vector2(48, 24), Vector2(48, 6), Vector2(68, 6)]), col, w, true)
        _guiones(ci, bezier(Vector2(6, 50), Vector2(18, 14), Vector2(40, 6), Vector2(56, 12)), col, w, 4.0, 5.0)
        ci.draw_circle(Vector2(6, 50), 5, col, true, -1.0, true)
        ci.draw_arc(Vector2(58, 14), 5, 0, TAU, 24, col, 2.5, true)
    elif id == "pelotazo":
        ci.draw_arc(Vector2(8, 48), 5, 0, TAU, 24, col, w, true)
        _guiones(ci, bezier(Vector2(12, 43), Vector2(22, 0), Vector2(50, -2), Vector2(60, 36)), col, w, 4.0, 5.0)
        ci.draw_circle(Vector2(61, 44), 5, col, true, -1.0, true)
    else:
        match c.kind:
            Card.Kind.PASS:
                ci.draw_arc(Vector2(12, 42), 6, 0, TAU, 24, col, w, true)
                ci.draw_arc(Vector2(58, 14), 6, 0, TAU, 24, col, w, true)
                ci.draw_polyline(bezier(Vector2(19, 38), Vector2(32, 30), Vector2(38, 22), Vector2(49, 18)), col, w, true)
                _punta(ci, [Vector2(43, 13), Vector2(51, 17), Vector2(45, 24)], col, w)
            Card.Kind.CONTROL:
                ci.draw_circle(Vector2(40, 44), 7, col, true, -1.0, true)
                _guiones(ci, bezier(Vector2(8, 8), Vector2(26, 4), Vector2(40, 18), Vector2(40, 33)), col, w, 4.0, 5.0)
                ci.draw_line(Vector2(30, 52), Vector2(58, 52), col, w, true)
            Card.Kind.DRIBBLE:
                _cruz(ci, Vector2(31, 12), 5.0, col, w)
                ci.draw_arc(Vector2(8, 46), 5, 0, TAU, 24, col, w, true)
                ci.draw_polyline(PackedVector2Array([Vector2(13, 42), Vector2(24, 28), Vector2(38, 40), Vector2(56, 20)]), col, w, true)
                _punta(ci, [Vector2(48, 18), Vector2(57, 19), Vector2(56, 28)], col, w)
            Card.Kind.CROSS:
                ci.draw_line(Vector2(8, 52), Vector2(8, 14), col, w, true)
                relleno(ci, PackedVector2Array([Vector2(8, 14), Vector2(22, 19), Vector2(8, 24)]), col, px)
                _guiones(ci, bezier(Vector2(12, 46), Vector2(28, 6), Vector2(50, 6), Vector2(60, 26)), col, w, 4.0, 5.0)
                ci.draw_circle(Vector2(61, 31), 5, col, true, -1.0, true)
            Card.Kind.SHOT:
                ci.draw_polyline(PackedVector2Array([Vector2(14, 50), Vector2(14, 12), Vector2(56, 12), Vector2(56, 50)]), col, w, true)
                ci.draw_arc(Vector2(44, 22), 6, 0, TAU, 24, col, 2.5, true)
                ci.draw_line(Vector2(44, 12), Vector2(44, 32), col, 2.0, true)
                ci.draw_line(Vector2(34, 22), Vector2(54, 22), col, 2.0, true)
            Card.Kind.PAUSE:
                ci.draw_rect(Rect2(23, 10, 9, 30), col)
                ci.draw_rect(Rect2(38, 10, 9, 30), col)
                ci.draw_line(Vector2(14, 50), Vector2(56, 50), col, w, true)
            Card.Kind.PRESS:
                _cruz(ci, Vector2(38, 28), 6.0, col, w)
                ci.draw_line(Vector2(6, 8), Vector2(24, 20), col, w, true)
                _punta(ci, [Vector2(16, 20), Vector2(25, 21), Vector2(22, 12)], col, w)
                ci.draw_line(Vector2(6, 48), Vector2(24, 36), col, w, true)
                _punta(ci, [Vector2(22, 44), Vector2(25, 35), Vector2(16, 36)], col, w)
                ci.draw_line(Vector2(66, 28), Vector2(50, 28), col, w, true)
                _punta(ci, [Vector2(56, 22), Vector2(49, 28), Vector2(56, 34)], col, w)
            Card.Kind.BLOCK:
                for x in [40.0, 49.0, 58.0]:
                    ci.draw_rect(Rect2(x, 10, 7, 38), col)
                ci.draw_arc(Vector2(12, 29), 5, 0, TAU, 24, col, w, true)
                _guiones(ci, PackedVector2Array([Vector2(18, 29), Vector2(36, 29)]), col, w, 4.0, 4.0)
            Card.Kind.INTERCEPT:
                ci.draw_arc(Vector2(8, 44), 5, 0, TAU, 24, col, w, true)
                ci.draw_arc(Vector2(62, 12), 5, 0, TAU, 24, col, w, true)
                _guiones(ci, PackedVector2Array([Vector2(13, 41), Vector2(57, 15)]), Color(col, col.a * 0.7), 2.5, 4.0, 4.0)
                ci.draw_line(Vector2(22, 52), Vector2(42, 20), col, w, true)
                _punta(ci, [Vector2(35, 22), Vector2(43, 19), Vector2(44, 28)], col, w)
            Card.Kind.CLEARANCE:
                ci.draw_circle(Vector2(12, 46), 5, col, true, -1.0, true)
                _guiones(ci, bezier(Vector2(16, 40), Vector2(26, 6), Vector2(48, 0), Vector2(64, 12)), col, w, 4.0, 5.0)
                _punta(ci, [Vector2(56, 6), Vector2(65, 12), Vector2(57, 17)], col, w)
                ci.draw_line(Vector2(4, 53), Vector2(30, 53), col, w, true)
    ci.draw_set_transform(Vector2.ZERO)


# Silueta del jugador (sin cara, D-35): cabeza, camiseta con los colores del club y el puesto escrito
# encima. `rect` es la caja de 60×70; `recorte` limita la camiseta (la ventana de la lámina).
static func jugador(ci: CanvasItem, rect: Rect2, camiseta: Color, detalle: Color, puesto: String, recorte: Rect2) -> void:
    var s := minf(rect.size.x / 60.0, rect.size.y / 70.0)
    var o := rect.position
    var cuerpo := PackedVector2Array()
    for p in bezier(Vector2(5, 70), Vector2(5, 44), Vector2(15, 33), Vector2(30, 33)):
        cuerpo.append(o + p * s)
    for p in bezier(Vector2(30, 33), Vector2(45, 33), Vector2(55, 44), Vector2(55, 70)):
        cuerpo.append(o + p * s)
    var caja := PackedVector2Array([recorte.position, Vector2(recorte.end.x, recorte.position.y), recorte.end,
            Vector2(recorte.position.x, recorte.end.y)])
    var trazo := Color("#111111")
    for poly in Geometry2D.intersect_polygons(cuerpo, caja):
        ci.draw_colored_polygon(poly, camiseta)
        var cerrado := PackedVector2Array(poly)
        cerrado.append(poly[0])
        ci.draw_polyline(cerrado, trazo, maxf(1.0, 2.0 * s), true)
    var cabeza := o + Vector2(30, 17) * s
    ci.draw_circle(cabeza, 11.0 * s, Color("#2a2a2d"), true, -1.0, true)
    var cuello := trazo if detalle.is_equal_approx(camiseta) else detalle
    ci.draw_polyline(PackedVector2Array([o + Vector2(22, 33) * s, o + Vector2(30, 42) * s, o + Vector2(38, 33) * s]),
            cuello, 3.0 * s, true)
    if puesto != "":
        var f := Paleta.letra("condensada_negra")
        var tam := maxi(Paleta.TEXTO_MIN, roundi(13.0 * s))
        var ancho := f.get_string_size(puesto, HORIZONTAL_ALIGNMENT_LEFT, -1, tam).x
        var base := o + Vector2(30, 61) * s - Vector2(ancho / 2.0, 0)
        var tinta := Color("#111111") if camiseta.get_luminance() > 0.5 else Color.WHITE
        if base.y < recorte.end.y:
            ci.draw_string(f, base, puesto, HORIZONTAL_ALIGNMENT_LEFT, -1, tam, tinta)


# ------------------------------------------------------------------ Trazos

static func bezier(p0: Vector2, p1: Vector2, p2: Vector2, p3: Vector2, n: int = 14) -> PackedVector2Array:
    var out := PackedVector2Array()
    for i in n + 1:
        var t := float(i) / n
        var u := 1.0 - t
        out.append(p0 * u * u * u + p1 * 3.0 * u * u * t + p2 * 3.0 * u * t * t + p3 * t * t * t)
    return out


static func arco(c: Vector2, r: float, desde: float, hasta: float, n: int = 16) -> PackedVector2Array:
    var out := PackedVector2Array()
    for i in n + 1:
        var a := lerpf(desde, hasta, float(i) / n)
        out.append(c + Vector2(cos(a), sin(a)) * r)
    return out


# Polígono relleno con el borde suavizado (draw_colored_polygon no suaviza).
static func relleno(ci: CanvasItem, pts: PackedVector2Array, col: Color, px: float = 1.0) -> void:
    ci.draw_colored_polygon(pts, col)
    var cerrado := PackedVector2Array(pts)
    cerrado.append(pts[0])
    ci.draw_polyline(cerrado, col, px, true)


# Línea punteada a lo largo de una polilínea (guión y espacio en las unidades del dibujo).
static func _guiones(ci: CanvasItem, pts: PackedVector2Array, col: Color, w: float, guion: float, espacio: float) -> void:
    var dibujando := true
    var resto := guion
    var tramo := PackedVector2Array([pts[0]])
    for i in range(1, pts.size()):
        var a := pts[i - 1]
        var b := pts[i]
        var largo := a.distance_to(b)
        var hecho := 0.0
        while largo - hecho > resto:
            hecho += resto
            var p := a.lerp(b, hecho / largo)
            if dibujando:
                tramo.append(p)
                ci.draw_polyline(tramo, col, w, true)
            tramo = PackedVector2Array([p])
            dibujando = not dibujando
            resto = guion if dibujando else espacio
        resto -= largo - hecho
        if dibujando:
            tramo.append(b)
    if dibujando and tramo.size() > 1:
        ci.draw_polyline(tramo, col, w, true)


static func _punta(ci: CanvasItem, pts: Array, col: Color, w: float) -> void:
    ci.draw_polyline(PackedVector2Array(pts), col, w, true)


static func _cruz(ci: CanvasItem, c: Vector2, r: float, col: Color, w: float) -> void:
    ci.draw_line(c + Vector2(-r, -r), c + Vector2(r, r), col, w, true)
    ci.draw_line(c + Vector2(r, -r), c + Vector2(-r, r), col, w, true)
