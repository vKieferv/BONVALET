extends Node3D

# T-11: el mundo 3D del partido de duelos (D-41), armado con las piezas de la prueba de T-12
# (scenes/prueba_3d/): la cancha con sus zonas y carteles, los jugadores low poly, la pelota con su
# sombra y la cámara de TV. Aquí se agregan los dos arcos, los 22 titulares y la pelota que vuela según
# la carta (Trayectoria). No sabe nada del motor: PantallaDuelos le dice dónde va cada uno.
# El local ataca hacia +x: su Salida, su Medio y el Área rival son ZONAS_X[0], [1] y [2].

const Jugador := preload("res://scenes/prueba_3d/jugador_low_poly.gd")
const Cancha := preload("res://scenes/prueba_3d/cancha_3d.gd")
const Malla := preload("res://scenes/prueba_3d/malla_low_poly.gd")
const Trayectoria := preload("res://scenes/prueba_3d/trayectoria.gd")

const RADIO_PELOTA := 0.2
# Las zonas miden 17 m, como en T-12 (las líneas del telestrador de Cancha están en -6 y 11).
const ZONAS_X := [[-23.0, -6.0], [-6.0, 11.0], [11.0, 28.0]]
const ARCO_LOCAL_X := -25.0
const ARCO_RIVAL_X := 30.0
const ARCO_MEDIO_ANCHO := 3.2
const ARCO_ALTO := 2.3
const Z_MIN := -5.4             # de la banda del fondo hacia la cámara: dónde se reparten las líneas
const Z_MAX := 6.4
# Cámara de TV de T-12: lejos y con lente larga (FOCO = píxeles por unidad a distancia 1).
const FOCO := 1183.0
const CAM_ALTO := 13.5
const CAM_Z := 27.0
const CAM_MIRA_Z := 0.9
const BOTAS := Color("#15171c")
const PIELES := ["#c98e63", "#a8714b", "#d9a47c", "#8d5b3a", "#e0b48f"]
const PELOS := ["#2a1d14", "#111111", "#3a2618", "#4a3322", "#6b4a2b"]
const ESTILOS := ["corto", "corto", "melena", "afro", "pelado"]
const ARQUERO_LOCAL := Color("#e3c640")
const ARQUERO_VISITA := Color("#3c3f47")

var camara: Camera3D
var pelota: MeshInstance3D
var jugadores := {}             # "L:id" o "V:id" -> jugador low poly
var anillos := {}               # nombre -> malla del anillo del suelo
var reloj := 0.0                # avanza con `velocidad`: el ataque rival se puede acelerar
var velocidad := 1.0
var encuadre_x := 0.0           # lo que la cámara quiere mostrar (entre la zona en juego y la siguiente)
var _sombra_pelota: MeshInstance3D
var _cam_x := 0.0
var _vuelo_carta := ""
var _vuelo_desde := Vector3.ZERO
var _vuelo_hasta := Vector3.ZERO
var _vuelo_ini := -1.0
var _vuelo_dura := 1.0
var _pelota_antes := Vector3.ZERO


func _ready() -> void:
    var entorno := Environment.new()
    entorno.background_mode = Environment.BG_COLOR
    entorno.background_color = Color("#0c130e")
    entorno.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
    entorno.ambient_light_color = Color("#dfe6f2")
    entorno.ambient_light_energy = 0.72
    entorno.tonemap_mode = Environment.TONE_MAPPER_LINEAR
    var mundo := WorldEnvironment.new()
    mundo.environment = entorno
    add_child(mundo)
    var sol := DirectionalLight3D.new()
    sol.rotation_degrees = Vector3(-52, -38, 0)
    sol.light_color = Color("#fff4dc")
    sol.light_energy = 0.95
    sol.shadow_enabled = true
    sol.directional_shadow_mode = DirectionalLight3D.SHADOW_ORTHOGONAL
    sol.directional_shadow_max_distance = 45.0
    sol.shadow_blur = 0.6
    add_child(sol)
    add_child(Cancha.new())
    _armar_arcos()
    camara = Camera3D.new()
    camara.fov = 22.0
    camara.near = 2.0
    camara.far = 110.0
    camara.position = Vector3(0, CAM_ALTO, CAM_Z)
    add_child(camara)
    camara.look_at(Vector3(0, 0, CAM_MIRA_Z))
    var bola := Malla.new()
    bola.pelota(RADIO_PELOTA)
    pelota = MeshInstance3D.new()
    pelota.mesh = bola.a_malla()
    pelota.set_surface_override_material(0, Malla.material_vertices())
    pelota.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
    add_child(pelota)
    var disco := Malla.new()
    disco.anillo(0.0, 1.0, 16, 0.0, Color(0, 0, 0, 1))
    _sombra_pelota = MeshInstance3D.new()
    _sombra_pelota.mesh = disco.a_malla()
    _sombra_pelota.set_surface_override_material(0, Malla.material_vertices(false, true))
    _sombra_pelota.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
    add_child(_sombra_pelota)
    var dorado := Color(Paleta.DORADO)
    anillos["portador"] = _malla_anillo([[0.92, 1.22, Color(0, 0, 0, 0.35)], [0.96, 1.18, dorado]])
    anillos["libre"] = _malla_anillo([[0.0, 0.86, Color("#4fd18b", 0.22)], [0.76, 0.88, Color("#4fd18b")]])
    for nombre: String in ["verde", "dorado", "coral", "gris"]:
        var c := color_tono(nombre)
        anillos[nombre] = _malla_anillo([[0.88, 1.28, Color(c, 0.3)], [0.96, 1.18, c]])


# Los mismos cortes de la placa de la lámina (Paleta.placa), para la línea y el anillo del apuntado.
static func color_tono(tono: String) -> Color:
    match tono:
        "verde":
            return Color("#5fd08f")
        "dorado":
            return Color("#ffd257")
        "coral":
            return Color("#ff8a7a")
    return Color("#c3c7cf")


static func tono(chance: float) -> String:
    var pct := roundi(chance * 100.0)
    if pct >= 60:
        return "verde"
    return "dorado" if pct >= 40 else "coral"


func _malla_anillo(capas: Array) -> ArrayMesh:
    var m := Malla.new()
    for capa: Array in capas:
        m.anillo(capa[0], capa[1], 28, 0.04, capa[2])
    var malla := m.a_malla()
    malla.surface_set_material(0, Malla.material_vertices(false, true))
    return malla


# Dos arcos simples: palos y travesaño blancos y una red translúcida.
func _armar_arcos() -> void:
    var palos := Malla.new()
    var red := Malla.new()
    var blanco := Color("#f4f4f4")
    var tela := Color(1, 1, 1, 0.22)
    for datos: Array in [[ARCO_LOCAL_X, -1.0], [ARCO_RIVAL_X, 1.0]]:
        var x: float = datos[0]
        var fondo: float = x + float(datos[1]) * 1.6
        var g := 0.09
        for z: float in [-ARCO_MEDIO_ANCHO, ARCO_MEDIO_ANCHO]:
            palos.caja(Vector3(x - g, 0, z - g), Vector3(x + g, ARCO_ALTO, z + g), blanco)
        palos.caja(Vector3(x - g, ARCO_ALTO - g, -ARCO_MEDIO_ANCHO), Vector3(x + g, ARCO_ALTO + g, ARCO_MEDIO_ANCHO), blanco)
        var a := Vector3(x, ARCO_ALTO, -ARCO_MEDIO_ANCHO)
        var b := Vector3(x, ARCO_ALTO, ARCO_MEDIO_ANCHO)
        var c := Vector3(fondo, 0.0, ARCO_MEDIO_ANCHO)
        var d := Vector3(fondo, 0.0, -ARCO_MEDIO_ANCHO)
        red.quad(a, b, c, d, tela)
        red.quad(d, c, b, a, tela)
        for z: float in [-ARCO_MEDIO_ANCHO, ARCO_MEDIO_ANCHO]:
            red.tri(Vector3(x, ARCO_ALTO, z), Vector3(x, 0, z), Vector3(fondo, 0, z), tela)
            red.tri(Vector3(fondo, 0, z), Vector3(x, 0, z), Vector3(x, ARCO_ALTO, z), tela)
        palos.suelo(x - 0.06, -ARCO_MEDIO_ANCHO - 2.5, x + 0.06, ARCO_MEDIO_ANCHO + 2.5, 0.02, Color(1, 1, 1, 0.78))
    var mp := MeshInstance3D.new()
    mp.mesh = palos.a_malla()
    mp.set_surface_override_material(0, Malla.material_vertices())
    add_child(mp)
    var mr := MeshInstance3D.new()
    mr.mesh = red.a_malla()
    mr.set_surface_override_material(0, Malla.material_vertices(false, true))
    mr.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
    add_child(mr)


# Los 22 titulares: jugadores = [{id, role, ...}] de SquadManager.duel_data; colores = [primario, secundario].
# La cara no existe (D-35); piel, pelo y peinado salen del id, así cada uno se ve siempre igual.
func armar_equipo(lado: String, lista: Array, colores: Array, short: Color) -> void:
    for pl: Dictionary in lista:
        var id := String(pl.get("id", ""))
        var h := absi(hash(id))
        var arquero := String(pl.get("role", "")) == "POR"
        var camiseta: Color = colores[0]
        if arquero:
            camiseta = ARQUERO_LOCAL if lado == "L" else ARQUERO_VISITA
        var j := Jugador.new()
        add_child(j)
        j.armar({
            "camiseta": camiseta,
            "short": Color("#15171c") if arquero else short,
            "medias": camiseta,
            "acento": colores[1],
            "botas": BOTAS,
            "piel": Color(PIELES[h % PIELES.size()]),
            "pelo": Color(PELOS[(h / 7) % PELOS.size()]),
            "estilo": ESTILOS[(h / 49) % ESTILOS.size()],
        })
        jugadores[lado + ":" + id] = j


func centro_zona(z: int, local: bool) -> float:
    var r: Array = ZONAS_X[z if local else 2 - z]
    return (float(r[0]) + float(r[1])) * 0.5


func arco_x(del_local: bool) -> float:
    return ARCO_LOCAL_X if del_local else ARCO_RIVAL_X


# ------------------------------------------------------------------ Pelota

func pelota_en(p: Vector3) -> void:
    _vuelo_ini = -1.0
    pelota.position = p


func volar(carta: String, hasta: Vector3) -> void:
    _vuelo_carta = carta
    _vuelo_desde = pelota.position
    _vuelo_hasta = hasta
    _vuelo_ini = reloj
    _vuelo_dura = Trayectoria.duracion(carta, _vuelo_desde, hasta)


func en_vuelo() -> bool:
    return _vuelo_ini >= 0.0


func duracion_vuelo() -> float:
    return _vuelo_dura


func _process(delta: float) -> void:
    reloj += delta * velocidad
    for k: String in jugadores:
        jugadores[k].mirar = pelota.position
    _mover_pelota(delta)
    _mover_camara(delta)


func _mover_pelota(delta: float) -> void:
    if _vuelo_ini >= 0.0:
        var t := (reloj - _vuelo_ini) / _vuelo_dura
        _pelota_antes = pelota.position
        if t >= 1.0:
            _vuelo_ini = -1.0
            pelota.position = _vuelo_hasta
        else:
            pelota.position = Trayectoria.punto(_vuelo_carta, _vuelo_desde, _vuelo_hasta, Trayectoria.avance(_vuelo_carta, t))
            var f := Trayectoria.forma(_vuelo_carta)
            var rumbo := pelota.position - _pelota_antes
            rumbo.y = 0.0
            if rumbo.length() > 0.0001:
                pelota.rotate(Vector3.UP.cross(rumbo).normalized(), delta * velocidad * float(f["giro"]))
            if float(f["efecto"]) != 0.0:
                pelota.rotate(Vector3.UP, delta * velocidad * float(f["efecto"]))
    var altura := pelota.position.y - RADIO_PELOTA
    var radio := clampf(0.34 + altura * 0.1, 0.34, 0.7)
    _sombra_pelota.position = Vector3(pelota.position.x, 0.05, pelota.position.z)
    _sombra_pelota.scale = Vector3(radio, 1.0, radio)
    var mat: StandardMaterial3D = _sombra_pelota.get_surface_override_material(0)
    mat.albedo_color.a = clampf(0.55 - altura * 0.09, 0.22, 0.55)


# Cámara de TV: se desliza detrás de la jugada, entre lo que hay que mostrar y la pelota.
func _mover_camara(delta: float) -> void:
    var objetivo := encuadre_x * 0.6 + pelota.position.x * 0.4
    _cam_x = lerpf(_cam_x, objetivo, 1.0 - exp(-2.6 * delta * velocidad))
    camara.position.x = _cam_x
    camara.look_at(Vector3(_cam_x + (pelota.position.x - _cam_x) * 0.08, 0, CAM_MIRA_Z))


func fijar_camara() -> void:
    _cam_x = encuadre_x * 0.6 + pelota.position.x * 0.4
    _mover_camara(0.0)
