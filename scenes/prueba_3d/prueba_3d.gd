extends Control

# T-12: prueba técnica de la cancha 3D low poly (D-41). Es una escena suelta, no se conecta al partido:
# arriba la señal de TV (3D en un SubViewport) y abajo láminas de CardUI. Arrastras una lámina de pase
# sobre Vidal, Sánchez, Fernández o Meléndez y al soltar la pelota viaja a ese jugador, que pasa a ser el
# portador (D-40). No hay motor ni tirada: el pase siempre llega y los % son de muestra.
# Se abre sola: Godot --path . res://scenes/prueba_3d/prueba_3d.tscn   (R = volver a Aceval)

const Jugador := preload("res://scenes/prueba_3d/jugador_low_poly.gd")
const Cancha := preload("res://scenes/prueba_3d/cancha_3d.gd")
const Grafica := preload("res://scenes/prueba_3d/grafica_tv.gd")
const Malla := preload("res://scenes/prueba_3d/malla_low_poly.gd")
const Trayectoria := preload("res://scenes/prueba_3d/trayectoria.gd")
const CARD_SCENE := preload("res://scenes/card_ui.tscn")

const ALTO_MANO := 260.0        # lo que queda abajo para las láminas; la señal toma el resto de la ventana
const RADIO_PELOTA := 0.2
const COLO := "colo_colo"
const LA_U := "universidad_de_chile"
# Los clubes solo guardan 2 colores: el short de la U saldría rojo. Se indica aquí para la prueba
# (hallazgo para el informe: los 20 uniformes piden un dato más por club).
const SHORT_POR_CLUB := {"universidad_de_chile": Color("#f2f2f2")}
const BOTAS := Color("#15171c")
# Cámara de TV: lejos y con lente larga, para que los jugadores de los bordes no se vean inclinados.
# FOCO son píxeles de pantalla por unidad a distancia 1: el zoom no cambia con el alto de la ventana.
const FOCO := 1183.0
const CAM_ALTO := 13.5
const CAM_Z := 27.0
const CAM_MIRA_Z := 0.9

# nombre, club, [x, z], piel, pelo, estilo de pelo
const PLANTEL := [
    ["ACEVAL", COLO, [-8.2, 7.0], "#c98e63", "#2a1d14", "corto"],
    ["VIDAL", COLO, [-3.2, 6.1], "#c98e63", "#111111", "corto"],
    ["SÁNCHEZ", COLO, [-2.4, -1.4], "#c98e63", "#3a2618", "melena"],
    ["FERNÁNDEZ", COLO, [2.9, 3.4], "#d9a47c", "#4a3322", "corto"],
    ["MELÉNDEZ", COLO, [7.6, 5.6], "#a8714b", "#111111", "afro"],
    ["SALAS", LA_U, [-6.6, 6.4], "#d9a47c", "#2a1d14", "corto"],
    ["CANDELO", LA_U, [-0.8, -1.0], "#a8714b", "#111111", "pelado"],
    ["ITURRA", LA_U, [1.4, 2.8], "#c98e63", "#111111", "melena"],
    ["DÍAZ", LA_U, [4.6, 3.6], "#a8714b", "#2a1d14", "afro"],
]
const RECEPTORES := ["VIDAL", "SÁNCHEZ", "FERNÁNDEZ", "MELÉNDEZ"]
# Quién marca a quién en esta jugada (D-40). Fijo: la IA de las marcas todavía no existe.
const MARCAS := {
    "ACEVAL": ["SALAS"],
    "VIDAL": [],
    "SÁNCHEZ": ["CANDELO"],
    "FERNÁNDEZ": ["ITURRA", "DÍAZ"],
    "MELÉNDEZ": [],
}
# Habilidades de muestra: nivel de squads_2006 + ajuste del puesto (docs/cartas.md, D-32). Fernández lleva
# el perfil Gambeteador del ejemplo de esa misma tabla.
const PROPIOS := {
    "ACEVAL": {"puesto": "LAT", "pase": 66, "regate": 66},
    "VIDAL": {"puesto": "MCD", "pase": 74, "regate": 64},
    "SÁNCHEZ": {"puesto": "EXT", "pase": 67, "regate": 75},
    "FERNÁNDEZ": {"puesto": "MCO", "pase": 87, "regate": 90},
    "MELÉNDEZ": {"puesto": "MCD", "pase": 72, "regate": 62},
}
const RIVALES := {
    "SALAS": {"quite": 53, "lectura": 58},
    "CANDELO": {"quite": 61, "lectura": 66},
    "ITURRA": {"quite": 75, "lectura": 75},
    "DÍAZ": {"quite": 67, "lectura": 67},
}
# Fórmula de docs/cartas.md ("Pase con marcas"): 39 + carta + 0,5 × (habilidad − la suya) + números.
const BASE_DUELO := 39.0
const FACTOR_DUELO := 0.5
const NUMEROS := 12.0

const CENTRO_MANO := 603.0
const ANCHO_MANO := 915.0
const SIN_DUELO := ["pelotazo"]   # docs/cartas.md: "El Pelotazo no pelea: se salta la línea"

const MANO := [
    {"id": "pase_corto", "giro": -5.0, "baja": 8.0, "motivo": ""},
    {"id": "toque_toque", "giro": -3.0, "baja": 3.0, "motivo": ""},
    {"id": "pase_filtrado", "giro": -1.0, "baja": 0.0, "motivo": ""},
    {"id": "pelotazo", "giro": 1.0, "baja": 0.0, "motivo": ""},
    {"id": "amague", "giro": 3.0, "baja": 3.0, "motivo": ""},
    {"id": "remate_simple", "giro": 5.0, "baja": 8.0, "motivo": "solo en el área"},
]

const GRIS_FLECHA := Color("#c3c7cf")
const CONTORNO_FLECHA := Color("#0d1118")

var _vista: SubViewport
var _senal: SubViewportContainer
var _camara: Camera3D
var _pelota: MeshInstance3D
var _sombra_pelota: MeshInstance3D
var _jugadores := {}            # nombre -> jugador
var _etiquetas := {}            # nombre -> gráfica de TV
var _rect_etiqueta := {}        # nombre -> dónde debe quedar (la gráfica llega ahí suavemente)
var _hueco_etiqueta := {}       # nombre -> posición elegida alrededor del jugador
var _zonas: Array = []          # [Label, x0, x1]
var _colores := {}              # club -> [primario, secundario]
var _color_marca := Color.WHITE
var _portador := "ACEVAL"
var _con_balon: Control
var _flecha: Control
var _camino: Control
var _filtro: ColorRect
var _barra: ColorRect
var _vivo: Control
var _raiz_mano: Control
var _volver_btn: Control
var _laminas: Array[CardUI] = []
var _elige := {}                # lámina -> gráfica "ELIGE"
var _anillos := {}
var _k := 1.0                   # píxeles reales de la ventana por unidad del lienzo
var _ancho := 1280.0
var _alto_senal := 460.0
var _reloj := 0.0
var _cam_x := 0.0
var _vuelo_carta := ""
var _vuelo_desde := Vector3.ZERO
var _vuelo_hasta := Vector3.ZERO
var _vuelo_ini := -1.0
var _vuelo_dura := 1.0
var _pelota_antes := Vector3.ZERO
var _pase_t := -1.0             # tiempo desde que el portador empezó a patear; negativo = no hay pase
var _pase_a := ""
var _pase_carta := ""
var _pase_contacto := 0.0
var _arrastre: CardUI           # lámina que se está arrastrando
var _mouse := Vector2.ZERO
var _apuntado := ""
var _linea_3d := PackedVector3Array()   # la curva que se ve y que recorrerá la pelota
var ver_trayectoria_en_vuelo := false   # deja la línea tenue durante el vuelo (para las capturas de comprobación)


func _ready() -> void:
    var liga := LeagueManager.new()
    liga.load_all()
    _colores[COLO] = liga.team_colors(liga.get_team(COLO))
    _colores[LA_U] = liga.team_colors(liga.get_team(LA_U))
    add_child(Mesa.madera())
    move_child(get_child(-1), 0)
    _senal = $Senal
    _vista = $Senal/Vista3D
    _armar_mundo()
    _armar_jugadores()
    _armar_senal_2d()
    _armar_mano()
    _flecha = Control.new()
    _flecha.size = Vector2(4000, 4000)
    _flecha.mouse_filter = Control.MOUSE_FILTER_IGNORE
    _flecha.draw.connect(_dibujar_flecha)
    add_child(_flecha)
    _ajustar_ventana()
    resized.connect(_ajustar_ventana)
    get_window().size_changed.connect(_ajustar_ventana)
    volver_a_aceval()


# ------------------------------------------------------------------ Ventana

# La cancha llena el ancho y se dibuja a la resolución real de la ventana, para que no se vea borrosa ni
# quede madera a los lados. Las láminas siguen centradas abajo.
func _ajustar_ventana() -> void:
    var lienzo := get_viewport_rect().size
    if lienzo.x <= 0.0 or lienzo.y <= 0.0:
        return
    _k = float(get_window().size.x) / lienzo.x
    _ancho = lienzo.x
    _alto_senal = lienzo.y - ALTO_MANO
    var pixeles := (Vector2(_ancho, _alto_senal) * _k).round()
    _vista.size = Vector2i(pixeles)
    _senal.scale = Vector2.ONE / _k
    _senal.size = pixeles
    _camara.fov = rad_to_deg(2.0 * atan(_alto_senal * 0.5 / FOCO))
    _filtro.size = Vector2(_ancho, _alto_senal)
    _barra.size = Vector2(_ancho, 40)
    _camino.position.x = (_ancho - 1280.0) * 0.5
    _vivo.position.x = _ancho - 18.0 - _vivo.size.x
    _con_balon.position = Vector2(16, _alto_senal - 40.0)
    _raiz_mano.position = Vector2((_ancho - 1280.0) * 0.5, lienzo.y - 720.0)


# De un punto del mundo a la pantalla (unidades del lienzo, las mismas del mouse).
func _a_pantalla(p: Vector3) -> Vector2:
    return _camara.unproject_position(p) / _k


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
    _camara.fov = 22.0
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
    _pelota.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF   # la sombra va justo debajo
    _vista.add_child(_pelota)
    # Sombra de la pelota: un disco bajo ella que se achica y aclara con la altura; así se lee el arco.
    var disco := Malla.new()
    disco.anillo(0.0, 1.0, 16, 0.0, Color(0, 0, 0, 1))
    _sombra_pelota = MeshInstance3D.new()
    _sombra_pelota.mesh = disco.a_malla()
    _sombra_pelota.set_surface_override_material(0, Malla.material_vertices(false, true))
    _sombra_pelota.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
    _vista.add_child(_sombra_pelota)
    var dorado := Color(Paleta.DORADO)
    _anillos["portador"] = _malla_anillo([[0.92, 1.22, Color(0, 0, 0, 0.35)], [0.96, 1.18, dorado]])
    _anillos["libre"] = _malla_anillo([[0.0, 0.86, Color("#4fd18b", 0.22)], [0.76, 0.88, Color("#4fd18b")]])
    for nombre: String in ["verde", "dorado", "coral", "gris"]:
        var c := _color_apuntar(nombre)
        _anillos[nombre] = _malla_anillo([[0.88, 1.28, Color(c, 0.3)], [0.96, 1.18, c]])


func _malla_anillo(capas: Array) -> ArrayMesh:
    var m := Malla.new()
    for capa: Array in capas:
        m.anillo(capa[0], capa[1], 28, 0.04, capa[2])
    var malla := m.a_malla()
    malla.surface_set_material(0, Malla.material_vertices(false, true))
    return malla


func _armar_jugadores() -> void:
    for dato: Array in PLANTEL:
        var j := Jugador.new()
        _vista.add_child(j)
        j.armar(_kit(String(dato[1]), Color(dato[3]), Color(dato[4]), String(dato[5])))
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
    _filtro = ColorRect.new()
    _filtro.mouse_filter = Control.MOUSE_FILTER_IGNORE
    var sh := Shader.new()
    sh.code = """shader_type canvas_item;
void fragment() {
    float linea = step(2.0, mod(FRAGCOORD.y, 3.0)) * 0.08;
    float vin = smoothstep(0.62, 1.05, length((UV - 0.5) * vec2(1.82, 2.0))) * 0.42;
    COLOR = vec4(0.0, 0.0, 0.0, 1.0 - (1.0 - linea) * (1.0 - vin));
}"""
    var mat := ShaderMaterial.new()
    mat.shader = sh
    _filtro.material = mat
    add_child(_filtro)
    # Nombres de zona: los escribe el telestrador sobre la imagen, derechos y sin deformarse.
    for dato: Array in [["SALIDA", Cancha.X_MIN, Cancha.SALIDA_X, 0.9], ["MEDIO", Cancha.SALIDA_X, Cancha.AREA_X, 0.95], ["ÁREA", Cancha.AREA_X, Cancha.X_MAX, 0.85]]:
        var l := Paleta.etiqueta(dato[0], "plumon", 28, Color(Cancha.TELESTRADOR, dato[3]))
        Paleta.sombra_tv(l)
        add_child(l)
        _zonas.append([l, dato[1], dato[2]])
    # Etiquetas: solo los de Colo-Colo, con sus marcas (puntos del color del rival, aclarado para verse).
    _color_marca = _colores[LA_U][0].lightened(0.25)
    for nombre: String in MARCAS:
        var g := Grafica.new()
        add_child(g)
        _etiquetas[nombre] = g
    # Barra de arriba
    _barra = ColorRect.new()
    _barra.color = Color(Paleta.TV_FONDO, 0.88)
    _barra.mouse_filter = Control.MOUSE_FILTER_IGNORE
    add_child(_barra)
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
    _vivo = Grafica.new()
    add_child(_vivo)
    _vivo.configurar("EN VIVO", 16, Color.WHITE, [Color(0, 0, 0, 0), Color(0, 0, 0, 0), Color(0, 0, 0, 0), Color(0, 0, 0, 0)], 1, Color("#ff3b2f"))
    _vivo.position.y = 20.0 - _vivo.size.y * 0.5
    # CON EL BALÓN abajo a la izquierda, como un zócalo de TV: arriba se montaba sobre los carteles.
    _con_balon = Control.new()
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


func _actualizar_etiquetas() -> void:
    for nombre: String in _etiquetas:
        var g: Control = _etiquetas[nombre]
        var marcas: int = MARCAS[nombre].size()
        if nombre == _portador:
            g.configurar(nombre, 16, Paleta.DORADO, Grafica.SEMI_NOCHE, marcas, _color_marca)
        elif nombre == _apuntado:
            var c := _color_apuntar(_tono_apuntado())
            var texto := nombre + " · LIBRE" if marcas == 0 else nombre
            g.configurar(texto, 17, c, Grafica.SEMI_NOCHE, marcas, _color_marca, c)
        elif marcas == 0:
            g.configurar(nombre + " · LIBRE", 16, Color.WHITE, Paleta.PLACA_VERDE)
        else:
            g.configurar(nombre, 16, Color.WHITE, Grafica.SEMI_NOCHE, marcas, _color_marca)


func _actualizar_anillos() -> void:
    for nombre: String in _jugadores:
        var j = _jugadores[nombre]
        if nombre == _portador:
            j.poner_anillo(_anillos["portador"])
        elif nombre == _apuntado:
            j.poner_anillo(_anillos[_tono_apuntado()])
        elif MARCAS.has(nombre) and MARCAS[nombre].is_empty():
            j.poner_anillo(_anillos["libre"])
        else:
            j.poner_anillo(null)


func _poner_con_balon(nombre: String) -> void:
    for hijo in _con_balon.get_children():
        hijo.queue_free()
    var a := Grafica.new()
    _con_balon.add_child(a)
    a.configurar("CON EL BALÓN", 15, Color("#0b111b"), Paleta.PLACA_DORADA)
    var b := Grafica.new()
    _con_balon.add_child(b)
    b.configurar("%s · %s" % [nombre, PROPIOS[nombre]["puesto"]], 20, Color("#0b111b"), Grafica.PLATA)
    b.position.x = a.size.x - a.size.y * Grafica.SKEW
    a.position.y = (b.size.y - a.size.y) * 0.5


# Rectángulo del cuerpo en pantalla: de los pies a la cabeza, con el ancho de un jugador.
func _rect_cuerpo(j: Node3D) -> Rect2:
    var pies := _a_pantalla(j.position)
    var cabeza := _a_pantalla(j.position + Vector3(0, Jugador.ALTURA, 0))
    var alto := absf(pies.y - cabeza.y)
    var ancho := alto * 0.42
    return Rect2((pies.x + cabeza.x) * 0.5 - ancho * 0.5, cabeza.y, ancho, alto)


func _rect_pelota() -> Rect2:
    var c := _a_pantalla(_pelota.position)
    return Rect2(c - Vector2(11, 11), Vector2(22, 22))


func _rect_con_balon() -> Rect2:
    var fin := Vector2.ZERO
    for hijo in _con_balon.get_children():
        var g: Control = hijo
        fin = fin.max(g.position + g.size)
    return Rect2(_con_balon.position, fin + Vector2(0, 4))


func _rect_punta() -> Rect2:
    if _arrastre == null or _linea_3d.is_empty():
        return Rect2()
    return Rect2(_a_pantalla(_linea_3d[-1]) - Vector2(26, 26), Vector2(52, 52))


# Elige dónde va cada etiqueta para no tapar a nadie. Primero el portador y el apuntado; los demás, de
# adelante hacia atrás. Cambiar de hueco cuesta algo, para que no salten de un lado a otro.
func _colocar_etiquetas(delta: float) -> void:
    var nombres: Array = _etiquetas.keys()
    nombres.sort_custom(func(a: String, b: String) -> bool: return _prioridad(a) > _prioridad(b))
    var cuerpos := {}
    for nombre: String in _jugadores:
        cuerpos[nombre] = _rect_cuerpo(_jugadores[nombre])
    var pelota := _rect_pelota()
    var ocupados: Array[Rect2] = [_rect_con_balon()]
    if _arrastre != null:
        ocupados.append(_rect_punta())
        for i in range(0, _linea_3d.size(), 2):
            ocupados.append(Rect2(_a_pantalla(_linea_3d[i]) - Vector2(9, 9), Vector2(18, 18)))
    for zona: Array in _zonas:
        var l: Label = zona[0]
        ocupados.append(Rect2(l.position, l.size))
    var limites := Rect2(6, 44, _ancho - 12, _alto_senal - 50)
    for nombre: String in nombres:
        var g: Control = _etiquetas[nombre]
        var s: Vector2 = g.size
        var propio: Rect2 = cuerpos[nombre]
        var pies := Vector2(propio.get_center().x, propio.end.y)
        var huecos := [
            Vector2(pies.x - s.x * 0.5, pies.y + 10),
            Vector2(pies.x - s.x + 10, pies.y + 10),
            Vector2(pies.x - 10, pies.y + 10),
            Vector2(propio.position.x - s.x - 8, propio.get_center().y),
            Vector2(propio.end.x + 8, propio.get_center().y),
            Vector2(pies.x - s.x * 0.5, propio.position.y - s.y - 8),
            Vector2(pies.x - s.x * 0.5, pies.y + 14 + s.y),
            Vector2(propio.position.x - s.x - 8, pies.y - s.y),
            Vector2(propio.end.x + 8, pies.y - s.y),
        ]
        var mejor := 0
        var mejor_costo := INF
        for i in huecos.size():
            var r := Rect2(huecos[i], s)
            var costo := i * 3.0
            if i != int(_hueco_etiqueta.get(nombre, 0)):
                costo += 8.0
            for otro: String in cuerpos:
                costo += r.intersection(cuerpos[otro]).get_area()
            costo += r.intersection(pelota).get_area()
            for o: Rect2 in ocupados:
                costo += r.intersection(o).get_area() * 3.0
            if not limites.encloses(r):
                costo += 2000.0
            if costo < mejor_costo:
                mejor_costo = costo
                mejor = i
        _hueco_etiqueta[nombre] = mejor
        var destino: Vector2 = huecos[mejor]
        _rect_etiqueta[nombre] = Rect2(destino, s)
        ocupados.append(Rect2(destino, s))
        g.position = g.position.lerp(destino, 1.0 - exp(-16.0 * delta))


func _prioridad(nombre: String) -> float:
    if nombre == _portador:
        return 3000.0
    if nombre == _apuntado:
        return 2000.0
    return _jugadores[nombre].position.z


# Nombres de zona: al centro del pedazo de zona que se ve, así ÁREA se entiende aunque asome poco.
func _colocar_zonas() -> void:
    var z := -8.8
    for zona: Array in _zonas:
        var l: Label = zona[0]
        var a := _a_pantalla(Vector3(zona[1], 0, z))
        var b := _a_pantalla(Vector3(zona[2], 0, z))
        var izq := maxf(a.x, 8.0)
        var der := minf(b.x, _ancho - 8.0)
        var ancho := l.get_minimum_size().x
        var x := clampf((izq + der - ancho) * 0.5, 8.0, _ancho - ancho - 8.0)
        l.position = Vector2(x, a.y - 14.0)
        l.size = l.get_minimum_size()
        l.visible = der - izq > ancho * 0.8


# Lo que se tapa ahora mismo (lo usa tools/prueba_3d_captura.gd): etiquetas contra etiquetas, cuerpos,
# pelota y zócalo. [] = nada se tapa.
func solapes() -> Array:
    var out: Array = []
    var nombres: Array = _rect_etiqueta.keys()
    var fondo := _rect_con_balon()
    for i in nombres.size():
        var r: Rect2 = _rect_etiqueta[nombres[i]]
        for j in range(i + 1, nombres.size()):
            if r.intersects(_rect_etiqueta[nombres[j]]):
                out.append("etiqueta %s con etiqueta %s" % [nombres[i], nombres[j]])
        for otro: String in _jugadores:
            if r.intersects(_rect_cuerpo(_jugadores[otro])):
                out.append("etiqueta %s sobre %s" % [nombres[i], otro])
        if r.intersects(_rect_pelota()):
            out.append("etiqueta %s sobre la pelota" % nombres[i])
        if r.intersects(fondo):
            out.append("etiqueta %s sobre CON EL BALÓN" % nombres[i])
    return out


# ------------------------------------------------------------------ Láminas

func _armar_mano() -> void:
    _raiz_mano = Control.new()
    _raiz_mano.size = Vector2(1280, 720)
    _raiz_mano.mouse_filter = Control.MOUSE_FILTER_IGNORE
    add_child(_raiz_mano)
    var catalogo := CardDB.load_catalog()
    for i in MANO.size():
        var dato: Dictionary = MANO[i]
        var ui: CardUI = CARD_SCENE.instantiate()
        ui.custom_minimum_size = CardUI.TAMANO
        _raiz_mano.add_child(ui)
        ui.setup(Card.from_dict(catalogo[dato["id"]]), i)
        ui.pivot_offset = CardUI.TAMANO * 0.5
        ui.rotation_degrees = dato["giro"]
        ui.chosen.connect(_al_tomar_lamina)
        var elige := Grafica.new()
        ui.add_child(elige)
        elige.triangulo = true
        elige.configurar("ELIGE", 20, Color.WHITE, Paleta.TV_AZUL)
        _elige[ui] = elige
        _laminas.append(ui)
    # Moneda de PA a la izquierda y botón principal a la derecha, como en v5.
    var moneda := TextureRect.new()
    moneda.texture = Paleta.moneda(Paleta.MONEDA["normal"])
    moneda.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
    moneda.size = Vector2(104, 104)
    moneda.position = Vector2(30, 482)
    moneda.mouse_filter = Control.MOUSE_FILTER_IGNORE
    _raiz_mano.add_child(moneda)
    var pa := Paleta.etiqueta("3", "condensada_negra", 56, Color("#1a1408"))
    pa.position = Vector2(30, 482)
    pa.size = Vector2(104, 72)
    pa.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    pa.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
    _raiz_mano.add_child(pa)
    var pa2 := Paleta.etiqueta("PA", "condensada_negra", 16, Color("#1a1408"), 2)
    pa2.position = Vector2(30, 546)
    pa2.size = Vector2(104, 20)
    pa2.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    _raiz_mano.add_child(pa2)
    var ceder := Grafica.new()
    _raiz_mano.add_child(ceder)
    ceder.margen = 16.0
    ceder.configurar("CEDER JUGADA", 24, Color.WHITE, Paleta.TV_AZUL)
    ceder.position = Vector2(1072, 490)
    _volver_btn = Grafica.new()
    _raiz_mano.add_child(_volver_btn)
    _volver_btn.margen = 12.0
    _volver_btn.configurar("VOLVER A ACEVAL (R)", 18, Color.WHITE, Grafica.SEMI_NOCHE, 0, Color.WHITE, Color(Paleta.DORADO))
    _volver_btn.position = Vector2(1072, 556)
    _volver_btn.mouse_filter = Control.MOUSE_FILTER_STOP
    _volver_btn.gui_input.connect(_al_pulsar_volver)
    var aviso := Paleta.etiqueta("arrastra un pase\na un compañero.\n% de muestra,\nsin tirada", "plumon", 14, Paleta.PLUMON_CREMA)
    aviso.position = Vector2(18, 596)
    aviso.rotation_degrees = -2.0
    _raiz_mano.add_child(aviso)


# La lámina del que tiene la pelota, como en v5: sin sello de bono y los pases dicen ELIGE hasta apuntar.
func _refrescar_mano() -> void:
    var ctx := {"jugador": {"name": _portador, "role": PROPIOS[_portador]["puesto"]}, "colores": _colores[COLO]}
    for i in _laminas.size():
        var ui := _laminas[i]
        if not ui.visible:
            continue
        var c: Card = ui.card
        var motivo: String = MANO[i]["motivo"]
        ui.setup(c, i, ctx)
        ui.seal_label.visible = false
        var chance := -1.0
        var es_pase := c.kind == Card.Kind.PASS
        if es_pase and ui == _arrastre and _apuntado != "":
            chance = porcentaje_pase(_portador, _apuntado, c)
        elif c.kind == Card.Kind.DRIBBLE:
            chance = porcentaje_regate(_portador, c)
        ui.update_stats(c.ap_cost, c.ap_cost, c.stamina_cost * MatchEngine.STAMINA_SCALE, maxf(chance, 0.0), motivo == "", false, [], motivo)
        ui.tooltip_text = ""
        ui.chance_label.visible = chance >= 0.0
        if chance >= 0.0 and es_pase:
            ui.effect_label.text = "%s a %s" % [_portador, _apuntado]
        ui._layout()
        var elige: Control = _elige[ui]
        elige.visible = es_pase and chance < 0.0
        elige.position = Vector2(ui._r_inner.end.x + 4.0 - elige.size.x, ui._r_window.end.y - elige.size.y + 2.0)
    _ordenar_mano()


# Centra las láminas que quedan: una jugada saca su lámina de la mano.
func _ordenar_mano() -> void:
    var visibles: Array[CardUI] = []
    for ui in _laminas:
        if ui.visible:
            visibles.append(ui)
    # Entre la moneda de PA y CEDER JUGADA; con la mano llena se montan un poco.
    var paso := minf(174.0, (ANCHO_MANO - CardUI.TAMANO.x) / maxf(visibles.size() - 1.0, 1.0))
    var x := CENTRO_MANO - (paso * (visibles.size() - 1.0) + CardUI.TAMANO.x) * 0.5
    for ui in visibles:
        var baja: float = MANO[_laminas.find(ui)]["baja"]
        var alza := 26.0 if ui == _arrastre else 0.0
        ui.position = Vector2(x, 464.0 + baja - alza)
        ui.z_index = 1 if ui == _arrastre else 0
        x += paso


# % de muestra, con los números de docs/cartas.md: libre suma por números, 1 contra 1 es duelo y 1 contra 2
# es duelo contra el mejor de los dos con el castigo por números. No sale del motor y no se tira. La forma
# de la trayectoria no entra aquí: una línea que pasa cerca de un rival no suma riesgo.
# El Pelotazo no tiene duelo (39%). Lo de sus marcas no está definido: lo conservador es que libre no sume
# y la doble marca sí reste.
func porcentaje_pase(portador: String, receptor: String, c: Card) -> float:
    var marcas: Array = MARCAS[receptor]
    var pts := BASE_DUELO + c.effective_bonus() * 100.0
    if SIN_DUELO.has(c.id):
        if marcas.size() > 1:
            pts -= NUMEROS
    elif marcas.is_empty():
        pts += NUMEROS
    else:
        var lectura := 0
        for m: String in marcas:
            lectura = maxi(lectura, RIVALES[m]["lectura"])
        pts += FACTOR_DUELO * (PROPIOS[portador]["pase"] - lectura)
        if marcas.size() > 1:
            pts -= NUMEROS
    return clampf(roundf(pts) / 100.0, 0.05, 0.95)


func porcentaje_regate(portador: String, c: Card) -> float:
    var marcas: Array = MARCAS[portador]
    var pts := BASE_DUELO + c.effective_bonus() * 100.0
    if marcas.is_empty():
        pts += NUMEROS
    else:
        var quite := 0
        for m: String in marcas:
            quite = maxi(quite, RIVALES[m]["quite"])
        pts += FACTOR_DUELO * (PROPIOS[portador]["regate"] - quite)
        if marcas.size() > 1:
            pts -= NUMEROS
    return clampf(roundf(pts) / 100.0, 0.05, 0.95)


# ------------------------------------------------------------------ Arrastrar y apuntar

func _al_tomar_lamina(ui: CardUI) -> void:
    if ocupado() or _arrastre != null:
        return
    if ui.card.kind != Card.Kind.PASS:
        ui.shake()
        return
    _arrastre = ui
    _mouse = ui.global_position + ui.size * 0.5
    ui.flash(Paleta.DORADO)
    _apuntado = ""
    _actualizar_apuntado()
    _refrescar_mano()


func _input(event: InputEvent) -> void:
    if event is InputEventKey and event.pressed and not event.echo:
        if event.keycode == KEY_R:
            volver_a_aceval()
        elif event.keycode == KEY_ESCAPE and _arrastre != null:
            _soltar(false)
    if _arrastre == null:
        return
    if event is InputEventMouseMotion:
        _mouse = event.position
        _actualizar_apuntado()
    elif event is InputEventMouseButton and not event.pressed:
        if event.button_index == MOUSE_BUTTON_LEFT:
            _mouse = event.position
            _actualizar_apuntado()
            _soltar(true)
        elif event.button_index == MOUSE_BUTTON_RIGHT:
            _soltar(false)


func _al_pulsar_volver(event: InputEvent) -> void:
    if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
        volver_a_aceval()


# Compañero válido bajo el mouse: su cuerpo o su etiqueta. "" si no hay.
func _receptor_bajo_mouse() -> String:
    var mejor := ""
    var mejor_d := INF
    for nombre: String in RECEPTORES:
        if nombre == _portador:
            continue
        var r := _rect_cuerpo(_jugadores[nombre]).grow(12.0)
        var sobre_etiqueta: bool = _rect_etiqueta.has(nombre) and Rect2(_rect_etiqueta[nombre]).has_point(_mouse)
        if r.has_point(_mouse) or sobre_etiqueta:
            var d := r.get_center().distance_to(_mouse)
            if d < mejor_d:
                mejor_d = d
                mejor = nombre
    return mejor


func _actualizar_apuntado() -> void:
    var nuevo := _receptor_bajo_mouse()
    if nuevo != _apuntado:
        _apuntado = nuevo
        _refrescar_mano()
        _actualizar_etiquetas()
        _actualizar_anillos()
    _linea_3d = Trayectoria.puntos(_arrastre.card.id, _pelota.position, _fin_linea())


func _soltar(aceptar: bool) -> void:
    var ui := _arrastre
    var receptor := _apuntado if aceptar else ""
    var destino := _fin_linea()
    _arrastre = null
    _apuntado = ""
    ui.flash(Color(0, 0, 0, 0))
    if receptor != "":
        ui.visible = false     # la lámina se gasta solo si el pase se hizo
        _lanzar_pase(receptor, ui.card.id, destino)
    _refrescar_mano()
    _actualizar_etiquetas()
    _actualizar_anillos()


# Dónde llega la pelota: a los pies del apuntado, del lado por donde viene.
func _llegada(nombre: String) -> Vector3:
    var pies: Vector3 = _jugadores[nombre].position
    var viene := Vector3(_pelota.position.x - pies.x, 0.0, _pelota.position.z - pies.z).normalized()
    return pies + viene * 0.6 + Vector3(0, RADIO_PELOTA, 0)


# La línea termina a los pies del apuntado o, sin objetivo, en el punto del pasto bajo el mouse.
func _fin_linea() -> Vector3:
    if _apuntado != "":
        return _llegada(_apuntado)
    return _punto_bajo_mouse()


func _punto_bajo_mouse() -> Vector3:
    var m := Vector2(clampf(_mouse.x, 2.0, _ancho - 2.0), clampf(_mouse.y, 44.0, _alto_senal - 2.0)) * _k
    var o := _camara.project_ray_origin(m)
    var d := _camara.project_ray_normal(m)
    var p := o + d * ((RADIO_PELOTA - o.y) / d.y)
    return Vector3(clampf(p.x, Cancha.X_MIN, Cancha.X_MAX), RADIO_PELOTA, clampf(p.z, Cancha.FONDO_Z, Cancha.FRENTE_Z))


func _tono_apuntado() -> String:
    if _apuntado == "" or _arrastre == null:
        return "gris"
    var pct := roundi(porcentaje_pase(_portador, _apuntado, _arrastre.card) * 100.0)
    if pct >= 60:
        return "verde"
    return "dorado" if pct >= 40 else "coral"


# Los mismos cortes de la placa de la lámina (Paleta.placa).
func _color_apuntar(tono: String) -> Color:
    match tono:
        "verde":
            return Color("#5fd08f")
        "dorado":
            return Color("#ffd257")
        "coral":
            return Color("#ff8a7a")
    return GRIS_FLECHA


func tono_flecha() -> String:
    return _tono_apuntado()


# La línea que se ve ahora, en el mundo 3D (lo usa tools/prueba_3d_captura.gd).
func puntos_linea() -> PackedVector3Array:
    return _linea_3d


# La línea del pase: la trayectoria real de la pelota, proyectada a la pantalla. Tramos gruesos que crecen
# hacia la punta, contorno oscuro para leerse sobre jugadores y gráficas, y una punta orientada según la curva.
func _dibujar_flecha() -> void:
    if _arrastre != null and not _linea_3d.is_empty():
        _dibujar_linea(_arrastre.card.id, _color_apuntar(_tono_apuntado()), 1.0, true)
    elif ver_trayectoria_en_vuelo and en_vuelo():
        _dibujar_linea(_vuelo_carta, Color.WHITE, 0.55, false)


func _dibujar_linea(carta: String, color: Color, alfa: float, con_punta: bool) -> void:
    var f := Trayectoria.forma(carta)
    var pts := PackedVector2Array()
    var largos := PackedFloat32Array()
    for i in _linea_3d.size():
        pts.append(_a_pantalla(_linea_3d[i]))
        largos.append(0.0 if i == 0 else largos[i - 1] + pts[i].distance_to(pts[i - 1]))
    var total := largos[-1]
    if total < 6.0:
        return
    if f["sombra"]:
        var suelo := PackedVector2Array()
        for p in _linea_3d:
            suelo.append(_a_pantalla(Vector3(p.x, 0.03, p.z)))
        _flecha.draw_polyline(suelo, Color(0, 0, 0, 0.4 * alfa), 8.0, true)
    var tramo: float = f["tramo"]
    var hueco: float = f["hueco"]
    var largo_punta := minf(36.0, total * 0.5)
    var limite := total - (largo_punta - 6.0 if con_punta else 0.0)
    var contorno := Color(CONTORNO_FLECHA, alfa)
    var relleno := Color(color, alfa)
    var s := fmod(_reloj * float(f["velocidad"]) * 5.0, tramo + hueco) - tramo
    while s < limite:
        var a := maxf(s, 16.0)     # empieza después de la pelota, para no taparla
        var b := minf(s + tramo, limite)
        if b - a > 2.0:
            var parte := _sub_curva(pts, largos, a, b)
            var ancho := lerpf(7.0, 13.0, (a + b) * 0.5 / total)
            _flecha.draw_polyline(parte, contorno, ancho + 5.0, true)
            _flecha.draw_polyline(parte, relleno, ancho, true)
        s += tramo + hueco
    if not con_punta:
        return
    var fin := pts[-1]
    var dir := (fin - pts[-4]).normalized()
    var lado := Vector2(-dir.y, dir.x)
    var ancho_punta := largo_punta * 0.58
    var atras := fin - dir * largo_punta
    var muesca := fin - dir * largo_punta * 0.72
    var punta := PackedVector2Array([fin, atras + lado * ancho_punta, muesca, atras - lado * ancho_punta])
    var borde := PackedVector2Array([fin, atras + lado * ancho_punta, muesca, atras - lado * ancho_punta, fin])
    _flecha.draw_polyline(borde, CONTORNO_FLECHA, 6.0, true)
    _flecha.draw_colored_polygon(punta, color)
    _flecha.draw_polyline(borde, CONTORNO_FLECHA, 2.5, true)


func _sub_curva(pts: PackedVector2Array, largos: PackedFloat32Array, a: float, b: float) -> PackedVector2Array:
    var out := PackedVector2Array()
    for i in range(1, pts.size()):
        if largos[i] < a or largos[i - 1] > b:
            continue
        var tramo := largos[i] - largos[i - 1]
        if out.is_empty():
            out.append(pts[i - 1].lerp(pts[i], clampf((a - largos[i - 1]) / tramo, 0.0, 1.0)))
        out.append(pts[i - 1].lerp(pts[i], clampf((b - largos[i - 1]) / tramo, 0.0, 1.0)))
    return out


# ------------------------------------------------------------------ El pase

func ocupado() -> bool:
    return _pase_t >= 0.0


func en_vuelo() -> bool:
    return _vuelo_ini >= 0.0


func portador() -> String:
    return _portador


func apuntado() -> String:
    return _apuntado


func arrastrando() -> bool:
    return _arrastre != null


# Todo vuelve al inicio: Aceval con la pelota, la mano completa. Para probar otro receptor.
func volver_a_aceval() -> void:
    if ocupado():
        return
    if _arrastre != null:
        _soltar(false)
    _vuelo_ini = -1.0
    for ui in _laminas:
        ui.visible = true
    for dato: Array in PLANTEL:
        var j: Node3D = _jugadores[dato[0]]
        j.colocar(_base(dato[0]), _base("ACEVAL") if dato[0] != "ACEVAL" else _base("FERNÁNDEZ"))
    _set_portador("ACEVAL")
    _pelota.position = _jugadores["ACEVAL"].junto_al_pie(_base("FERNÁNDEZ"), RADIO_PELOTA)
    if _cam_x == 0.0:
        _cam_x = _objetivo_camara(_pelota.position.x)


func _base(nombre: String) -> Vector3:
    for dato: Array in PLANTEL:
        if dato[0] == nombre:
            return Vector3(dato[2][0], 0, dato[2][1])
    return Vector3.ZERO


func _set_portador(nombre: String) -> void:
    _portador = nombre
    _poner_con_balon(nombre)
    _actualizar_etiquetas()
    _actualizar_anillos()
    _refrescar_mano()
    _volver_btn.modulate.a = 0.55 if nombre == "ACEVAL" else 1.0
    _camino.queue_redraw()


# A dónde corre cada uno: el receptor espera la pelota donde apuntó la línea, sus marcas se quedan con él y
# los demás se acercan un poco a la jugada. Los rivales guardan su distancia con el que marcan.
func _destino_propio(nombre: String, receptor: String) -> Vector3:
    var base := _base(nombre)
    if nombre == receptor:
        return _jugadores[nombre].position
    return base.move_toward(_base(receptor), 0.8)


func _destino(nombre: String, receptor: String) -> Vector3:
    if MARCAS.has(nombre):
        return _destino_propio(nombre, receptor)
    for marcado: String in MARCAS:
        if MARCAS[marcado].has(nombre):
            return _destino_propio(marcado, receptor) + _base(nombre) - _base(marcado)
    return _base(nombre)


func _lanzar_pase(receptor: String, carta: String, destino: Vector3) -> void:
    _pase_a = receptor
    _pase_carta = carta
    _vuelo_hasta = destino
    _pase_t = 0.0
    var rapidez: float = Trayectoria.forma(carta)["patada"]
    _pase_contacto = Jugador.CONTACTO_PATADA / rapidez
    _jugadores[_portador].patear(rapidez)


func _avanzar_pase(delta: float) -> void:
    if _pase_t < 0.0:
        return
    var antes := _pase_t
    _pase_t += delta
    if antes < _pase_contacto and _pase_t >= _pase_contacto:
        _vuelo_carta = _pase_carta
        _vuelo_desde = _pelota.position
        _vuelo_ini = _reloj
        _vuelo_dura = Trayectoria.duracion(_pase_carta, _vuelo_desde, _vuelo_hasta)
        for nombre: String in _jugadores:
            _jugadores[nombre].ir_a(_destino(nombre, _pase_a), _vuelo_dura)
    elif antes >= _pase_contacto and _vuelo_ini < 0.0:
        _pase_t = -1.0
        _set_portador(_pase_a)


func _process(delta: float) -> void:
    _reloj += delta
    _avanzar_pase(delta)
    for nombre: String in _jugadores:
        _jugadores[nombre].mirar = _pelota.position
    _mover_pelota(delta)
    _mover_camara(delta)
    _colocar_zonas()
    _colocar_etiquetas(delta)
    if _arrastre != null:
        _actualizar_apuntado()
    _flecha.queue_redraw()


func _mover_pelota(delta: float) -> void:
    if _vuelo_ini >= 0.0:
        var t := (_reloj - _vuelo_ini) / _vuelo_dura
        _pelota_antes = _pelota.position
        if t >= 1.0:
            _vuelo_ini = -1.0
            _pelota.position = _vuelo_hasta
        else:
            _pelota.position = Trayectoria.punto(_vuelo_carta, _vuelo_desde, _vuelo_hasta, Trayectoria.avance(_vuelo_carta, t))
            _girar_pelota(delta)
    var altura := _pelota.position.y - RADIO_PELOTA
    var radio := clampf(0.34 + altura * 0.1, 0.34, 0.7)
    _sombra_pelota.position = Vector3(_pelota.position.x, 0.05, _pelota.position.z)
    _sombra_pelota.scale = Vector3(radio, 1.0, radio)
    var mat: StandardMaterial3D = _sombra_pelota.get_surface_override_material(0)
    mat.albedo_color.a = clampf(0.55 - altura * 0.09, 0.22, 0.55)


# La pelota rueda en la dirección que lleva; cada carta le da su giro y su efecto.
func _girar_pelota(delta: float) -> void:
    var f := Trayectoria.forma(_vuelo_carta)
    var rumbo := _pelota.position - _pelota_antes
    rumbo.y = 0.0
    if rumbo.length() > 0.0001:
        _pelota.rotate(Vector3.UP.cross(rumbo).normalized(), delta * float(f["giro"]))
    if float(f["efecto"]) != 0.0:
        _pelota.rotate(Vector3.UP, delta * float(f["efecto"]))


func _objetivo_camara(x_pelota: float) -> float:
    return x_pelota * 0.45


# Cámara de TV: alta y de costado; se desliza suave detrás de la pelota y gira un poco hacia ella.
func _mover_camara(delta: float) -> void:
    var objetivo := _objetivo_camara(_pelota.position.x)
    _cam_x = lerpf(_cam_x, objetivo, 1.0 - exp(-2.6 * delta))
    _camara.position.x = _cam_x
    _camara.look_at(Vector3(_cam_x + (_pelota.position.x - _cam_x) * 0.08, 0, CAM_MIRA_Z))
