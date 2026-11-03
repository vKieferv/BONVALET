extends RefCounted

# T-12 (I-63): la trayectoria del balón según la carta. Es la única fuente: la línea de apuntar es esta curva
# proyectada a la pantalla y la pelota recorre esta misma curva al soltar. Es solo presentación: la forma no
# cambia el %. La tabla es de valores simples, fácil de pasar a data/cards.json más adelante.
#   alto_min, alto_por_metro, alto_max: altura en metros en la mitad del recorrido
#   curva: cuánto se abre hacia un lado, como fracción de la distancia
#   velocidad: metros por segundo; frenado: 1 = constante, más de 1 = sale rápido y se frena
#   giro: vueltas de la pelota en radianes por segundo; efecto: giro sobre sí misma
#   patada: rapidez de la patada; sombra: dibuja la sombra de la línea en el pasto
#   tramo, hueco: largo en píxeles de los tramos de la línea
const FORMAS := {
    "pase_corto": {
        "alto_min": 0.0, "alto_por_metro": 0.0, "alto_max": 0.0, "curva": 0.0, "velocidad": 12.0, "frenado": 1.5,
        "giro": 16.0, "efecto": 0.0, "patada": 1.0, "sombra": false, "tramo": 28.0, "hueco": 10.0,
    },
    "toque_toque": {
        "alto_min": 0.28, "alto_por_metro": 0.0, "alto_max": 0.28, "curva": 0.0, "velocidad": 21.0, "frenado": 1.0,
        "giro": 30.0, "efecto": 0.0, "patada": 1.8, "sombra": false, "tramo": 12.0, "hueco": 9.0,
    },
    "pase_filtrado": {
        "alto_min": 0.0, "alto_por_metro": 0.0, "alto_max": 0.0, "curva": 0.2, "velocidad": 14.0, "frenado": 1.25,
        "giro": 20.0, "efecto": 14.0, "patada": 1.0, "sombra": false, "tramo": 24.0, "hueco": 10.0,
    },
    "pelotazo": {
        "alto_min": 2.6, "alto_por_metro": 0.26, "alto_max": 5.5, "curva": 0.0, "velocidad": 8.0, "frenado": 1.0,
        "giro": 7.0, "efecto": 0.0, "patada": 0.8, "sombra": true, "tramo": 18.0, "hueco": 13.0,
    },
    # T-11: las demás jugadas del partido (por tipo de carta, ver para_carta).
    "centro": {
        "alto_min": 1.6, "alto_por_metro": 0.16, "alto_max": 3.6, "curva": 0.12, "velocidad": 12.0, "frenado": 1.1,
        "giro": 9.0, "efecto": 6.0, "patada": 0.9, "sombra": true, "tramo": 20.0, "hueco": 12.0,
    },
    "remate": {
        "alto_min": 0.5, "alto_por_metro": 0.03, "alto_max": 1.1, "curva": 0.03, "velocidad": 24.0, "frenado": 1.0,
        "giro": 34.0, "efecto": 0.0, "patada": 1.3, "sombra": false, "tramo": 30.0, "hueco": 8.0,
    },
    "tiro_lejano": {
        "alto_min": 1.0, "alto_por_metro": 0.06, "alto_max": 2.2, "curva": 0.06, "velocidad": 22.0, "frenado": 1.0,
        "giro": 30.0, "efecto": 4.0, "patada": 1.2, "sombra": true, "tramo": 30.0, "hueco": 8.0,
    },
    "conduccion": {
        "alto_min": 0.0, "alto_por_metro": 0.0, "alto_max": 0.0, "curva": 0.0, "velocidad": 7.0, "frenado": 1.0,
        "giro": 12.0, "efecto": 0.0, "patada": 1.4, "sombra": false, "tramo": 14.0, "hueco": 10.0,
    },
}
const POR_DEFECTO := "pase_corto"
const DURACION_MIN := 0.3
const DURACION_MAX := 2.4


static func forma(carta: String) -> Dictionary:
    return FORMAS.get(carta, FORMAS[POR_DEFECTO])


# Forma de una carta del partido: la suya si tiene (los 4 pases de T-12); si no, la de su tipo.
static func para_carta(c: Card) -> String:
    if c == null:
        return POR_DEFECTO
    if FORMAS.has(c.id):
        return c.id
    match c.kind:
        Card.Kind.CROSS:
            return "centro"
        Card.Kind.SHOT:
            return "tiro_lejano" if c.long_range else "remate"
        Card.Kind.DRIBBLE, Card.Kind.CONTROL:
            return "conduccion"
    return "pelotazo" if c.steps >= 2 else POR_DEFECTO


static func _distancia_plana(origen: Vector3, destino: Vector3) -> float:
    return Vector2(destino.x - origen.x, destino.z - origen.z).length()


# Altura en la mitad del recorrido.
static func altura(carta: String, origen: Vector3, destino: Vector3) -> float:
    var f := forma(carta)
    var d := _distancia_plana(origen, destino)
    return clampf(d * float(f["alto_por_metro"]), float(f["alto_min"]), float(f["alto_max"]))


# La curva: k va de 0 (origen) a 1 (destino). Se abre siempre hacia la cámara, donde se lee mejor.
static func punto(carta: String, origen: Vector3, destino: Vector3, k: float) -> Vector3:
    var f := forma(carta)
    var campana := 4.0 * k * (1.0 - k)
    var p := origen.lerp(destino, k)
    var d := _distancia_plana(origen, destino)
    if float(f["curva"]) != 0.0 and d > 0.01:
        var lado := Vector3(-(destino.z - origen.z), 0.0, destino.x - origen.x) / d
        if lado.z < 0.0:
            lado = -lado
        p += lado * d * float(f["curva"]) * campana
    p.y += altura(carta, origen, destino) * campana
    return p


static func puntos(carta: String, origen: Vector3, destino: Vector3, n: int = 48) -> PackedVector3Array:
    var out := PackedVector3Array()
    for i in n + 1:
        out.append(punto(carta, origen, destino, float(i) / n))
    return out


# Cuánto dura el recorrido, en segundos.
static func duracion(carta: String, origen: Vector3, destino: Vector3) -> float:
    return clampf(_distancia_plana(origen, destino) / float(forma(carta)["velocidad"]), DURACION_MIN, DURACION_MAX)


# Del tiempo (0 a 1) al lugar en la curva (0 a 1).
static func avance(carta: String, t: float) -> float:
    return 1.0 - pow(1.0 - clampf(t, 0.0, 1.0), float(forma(carta)["frenado"]))
