extends Node3D

# T-12: jugador low poly hecho en código, sin cara (D-35). Un muñeco de piezas rígidas: pelvis, torso,
# cabeza, pelo, 2 brazos, 2 muslos y 2 piernas. Las mallas se comparten entre jugadores y cada parte
# tiene su material (colores del club). La animación son rotaciones por código, sin esqueleto.

const Malla := preload("res://scenes/prueba_3d/malla_low_poly.gd")

const ALTURA_CADERA := 0.92
const DURACION_PATADA := 0.55
const CONTACTO_PATADA := 0.25   # segundos desde que empieza la patada hasta que toca la pelota

var kit := {}                   # camiseta, short, medias, acento, piel, pelo, botas (colores) y estilo (pelo)
var mirar := Vector3.ZERO       # a dónde mira cuando está quieto (la pelota)

var _destino := Vector3.ZERO
var _velocidad := 0.0
var _rumbo := 0.0
var _carrera := 0.0             # 0 quieto, 1 corriendo: mezcla de las dos animaciones
var _t := 0.0
var _fase_pasos := 0.0
var _patada := -1.0             # segundos desde que empezó la patada; negativo = no patea

var _cuerpo: Node3D
var _torso: Node3D
var _cabeza: Node3D
var _brazos: Array[Node3D] = []
var _muslos: Array[Node3D] = []
var _rodillas: Array[Node3D] = []
var _anillo: MeshInstance3D


static var _formas := {}


static func _forma(nombre: String) -> ArrayMesh:
    if _formas.is_empty():
        _armar_formas()
    return _formas[nombre]


static func _armar_formas() -> void:
    # Pelvis (short)
    var m := Malla.new()
    m.prisma(-0.1, Vector2(0.17, 0.115), 0.1, Vector2(0.195, 0.125), 6)
    _formas["pelvis"] = m.a_malla()
    # Torso: camiseta y cuello
    m = Malla.new()
    m.prisma(0.0, Vector2(0.19, 0.135), 0.36, Vector2(0.28, 0.18), 6)
    m.prisma(0.36, Vector2(0.28, 0.18), 0.52, Vector2(0.17, 0.12), 6)
    _formas["torso"] = m.a_malla()
    m = Malla.new()
    m.prisma(0.5, Vector2(0.095, 0.09), 0.56, Vector2(0.085, 0.08), 6)
    m.a_malla(_formas["torso"])
    # Cuello y cabeza (piel, sin cara)
    m = Malla.new()
    m.prisma(0.0, Vector2(0.06, 0.06), 0.08, Vector2(0.06, 0.06), 5)
    m.prisma(0.06, Vector2(0.085, 0.095), 0.16, Vector2(0.125, 0.135), 6)
    m.prisma(0.16, Vector2(0.125, 0.135), 0.29, Vector2(0.115, 0.125), 6)
    m.prisma(0.29, Vector2(0.115, 0.125), 0.33, Vector2(0.08, 0.085), 6)
    _formas["cabeza"] = m.a_malla()
    # Pelo, tres estilos para distinguir a los jugadores sin caras
    m = Malla.new()
    m.prisma(0.215, Vector2(0.133, 0.143), 0.31, Vector2(0.123, 0.133), 6)
    m.prisma(0.31, Vector2(0.123, 0.133), 0.37, Vector2(0.07, 0.075), 6)
    m.prisma(0.1, Vector2(0.11, 0.05), 0.24, Vector2(0.13, 0.07), 6, Color.WHITE, Vector2(0, 0.085), Vector2(0, 0.085))
    _formas["pelo_corto"] = m.a_malla()
    m = Malla.new()
    m.prisma(0.2, Vector2(0.133, 0.143), 0.31, Vector2(0.125, 0.135), 6)
    m.prisma(0.31, Vector2(0.125, 0.135), 0.36, Vector2(0.075, 0.08), 6)
    m.prisma(-0.04, Vector2(0.13, 0.05), 0.24, Vector2(0.135, 0.08), 6, Color.WHITE, Vector2(0, 0.095), Vector2(0, 0.08))
    _formas["pelo_melena"] = m.a_malla()
    m = Malla.new()
    m.prisma(0.17, Vector2(0.15, 0.16), 0.3, Vector2(0.185, 0.195), 7)
    m.prisma(0.3, Vector2(0.185, 0.195), 0.43, Vector2(0.11, 0.115), 7)
    _formas["pelo_afro"] = m.a_malla()
    # Muslo: short y piel
    m = Malla.new()
    m.prisma(-0.23, Vector2(0.1, 0.1), 0.05, Vector2(0.115, 0.115), 6)
    _formas["muslo"] = m.a_malla()
    m = Malla.new()
    m.prisma(-0.44, Vector2(0.07, 0.075), -0.23, Vector2(0.09, 0.09), 6)
    m.a_malla(_formas["muslo"])
    # Pierna: media y bota
    m = Malla.new()
    m.prisma(-0.37, Vector2(0.058, 0.062), 0.0, Vector2(0.075, 0.08), 6)
    _formas["pierna"] = m.a_malla()
    m = Malla.new()
    m.prisma(-0.47, Vector2(0.075, 0.13), -0.39, Vector2(0.07, 0.11), 6, Color.WHITE, Vector2(0, -0.05), Vector2(0, -0.04))
    m.prisma(-0.39, Vector2(0.066, 0.075), -0.36, Vector2(0.06, 0.066), 6)
    m.a_malla(_formas["pierna"])
    # Brazo: manga y piel
    m = Malla.new()
    m.prisma(-0.24, Vector2(0.07, 0.07), 0.03, Vector2(0.085, 0.085), 6)
    _formas["brazo"] = m.a_malla()
    m = Malla.new()
    m.prisma(-0.46, Vector2(0.048, 0.048), -0.24, Vector2(0.06, 0.06), 5)
    m.prisma(-0.53, Vector2(0.04, 0.05), -0.46, Vector2(0.055, 0.055), 5)
    m.a_malla(_formas["brazo"])


# Triángulos de un jugador (para el informe): se suman las piezas, con 2 brazos, 2 muslos y 2 piernas.
static func triangulos_por_jugador(estilo: String = "corto") -> int:
    var total := 0
    for nombre in ["pelvis", "torso", "cabeza", "pelo_" + estilo]:
        total += _forma(nombre).get_faces().size() / 3
    for nombre in ["brazo", "muslo", "pierna"]:
        total += 2 * _forma(nombre).get_faces().size() / 3
    return total


func armar(p_kit: Dictionary) -> void:
    kit = p_kit
    _rumbo = randf_range(0.0, TAU)
    _t = randf_range(0.0, 6.0)
    _cuerpo = _pivote(self, Vector3(0, ALTURA_CADERA, 0))
    _pieza(_cuerpo, "pelvis", [kit["short"]])
    _torso = _pivote(_cuerpo, Vector3(0, 0.08, 0))
    _pieza(_torso, "torso", [kit["camiseta"], kit["acento"]])
    _cabeza = _pivote(_torso, Vector3(0, 0.52, 0))
    _pieza(_cabeza, "cabeza", [kit["piel"]])
    var estilo := String(kit.get("estilo", "corto"))
    if estilo != "pelado":
        _pieza(_cabeza, "pelo_" + estilo, [kit["pelo"]])
    for lado: float in [-1.0, 1.0]:
        var brazo := _pivote(_torso, Vector3(lado * 0.31, 0.45, 0))
        _pieza(brazo, "brazo", [kit["camiseta"], kit["piel"]])
        _brazos.append(brazo)
        var muslo := _pivote(_cuerpo, Vector3(lado * 0.105, -0.02, 0))
        _pieza(muslo, "muslo", [kit["short"], kit["piel"]])
        _muslos.append(muslo)
        var rodilla := _pivote(muslo, Vector3(0, -0.43, 0))
        _pieza(rodilla, "pierna", [kit["medias"], kit["botas"]])
        _rodillas.append(rodilla)
    _destino = position


func _pivote(padre: Node3D, pos: Vector3) -> Node3D:
    var n := Node3D.new()
    n.position = pos
    padre.add_child(n)
    return n


func _pieza(padre: Node3D, forma: String, colores: Array) -> void:
    var mi := MeshInstance3D.new()
    mi.mesh = _forma(forma)
    for i in colores.size():
        mi.set_surface_override_material(i, Malla.material(colores[i]))
    padre.add_child(mi)


# Lo pone en un lugar de golpe, mirando a `objetivo`.
func colocar(pos: Vector3, objetivo: Vector3) -> void:
    position = pos
    _destino = pos
    mirar = objetivo
    var dir := objetivo - pos
    _rumbo = atan2(-dir.x, -dir.z)
    rotation.y = _rumbo


# Corre hasta `pos` en `tiempo` segundos.
func ir_a(pos: Vector3, tiempo: float) -> void:
    _destino = pos
    _velocidad = position.distance_to(pos) / maxf(tiempo, 0.05)


func patear() -> void:
    _patada = 0.0


# Pone o saca el anillo del suelo (portador, receptor, libre). null = sin anillo.
func poner_anillo(malla: Mesh) -> void:
    if _anillo == null:
        _anillo = MeshInstance3D.new()
        _anillo.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
        _anillo.top_level = true
        add_child(_anillo)
    _anillo.mesh = malla
    _anillo.visible = malla != null


func _process(delta: float) -> void:
    _t += delta
    _mover(delta)
    _animar(delta)
    if _anillo != null:
        _anillo.global_position = Vector3(position.x, 0.0, position.z)


func _mover(delta: float) -> void:
    var falta := _destino - position
    falta.y = 0.0
    var distancia := falta.length()
    var corre := distancia > 0.03
    if corre:
        position += falta / distancia * minf(_velocidad * delta, distancia)
        _rumbo = atan2(-falta.x, -falta.z)
        _fase_pasos += delta * clampf(_velocidad * 2.2, 8.0, 13.0)
    else:
        var dir := mirar - position
        _rumbo = atan2(-dir.x, -dir.z)
    rotation.y = lerp_angle(rotation.y, _rumbo, 1.0 - exp(-9.0 * delta))
    _carrera = move_toward(_carrera, 1.0 if corre else 0.0, delta * 7.0)


func _animar(delta: float) -> void:
    var c := _carrera
    var respira := sin(_t * 2.3)
    var lento := sin(_t * 1.1)
    var paso := sin(_fase_pasos)
    # Tronco: respira quieto; al correr se inclina y rebota.
    _torso.scale.y = 1.0 + 0.016 * respira * (1.0 - c)
    _torso.rotation.x = lerpf(0.03 * lento, -0.24, c)
    _torso.rotation.z = 0.025 * lento * (1.0 - c)
    _cuerpo.position.y = ALTURA_CADERA - 0.012 * (1.0 - c) + 0.045 * absf(cos(_fase_pasos)) * c
    _cuerpo.position.x = 0.012 * lento * (1.0 - c)
    _cabeza.rotation.x = lerpf(0.03 * respira, 0.14, c)
    # Brazos: casi quietos o se balancean contra las piernas.
    for i in 2:
        var lado := -1.0 if i == 0 else 1.0
        var brazo := _brazos[i]
        brazo.rotation.x = lerpf(0.05 * respira * lado, -paso * lado * 0.85 + 0.15, c)
        brazo.rotation.z = lado * lerpf(0.13 + 0.015 * respira, 0.2, c)
    # Piernas: un poco flectadas o la zancada (la rodilla se dobla cuando la pierna va atrás).
    for i in 2:
        var lado := -1.0 if i == 0 else 1.0
        var zancada := paso * lado
        _muslos[i].rotation.x = lerpf(0.1, zancada * 0.75 + 0.15, c)
        _muslos[i].rotation.z = lado * lerpf(0.05, 0.015, c)
        _rodillas[i].rotation.x = lerpf(-0.18, -0.25 - maxf(0.0, -cos(_fase_pasos + (0.0 if i == 0 else PI))) * 1.1, c)
    if _patada >= 0.0:
        _animar_patada(delta)


# La pierna derecha va atrás, pasa por la pelota y vuelve. Los brazos abren para equilibrar.
func _animar_patada(delta: float) -> void:
    _patada += delta
    var t := _patada
    if t >= DURACION_PATADA:
        _patada = -1.0
        return
    var muslo := 0.1
    var rodilla := -0.18
    if t < CONTACTO_PATADA:
        var k := t / CONTACTO_PATADA
        muslo = lerpf(0.1, -0.75, smoothstep(0.0, 0.7, k))
        rodilla = lerpf(-0.18, -1.25, smoothstep(0.0, 0.7, k))
        if k > 0.7:
            var golpe := (k - 0.7) / 0.3
            muslo = lerpf(-0.75, 0.35, golpe)
            rodilla = lerpf(-1.25, -0.5, golpe)
    else:
        var k := (t - CONTACTO_PATADA) / (DURACION_PATADA - CONTACTO_PATADA)
        muslo = lerpf(0.35, 1.05, smoothstep(0.0, 0.4, k))
        rodilla = lerpf(-0.5, -0.1, smoothstep(0.0, 0.4, k))
        if k > 0.4:
            var baja := (k - 0.4) / 0.6
            muslo = lerpf(1.05, 0.1, baja)
            rodilla = lerpf(-0.1, -0.18, baja)
    _muslos[1].rotation.x = muslo
    _rodillas[1].rotation.x = rodilla
    _torso.rotation.x = 0.12 * sin(t / DURACION_PATADA * PI)
    _brazos[0].rotation.x = 0.5 * sin(t / DURACION_PATADA * PI)
    _brazos[1].rotation.x = -0.5 * sin(t / DURACION_PATADA * PI)
    _brazos[0].rotation.z = -0.45
    _brazos[1].rotation.z = 0.45


# Pelota junto al pie del jugador, del lado de `hacia`.
func junto_al_pie(hacia: Vector3, radio_pelota: float) -> Vector3:
    var dir := hacia - position
    dir.y = 0.0
    if dir.length() < 0.01:
        dir = Vector3.FORWARD
    return position + dir.normalized() * 0.42 + Vector3(0, radio_pelota, 0)
