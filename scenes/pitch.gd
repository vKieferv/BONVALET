class_name Pitch
extends Control

# Cancha 2D dibujada por código (césped a franjas, líneas, áreas y porterías).
# Ataca hacia la derecha. Se puede reemplazar por un TextureRect sin tocar el resto.

const GRASS_DARK := Color("#2f7d32")
const GRASS_LIGHT := Color("#388e3c")
const LINE := Color(1, 1, 1, 0.88)


# Rectángulo del campo de juego (en coordenadas locales).
func field_rect() -> Rect2:
    return Rect2(size.x * 0.04, size.y * 0.06, size.x * 0.92, size.y * 0.90)


func _notification(what: int) -> void:
    if what == NOTIFICATION_RESIZED:
        queue_redraw()


func _draw() -> void:
    var bands := 16
    var bw := size.x / bands
    for i in bands:
        draw_rect(Rect2(i * bw, 0.0, bw + 1.0, size.y), GRASS_LIGHT if i % 2 == 0 else GRASS_DARK)

    var r := field_rect()
    var lw := maxf(2.0, size.y * 0.004)
    var cx := r.position.x + r.size.x / 2.0
    var cy := r.position.y + r.size.y / 2.0
    var rc := r.size.y * 0.14

    draw_rect(r, LINE, false, lw)
    draw_line(Vector2(cx, r.position.y), Vector2(cx, r.end.y), LINE, lw)
    draw_arc(Vector2(cx, cy), rc, 0.0, TAU, 64, LINE, lw)
    draw_circle(Vector2(cx, cy), lw * 1.6, LINE)

    for side in [0, 1]:
        var left: bool = side == 0
        var gx: float = r.position.x if left else r.end.x
        var sgn := 1.0 if left else -1.0
        var aw := r.size.x * 0.16
        var ah := r.size.y * 0.58
        var sw := r.size.x * 0.06
        var sh := r.size.y * 0.28
        draw_rect(Rect2(gx if left else gx - aw, cy - ah / 2.0, aw, ah), LINE, false, lw)
        draw_rect(Rect2(gx if left else gx - sw, cy - sh / 2.0, sw, sh), LINE, false, lw)
        var spot := Vector2(gx + sgn * r.size.x * 0.11, cy)
        draw_circle(spot, lw * 1.6, LINE)
        var a0 := -0.93 if left else PI - 0.93
        draw_arc(spot, rc, a0, a0 + 1.86, 24, LINE, lw)
        var gw := r.size.x * 0.012
        var gh := r.size.y * 0.12
        draw_rect(Rect2(gx - gw if left else gx, cy - gh / 2.0, gw, gh), Color(1, 1, 1, 0.35))

    # Sombreado de transmisión (arriba y abajo)
    var steps := 10
    var th := size.y * 0.22 / steps
    for i in steps:
        var a := 0.30 * (1.0 - float(i) / steps)
        draw_rect(Rect2(0.0, i * th, size.x, th), Color(0, 0, 0, a))
        draw_rect(Rect2(0.0, size.y - (i + 1) * th, size.x, th), Color(0, 0, 0, a))
