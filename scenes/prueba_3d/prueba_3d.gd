extends Control

# T-12: prueba técnica de la cancha 3D low poly. Es una escena suelta, no se conecta al partido: arriba
# la señal de TV (3D en un SubViewport) y abajo láminas de CardUI, para ver cómo conviven 3D y 2D. Imita
# la maqueta v5 (lienzo "Dirección visual"): Aceval (Colo-Colo) le pasa a Fernández, marcado por dos de
# la U. El pase corre en loop. Se abre sola: Godot --path . res://scenes/prueba_3d/prueba_3d.tscn

const Jugador := preload("res://scenes/prueba_3d/jugador_low_poly.gd")
const Cancha := preload("res://scenes/prueba_3d/cancha_3d.gd")
const Grafica := preload("res://scenes/prueba_3d/grafica_tv.gd")
const Malla := preload("res://scenes/prueba_3d/malla_low_poly.gd")
const CARD_SCENE := preload("res://scenes/card_ui.tscn")

const ALTO_SENAL := 460.0
const RADIO_PELOTA := 0.2
const COLO := "colo_colo"
const LA_U := "universidad_de_chile"
# Los clubes solo guardan 2 colores: el short de la U saldría rojo. Se indica aquí para la prueba
# (hallazgo para el informe: los 20 uniformes piden un dato más por club).
const SHORT_POR_CLUB := {"universidad_de_chile": Color("#f2f2f2")}
const BOTAS := Color("#15171c")
# Cámara de TV: lejos y con lente larga, para que los jugadores de los bordes no se vean inclinados.
const CAM_FOV := 22.0
const CAM_ALTO := 13.5
const CAM_Z := 27.0
const CAM_MIRA_Z := 0.9

# Línea de tiempo del loop, en segundos.
const T_PATADA := 1.6
const T_SALE := T_PATADA + Jugador.CONTACTO_PATADA
const T_LLEGA := T_SALE + 1.2
const T_VUELVE := 5.2
const T_VUELTA_LLEGA := T_VUELVE + 1.2
const T_LOOP := 7.0
# Momentos de las capturas (los usa tools/prueba_3d_captura.gd).
const T_ANTES := 1.2
const T_AIRE := T_SALE + 0.6
const T_RECIBE := T_LLEGA + 0.25

# nombre, club, [x, z] al empezar, [x, z] tras el pase, piel, pelo, estilo, marcas (D-40), libre
const PLANTEL := [
    ["ACEVAL", COLO, [-8.2, 7.0], [-6.5, 6.5], "#c98e63", "#2a1d14", "corto", 0, false],
    ["VIDAL", COLO, [-3.2, 6.1], [-1.9, 5.7], "#c98e63", "#111111", "corto", 0, true],
    ["SÁNCHEZ", COLO, [-1.6, -1.4], [0.5, -0.9], "#c98e63", "#3a2618", "melena", 1, false],
    ["FERNÁNDEZ", COLO, [2.9, 3.4], [1.5, 4.0], "#d9a47c", "#4a3322", "corto", 2, false],
    ["MELÉNDEZ", COLO, [7.3, 5.6], [8.4, 5.1], "#a8714b", "#111111", "afro", 0, true],
    ["SALAS", LA_U, [-6.8, 6.7], [-5.0, 6.0], "#d9a47c", "#2a1d14", "corto", 0, false],
    ["CANDELO", LA_U, [-0.3, -1.2], [1.8, -0.7], "#a8714b", "#111111", "pelado", 0, false],
    ["ITURRA", LA_U, [1.9, 3.1], [0.5, 3.5], "#c98e63", "#111111", "melena", 0, false],
    ["DÍAZ", LA_U, [4.0, 3.8], [2.7, 4.6], "#a8714b", "#2a1d14", "afro", 0, false],
]

var t := 0.0                    # segundos dentro del loop

var _vista: SubViewport
var _camara: Camera3D
var _pelota: MeshInstance3D
var _jugadores := {}            # nombre -> jugador
var _etiquetas := {}            # nombre -> gráfica de TV
var _colores := {}              # club -> [primario, secundario]
var _color_marca := Color.WHITE
var _portador := "ACEVAL"
var _con_balon: Control
var _flecha: Control
var _camino: Control
var _cam_x := 0.0
var _vuelo_desde := Vector3.ZERO
var _vuelo_hasta := Vector3.ZERO
var _vuelo_ini := -1.0
var _vuelo_dura := 1.0
var _pasos := {}                # eventos de esta vuelta del loop que ya pasaron
var _anillo_portador: ArrayMesh
var _anillo_receptor: ArrayMesh
var _anillo_libre: ArrayMesh
var _carta_apuntada: Control


func _ready() -> void:
    var liga := LeagueManager.new()
    liga.load_all()
    _colores[COLO] = liga.team_colors(liga.get_team(COLO))
    _colores[LA_U] = liga.team_colors(liga.get_team(LA_U))
    add_child(Mesa.madera())
    move_child(get_child(-1), 0)
    _vista = $Senal/Vista3D
    _armar_mundo()
    _armar_jugadores()
    _armar_senal_2d()
    _armar_mano()
    reiniciar()


# ------------------------------------------------------------------ Mundo 3D

func _armar_mundo() -> void:
    var entorno := Environment.new()
    entorno.background_mode = Environment.BG_COLOR
    entorno.background_color = Color("#0c130e")
    entorno.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
    entorno.ambient_light_color = Color("#dfe6f2")
    entorno.ambient_light_energy = 0.72
    entorno.tonemap_mode = Environment.TONE_MAPPER_LINEAR
    var mundo := WorldEnvironment.new()
    mundo.environment = entorno
    _vista.add_child(mundo)
    var sol := DirectionalLight3D.new()
    sol.rotation_degrees = Vector3(-52, -38, 0)
    sol.light_color = Color("#fff4dc")
    sol.light_energy = 0.95
    sol.shadow_enabled = true
    sol.directional_shadow_mode = DirectionalLight3D.SHADOW_ORTHOGONAL
    sol.directional_shadow_max_distance = 45.0
    sol.shadow_blur = 0.6
    _vista.add_child(sol)
    _vista.add_child(Cancha.new())
    _camara = Camera3D.new()
    _camara.fov = CAM_FOV
    _camara.near = 2.0
    _camara.far = 110.0
    _camara.position = Vector3(0, CAM_ALTO, CAM_Z)
    _vista.add_child(_camara)
    _camara.look_at(Vector3(0, 0, CAM_MIRA_Z))
    var bola := Malla.new()
    bola.pelota(RADIO_PELOTA)
    _pelota = MeshInstance3D.new()
    _pelota.mesh = bola.a_malla()
    _pelota.set_surface_override_material(0, Malla.material_vertices())
    _vista.add_child(_pelota)
    _anillo_portador = _malla_anillo([[0.82, 0.92, Color(Paleta.DORADO)]])
    _anillo_receptor = _malla_anillo([[0.82, 1.08, Color("#ffe14d", 0.28)], [0.9, 1.0, Color("#ffe14d")]])
    _anillo_libre = _malla_anillo([[0.0, 0.72, Color("#4fd18b", 0.2)], [0.68, 0.76, Color("#4fd18b")]])


func _malla_anillo(capas: Array) -> ArrayMesh:
    var m := Malla.new()
    for capa: Array in capas:
        m.anillo(capa[0], capa[1], 28, 0.04, capa[2])
    var malla := m.a_malla()
    malla.surface_set_material(0, Malla.material_vertices(false, true))
    return malla


func _armar_jugadores() -> void:
    for dato: Array in PLANTEL:
        var club := String(dato[1])
        var j := Jugador.new()
        _vista.add_child(j)
        j.armar(_kit(club, Color(dato[4]), Color(dato[5]), String(dato[6])))
        _jugadores[dato[0]] = j


func _kit(club: String, piel: Color, pelo: Color, estilo: String) -> Dictionary:
    var cols: Array = _colores[club]
    return {
        "camiseta": cols[0],
        "short": SHORT_POR_CLUB.get(club, cols[1]),
        "medias": cols[0],
        "acento": cols[1],
        "botas": BOTAS,
        "piel": piel,
        "pelo": pelo,
        "estilo": estilo,
    }


# Agrega jugadores sin nombre más atrás, para medir cómo cae el rendimiento con la cancha llena.
func agregar_extras(cantidad: int) -> void:
    var pieles := ["#c98e63", "#a8714b", "#d9a47c"]
    var estilos := ["corto", "melena", "afro", "pelado"]
    for i in cantidad:
        var club := COLO if i % 2 == 0 else LA_U
        var j := Jugador.new()
        _vista.add_child(j)
        j.armar(_kit(club, Color(pieles[i % 3]), Color("#1c1410"), estilos[i % 4]))
        var pos := Vector3(-12.0 + (i % 7) * 4.5, 0.0, -5.5 + (i / 7) * 3.2 + (i % 2) * 0.8)
        j.colocar(pos, Vector3.ZERO)
        j.ir_a(pos + Vector3(1.5, 0, 0.8), 0.5)


# ------------------------------------------------------------------ 2D sobre la señal

func _armar_senal_2d() -> void:
    # Líneas de TV y viñeta, como en la maqueta.
    var filtro := ColorRect.new()
    filtro.size = Vector2(1280, ALTO_SENAL)
    filtro.mouse_filter = Control.MOUSE_FILTER_IGNORE
    var sh := Shader.new()
    sh.code = """shader_type canvas_item;
void fragment() {
    float linea = step(2.0, mod(FRAGCOORD.y, 3.0)) * 0.08;
    float vin = smoothstep(0.62, 1.05, length((UV - 0.5) * vec2(1.82, 2.0))) * 0.42;
    COLOR = vec4(0.0, 0.0, 0.0, 1.0 - (1.0 - linea) * (1.0 - vin));
}"""
    var mat := ShaderMaterial.new()
    mat.shader = sh
    filtro.material = mat
    add_child(filtro)
    # Etiquetas: solo los de Colo-Colo, con sus marcas (puntos del color del rival, aclarado para verse).
    _color_marca = _colores[LA_U][0].lightened(0.25)
    for dato: Array in PLANTEL:
        if dato[1] != COLO:
            continue
        var g := Grafica.new()
        add_child(g)
        _etiquetas[dato[0]] = g
    _flecha = Control.new()
    _flecha.size = Vector2(1280, 720)
    _flecha.mouse_filter = Control.MOUSE_FILTER_IGNORE
    _flecha.draw.connect(_dibujar_flecha)
    add_child(_flecha)
    # Barra de arriba
    var barra := ColorRect.new()
    barra.size = Vector2(1280, 40)
    barra.color = Color(Paleta.TV_FONDO, 0.88)
    barra.mouse_filter = Control.MOUSE_FILTER_IGNORE
    add_child(barra)
    var x := 16.0
    for parte: Array in [["CC", 20, Color("#111111"), Grafica.PLATA],
            ["0 - 0", 24, Color.WHITE, Paleta.TV_AZUL],
            ["UCH", 20, Color.WHITE, [Color("#2b56c4"), Color("#0033a0"), Color("#002680"), Color("#0a3aa8")]],
            ["12'", 20, Paleta.DORADO, Grafica.SEMI_NOCHE]]:
        var g := Grafica.new()
        add_child(g)
        g.configurar(parte[0], parte[1], parte[2], parte[3])
        g.position = Vector2(x, 20.0 - g.size.y * 0.5)
        x += g.size.x - g.size.y * Grafica.SKEW
    _camino = Control.new()
    _camino.size = Vector2(1280, 40)
    _camino.mouse_filter = Control.MOUSE_FILTER_IGNORE
    _camino.draw.connect(_dibujar_camino)
    add_child(_camino)
    var vivo := Grafica.new()
    add_child(vivo)
    vivo.configurar("EN VIVO", 16, Color.WHITE, [Color(0, 0, 0, 0), Color(0, 0, 0, 0), Color(0, 0, 0, 0), Color(0, 0, 0, 0)], 1, Color("#ff3b2f"))
    vivo.position = Vector2(1262.0 - vivo.size.x, 20.0 - vivo.size.y * 0.5)
    _con_balon = Control.new()
    _con_balon.position = Vector2(16, 54)
    _con_balon.mouse_filter = Control.MOUSE_FILTER_IGNORE
    add_child(_con_balon)


func _dibujar_camino() -> void:
    var f := Paleta.letra("tv", 1)
    var y := 20.0
    var x := 470.0
    var actual := 0 if _portador == "ACEVAL" else 1
    var nombres := ["SALIDA", "MEDIO", "ÁREA"]
    for i in 3:
        var color := Color.WHITE if i == actual else (Paleta.DORADO if i == actual + 1 else Color("#8d9ab0"))
        if i == actual:
            _camino.draw_circle(Vector2(x + 9, y), 12.0, Color(1, 1, 1, 0.25), true, -1.0, true)
            _camino.draw_circle(Vector2(x + 9, y), 9.0, color, true, -1.0, true)
        else:
            _camino.draw_arc(Vector2(x + 9, y), 7.5, 0.0, TAU, 24, color, 3.0, true)
        x += 24.0
        _camino.draw_string(f, Vector2(x, y + 7.0), nombres[i], HORIZONTAL_ALIGNMENT_LEFT, -1, 18, color)
        x += f.get_string_size(nombres[i], HORIZONTAL_ALIGNMENT_LEFT, -1, 18).x + 10.0
        if i < 2:
            _camino.draw_rect(Rect2(x, y - 1.5, 54, 3), Color(1, 1, 1, 0.3))
            x += 64.0


# Flecha de apuntar: de la lámina al receptor. Se dibuja en 2D y sigue a la cámara 3D.
func _dibujar_flecha() -> void:
    if t >= T_PATADA or _carta_apuntada == null:
        return
    var j: Node3D = _jugadores["FERNÁNDEZ"]
    var fin := _camara.unproject_position(j.position + Vector3(0, 2.1, 0))
    var ini := _carta_apuntada.global_position + Vector2(_carta_apuntada.size.x * 0.5, 2.0)
    var ctrl1 := ini + Vector2(-20, -190)
    var ctrl2 := fin + Vector2(-260, -70)
    var puntos := PackedVector2Array()
    for i in 73:
        var k := i / 72.0
        puntos.append(ini.bezier_interpolate(ctrl1, ctrl2, fin, k))
    _flecha.draw_polyline(puntos, Color(Paleta.DORADO, 0.35), 10.0, true)
    var paso := 0
    while paso < 70:
        var tramo := puntos.slice(paso, paso + 4)
        _flecha.draw_polyline(tramo, Color("#1a1408"), 8.0, true)
        _flecha.draw_polyline(tramo, Color("#ffe08a"), 5.0, true)
        paso += 5
    var dir := (fin - puntos[68]).normalized()
    var lado := Vector2(-dir.y, dir.x)
    var punta := PackedVector2Array([fin + dir * 10.0, fin - dir * 12.0 + lado * 12.0, fin - dir * 12.0 - lado * 12.0])
    _flecha.draw_colored_polygon(punta, Color("#ffe08a"))
    _flecha.draw_polyline(PackedVector2Array([punta[0], punta[1], punta[2], punta[0]]), Color("#1a1408"), 2.5, true)


func _actualizar_etiquetas() -> void:
    for dato: Array in PLANTEL:
        var nombre: String = dato[0]
        if not _etiquetas.has(nombre):
            continue
        var g: Control = _etiquetas[nombre]
        if nombre == _portador:
            g.configurar(nombre, 16, Paleta.DORADO, Grafica.SEMI_NOCHE, dato[7], _color_marca)
        elif dato[8]:
            g.configurar(nombre + " · LIBRE", 16, Color.WHITE, Paleta.PLACA_VERDE)
        elif nombre == "FERNÁNDEZ":
            g.configurar(nombre, 17, Color("#ffe14d"), Grafica.SEMI_NOCHE, dato[7], _color_marca, Color("#ffe14d"))
        else:
            g.configurar(nombre, 16, Color.WHITE, Grafica.SEMI_NOCHE, dato[7], _color_marca)


func _colocar_etiquetas() -> void:
    for nombre: String in _etiquetas:
        var j: Node3D = _jugadores[nombre]
        var g: Control = _etiquetas[nombre]
        var p := _camara.unproject_position(j.position)
        g.position = Vector2(p.x - g.size.x * 0.5, p.y + 12.0)


func _poner_con_balon(nombre: String, puesto: String) -> void:
    for hijo in _con_balon.get_children():
        hijo.queue_free()
    var a := Grafica.new()
    _con_balon.add_child(a)
    a.configurar("CON EL BALÓN", 15, Color("#0b111b"), Paleta.PLACA_DORADA)
    var b := Grafica.new()
    _con_balon.add_child(b)
    b.configurar("%s · %s" % [nombre, puesto], 20, Color("#0b111b"), Grafica.PLATA)
    b.position.x = a.size.x - a.size.y * Grafica.SKEW
    a.position.y = (b.size.y - a.size.y) * 0.5


# ------------------------------------------------------------------ Láminas (2D, estáticas)

func _armar_mano() -> void:
    var catalogo := CardDB.load_catalog()
    var ctx := {"jugador": {"name": "Aceval", "role": "LAT"}, "colores": _colores[COLO]}
    # id, % de la placa (valores de la maqueta), motivo si no se puede jugar, giro, baja
    var mano := [["pase_corto", 0.29, "", -3.0, 0.0],
            ["toque_toque", 0.57, "", -1.0, 6.0],
            ["amague", 0.64, "", 1.0, 8.0],
            ["remate_simple", 0.0, "solo en el área", 3.0, 10.0]]
    var x := 268.0
    for dato: Array in mano:
        var c := Card.from_dict(catalogo[dato[0]])
        var ui: CardUI = CARD_SCENE.instantiate()
        ui.custom_minimum_size = CardUI.TAMANO
        add_child(ui)
        ui.setup(c, 0, ctx)
        ui.update_stats(c.ap_cost, c.ap_cost, c.stamina_cost * MatchEngine.STAMINA_SCALE, dato[1], dato[2] == "", false, [], dato[2])
        if dato[2] != "":
            ui.chance_label.visible = false
        ui.set_interactive(false)
        ui.mouse_filter = Control.MOUSE_FILTER_IGNORE
        ui.position = Vector2(x, 464.0 + dato[4])
        ui.pivot_offset = CardUI.TAMANO * 0.5
        ui.rotation_degrees = dato[3]
        if _carta_apuntada == null:
            _carta_apuntada = ui
        x += 174.0
    # Moneda de PA a la izquierda y botón principal a la derecha, como en v5.
    var moneda := TextureRect.new()
    moneda.texture = Paleta.moneda(Paleta.MONEDA["normal"])
    moneda.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
    moneda.size = Vector2(104, 104)
    moneda.position = Vector2(30, 490)
    moneda.mouse_filter = Control.MOUSE_FILTER_IGNORE
    add_child(moneda)
    var pa := Paleta.etiqueta("3", "condensada_negra", 56, Color("#1a1408"))
    pa.position = Vector2(30, 490)
    pa.size = Vector2(104, 72)
    pa.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    pa.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
    add_child(pa)
    var pa2 := Paleta.etiqueta("PA", "condensada_negra", 16, Color("#1a1408"), 2)
    pa2.position = Vector2(30, 554)
    pa2.size = Vector2(104, 20)
    pa2.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    add_child(pa2)
    var ceder := Grafica.new()
    add_child(ceder)
    ceder.margen = 16.0
    ceder.configurar("CEDER JUGADA", 24, Color.WHITE, Paleta.TV_AZUL)
    ceder.position = Vector2(1080, 510)
    var aviso := Paleta.etiqueta("prueba técnica T-12: valores de la maqueta", "plumon", 14, Paleta.PLUMON_CREMA)
    aviso.position = Vector2(30, 622)
    aviso.size = Vector2(190, 60)
    aviso.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
    aviso.rotation_degrees = -2.0
    add_child(aviso)


# ------------------------------------------------------------------ Loop del pase

func reiniciar() -> void:
    t = 0.0
    _pasos.clear()
    _vuelo_ini = -1.0
    var aceval: Node3D = _jugadores["ACEVAL"]
    var inicio := Vector3(PLANTEL[0][2][0], 0, PLANTEL[0][2][1])
    aceval.position = inicio
    var destino := _pos(3, 2)
    for i in PLANTEL.size():
        var j: Node3D = _jugadores[PLANTEL[i][0]]
        j.colocar(_pos(i, 2), inicio if i != 0 else destino)
    _cam_x = _objetivo_camara(inicio.x)
    _set_portador("ACEVAL", "LAT")
    _pelota.position = aceval.junto_al_pie(destino, RADIO_PELOTA)


func _pos(indice: int, columna: int) -> Vector3:
    var p: Array = PLANTEL[indice][columna]
    return Vector3(p[0], 0, p[1])


func _set_portador(nombre: String, puesto: String) -> void:
    _portador = nombre
    _poner_con_balon(nombre, puesto)
    _actualizar_etiquetas()
    for dato: Array in PLANTEL:
        var j = _jugadores[dato[0]]
        if dato[0] == nombre:
            j.poner_anillo(_anillo_portador)
        elif dato[0] == "FERNÁNDEZ":
            j.poner_anillo(_anillo_receptor)
        elif dato[8]:
            j.poner_anillo(_anillo_libre)
        else:
            j.poner_anillo(null)
    if _camino != null:
        _camino.queue_redraw()


func _una_vez(evento: String, instante: float) -> bool:
    if t >= instante and not _pasos.has(evento):
        _pasos[evento] = true
        return true
    return false


func _lanzar(desde: Vector3, hasta: Vector3, dura: float) -> void:
    _vuelo_desde = desde
    _vuelo_hasta = hasta
    _vuelo_ini = t
    _vuelo_dura = dura


func _process(delta: float) -> void:
    t += delta
    if t >= T_LOOP:
        reiniciar()
    if _una_vez("patada", T_PATADA):
        _jugadores["ACEVAL"].patear()
    if _una_vez("sale", T_SALE):
        var llegada: Vector3 = _pos(3, 3)
        _lanzar(_pelota.position, llegada + (_pelota.position - llegada).normalized() * 0.42, T_LLEGA - T_SALE)
        for i in PLANTEL.size():
            _jugadores[PLANTEL[i][0]].ir_a(_pos(i, 3), T_LLEGA - T_SALE - 0.05)
    if _una_vez("llega", T_LLEGA):
        _set_portador("FERNÁNDEZ", "MCO")
    if _una_vez("vuelve", T_VUELVE):
        var inicio: Vector3 = _pos(0, 2)
        var vuelta: Vector3 = inicio + (_pelota.position - inicio).normalized() * 0.42
        _lanzar(_pelota.position, vuelta, T_VUELTA_LLEGA - T_VUELVE)
        for i in PLANTEL.size():
            _jugadores[PLANTEL[i][0]].ir_a(_pos(i, 2), T_VUELTA_LLEGA - T_VUELVE - 0.05)
    if _una_vez("recupera", T_VUELTA_LLEGA):
        _set_portador("ACEVAL", "LAT")
    # Todos miran la pelota.
    for i in PLANTEL.size():
        _jugadores[PLANTEL[i][0]].mirar = _pelota.position
    _mover_pelota(delta)
    _mover_camara(delta)
    _colocar_etiquetas()
    _flecha.queue_redraw()


func _mover_pelota(delta: float) -> void:
    if _vuelo_ini < 0.0:
        return
    var k := (t - _vuelo_ini) / _vuelo_dura
    if k >= 1.0:
        _vuelo_ini = -1.0
        _pelota.position = Vector3(_vuelo_hasta.x, RADIO_PELOTA, _vuelo_hasta.z)
        return
    var p := _vuelo_desde.lerp(_vuelo_hasta, k)
    p.y = RADIO_PELOTA + 4.0 * 2.6 * k * (1.0 - k)
    _pelota.position = p
    _pelota.rotate_object_local(Vector3.RIGHT, -delta * 11.0)
    _pelota.rotate_object_local(Vector3.UP, delta * 3.0)


func _objetivo_camara(x_pelota: float) -> float:
    return x_pelota * 0.45


# Cámara de TV: alta y de costado; se desliza suave detrás de la pelota y gira un poco hacia ella.
func _mover_camara(delta: float) -> void:
    var objetivo := _objetivo_camara(_pelota.position.x)
    _cam_x = lerpf(_cam_x, objetivo, 1.0 - exp(-2.6 * delta))
    _camara.position.x = _cam_x
    _camara.look_at(Vector3(_cam_x + (_pelota.position.x - _cam_x) * 0.08, 0, CAM_MIRA_Z))
