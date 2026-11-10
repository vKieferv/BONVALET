class_name PantallaDuelos
extends Control

# T-11: la pantalla del partido en el modo de duelos (D-40 a D-43), como la maqueta v5 y la prueba 3D
# de T-12. Arriba la señal de TV con la cancha 3D (CanchaPartido); abajo las láminas, los PA, el mazo,
# el descarte, CEDER JUGADA y Aguantar. Solo muestra y recoge lo que hace el jugador: match_view sigue
# siendo quien llama al motor. Todo número que se ve sale del motor (success_chance, marcas, PA...).
#   - Ataque: la lámina de pase se arrastra a un compañero (la línea es la trayectoria de la carta, I-63)
#     y su % se calcula para ese receptor; regates, controles y remates se sueltan sobre la cancha.
#     Antes de la primera jugada se puede tocar a otro compañero de la zona para salir con él.
#   - Mantener una lámina sin moverla muestra la cuenta completa del % (gráfica de TV).
#   - Cada tirada se ve: aguja contra el % (I-58). El ataque del rival se anima paso a paso (I-60).

signal jugar_carta(indice: int, receptor: String)
signal ceder
signal aguantar
signal despejar
signal postura_elegida(p: int)
signal portador_elegido(id: String)
signal corner_elegido(id: String)   # D-48: a quién va el centro del córner

const Cancha := preload("res://scenes/partido/cancha_partido.gd")
const Jugador := preload("res://scenes/prueba_3d/jugador_low_poly.gd")
const Grafica := preload("res://scenes/prueba_3d/grafica_tv.gd")
const Trayectoria := preload("res://scenes/prueba_3d/trayectoria.gd")
const CanchaZonas := preload("res://scenes/prueba_3d/cancha_3d.gd")
const CARD_SCENE := preload("res://scenes/card_ui.tscn")

const ALTO_MANO := 260.0
const CENTRO_MANO := 603.0
const ANCHO_MANO := 915.0
const Y_LAMINAS := 464.0
const MANTENER_S := 0.45        # mantener la lámina quieta: cuenta completa
const ARRASTRE_MIN := 14.0      # píxeles de movimiento para que cuente como arrastre
const RAPIDO_RIVAL := 3.0       # velocidad de las jugadas del rival que no son importantes
const CONTORNO_FLECHA := Color("#0d1118")
const VERDE := Color("#4fd18b")
const CORAL := Color("#ff7a6b")
# T-16: reparto de una línea dentro de su zona. Cada jugador va en una columna distinta a la de sus vecinos
# (metros desde el centro de la zona, hacia el arco rival), así no quedan en fila ni se tapan en pantalla.
const COLUMNAS := [-4.0, 0.6, -1.8, 2.8, -3.0, 1.6]
# Dónde se para cada marcador respecto de su marcado: [hacia el arco, hacia la cámara], uno por marca.
const MARCAS := [Vector2(1.3, -0.7), Vector2(1.3, 0.9), Vector2(2.2, 0.1), Vector2(2.3, -1.5)]
const LIBRES_X := 6.4          # los rivales sin marca de la zona, más atrás
const SEP_X := 1.25            # separación mínima entre dos jugadores: a lo ancho de la pantalla...
const SEP_Z := 1.5             # ...y en profundidad (se ve aplastada por la cámara)
const SHORT_POR_CLUB := {"universidad_de_chile": Color("#f2f2f2")}   # los clubes guardan 2 colores (hallazgo de T-12)

enum Modo { NEUTRAL, ATAQUE, DEFENSA, RIVAL }

var engine: MatchEngine         # el tuyo
var rival_engine: MatchEngine
var contexto_carta: Callable    # match_view._card_context, para las láminas de defensa
var modo := Modo.NEUTRAL
var ocupado := false            # match_view anima o muestra un cartel: no se juega
var cancha: Cancha

var _liga: LeagueManager
var _equipo_l := {}
var _equipo_v := {}
var _colores_l: Array = []
var _colores_v: Array = []
var _nombres := {}              # "L:id" -> {name, role}
var _madera: ColorRect
var _vista: SubViewport
var _senal: SubViewportContainer
var _filtro: ColorRect
var _barra: ColorRect
var _marcador: Array = []       # [local, resultado, visita, minuto]
var _camino: Control
var _vivo: Control
var _posturas: Array = []
var _postura := 1
var _postura_fija := false
var _flow: Control
var _estamina: Control
var _zonas: Array = []          # [Label, zona]
var _etiquetas := {}            # clave -> gráfica de TV
var _rect_etiqueta := {}
var _hueco_etiqueta := {}
var _rotulados: Array = []      # claves con etiqueta en este momento
var _info := {}                 # clave -> {marcas: n, zona}
var _portador := ""             # clave del que tiene la pelota ("L:id")
var _zona := 0
var _local_ataca := true
var _con_balon: Control
var _flecha: Control
var _placa: Control             # el % del pase junto al compañero apuntado (playtest 2026-11-04)
var _tirada: Control
var _cuenta: Control
var _raiz_mano: Control
var _laminas: Array[CardUI] = []
var _elige := {}
var _flechas_linea := {}        # lámina -> triángulo ▲▼ después de "a FERNÁNDEZ"
var _pa: Label
var _moneda: TextureRect
var _mazo: Control
var _descarte: Control
var _boton_aguantar: Control
var _boton_ceder: Control
var _boton_acelerar: Control
var _boton_saltar: Control
var _aviso: Label
var _k := 1.0
var _ancho := 1280.0
var _alto_senal := 460.0
var _reloj := 0.0
var _arrastre: CardUI
var _apuntado := ""             # id del receptor apuntado (sin lado)
var _presionado: CardUI
var _encima: CardUI             # la lámina bajo el cursor: pasa al frente (T-16)
var _pres_pos := Vector2.ZERO
var _pres_t := 0.0
var _movido := false
var _pegado := false            # pase elegido con un clic: sigue apuntando hasta el próximo clic
var _cuenta_de: CardUI
var _mouse := Vector2.ZERO
var _linea_3d := PackedVector3Array()
var _forma_linea := ""
var _velocidad := 1.0
var _saltar := false
var _acelerado := false         # ACELERAR en el ataque rival (×3 sobre la velocidad de cada jugada)
var _tirada_datos := {}
var _tirada_t := -1.0
var _tirada_aguja := 0.0
var ultima_tirada := {}         # lo que muestra la tirada (smoke_match la compara con el evento)
var intencion := {}             # D-44: la jugada que anunció el rival (CoachBot.intent) mientras defiendes
var _intencion_g: Control
var _linea_rival_2d := PackedVector2Array()   # la línea de su pase en pantalla (para soltar la Intercepción)


# ------------------------------------------------------------------ Armado

func armar(liga: LeagueManager, equipo_l: Dictionary, equipo_v: Dictionary, jugadores_l: Array, jugadores_v: Array) -> void:
    _liga = liga
    _equipo_l = equipo_l
    _equipo_v = equipo_v
    _colores_l = liga.team_colors(equipo_l)
    _colores_v = liga.team_colors(equipo_v)
    set_anchors_preset(Control.PRESET_FULL_RECT)
    mouse_filter = Control.MOUSE_FILTER_IGNORE
    _madera = Mesa.madera()   # la mesa del DT bajo las láminas, como en la prueba de T-12
    add_child(_madera)
    _senal = SubViewportContainer.new()
    _senal.mouse_filter = Control.MOUSE_FILTER_IGNORE
    add_child(_senal)
    _vista = SubViewport.new()
    _vista.own_world_3d = true
    _vista.handle_input_locally = false
    _vista.msaa_3d = Viewport.MSAA_2X
    _vista.render_target_update_mode = SubViewport.UPDATE_ALWAYS
    _senal.add_child(_vista)
    cancha = Cancha.new()
    _vista.add_child(cancha)
    for pl: Dictionary in jugadores_l:
        _nombres["L:" + String(pl["id"])] = pl
    for pl: Dictionary in jugadores_v:
        _nombres["V:" + String(pl["id"])] = pl
    cancha.armar_equipo("L", jugadores_l, _colores_l, _short(equipo_l, _colores_l))
    cancha.armar_equipo("V", jugadores_v, _colores_v, _short(equipo_v, _colores_v))
    _armar_senal_2d()
    _armar_mano()
    _flecha = Control.new()
    _flecha.size = Vector2(4000, 4000)
    _flecha.mouse_filter = Control.MOUSE_FILTER_IGNORE
    _flecha.draw.connect(_dibujar_flecha)
    _placa = Control.new()
    _placa.mouse_filter = Control.MOUSE_FILTER_IGNORE
    _placa.visible = false
    _placa.draw.connect(_dibujar_placa)
    add_child(_flecha)
    add_child(_placa)   # encima de la línea del pase
    _intencion_g = Grafica.new()   # D-44: lo que va a hacer el rival, arriba de la cancha
    _intencion_g.mouse_filter = Control.MOUSE_FILTER_IGNORE
    _intencion_g.visible = false
    add_child(_intencion_g)
    _tirada = Control.new()
    _tirada.mouse_filter = Control.MOUSE_FILTER_IGNORE
    _tirada.size = Vector2(640, 120)   # baja (T-16): al pie de la cancha tapa lo menos posible
    _tirada.visible = false
    _tirada.draw.connect(_dibujar_tirada)
    add_child(_tirada)
    _cuenta = Control.new()
    _cuenta.mouse_filter = Control.MOUSE_FILTER_IGNORE
    _cuenta.visible = false
    _cuenta.draw.connect(_dibujar_cuenta)
    add_child(_cuenta)
    _ajustar_ventana()
    resized.connect(_ajustar_ventana)
    get_window().size_changed.connect(_ajustar_ventana)


func _short(equipo: Dictionary, colores: Array) -> Color:
    return SHORT_POR_CLUB.get(String(equipo.get("id", "")), colores[1])


func _ajustar_ventana() -> void:
    var lienzo := get_viewport_rect().size
    if lienzo.x <= 0.0 or lienzo.y <= 0.0 or _vista == null:
        return
    _k = maxf(0.01, float(get_window().size.x) / lienzo.x)
    _ancho = lienzo.x
    _alto_senal = lienzo.y - ALTO_MANO
    var pixeles := (Vector2(_ancho, _alto_senal) * _k).round()
    _vista.size = Vector2i(maxi(2, int(pixeles.x)), maxi(2, int(pixeles.y)))
    _senal.scale = Vector2.ONE / _k
    _senal.size = pixeles
    cancha.camara.fov = rad_to_deg(2.0 * atan(_alto_senal * 0.5 / Cancha.FOCO))
    _filtro.size = Vector2(_ancho, _alto_senal)
    _madera.size = lienzo
    (_madera.material as ShaderMaterial).set_shader_parameter("tam", lienzo)
    _barra.size = Vector2(_ancho, 40)
    _camino.position.x = (_ancho - 1280.0) * 0.5
    _vivo.position.x = _ancho - 18.0 - _vivo.size.x
    _con_balon.position = Vector2(16, _alto_senal - 40.0)
    _raiz_mano.position = Vector2((_ancho - 1280.0) * 0.5, lienzo.y - 720.0)
    _colocar_barra()
    # T-16: la tirada va al pie de la cancha, centrada: no tapa las láminas (ni las tuyas ni las de defensa
    # mientras ataca el rival). Las etiquetas la esquivan (_colocar_etiquetas).
    _tirada.position = Vector2((_ancho - _tirada.size.x) * 0.5, _alto_senal - _tirada.size.y - 10.0)


func _a_pantalla(p: Vector3) -> Vector2:
    return cancha.camara.unproject_position(p) / _k


func _jug(clave: String) -> Node3D:
    return cancha.jugadores.get(clave)


static func apellido(nombre: String) -> String:
    return Mesa.apellido(nombre).to_upper()


func _nombre(clave: String) -> String:
    return apellido(String(_nombres.get(clave, {}).get("name", "?")))


# ------------------------------------------------------------------ Señal 2D: barra, zonas, etiquetas

func _armar_senal_2d() -> void:
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
    for z in 3:
        var l := Paleta.etiqueta("", "plumon", 28, Color(CanchaZonas.TELESTRADOR, 0.9))
        Paleta.sombra_tv(l)
        add_child(l)
        _zonas.append(l)
    _barra = ColorRect.new()
    _barra.color = Color(Paleta.TV_FONDO, 0.88)
    _barra.mouse_filter = Control.MOUSE_FILTER_IGNORE
    add_child(_barra)
    for i in 4:
        var g := Grafica.new()
        add_child(g)
        _marcador.append(g)
    _estamina = Control.new()
    _estamina.mouse_filter = Control.MOUSE_FILTER_IGNORE
    _estamina.size = Vector2(150, 30)
    _estamina.draw.connect(_dibujar_estamina)
    add_child(_estamina)
    _camino = Control.new()
    _camino.size = Vector2(1280, 40)
    _camino.mouse_filter = Control.MOUSE_FILTER_IGNORE
    _camino.draw.connect(_dibujar_camino)
    add_child(_camino)
    _vivo = Grafica.new()
    add_child(_vivo)
    _vivo.configurar("EN VIVO", 16, Color.WHITE, [Color(0, 0, 0, 0), Color(0, 0, 0, 0), Color(0, 0, 0, 0), Color(0, 0, 0, 0)], 1, Color("#ff3b2f"))
    _vivo.position.y = 20.0 - _vivo.size.y * 0.5
    for i in 3:
        var g := Grafica.new()
        add_child(g)
        g.mouse_filter = Control.MOUSE_FILTER_STOP
        g.gui_input.connect(_al_pulsar_postura.bind(i))
        _posturas.append(g)
    _flow = Grafica.new()
    add_child(_flow)
    _flow.configurar("EN RACHA", 18, Color("#1a1408"), [Color("#ffd24a"), Color("#ff9a2e"), Color("#ff6a00"), Color("#ff8a1a")])
    _flow.visible = false
    _con_balon = Control.new()
    _con_balon.mouse_filter = Control.MOUSE_FILTER_IGNORE
    add_child(_con_balon)
    set_marcador(0, 0, 0)
    set_postura(1, false)


# Sigla del marcador: iniciales del nombre corto (Colo-Colo CC, U. Católica UC). Con "de" se agregan dos
# letras de la última palabra, para no confundir a la U. de Chile (UCH) con la Católica.
static func sigla(corto_club: String) -> String:
    var corto := corto_club.to_upper().replace(".", " ").replace("-", " ")
    var palabras := corto.split(" ", false)
    var partes: Array = []
    for p in palabras:
        if p.length() > 2 or partes.is_empty():
            partes.append(p)
    if partes.size() == 1:
        return String(partes[0]).left(3)
    var s := ""
    for p in partes:
        s += String(p).left(1)
    if palabras.has("DE") and s.length() == 2:
        s = s.left(1) + String(partes[-1]).left(2)
    return s.left(3)


func _sigla(equipo: Dictionary) -> String:
    return sigla(String(equipo.get("short_name", "?")))


func _fondo_club(colores: Array) -> Array:
    var a: Color = colores[0]
    return [a.lightened(0.18), a, a.darkened(0.2), a.darkened(0.06)]


func _texto_club(colores: Array) -> Color:
    var a: Color = colores[0]
    return Color("#111111") if a.get_luminance() > 0.55 else Color.WHITE


func set_marcador(goles_l: int, goles_v: int, minuto: int) -> void:
    if _marcador.is_empty():
        return
    _marcador[0].configurar(_sigla(_equipo_l), 20, _texto_club(_colores_l), _fondo_club(_colores_l))
    _marcador[1].configurar("%d - %d" % [goles_l, goles_v], 24, Color.WHITE, Paleta.TV_AZUL)
    _marcador[2].configurar(_sigla(_equipo_v), 20, _texto_club(_colores_v), _fondo_club(_colores_v))
    _marcador[3].configurar("%d'" % minuto, 20, Paleta.DORADO, Grafica.SEMI_NOCHE)
    _colocar_barra()


func texto_marcador() -> String:
    return _marcador[1].texto if not _marcador.is_empty() else ""


func set_postura(p: int, fija: bool) -> void:
    _postura = p
    _postura_fija = fija
    var nombres := ["BAJO", "NORMAL", "ALTO"]   # T-16: en español (el GDD las llama LOW / NORMAL / HIGH)
    for i in 3:
        var activa := i == p
        var g: Control = _posturas[i]
        g.configurar(nombres[i], 16, Color("#0b111b") if activa else Color.WHITE,
                Paleta.PLACA_DORADA if activa else Grafica.SEMI_NOCHE)
        g.modulate.a = 0.5 if fija and not activa else 1.0
        g.tooltip_text = "Postura del próximo Momento (fija durante la jugada)" if fija else "Postura del próximo Momento"
    _colocar_barra()


func _colocar_barra() -> void:
    if _marcador.is_empty():
        return
    var x := 16.0
    for g: Control in _marcador:
        g.position = Vector2(x, 20.0 - g.size.y * 0.5)
        x += g.size.x - g.size.y * Grafica.SKEW
    _estamina.position = Vector2(x + 10.0, 5.0)
    var xr := _ancho - 18.0
    _vivo.position.x = xr - _vivo.size.x
    xr = _vivo.position.x - 14.0
    for i in range(2, -1, -1):
        var g: Control = _posturas[i]
        xr -= g.size.x - g.size.y * Grafica.SKEW
        g.position = Vector2(xr, 20.0 - g.size.y * 0.5)
    _flow.position = Vector2(16.0, 48.0)


func set_flow(activo: bool) -> void:
    _flow.visible = activo


# Estamina del equipo (D-31 la hará por jugador): una gota y una barra, sin número (v5: mostrar por excepción).
func _dibujar_estamina() -> void:
    if engine == null:
        return
    var pct := engine.player.energy_pct()
    Icono.dibujar(_estamina, "gota", Rect2(0, 6, 18, 18), Color("#5cc8ff"))
    var r := Rect2(24, 11, 110, 8)
    _estamina.draw_rect(r, Color(0, 0, 0, 0.55))
    var col := Color("#5cc8ff") if pct >= 0.7 else (Color("#f0883e") if pct >= 0.3 else CORAL)
    _estamina.draw_rect(Rect2(r.position, Vector2(r.size.x * clampf(pct, 0.0, 1.0), r.size.y)), col)
    _estamina.tooltip_text = "Estamina %d/%d · %s" % [int(engine.player.energy), int(engine.player.max_energy()),
            ["ÓPTIMO", "CANSADO", "AGOTADO"][engine.player.zone()]]


func _al_pulsar_postura(event: InputEvent, i: int) -> void:
    if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT and not _postura_fija:
        postura_elegida.emit(i)


# Camino del Momento: Salida ● — Medio — Área, del que ataca; la zona en juego en blanco, la siguiente dorada.
func _dibujar_camino() -> void:
    var f := Paleta.letra("tv", 1)
    var y := 20.0
    var x := 520.0
    var activo := modo == Modo.ATAQUE or modo == Modo.RIVAL
    if modo == Modo.RIVAL:
        var t := "ATACA " + _sigla(_equipo_v)
        _camino.draw_string(f, Vector2(x - 12.0 - f.get_string_size(t, HORIZONTAL_ALIGNMENT_LEFT, -1, 18).x, y + 7.0), t,
                HORIZONTAL_ALIGNMENT_LEFT, -1, 18, _colores_v[0].lightened(0.3))
    var nombres := ["SALIDA", "MEDIO", "ÁREA"]
    for i in 3:
        var color := Color("#8d9ab0")
        if activo and i == _zona:
            color = Color.WHITE
        elif activo and i == _zona + 1:
            color = Paleta.DORADO
        if activo and i == _zona:
            _camino.draw_circle(Vector2(x + 9, y), 12.0, Color(1, 1, 1, 0.25), true, -1.0, true)
            _camino.draw_circle(Vector2(x + 9, y), 9.0, color, true, -1.0, true)
        else:
            _camino.draw_arc(Vector2(x + 9, y), 7.5, 0.0, TAU, 24, color, 3.0, true)
        x += 24.0
        _camino.draw_string(f, Vector2(x, y + 7.0), nombres[i], HORIZONTAL_ALIGNMENT_LEFT, -1, 18, color)
        x += f.get_string_size(nombres[i], HORIZONTAL_ALIGNMENT_LEFT, -1, 18).x + 10.0
        if i < 2:
            _camino.draw_rect(Rect2(x, y - 1.5, 44, 3), Color(1, 1, 1, 0.3))
            x += 54.0


func zona_camino() -> int:
    return _zona


func _poner_con_balon() -> void:
    for hijo in _con_balon.get_children():
        hijo.queue_free()
    if _portador == "" or not _nombres.has(_portador):
        return
    var local := _portador.begins_with("L:")
    var a := Grafica.new()
    _con_balon.add_child(a)
    a.configurar("CON EL BALÓN", 15, Color("#0b111b"), Paleta.PLACA_DORADA if local else _fondo_club(_colores_v))
    var b := Grafica.new()
    _con_balon.add_child(b)
    b.configurar("%s · %s" % [_nombre(_portador), String(_nombres[_portador].get("role", ""))], 20, Color("#0b111b"), Grafica.PLATA)
    b.position.x = a.size.x - a.size.y * Grafica.SKEW
    a.position.y = (b.size.y - a.size.y) * 0.5


func texto_con_balon() -> String:
    var out: Array = []
    for hijo in _con_balon.get_children():
        if not hijo.is_queued_for_deletion():
            out.append(hijo.texto)
    return " ".join(out)


# ------------------------------------------------------------------ Formación: dónde va cada uno

# Posición de los 22 según el estado del Momento del que ataca (`e`): sus líneas en sus zonas, los que
# los marcan pegados a ellos del lado del arco (un punto por marca), los rivales libres de cada línea un
# poco más atrás y los arqueros en su arco. Llena _info (marcas y zona de cada atacante) para las etiquetas.
func _posiciones(e: MatchEngine, local: bool, zona: int, portador: String, marcas: Dictionary) -> Dictionary:
    var dir := 1.0 if local else -1.0
    var at := "L:" if local else "V:"
    var de := "V:" if local else "L:"
    var out := {}
    _info.clear()
    for z in 3:
        var centro: float = cancha.centro_zona(z, local)
        var linea: Array = e.zone_players(z)
        var n := linea.size()
        var tomados := {}
        for i in n:
            var p: Dictionary = linea[i]
            var pos := Vector3(centro + dir * float(COLUMNAS[i % COLUMNAS.size()]), 0, lerpf(Cancha.Z_MIN, Cancha.Z_MAX, (i + 0.5) / n))
            out[at + String(p["id"])] = pos
            var ms: Array = (marcas.get(z, {}) as Dictionary).get(p["id"], [])
            _info[at + String(p["id"])] = {"marcas": ms.size(), "zona": z}
            for j in ms.size():
                out[de + String(ms[j]["id"])] = _junto_a(pos, dir, j)
                tomados[ms[j]["id"]] = true
        var libres: Array = e.defender_line(z).filter(func(d): return not tomados.has(d["id"]))
        for j in libres.size():
            out[de + String(libres[j]["id"])] = Vector3(centro + dir * LIBRES_X, 0,
                    lerpf(Cancha.Z_MIN + 1.0, Cancha.Z_MAX - 1.0, (j + 0.5) / libres.size()))
    # El portador que entró a otra zona con un regate: adelante en esa zona, con sus marcas.
    var pid := portador.trim_prefix(at)
    if pid != "" and not e.zone_players(zona).any(func(p): return p["id"] == pid):
        var pos := Vector3(cancha.centro_zona(zona, local) - dir * 1.0, 0, 0.6)
        out[at + pid] = pos
        var ms: Array = (marcas.get(zona, {}) as Dictionary).get(pid, [])
        _info[at + pid] = {"marcas": ms.size(), "zona": zona}
        for j in ms.size():
            out[de + String(ms[j]["id"])] = _junto_a(pos, dir, j)
    elif pid != "" and _info.has(at + pid):
        _info[at + pid]["zona"] = zona
    var mio := MatchEngine.keeper_of(e.duel_players)
    var suyo := MatchEngine.keeper_of(e.rival_players)
    if not mio.is_empty():
        out[at + String(mio["id"])] = Vector3(cancha.arco_x(local) + dir * 1.5, 0, 0.2)
    if not suyo.is_empty():
        out[de + String(suyo["id"])] = Vector3(cancha.arco_x(not local) - dir * 1.4, 0, 0.2)
    _separar(out, [at + String(mio.get("id", "")), de + String(suyo.get("id", ""))])
    return out


# El marcador número j de un jugador: pegado a él, del lado del arco que defiende.
func _junto_a(pos: Vector3, dir: float, j: int) -> Vector3:
    var o: Vector2 = MARCAS[mini(j, MARCAS.size() - 1)]
    return pos + Vector3(dir * o.x, 0, o.y)


# Separación mínima (T-16): si dos quedaron encima, se apartan lo justo (los marcadores siguen junto a su
# marcado). `fijos` no se mueven (los arqueros). Siempre da el mismo resultado para las mismas posiciones.
func _separar(pos: Dictionary, fijos: Array) -> void:
    var claves: Array = pos.keys()
    claves.sort()
    for vuelta in 8:
        var movio := false
        for a in claves.size():
            for b in range(a + 1, claves.size()):
                var pa: Vector3 = pos[claves[a]]
                var pb: Vector3 = pos[claves[b]]
                var e := Vector2((pb.x - pa.x) / SEP_X, (pb.z - pa.z) / SEP_Z)
                var l := e.length()
                if l >= 1.0:
                    continue
                var fa := fijos.has(claves[a])
                var fb := fijos.has(claves[b])
                if fa and fb:
                    continue
                var hacia := e / l if l > 0.001 else Vector2(1, 0)
                var falta := (1.0 - l) * (1.0 if fa or fb else 0.5)
                var mov := Vector3(hacia.x * falta * SEP_X, 0, hacia.y * falta * SEP_Z)
                if not fa:
                    pos[claves[a]] = pa - mov
                if not fb:
                    pos[claves[b]] = pb + mov
                movio = true
        if not movio:
            return


# Sin Momento en juego (antes de un ataque rival o entre jugadas): cada equipo en sus líneas, sin marcas.
func _posiciones_neutras() -> Dictionary:
    var out := {}
    _info.clear()
    for datos: Array in [[engine, true, "L:"], [rival_engine, false, "V:"]]:
        var e: MatchEngine = datos[0]
        var local: bool = datos[1]
        var dir := 1.0 if local else -1.0
        var lineas := MatchEngine.lines_of(e.duel_players, e.formation, e.posture)
        for z in 3:
            var centro: float = cancha.centro_zona(z, local)
            var linea: Array = lineas[z]
            for i in linea.size():
                out[String(datos[2]) + String(linea[i]["id"])] = Vector3(centro + dir * (float(COLUMNAS[i % COLUMNAS.size()]) + 1.4), 0,
                        lerpf(Cancha.Z_MIN, Cancha.Z_MAX, (i + 0.5) / linea.size()))
        var arquero := MatchEngine.keeper_of(e.duel_players)
        if not arquero.is_empty():
            out[String(datos[2]) + String(arquero["id"])] = Vector3(cancha.arco_x(local) + dir * 1.5, 0, 0.2)
    _separar(out, [])
    return out


# Mueve a cada uno a su lugar (tiempo 0 = de golpe) y deja la pelota en el pie del portador.
func _formar(pos: Dictionary, tiempo: float) -> void:
    var hacia := Vector3(cancha.arco_x(not _local_ataca), 0, 0)
    for clave: String in pos:
        var j := _jug(clave)
        if j == null:
            continue
        if tiempo <= 0.0 or _saltar:
            j.colocar(pos[clave], hacia)
        else:
            j.ir_a(pos[clave], tiempo / _velocidad)


func _pelota_al_portador(de_golpe: bool) -> void:
    var j := _jug(_portador)
    if j == null:
        return
    var hacia := Vector3(cancha.arco_x(not _portador.begins_with("L:")), 0, j.position.z)
    var p: Vector3 = j.junto_al_pie(hacia, Cancha.RADIO_PELOTA)
    if de_golpe or _saltar:
        cancha.pelota_en(p)
    else:
        cancha.volar("conduccion", p)


func _encuadrar() -> void:
    var a: float = cancha.centro_zona(_zona, _local_ataca)
    var b: float = cancha.centro_zona(mini(_zona + 1, 2), _local_ataca)
    cancha.encuadre_x = (a + b) * 0.5 if _zona < 2 else cancha.centro_zona(2, _local_ataca) + (3.0 if _local_ataca else -3.0)


# ------------------------------------------------------------------ Estados que pide match_view

# Tu ataque: el estado del motor, la mano y las etiquetas. tiempo 0 = todos a su lugar de golpe.
func mostrar_ataque(tiempo: float = 0.6) -> void:
    _saltar = false   # un SALTAR del ataque rival no se salta tus jugadas
    modo = Modo.ATAQUE
    _local_ataca = true
    _sincronizar_ataque(tiempo)
    armar_mano()
    if tiempo <= 0.0:
        cancha.fijar_camara()


func _sincronizar_ataque(tiempo: float) -> void:
    _zona = engine.zone
    _portador = "L:" + String(engine.carrier.get("id", ""))
    _formar(_posiciones(engine, true, _zona, _portador, engine.marks), tiempo)
    _pelota_al_portador(tiempo <= 0.0)
    _rotular()
    _encuadrar()
    _poner_con_balon()
    _camino.queue_redraw()


func mostrar_defensa() -> void:
    modo = Modo.DEFENSA
    intencion = {}
    _local_ataca = false
    _neutral()
    armar_mano()


func mostrar_neutral(local_ataca: bool = true) -> void:
    _saltar = false
    modo = Modo.NEUTRAL
    _local_ataca = local_ataca
    _neutral()
    armar_mano()


# D-44 (T-15), la defensa es el ataque al revés: el rival anunció su jugada (it de CoachBot.intent). La
# cancha muestra su ataque con tus marcas, arriba su intención (quién la tiene, a quién pasa o si regatea o
# remata, y su %; la placa junto al que va a recibir o rematar) y abajo tu mano de defensa: la lámina se
# arrastra sobre un rival y la juega tu defensor más cercano (MatchEngine.defense_defender).
func mostrar_intencion(it: Dictionary, primero: bool = false) -> void:
    intencion = it
    modo = Modo.DEFENSA
    _local_ataca = false
    _saltar = false
    _velocidad = 1.0
    cancha.velocidad = 1.0
    _zona = rival_engine.zone
    _portador = "V:" + String(rival_engine.carrier.get("id", ""))
    _formar(_posiciones(rival_engine, false, _zona, _portador, rival_engine.marks), 0.0 if primero else 0.5)
    _pelota_al_portador(primero)
    _rotular()
    _encuadrar()
    if primero:
        cancha.fijar_camara()
    _poner_con_balon()
    _camino.queue_redraw()
    armar_mano()


# El % de la jugada anunciada del rival (con lo que ya le restó tu defensa): el mismo que va a tirar.
func intencion_pct() -> int:
    if intencion.is_empty():
        return -1
    if intencion.get("hold", false):
        return roundi(rival_engine.hold_chance() * 100.0)
    if intencion.has("corner"):
        return roundi(rival_engine.corner_chance(String(intencion["corner"])) * 100.0)
    return roundi(rival_engine.success_chance(intencion["card"], -1, String(intencion.get("receiver", ""))) * 100.0)


# "UCH · SALAS: PASE CORTO a MENA · 54%" (smoke_match lo compara con el motor del rival).
func intencion_texto() -> String:
    if intencion.is_empty():
        return ""
    var quien := "%s · %s" % [_sigla(_equipo_v), apellido(String(rival_engine.carrier.get("name", "")))]
    if intencion.has("corner"):   # D-48: "UCH · CÓRNER de SALAS a MENA · 54%"
        return "%s · CÓRNER de %s a %s · %d%%" % [_sigla(_equipo_v), apellido(String(rival_engine.corner_taker().get("name", ""))),
                apellido(String(rival_engine._player_by_id(String(intencion["corner"])).get("name", ""))), intencion_pct()]
    if intencion.get("hold", false):
        return "%s AGUANTA EL BALÓN · %d%%" % [quien, intencion_pct()]
    var c: Card = intencion["card"]
    var txt := "%s: %s" % [quien, c.display_name.to_upper()]
    var r := String(intencion.get("receiver", ""))
    if r != "":
        txt += " a " + apellido(String(rival_engine._player_by_id(r).get("name", "")))
    elif c.kind == Card.Kind.SHOT:
        txt += " AL ARCO"
    return txt + " · %d%%" % intencion_pct()


func _actualizar_intencion() -> void:
    if _intencion_g == null:
        return
    _intencion_g.visible = modo == Modo.DEFENSA and not intencion.is_empty()
    if not _intencion_g.visible:
        return
    _intencion_g.configurar("VA A JUGAR  " + intencion_texto(), 20, Color.WHITE, _fondo_club(_colores_v))
    _intencion_g.position = Vector2((_ancho - _intencion_g.size.x) * 0.5, 50.0)


# Rival sobre el que se suelta la lámina de defensa: el único que sirve para esa carta (defense_target),
# si el mouse está sobre su cuerpo o su etiqueta; la Intercepción, también sobre la línea de su pase.
func _rival_apuntado(c: Card) -> String:
    var t := engine.defense_target(c)
    if t == "":
        return ""
    if _companero_bajo_mouse([{"id": t}], "V:") != "":
        return t
    if c.kind == Card.Kind.INTERCEPT and _linea_rival_2d.size() >= 2:
        for i in _linea_rival_2d.size() - 1:
            var p := Geometry2D.get_closest_point_to_segment(_mouse, _linea_rival_2d[i], _linea_rival_2d[i + 1])
            if p.distance_to(_mouse) < 26.0:
                return t
    return ""


# La línea del pase anunciado del rival: blanca, o del color de tu % si la apuntas con una Intercepción.
func _dibujar_linea_rival() -> void:
    _linea_rival_2d = PackedVector2Array()
    var c: Card = intencion.get("card")
    var r := String(intencion.get("receiver", ""))
    if c == null or r == "" or _jug("V:" + r) == null:
        return
    var forma := Trayectoria.para_carta(c)
    var pts3 := Trayectoria.puntos(forma, cancha.pelota.position, _llegada("V:" + r))
    if pts3.size() < 4:
        return
    var pts := PackedVector2Array()
    var suelo := PackedVector2Array()
    for p in pts3:
        pts.append(_a_pantalla(p))
        suelo.append(_a_pantalla(Vector3(p.x, 0.03, p.z)))
    _linea_rival_2d = suelo
    var color := Color(1, 1, 1, 0.9)
    if _arrastre != null and _arrastre.card.kind == Card.Kind.INTERCEPT and _apuntado == r:
        color = Cancha.color_tono(_tono_apuntado())
    _linea(pts, suelo, forma, color)


func _neutral() -> void:
    _formar(_posiciones_neutras(), 0.8)
    _rotulados.clear()
    _portador = ""
    _poner_con_balon()
    var x: float = cancha.centro_zona(0, _local_ataca)
    cancha.pelota_en(Vector3(x + (1.0 if _local_ataca else -1.0) * 2.0, Cancha.RADIO_PELOTA, 0.6))
    cancha.encuadre_x = x
    _actualizar_etiquetas()
    _camino.queue_redraw()


# Quién lleva etiqueta: el portador y los atacantes de la zona en juego y de la siguiente.
func _rotular() -> void:
    _rotulados.clear()
    for clave: String in _info:
        var z: int = _info[clave]["zona"]
        if z == _zona or z == mini(_zona + 1, 2) or clave == _portador:
            _rotulados.append(clave)
    _actualizar_etiquetas()
    _actualizar_anillos()


func _actualizar_etiquetas() -> void:
    for clave: String in _etiquetas.keys():
        if not _rotulados.has(clave):
            _etiquetas[clave].queue_free()
            _etiquetas.erase(clave)
            _rect_etiqueta.erase(clave)
    var defiende: Array = _colores_v if _local_ataca else _colores_l
    var color_marca: Color = defiende[0].lightened(0.25)
    if color_marca.get_luminance() > 0.85:
        color_marca = defiende[1].lightened(0.1)
    for clave: String in _rotulados:
        if not _etiquetas.has(clave):
            var g := Grafica.new()
            add_child(g)
            move_child(g, _flecha.get_index() if _flecha != null else get_child_count() - 1)
            var j := _jug(clave)
            if j != null:
                g.position = _a_pantalla(j.position) + Vector2(-40, 10)
            _etiquetas[clave] = g
        var g: Control = _etiquetas[clave]
        var n: int = _info.get(clave, {}).get("marcas", 0)
        var nombre := _nombre(clave)
        var id := clave.substr(2)
        if clave == _portador:
            g.configurar(nombre, 16, Paleta.DORADO, Grafica.SEMI_NOCHE, n, color_marca)
        elif id == _apuntado and _arrastre != null:
            var c := Cancha.color_tono(_tono_apuntado())
            g.configurar(nombre + " · LIBRE" if n == 0 else nombre, 17, c, Grafica.SEMI_NOCHE, n, color_marca, c)
        elif n == 0:
            g.configurar(nombre + " · LIBRE", 16, Color.WHITE, Paleta.PLACA_VERDE)
        else:
            g.configurar(nombre, 16, Color.WHITE, Grafica.SEMI_NOCHE, n, color_marca)


# Lo que muestra cada etiqueta: {clave: {texto, puntos}} (smoke_match lo compara con las marcas del motor).
func etiquetas() -> Dictionary:
    var out := {}
    for clave: String in _etiquetas:
        out[clave] = {"texto": _etiquetas[clave].texto, "puntos": _etiquetas[clave].puntos}
    return out


func portador() -> String:
    return _portador


func _actualizar_anillos() -> void:
    var lado := "V:" if modo == Modo.DEFENSA else "L:"
    var defensor := defensor_resaltado()
    for clave: String in cancha.jugadores:
        var j = cancha.jugadores[clave]
        if clave == _portador:
            j.poner_anillo(cancha.anillos["portador"])
        elif defensor != "" and clave == defensor:   # D-44: el tuyo que juega la carta de defensa
            j.poner_anillo(cancha.anillos[Cancha.tono(engine.success_chance(_arrastre.card))])
        elif _arrastre != null and clave.substr(2) == _apuntado and clave.begins_with(lado):
            j.poner_anillo(cancha.anillos[_tono_apuntado()])
        elif _rotulados.has(clave) and int(_info.get(clave, {}).get("marcas", 1)) == 0:
            j.poner_anillo(cancha.anillos["libre"])
        else:
            j.poner_anillo(null)


# Clave ("L:id") de tu defensor mientras arrastras una lámina de defensa por duelos; "" si no.
func defensor_resaltado() -> String:
    if modo != Modo.DEFENSA or _arrastre == null or engine == null or not engine.duel_defense_on():
        return ""
    var d := engine.defense_defender(_arrastre.card)
    return "" if d.is_empty() else "L:" + String(d["id"])


func _rect_cuerpo(j: Node3D) -> Rect2:
    var pies := _a_pantalla(j.position)
    var cabeza := _a_pantalla(j.position + Vector3(0, Jugador.ALTURA, 0))
    var alto := absf(pies.y - cabeza.y)
    var ancho := alto * 0.42
    return Rect2((pies.x + cabeza.x) * 0.5 - ancho * 0.5, cabeza.y, ancho, alto)


func _rect_pelota() -> Rect2:
    return Rect2(_a_pantalla(cancha.pelota.position) - Vector2(11, 11), Vector2(22, 22))


func _rect_con_balon() -> Rect2:
    var fin := Vector2.ZERO
    for hijo in _con_balon.get_children():
        var g: Control = hijo
        fin = fin.max(g.position + g.size)
    return Rect2(_con_balon.position, fin + Vector2(0, 4))


# Etiquetas sin taparse (algoritmo de T-12): primero el portador y el apuntado, después de adelante hacia
# atrás; cambiar de hueco cuesta, para que no salten.
func _colocar_etiquetas(delta: float) -> void:
    var claves: Array = _etiquetas.keys()
    claves.sort_custom(func(a: String, b: String) -> bool: return _prioridad(a) > _prioridad(b))
    var cuerpos := {}
    var limites_vista := Rect2(-60, 0, _ancho + 120, _alto_senal + 60)
    for clave: String in cancha.jugadores:
        var r := _rect_cuerpo(cancha.jugadores[clave])
        if limites_vista.intersects(r):
            cuerpos[clave] = r
    var pelota := _rect_pelota()
    var ocupados: Array[Rect2] = [_rect_con_balon(), Rect2(0, 0, _ancho, 72)]
    if _intencion_g != null and _intencion_g.visible:
        ocupados.append(Rect2(_intencion_g.position, _intencion_g.size).grow(4.0))
    if _placa.visible:
        ocupados.append(Rect2(_placa.position, _placa.size).grow(4.0))
    if _tirada.visible:
        ocupados.append(Rect2(_tirada.position, _tirada.size))
    if _arrastre != null:
        for i in range(0, _linea_3d.size(), 2):
            ocupados.append(Rect2(_a_pantalla(_linea_3d[i]) - Vector2(9, 9), Vector2(18, 18)))
    for l: Label in _zonas:
        if l.visible:
            ocupados.append(Rect2(l.position, l.size))
    var limites := Rect2(6, 44, _ancho - 12, _alto_senal - 50)
    for clave: String in claves:
        var g: Control = _etiquetas[clave]
        var j := _jug(clave)
        if j == null:
            continue
        var s: Vector2 = g.size
        var propio := _rect_cuerpo(j)
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
            Vector2(propio.position.x - s.x - 8, propio.position.y - s.y * 0.5),
            Vector2(propio.end.x + 8, propio.position.y - s.y * 0.5),
            Vector2(pies.x - s.x * 0.5, pies.y + 18 + s.y * 2.0),
            Vector2(pies.x - s.x * 0.5, propio.position.y - s.y * 2.0 - 12),
        ]
        var mejor := 0
        var mejor_costo := INF
        for i in huecos.size():
            # T-16: ningún hueco sale de la pantalla (se acota al borde; alejarse de su jugador cuesta) y
            # pisar otra etiqueta o una gráfica cuesta mucho más que tapar un cuerpo.
            var pedido: Vector2 = huecos[i]
            huecos[i] = Vector2(clampf(pedido.x, limites.position.x, maxf(limites.position.x, limites.end.x - s.x)),
                    clampf(pedido.y, limites.position.y, maxf(limites.position.y, limites.end.y - s.y)))
            var r := Rect2(huecos[i], s)
            var costo := i * 3.0 + pedido.distance_to(huecos[i]) * 1.5
            if i != int(_hueco_etiqueta.get(clave, 0)):
                costo += 8.0
            for otro: String in cuerpos:
                costo += r.intersection(cuerpos[otro]).get_area()
            costo += r.intersection(pelota).get_area()
            for o: Rect2 in ocupados:
                costo += r.intersection(o).get_area() * 12.0
            if costo < mejor_costo:
                mejor_costo = costo
                mejor = i
        _hueco_etiqueta[clave] = mejor
        var destino: Vector2 = huecos[mejor]
        _rect_etiqueta[clave] = Rect2(destino, s)
        ocupados.append(Rect2(destino, s))
        g.position = destino if _saltar else g.position.lerp(destino, 1.0 - exp(-16.0 * delta))


func _prioridad(clave: String) -> float:
    if clave == _portador:
        return 3000.0
    if clave.substr(2) == _apuntado:
        return 2000.0
    var j := _jug(clave)
    return j.position.z if j != null else 0.0


func _colocar_zonas() -> void:
    var nombres := ["SALIDA", "MEDIO", "ÁREA"]
    for i in 3:
        var l: Label = _zonas[i]
        # La zona i del que ataca: con el rival atacando, su Salida es tu Área (a la derecha).
        var z := i
        l.text = nombres[z]
        var r: Array = Cancha.ZONAS_X[z if _local_ataca else 2 - z]
        var a := _a_pantalla(Vector3(r[0], 0, -8.8))
        var b := _a_pantalla(Vector3(r[1], 0, -8.8))
        var izq := maxf(minf(a.x, b.x), 8.0)
        var der := minf(maxf(a.x, b.x), _ancho - 8.0)
        var ancho := l.get_minimum_size().x
        l.position = Vector2(clampf((izq + der - ancho) * 0.5, 8.0, _ancho - ancho - 8.0), a.y - 14.0)
        l.size = l.get_minimum_size()
        l.visible = der - izq > ancho * 0.8


# ------------------------------------------------------------------ Mano

func _armar_mano() -> void:
    _raiz_mano = Control.new()
    _raiz_mano.size = Vector2(1280, 720)
    _raiz_mano.mouse_filter = Control.MOUSE_FILTER_IGNORE
    add_child(_raiz_mano)
    _moneda = TextureRect.new()
    _moneda.texture = Paleta.moneda(Paleta.MONEDA["normal"])
    _moneda.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
    _moneda.size = Vector2(96, 96)
    _moneda.position = Vector2(26, 470)
    _moneda.mouse_filter = Control.MOUSE_FILTER_IGNORE
    _raiz_mano.add_child(_moneda)
    _pa = Paleta.etiqueta("—", "condensada_negra", 50, Color("#1a1408"))
    _pa.position = Vector2(26, 470)
    _pa.size = Vector2(96, 66)
    _pa.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    _pa.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
    _raiz_mano.add_child(_pa)
    var pa2 := Paleta.etiqueta("PA", "condensada_negra", 16, Color("#1a1408"), 2)
    pa2.position = Vector2(26, 528)
    pa2.size = Vector2(96, 20)
    pa2.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    _raiz_mano.add_child(pa2)
    _mazo = Grafica.new()
    _raiz_mano.add_child(_mazo)
    _mazo.position = Vector2(14, 580)
    _boton_aguantar = _boton("AGUANTAR", 16, Vector2(14, 626), func() -> void: _al_boton("aguantar"))
    _boton_ceder = _boton("CEDER JUGADA", 24, Vector2(1066, 486), func() -> void: _al_boton("ceder"))
    _boton_ceder.margen = 16.0
    _descarte = Grafica.new()
    _raiz_mano.add_child(_descarte)
    _descarte.position = Vector2(1080, 596)
    _boton_acelerar = _boton("ACELERAR", 20, Vector2(1066, 486), func() -> void: acelerar())
    _boton_saltar = _boton("SALTAR", 20, Vector2(1066, 540), func() -> void: saltar())
    _aviso = Paleta.etiqueta("", "plumon", 15, Paleta.PLUMON_CREMA)
    _aviso.position = Vector2(1076, 640)
    _aviso.size = Vector2(196, 78)
    _aviso.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
    _aviso.rotation_degrees = -2.0
    _raiz_mano.add_child(_aviso)


func _boton(texto: String, tam: int, pos: Vector2, al_pulsar: Callable) -> Control:
    var g := Grafica.new()
    _raiz_mano.add_child(g)
    g.margen = 12.0
    g.configurar(texto, tam, Color.WHITE, Paleta.TV_AZUL)
    g.position = pos
    g.mouse_filter = Control.MOUSE_FILTER_STOP
    g.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
    g.gui_input.connect(func(ev: InputEvent) -> void:
        if ev is InputEventMouseButton and ev.pressed and ev.button_index == MOUSE_BUTTON_LEFT and g.modulate.a > 0.9:
            al_pulsar.call())
    return g


func _al_boton(nombre: String) -> void:
    if ocupado or _arrastre != null:
        return
    match nombre:
        "ceder":
            ceder.emit()
        "aguantar":
            if modo == Modo.DEFENSA:
                despejar.emit()
            else:
                aguantar.emit()


# Rehace las láminas con la mano del motor (nueva mano, carta jugada, defensa...).
func armar_mano() -> void:
    for ui in _laminas:
        ui.queue_free()
    _laminas.clear()
    _encima = null
    _elige.clear()
    _flechas_linea.clear()
    _soltar(false)
    # T-16: mientras ataca el rival tus láminas de defensa siguen en la mesa (sin jugarse): no queda solo madera.
    var mirando := modo == Modo.RIVAL and engine != null and engine.in_defense
    if engine != null and (modo == Modo.ATAQUE or modo == Modo.DEFENSA or mirando):
        var cartas: Array = engine.deck.hand
        for i in cartas.size():
            var ui: CardUI = CARD_SCENE.instantiate()
            ui.custom_minimum_size = CardUI.TAMANO
            _raiz_mano.add_child(ui)
            ui.size = CardUI.TAMANO
            ui.setup(cartas[i], i)
            ui.pivot_offset = CardUI.TAMANO * 0.5
            ui.rotation_degrees = (i - (cartas.size() - 1) * 0.5) * 2.0
            ui.chosen.connect(_al_tomar_lamina)
            if mirando:
                ui.set_interactive(false)
                ui.modulate = Color(0.82, 0.82, 0.82)
            ui.mouse_entered.connect(_al_entrar_lamina.bind(ui))
            ui.mouse_exited.connect(_al_salir_lamina.bind(ui))
            var elige := Grafica.new()
            ui.body.add_child(elige)   # en el cuerpo: sube con la lámina cuando el cursor la levanta
            elige.triangulo = true
            elige.configurar("ELIGE", 20, Color.WHITE, Paleta.TV_AZUL)
            elige.visible = false
            _elige[ui] = elige
            var fl := Control.new()
            fl.mouse_filter = Control.MOUSE_FILTER_IGNORE
            fl.size = Vector2(14, 14)
            fl.draw.connect(_dibujar_triangulo.bind(fl))
            fl.visible = false
            ui.body.add_child(fl)
            _flechas_linea[ui] = fl
            _laminas.append(ui)
    refrescar()


func laminas() -> Array[CardUI]:
    return _laminas


# Recalcula lo que muestra la pantalla con el estado del motor: láminas, PA, mazo, descarte y botones.
func refrescar() -> void:
    if engine == null:
        return
    var turno := modo == Modo.ATAQUE or modo == Modo.DEFENSA
    _pa.text = "%d" % engine.ap if turno else "—"
    _moneda.modulate.a = 1.0 if turno else 0.45
    _mazo.configurar("MAZO %d" % engine.deck.draw_pile.size(), 18, Color.WHITE, Grafica.SEMI_NOCHE)
    _descarte.configurar("DESCARTE %d" % engine.deck.discard_pile.size(), 18, Color.WHITE, Grafica.SEMI_NOCHE)
    var rival := modo == Modo.RIVAL
    _boton_ceder.visible = not rival
    _boton_ceder.configurar("DEJAR PASAR" if modo == Modo.DEFENSA else "CEDER JUGADA", 24, Color.WHITE, Paleta.TV_AZUL)
    _boton_ceder.modulate.a = 1.0 if turno and not ocupado else 0.45
    _boton_aguantar.visible = modo != Modo.RIVAL
    if modo == Modo.DEFENSA:
        _boton_aguantar.configurar("DESPEJE", 16, Color.WHITE, Paleta.TV_AZUL)
        _boton_aguantar.modulate.a = 1.0 if engine.can_emergency_clear() and not ocupado else 0.45
        _boton_aguantar.tooltip_text = "Despeje de emergencia: gasta todos tus PA y %d de estamina; sus remates −%d, pero le devuelves la pelota." % [
                roundi(engine.emergency_stamina_cost()), roundi(MatchEngine.EMERGENCY_SHOT_PENALTY * 100.0)]
    else:
        _boton_aguantar.configurar("AGUANTAR", 16, Color.WHITE, Paleta.TV_AZUL)
        var puede := modo == Modo.ATAQUE and engine.can_hold() and not ocupado
        _boton_aguantar.modulate.a = 1.0 if puede else 0.45
        _boton_aguantar.tooltip_text = "Aguantar el balón (%d PA · %d%%): mano nueva; si falla, te la roban." % [
                engine.hold_ap_cost(), roundi(engine.hold_chance() * 100.0)] if modo == Modo.ATAQUE else ""
    _boton_acelerar.visible = rival
    _boton_saltar.visible = rival
    _boton_acelerar.configurar("ACELERADO" if _acelerado else "ACELERAR", 20, Color.WHITE, Grafica.SEMI_NOCHE if _acelerado else Paleta.TV_AZUL)
    _aviso.text = _texto_aviso()
    _estamina.queue_redraw()
    _actualizar_intencion()
    _refrescar_laminas()


func _texto_aviso() -> String:
    match modo:
        Modo.ATAQUE:
            if engine.corner_pending:
                return "córner: toca a quien va a cabecear"
            if engine.moment_plays == 0 and engine.zone_players(engine.zone).size() > 1:
                return "toca a un compañero para salir con él"
            return "mantén la carta: ver la cuenta"
        Modo.DEFENSA:
            if engine.duel_defense_on():
                return "arrastra la carta sobre el rival"
            return "toca una carta para defender"
        Modo.RIVAL:
            return "ataca %s" % String(_equipo_v.get("short_name", "")).to_lower()
    return ""


func pa_texto() -> String:
    return _pa.text


func mazo_texto() -> String:
    return _mazo.texto


func descarte_texto() -> String:
    return _descarte.texto


# La lámina simple de v5: costo, nombre, una línea y un solo %. Los pases dicen ELIGE hasta que apuntas.
func _refrescar_laminas() -> void:
    var mirando := modo == Modo.RIVAL and engine.in_defense
    if not ((modo == Modo.ATAQUE and not engine.moment_over) or (modo == Modo.DEFENSA and engine.in_defense) or mirando):
        _ordenar_mano()
        return
    for ui in _laminas:
        var c: Card = ui.card
        if mirando:   # se ven, no se juegan: costo, nombre y palabras clave, sin % ni cinta
            ui.setup(c, ui.hand_index, _contexto(c))
            ui.seal_label.visible = false
            ui.update_stats(engine.ap_cost_of(c), c.ap_cost, engine.stamina_cost_of(c), 0.0, true, false, [], "")
            ui.tooltip_text = ""
            ui.chance_label.visible = false
            ui.effect_label.text = String(linea_de(c, "")[0])
            ui._layout()
            continue
        var ataque := modo == Modo.ATAQUE
        ui.setup(c, ui.hand_index, _contexto(c))
        ui.seal_label.visible = false
        var receptor := _apuntado if ui == _arrastre else ""
        var pase := ataque and MatchEngine.is_pass(c)
        var chance := -1.0
        if not pase or receptor != "":
            chance = engine.success_chance(c, -1, receptor)
        if not ataque and engine.duel_defense_on() and c.kind != Card.Kind.CLEARANCE and engine.defense_target(c) == "":
            chance = -1.0   # D-44: no sirve contra esta jugada: sin defensor, no hay %
        var usable := engine.can_play(c) and not ocupado
        ui.update_stats(engine.ap_cost_of(c), c.ap_cost, engine.stamina_cost_of(c), maxf(chance, 0.0), usable,
                c.flow_uses > 0 and engine.flow_active, [], "" if ocupado else CardUI.unplayable_reason(engine, c))
        ui.tooltip_text = ""
        ui.chance_label.visible = chance >= 0.0 and c.type != Card.Type.PENALTY
        if engine.corner_taken and MatchEngine.CORNER_CARDS.has(c.id) and modo == Modo.ATAQUE:
            ui.flash(Paleta.DORADO)   # D-48: Cabezazo y Palomita brillan después de un córner
        var linea := linea_de(c, receptor)
        ui.effect_label.text = linea[0]
        ui._layout()
        var fl: Control = _flechas_linea[ui]
        fl.set_meta("flecha", linea[1])
        fl.set_meta("arriba", linea[1] > 0)
        var elige: Control = _elige[ui]
        elige.visible = pase and chance < 0.0 and usable
    _ordenar_mano()


func _contexto(c: Card) -> Dictionary:
    if modo == Modo.ATAQUE and not engine.carrier.is_empty():
        return {"jugador": {"name": String(engine.carrier.get("name", "")), "role": String(engine.carrier.get("role", ""))},
            "colores": _colores_l}
    return contexto_carta.call(c) if contexto_carta.is_valid() else {}


# La línea de la lámina: [texto, flecha] con flecha 1 = ▲ (le ganas el duelo), -1 = ▼, 0 = sin flecha.
# En el ataque: a quién va o contra quién es el duelo (a FERNÁNDEZ ▼, a SALAS ▲, LIBRE) o sus efectos
# (ROBA 1); en la defensa, las palabras clave de siempre.
func linea_de(c: Card, receptor: String) -> Array:
    if modo == Modo.DEFENSA and engine.duel_defense_on() and c.kind != Card.Kind.CLEARANCE:
        # D-44: sobre quién va y si tu defensor le gana el duelo (▲▼); si no sirve contra esta jugada, por qué.
        var t := engine.defense_target(c)
        if t != "":
            return ["sobre " + apellido(String(rival_engine._player_by_id(t).get("name", ""))), _duelo(c, "")]
        match c.kind:
            Card.Kind.BLOCK:
                return ["SOLO A UN REMATE", 0]
            Card.Kind.INTERCEPT:
                return ["SOLO A UN PASE", 0]
        return ["A SU JUGADA", 0]
    if modo != Modo.ATAQUE:
        return [CardUI.keywords(c, contexto_carta.call(c) if contexto_carta.is_valid() else {}), 0]
    if c.type == Card.Type.PENALTY:
        return ["OCUPA LA MANO", 0]
    var duelo := _duelo(c, receptor)
    if MatchEngine.is_pass(c) and receptor != "":
        var nombre := apellido(String(engine._player_by_id(receptor).get("name", "")))
        return ["a %s · LIBRE" % nombre, 0] if engine.markers_of(engine.pass_zone(c, receptor), receptor).is_empty() \
                else ["a " + nombre, duelo]
    var fx := CardUI.effect_text(c)
    if c.back:
        fx = "ATRÁS" if fx == "" else "ATRÁS · " + fx
    if fx != "" or MatchEngine.is_pass(c):
        return [fx, 0]
    if c.kind == Card.Kind.PAUSE:
        return ["RECUPERA ESTAMINA", 0]
    if c.kind == Card.Kind.SHOT:
        var arquero := MatchEngine.keeper_of(engine.rival_players)
        return ["a " + apellido(String(arquero.get("name", ""))), duelo] if not arquero.is_empty() else ["REMATA", 0]
    var m := engine.carrier_markers()
    if m.is_empty():
        return ["LIBRE", 0]
    return ["a " + apellido(String(MatchEngine._best_by(m, "quite").get("name", ""))), duelo]


func _duelo(c: Card, receptor: String) -> int:
    for item in engine.chance_breakdown(c, -1, receptor):
        if String(item["label"]).begins_with("Duelo"):
            return 1 if float(item["value"]) >= 0.0 else -1
    return 0


func _dibujar_triangulo(fl: Control) -> void:
    var arriba: bool = fl.get_meta("arriba", true)
    var col := Color("#1c6b3e") if arriba else Color("#b3261e")
    var pts := PackedVector2Array([Vector2(1, 12), Vector2(13, 12), Vector2(7, 2)]) if arriba \
            else PackedVector2Array([Vector2(1, 2), Vector2(13, 2), Vector2(7, 12)])
    fl.draw_colored_polygon(pts, col)


func _ordenar_mano() -> void:
    var n := _laminas.size()
    var paso := minf(174.0, (ANCHO_MANO - CardUI.TAMANO.x) / maxf(n - 1.0, 1.0))
    var x := CENTRO_MANO - (paso * (n - 1.0) + CardUI.TAMANO.x) * 0.5
    for i in n:
        var ui := _laminas[i]
        var baja := absf(i - (n - 1) * 0.5) * 4.0
        var alza := 26.0 if ui == _arrastre or ui == _presionado else 0.0
        ui.position = Vector2(x, Y_LAMINAS + baja - alza)
        # T-16: abanico. La que se arrastra, se aprieta o está bajo el cursor pasa al frente y se ve entera;
        # las demás arman el tipo, la moneda, el nombre y la placa del % en la franja que deja ver la siguiente.
        var frente := ui == _arrastre or ui == _presionado or ui == _encima
        ui.z_index = 2 if ui == _arrastre else (1 if frente else 0)
        ui.ancho_visible = 0.0 if frente or i == n - 1 or paso >= CardUI.TAMANO.x else paso
        _colocar_extras(ui)
        x += paso


# El triángulo ▲▼ después de la línea y la gráfica ELIGE, según el armado que le quedó a la lámina.
func _colocar_extras(ui: CardUI) -> void:
    if not _elige.has(ui):
        return
    var fl: Control = _flechas_linea[ui]
    fl.visible = int(fl.get_meta("flecha", 0)) != 0 and ui.effect_label.visible
    if fl.visible:
        var f := ui.effect_label.get_theme_font("font")
        var tam := ui.effect_label.get_theme_font_size("font_size")
        var w := f.get_string_size(ui.effect_label.text, HORIZONTAL_ALIGNMENT_LEFT, -1, tam).x
        var r := Rect2(ui.effect_label.position, ui.effect_label.size)
        fl.position = Vector2(minf(r.position.x + w + 5.0, ui.limite_x() - 16.0), r.position.y + minf(r.size.y, tam * 1.2) * 0.5 - 7.0)
        fl.queue_redraw()
    var elige: Control = _elige[ui]
    elige.position = Vector2(ui.limite_x() + (4.0 if ui.ancho_visible <= 0.0 else -2.0) - elige.size.x, ui._r_window.end.y - elige.size.y + 2.0)


func _al_entrar_lamina(ui: CardUI) -> void:
    _encima = ui
    _ordenar_mano()


func _al_salir_lamina(ui: CardUI) -> void:
    if _encima == ui:
        _encima = null
        _ordenar_mano()


# ------------------------------------------------------------------ Mouse: tomar, apuntar, soltar

func _al_tomar_lamina(ui: CardUI) -> void:
    if ocupado or not (modo == Modo.ATAQUE or modo == Modo.DEFENSA):
        return
    if _pegado:
        return   # el clic lo resuelve _input
    _presionado = ui   # _input ya guardó en _mouse dónde se apretó
    _pres_pos = _mouse
    _pres_t = _reloj
    _movido = false
    if not engine.can_play(ui.card):
        ui.shake()   # igual se puede mantener para ver la cuenta
        return
    if modo == Modo.ATAQUE:
        _arrastre = ui
        _apuntado = ""
        _forma_linea = Trayectoria.para_carta(ui.card)
        ui.flash(Paleta.DORADO)
        _actualizar_apuntado()
    elif engine.duel_defense_on() and ui.card.kind != Card.Kind.CLEARANCE:
        _arrastre = ui   # D-44: se arrastra sobre el rival; tu defensor se ve con su anillo
        _apuntado = ""
        ui.flash(Paleta.DORADO)
        _actualizar_apuntado()
        _actualizar_anillos()
    _refrescar_laminas()


func _input(event: InputEvent) -> void:
    if engine == null:
        return
    if event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_ESCAPE and _arrastre != null:
        _soltar(false)
        return
    if event is InputEventMouseMotion:
        _mouse = event.position
        if _presionado != null and _mouse.distance_to(_pres_pos) > ARRASTRE_MIN:
            _movido = true
        if _arrastre != null:
            _actualizar_apuntado()
        return
    if not (event is InputEventMouseButton):
        return
    _mouse = event.position
    if event.button_index == MOUSE_BUTTON_RIGHT and event.pressed:
        _soltar(false)
        return
    if event.button_index != MOUSE_BUTTON_LEFT:
        return
    if event.pressed:
        if _pegado:
            _actualizar_apuntado()
            var ui := _arrastre
            var r := _apuntado
            _soltar(false)
            if r != "" and ui != null:
                _jugar(ui, r)
            get_viewport().set_input_as_handled()
        elif _arrastre == null and _presionado == null and modo == Modo.ATAQUE and not ocupado and engine.corner_pending:
            var receptor := _companero_bajo_mouse(engine.corner_receivers())   # D-48: el centro del córner
            if receptor != "":
                corner_elegido.emit(receptor)
                get_viewport().set_input_as_handled()
        elif _arrastre == null and _presionado == null and modo == Modo.ATAQUE and not ocupado and engine.moment_plays == 0:
            var otro := _companero_bajo_mouse(engine.zone_players(engine.zone))
            if otro != "" and otro != String(engine.carrier.get("id", "")):
                portador_elegido.emit(otro)
                get_viewport().set_input_as_handled()
        return
    # Soltó el botón.
    var ui := _presionado
    if ui == null:
        return
    var vio_cuenta := _cuenta.visible
    _cuenta.visible = false
    _cuenta_de = null
    if vio_cuenta or ocupado:
        _soltar(false)
        return
    if modo == Modo.DEFENSA:
        _presionado = null
        if _arrastre != null:   # D-44: soltarla sobre el rival (un clic: sobre el único que sirve)
            _actualizar_apuntado()
            var objetivo := _apuntado
            if objetivo == "" and not _movido:
                objetivo = engine.defense_target(ui.card)
            _soltar(false)
            if objetivo != "":
                _jugar(ui, objetivo)
            return
        if not _movido or _mouse.y < _alto_senal:
            _jugar(ui, "")
        _refrescar_laminas()
        return
    if _arrastre == null:
        _presionado = null
        _refrescar_laminas()
        return
    _actualizar_apuntado()
    if MatchEngine.is_pass(ui.card):
        if _apuntado != "":
            var r := _apuntado
            _soltar(false)
            _jugar(ui, r)
        elif not _movido:
            _pegado = true   # un clic: sigue apuntando con el mouse hasta el próximo clic
            _presionado = null
        else:
            _soltar(false)
    else:
        var en_cancha := _mouse.y < _alto_senal
        _soltar(false)
        if en_cancha or not _movido:
            _jugar(ui, "")


func _jugar(ui: CardUI, receptor: String) -> void:
    if ocupado or not is_instance_valid(ui):
        return
    if not engine.can_play(ui.card, receptor) or (modo == Modo.ATAQUE and MatchEngine.is_pass(ui.card) and receptor == ""):
        ui.shake()
        return
    jugar_carta.emit(ui.hand_index, receptor)


func _soltar(_aceptar: bool) -> void:
    var ui := _arrastre
    _arrastre = null
    _presionado = null
    _pegado = false
    _apuntado = ""
    _linea_3d = PackedVector3Array()
    _cuenta.visible = false
    if ui != null and is_instance_valid(ui):
        ui.flash(Color(0, 0, 0, 0))
    if (modo == Modo.ATAQUE or modo == Modo.DEFENSA) and engine != null:
        _actualizar_etiquetas()
        _actualizar_anillos()
    if is_inside_tree():
        _refrescar_laminas()


# Compañero bajo el mouse (su cuerpo o su etiqueta), de `lista`; "" si no hay.
func _companero_bajo_mouse(lista: Array, lado: String = "L:") -> String:
    var mejor := ""
    var mejor_d := INF
    for pl: Dictionary in lista:
        var clave := lado + String(pl["id"])
        var j := _jug(clave)
        if j == null:
            continue
        var r := _rect_cuerpo(j).grow(12.0)
        var sobre: bool = _rect_etiqueta.has(clave) and Rect2(_rect_etiqueta[clave]).has_point(_mouse)
        if r.has_point(_mouse) or sobre:
            var d := r.get_center().distance_to(_mouse)
            if d < mejor_d:
                mejor_d = d
                mejor = String(pl["id"])
    return mejor


func _actualizar_apuntado() -> void:
    if _arrastre == null:
        return
    var nuevo := ""
    var defensa := modo == Modo.DEFENSA
    if defensa:
        nuevo = _rival_apuntado(_arrastre.card)
    elif MatchEngine.is_pass(_arrastre.card):
        nuevo = _companero_bajo_mouse(engine.receivers(_arrastre.card))
    if nuevo != _apuntado:
        _apuntado = nuevo
        _refrescar_laminas()
        _actualizar_etiquetas()
        _actualizar_anillos()
    if not defensa and MatchEngine.is_pass(_arrastre.card):
        _linea_3d = Trayectoria.puntos(_forma_linea, cancha.pelota.position, _fin_linea())
    else:
        _linea_3d = PackedVector3Array()


func _llegada(clave: String) -> Vector3:
    var pies: Vector3 = _jug(clave).position
    var viene := Vector3(cancha.pelota.position.x - pies.x, 0.0, cancha.pelota.position.z - pies.z).normalized()
    return pies + viene * 0.6 + Vector3(0, Cancha.RADIO_PELOTA, 0)


func _fin_linea() -> Vector3:
    if _apuntado != "":
        return _llegada("L:" + _apuntado)
    var m := Vector2(clampf(_mouse.x, 2.0, _ancho - 2.0), clampf(_mouse.y, 44.0, _alto_senal - 2.0)) * _k
    var o: Vector3 = cancha.camara.project_ray_origin(m)
    var d: Vector3 = cancha.camara.project_ray_normal(m)
    var p := o + d * ((Cancha.RADIO_PELOTA - o.y) / d.y)
    return Vector3(clampf(p.x, CanchaZonas.X_MIN, CanchaZonas.X_MAX), Cancha.RADIO_PELOTA, clampf(p.z, CanchaZonas.FONDO_Z, CanchaZonas.FRENTE_Z))


func _tono_apuntado() -> String:
    if _apuntado == "" or _arrastre == null:
        return "gris"
    return Cancha.tono(engine.success_chance(_arrastre.card, -1, _apuntado))


func apuntado() -> String:
    return _apuntado


func arrastrando() -> bool:
    return _arrastre != null


# Centro en pantalla de un jugador (para el mouse simulado de smoke_match): a media altura del cuerpo.
func punto_de(clave: String) -> Vector2:
    var j := _jug(clave)
    return _rect_cuerpo(j).get_center() if j != null else Vector2.ZERO


func _dibujar_flecha() -> void:
    if modo == Modo.DEFENSA and not intencion.is_empty():
        _dibujar_linea_rival()
    if _arrastre == null or _linea_3d.size() < 4:
        return
    var pts := PackedVector2Array()
    var suelo := PackedVector2Array()
    for p in _linea_3d:
        pts.append(_a_pantalla(p))
        suelo.append(_a_pantalla(Vector3(p.x, 0.03, p.z)))
    _linea(pts, suelo, _forma_linea, Cancha.color_tono(_tono_apuntado()))


# La línea del pase de T-12: la trayectoria real proyectada, tramos que crecen hacia la punta y contorno oscuro.
func _linea(pts: PackedVector2Array, suelo: PackedVector2Array, carta: String, color: Color) -> void:
    var f := Trayectoria.forma(carta)
    var largos := PackedFloat32Array()
    for i in pts.size():
        largos.append(0.0 if i == 0 else largos[i - 1] + pts[i].distance_to(pts[i - 1]))
    var total := largos[-1]
    if total < 6.0:
        return
    if f["sombra"]:
        _flecha.draw_polyline(suelo, Color(0, 0, 0, 0.4), 8.0, true)
    var tramo: float = f["tramo"]
    var hueco: float = f["hueco"]
    var largo_punta := minf(36.0, total * 0.5)
    var limite := total - (largo_punta - 6.0)
    var s := fmod(_reloj * float(f["velocidad"]) * 5.0, tramo + hueco) - tramo
    while s < limite:
        var a := maxf(s, 16.0)
        var b := minf(s + tramo, limite)
        if b - a > 2.0:
            var parte := _sub_curva(pts, largos, a, b)
            var ancho := lerpf(7.0, 13.0, (a + b) * 0.5 / total)
            _flecha.draw_polyline(parte, CONTORNO_FLECHA, ancho + 5.0, true)
            _flecha.draw_polyline(parte, color, ancho, true)
        s += tramo + hueco
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


# ------------------------------------------------------------------ Cuenta completa (mantener la carta)

# Líneas de la cuenta de una carta: el desglose del motor (lo mismo que se tira), su desgaste y lo que pasa
# si falla. smoke_match la compara con el motor.
func cuenta_de(c: Card, receptor: String) -> Array:
    var out: Array = []
    if c.type == Card.Type.PENALTY:
        return [["Penalización: ocupa la mano", ""]]
    if modo == Modo.ATAQUE and MatchEngine.is_pass(c) and receptor == "":
        receptor = engine.best_receiver(c)
        if receptor != "":
            out.append(["Al mejor receptor: " + apellido(String(engine._player_by_id(receptor).get("name", ""))), ""])
    for item in engine.chance_breakdown(c, -1, receptor):
        out.append([String(item["label"]).replace("Postura LOW", "Postura: BAJO"), "%+d" % roundi(float(item["value"]) * 100.0)])
    out.append(["Acierto", "%d%%" % roundi(engine.success_chance(c, -1, receptor) * 100.0)])
    var robo := engine.steal_chance(c, -1, receptor)
    if robo > 0.0:
        out.append(["Robo si falla", "%d%%" % roundi(robo * 100.0)])
    var atajada := engine.save_chance(c, -1, receptor)
    if atajada > 0.0:
        out.append(["Atajada si falla", "%d%%" % roundi(atajada * 100.0)])
    if modo == Modo.ATAQUE and engine.duel_on() and engine.duel_outcomes:   # D-48: qué pasa si falla
        var lb := engine.loose_ball(c, receptor)
        for o: Array in engine.fail_outcomes(c):
            var nombre := String(MatchEngine.OUTCOME_TEXT.get(o[0], o[0])).replace("¡", "").replace("!", "").to_lower()
            if (o[0] == "dividida" or o[0] == "rebote") and not lb.is_empty():
                nombre += " (la ganas %d%%)" % roundi(float(lb["chance"]) * 100.0)
            out.append(["Si falla: " + nombre, "%d%%" % roundi(float(o[1]) * 100.0)])
    out.append(["Cuesta %d PA · desgaste" % engine.ap_cost_of(c), "%d" % roundi(engine.stamina_cost_of(c))])
    return out


func cuenta_visible() -> bool:
    return _cuenta.visible


func _mostrar_cuenta(ui: CardUI) -> void:
    _cuenta_de = ui
    var lineas := cuenta_de(ui.card, _apuntado if ui == _arrastre else "")
    var f := Paleta.letra("tv")
    var ancho := 260.0
    for l: Array in lineas:
        ancho = maxf(ancho, f.get_string_size(String(l[0]), HORIZONTAL_ALIGNMENT_LEFT, -1, 16).x + 90.0)
    _cuenta.size = Vector2(ancho, 30.0 + lineas.size() * 22.0)
    _cuenta.set_meta("lineas", lineas)
    _cuenta.set_meta("titulo", ui.card.display_name.to_upper())
    var p := ui.get_global_rect()
    _cuenta.position = Vector2(clampf(p.get_center().x - ancho * 0.5, 8.0, _ancho - ancho - 8.0),
            p.position.y - _cuenta.size.y - 10.0)
    _cuenta.visible = true
    _cuenta.queue_redraw()


func _dibujar_cuenta() -> void:
    var s := _cuenta.size
    var dx := 6.0
    _cuenta.draw_colored_polygon(PackedVector2Array([Vector2(dx, 4), Vector2(s.x + 4, 4), Vector2(s.x - dx + 4, s.y + 4), Vector2(4, s.y + 4)]), Color(0, 0, 0, 0.5))
    _cuenta.draw_colored_polygon(PackedVector2Array([Vector2(dx, 0), Vector2(s.x, 0), Vector2(s.x - dx, s.y), Vector2(0, s.y)]), Color(0.043, 0.067, 0.106, 0.95))
    _cuenta.draw_rect(Rect2(dx, 0, s.x - dx, 3), Paleta.DORADO)
    var f := Paleta.letra("tv")
    _cuenta.draw_string(f, Vector2(14, 22), String(_cuenta.get_meta("titulo", "")), HORIZONTAL_ALIGNMENT_LEFT, -1, 16, Paleta.DORADO)
    var y := 44.0
    for l: Array in _cuenta.get_meta("lineas", []):
        var valor := String(l[1])
        var col := Color.WHITE
        if valor.begins_with("+") and valor != "+0":
            col = VERDE
        elif valor.begins_with("-"):
            col = CORAL
        _cuenta.draw_string(f, Vector2(14, y), String(l[0]), HORIZONTAL_ALIGNMENT_LEFT, s.x - 90.0, 16, Color("#dfe6f2"))
        _cuenta.draw_string(f, Vector2(s.x - 70, y), valor, HORIZONTAL_ALIGNMENT_RIGHT, 56, 16, col)
        y += 22.0


# ------------------------------------------------------------------ La tirada (I-58)

# Muestra la aguja contra el % y espera a que se detenga. roll del motor (0-1): éxito si roll < chance.
func mostrar_tirada(titulo: String, chance: float, roll: float, ok: bool, color_titulo: Color = Paleta.DORADO) -> void:
    var pct := roundi(chance * 100.0)
    var sacaste := floori(roll * 100.0)
    _tirada_datos = {"titulo": titulo, "pct": pct, "sacaste": sacaste, "ok": ok, "color": color_titulo}
    ultima_tirada = _tirada_datos.duplicate()
    _tirada_t = 0.0
    _tirada_aguja = 0.0
    _tirada.visible = true
    _tirada.modulate.a = 1.0
    _tirada.queue_redraw()
    await _esperar(0.75)
    _tirada_t = 1.0
    _tirada.queue_redraw()


func texto_tirada() -> String:
    if _tirada_datos.is_empty():
        return ""
    return "SACASTE %d · NECESITABAS MENOS DE %d" % [_tirada_datos["sacaste"], _tirada_datos["pct"]]


func ocultar_tirada() -> void:
    if not _tirada.visible:
        return
    if _saltar:
        _tirada.visible = false
        return
    var t := create_tween()
    t.tween_property(_tirada, "modulate:a", 0.0, 0.2)
    await t.finished
    _tirada.visible = false


func _dibujar_tirada() -> void:
    if _tirada_datos.is_empty():
        return
    var s := _tirada.size
    var dx := s.y * Grafica.SKEW
    _tirada.draw_colored_polygon(PackedVector2Array([Vector2(dx, 4), Vector2(s.x + 4, 4), Vector2(s.x - dx + 4, s.y + 4), Vector2(4, s.y + 4)]), Color(0, 0, 0, 0.55))
    _tirada.draw_colored_polygon(PackedVector2Array([Vector2(dx, 0), Vector2(s.x, 0), Vector2(s.x - dx, s.y), Vector2(0, s.y)]), Color(0.043, 0.067, 0.106, 0.94))
    var f := Paleta.letra("tv")
    var pct: int = _tirada_datos["pct"]
    _tirada.draw_rect(Rect2(dx, 0, s.x - dx, 4), Paleta.DORADO)
    _tirada.draw_string(f, Vector2(dx + 12, 27), String(_tirada_datos["titulo"]), HORIZONTAL_ALIGNMENT_LEFT, s.x - 200, 20, _tirada_datos["color"])
    _tirada.draw_string(f, Vector2(s.x - 190, 28), "NECESITAS < %d" % pct, HORIZONTAL_ALIGNMENT_RIGHT, 170, 22, Paleta.placa(pct / 100.0)[0][0])
    # Barra gruesa: verde lo que sale, coral lo que falla; la aguja con su número encima.
    var barra := Rect2(dx + 8, 37, s.x - dx * 2 - 16, 32)
    var corte := barra.size.x * pct / 100.0
    _tirada.draw_rect(barra.grow(3), CONTORNO_FLECHA)
    _tirada.draw_rect(Rect2(barra.position, Vector2(corte, barra.size.y)), Color(VERDE, 0.92))
    _tirada.draw_rect(Rect2(barra.position + Vector2(corte, 0), Vector2(barra.size.x - corte, barra.size.y)), Color(CORAL, 0.85))
    _tirada.draw_rect(Rect2(barra.position + Vector2(corte - 2, -4), Vector2(4, barra.size.y + 8)), Color.WHITE)
    for marca in [0, 25, 50, 75, 99]:
        var mx: float = barra.position.x + barra.size.x * marca / 100.0
        _tirada.draw_rect(Rect2(mx - 1, barra.end.y - 8, 2, 8), Color(0, 0, 0, 0.35))
    var x := barra.position.x + barra.size.x * _tirada_aguja / 100.0
    var aguja := PackedVector2Array([Vector2(x, barra.position.y - 8), Vector2(x, barra.end.y + 8)])
    _tirada.draw_polyline(aguja, CONTORNO_FLECHA, 9.0)
    _tirada.draw_polyline(aguja, Color.WHITE, 5.0)
    var n := "%d" % roundi(_tirada_aguja)
    var nw := f.get_string_size(n, HORIZONTAL_ALIGNMENT_LEFT, -1, 26).x
    var nx := clampf(x - nw * 0.5, barra.position.x + 4, barra.end.x - nw - 4)
    _tirada.draw_string(f, Vector2(nx + 2, barra.end.y - 5), n, HORIZONTAL_ALIGNMENT_LEFT, -1, 26, CONTORNO_FLECHA)
    _tirada.draw_string(f, Vector2(nx, barra.end.y - 7), n, HORIZONTAL_ALIGNMENT_LEFT, -1, 26, Color.WHITE)
    if _tirada_t >= 1.0:
        var ok: bool = _tirada_datos["ok"]
        var sac := "SACASTE %d" % int(_tirada_datos["sacaste"])
        _tirada.draw_string(f, Vector2(dx + 10, s.y - 12), sac, HORIZONTAL_ALIGNMENT_LEFT, -1, 30, Color.WHITE)
        var w := f.get_string_size(sac, HORIZONTAL_ALIGNMENT_LEFT, -1, 30).x
        _tirada.draw_string(f, Vector2(dx + 22 + w, s.y - 14), "· NECESITABAS MENOS DE %d" % pct, HORIZONTAL_ALIGNMENT_LEFT, -1, 18, Color("#dfe6f2"))
        _tirada.draw_string(f, Vector2(s.x - 170, s.y - 10), "SALE" if ok else "FALLA", HORIZONTAL_ALIGNMENT_RIGHT, 150, 36, VERDE if ok else CORAL)


func _animar_aguja(delta: float) -> void:
    if _tirada_t < 0.0 or _tirada_t >= 1.0 or not _tirada.visible:
        return
    _tirada_t = minf(0.999, _tirada_t + delta * _velocidad / 0.75)
    var meta := float(_tirada_datos["sacaste"])
    # Recorre la barra una vez y frena en lo que salió.
    var t := _tirada_t
    _tirada_aguja = lerpf(0.0, 99.0, t / 0.55) if t < 0.55 else lerpf(99.0, meta, 1.0 - pow(1.0 - (t - 0.55) / 0.45, 3.0))
    _tirada.queue_redraw()


# ------------------------------------------------------------------ Animar jugadas

func _esperar(s: float) -> void:
    if _saltar or s <= 0.0:
        return
    await get_tree().create_timer(s / _velocidad).timeout


func _esperar_vuelo() -> void:
    while cancha.en_vuelo() and not _saltar:
        await get_tree().process_frame
    if _saltar and cancha.en_vuelo():
        cancha.pelota_en(cancha._vuelo_hasta)


# Lo que hay que saber antes de jugar para animar la jugada después: portador, zona y marcas.
func instantanea(e: MatchEngine) -> Dictionary:
    return {"portador": String(e.carrier.get("id", "")), "zona": e.zone, "marcas": e.marks.duplicate()}


# Anima tu jugada (ev de MatchEngine.play_card o hold_ball): la tirada, la pelota y el resultado, y deja
# la cancha con el estado nuevo del motor. En la defensa solo se ve la tirada.
func animar_jugada(ev: Dictionary, card: Card, antes: Dictionary) -> void:
    if not ev.get("ok", false):
        return
    var titulo := "AGUANTAR" if ev.get("hold", false) else ("CÓRNER" if card == null else card.display_name.to_upper())
    if ev.get("defense", false):
        var d := String(ev.get("defender", ""))   # D-44: quién la jugó y sobre quién
        if d != "":
            titulo += " · %s sobre %s" % [apellido(String(engine._player_by_id(d).get("name", ""))),
                    apellido(String(rival_engine._player_by_id(String(ev.get("target", ""))).get("name", "")))]
        await mostrar_tirada(titulo, ev["chance"], ev["roll"], ev["success"])
        await _esperar(0.5)
        await ocultar_tirada()
        return
    var receptor := String(ev.get("receiver", ""))
    if receptor != "":
        titulo += " · a " + apellido(String(engine._player_by_id(receptor).get("name", "")))
    await mostrar_tirada(titulo, ev["chance"], ev["roll"], ev["success"])
    if not ev.get("hold", false):
        await _jugada_balon(ev, card, true, String(ev.get("carrier", antes["portador"])), receptor, antes["marcas"], int(antes["zona"]))
    await _esperar(0.25)
    if not engine.moment_over:
        _sincronizar_ataque(0.55)
    await ocultar_tirada()


# D-48: la pelota según el desenlace. Los robos y la atajada van como siempre (_animar_balon); el resto
# tiene su propia animación (lateral, afuera, córner, falta, dividida con su tirada); el córner, la suya.
# Después, el desenlace se anuncia como gráfica de TV.
func _jugada_balon(ev: Dictionary, card: Card, local: bool, portador: String, receptor: String, marcas: Dictionary, zona: int) -> void:
    if ev.get("corner", false):
        await _animar_corner(ev, local)
        return
    var o := String(ev.get("outcome", ""))
    if o == "" or o == "cortada" or o == "pierde" or o == "atajada":
        if card != null:
            await _animar_balon(ev, card, local, portador, receptor, marcas, zona)
    else:
        await _animar_desenlace(ev, card, local, portador, zona)
    if o != "":
        await _anunciar(String(MatchEngine.OUTCOME_TEXT.get(o, o.to_upper())))


var _desenlace_g: Control
var ultimo_desenlace := ""      # lo último anunciado (smoke_match y las capturas lo leen)


func _anunciar(texto: String) -> void:
    ultimo_desenlace = texto
    if _desenlace_g == null:
        _desenlace_g = Grafica.new()
        _desenlace_g.mouse_filter = Control.MOUSE_FILTER_IGNORE
        add_child(_desenlace_g)
    _desenlace_g.configurar(texto, 40, Paleta.DORADO, Grafica.SEMI_NOCHE)
    _desenlace_g.position = Vector2((_ancho - _desenlace_g.size.x) * 0.5, _alto_senal * 0.32)
    _desenlace_g.visible = true
    await _esperar(0.8)
    _desenlace_g.visible = false


func _animar_desenlace(ev: Dictionary, card: Card, local: bool, portador: String, zona: int) -> void:
    var at := "L:" if local else "V:"
    var de := "V:" if local else "L:"
    var dir := 1.0 if local else -1.0
    var yo := _jug(at + portador)
    if yo == null:
        return
    var o := String(ev["outcome"])
    var forma := Trayectoria.para_carta(card) if card != null else "pase_corto"
    if card != null and (MatchEngine.is_pass(card) or card.kind == Card.Kind.SHOT):
        var patada: float = Trayectoria.forma(forma)["patada"]
        yo.patear(patada)
        await _esperar(Jugador.CONTACTO_PATADA / patada)
    var arco := cancha.arco_x(not local)
    match o:
        "lateral":
            cancha.volar("pase_corto", Vector3(yo.position.x + dir * 4.0, Cancha.RADIO_PELOTA, CanchaZonas.FONDO_Z - 0.6))
            await _esperar_vuelo()
        "afuera":
            cancha.volar(forma, Vector3(arco + dir * 1.5, 0.6, 4.6))
            await _esperar_vuelo()
        "corner":
            cancha.volar(forma, Vector3(arco - dir * 0.6, 0.9, 2.6))
            await _esperar_vuelo()
            cancha.volar("pase_corto", Vector3(arco - dir * 0.4, Cancha.RADIO_PELOTA, CanchaZonas.FONDO_Z + 0.8))
            await _esperar_vuelo()
        "falta":
            await _esperar(0.5)
        "dividida", "rebote":
            var d: Dictionary = ev.get("dividida", {})
            var ja := _jug(at + String(d.get("attacker", portador)))
            var jd := _jug(de + String(d.get("defender", "")))
            if ja == null:
                ja = yo
            var mid := ja.position + Vector3(dir * 2.0, 0, 0)
            if o == "rebote":
                mid = Vector3(arco - dir * 6.0, 0, 1.0)
            elif jd != null:
                mid = (ja.position + jd.position) * 0.5
            cancha.volar("pase_corto", mid + Vector3(0, Cancha.RADIO_PELOTA, 0))
            ja.ir_a(mid - Vector3(dir * 0.6, 0, 0.3), 0.4 / _velocidad)
            if jd != null:
                jd.ir_a(mid + Vector3(dir * 0.6, 0, 0.3), 0.4 / _velocidad)
            await _esperar_vuelo()
            var nombre_a := apellido(String((engine if local else rival_engine)._player_by_id(String(d.get("attacker", ""))).get("name", "")))
            var nombre_d := apellido(String((rival_engine if local else engine)._player_by_id(String(d.get("defender", ""))).get("name", "")))
            var titulo := "%s · %s contra %s" % ["REBOTE" if o == "rebote" else "DIVIDIDA", nombre_a, nombre_d]
            await mostrar_tirada(titulo, float(d.get("chance", 0.5)), float(d.get("roll", 0.0)), bool(d.get("won", false)),
                    Paleta.DORADO if local else _colores_v[0].lightened(0.3))
            var gana := ja if d.get("won", false) or jd == null else jd
            cancha.volar("conduccion", gana.junto_al_pie(Vector3(arco, 0, gana.position.z), Cancha.RADIO_PELOTA))
            await _esperar_vuelo()


# D-48: el córner. El lanzador va a la esquina y centra; si llega, la pelota cae en el receptor; si no, la
# despeja el que lo marcaba (o el arquero).
func _animar_corner(ev: Dictionary, local: bool) -> void:
    var at := "L:" if local else "V:"
    var de := "V:" if local else "L:"
    var dir := 1.0 if local else -1.0
    var e := engine if local else rival_engine
    var arco := cancha.arco_x(not local)
    var esquina := Vector3(arco - dir * 0.4, Cancha.RADIO_PELOTA, CanchaZonas.FONDO_Z + 0.8)
    var lanza := _jug(at + String(ev.get("carrier", "")))
    if lanza != null:
        lanza.colocar(esquina + Vector3(-dir * 0.8, 0, -0.6), Vector3(arco - dir * 6.0, 0, 0))
    cancha.pelota_en(esquina)
    await _esperar(0.3)
    var r := String(ev.get("receiver", ""))
    var destino := _jug(at + r)
    if not ev.get("success", false):
        var m: Array = e.markers_of(MatchEngine.Zone.AREA, r)
        var k := MatchEngine.keeper_of(e.rival_players)
        var corta := String(MatchEngine._best_by(m, "lectura")["id"]) if not m.is_empty() else String(k.get("id", ""))
        destino = _jug(de + corta) if corta != "" else destino
    if lanza != null:
        lanza.patear(Trayectoria.forma("centro")["patada"])
        await _esperar(Jugador.CONTACTO_PATADA / float(Trayectoria.forma("centro")["patada"]))
    if destino != null:
        cancha.volar("centro", destino.position + Vector3(0, 1.4, 0))
        await _esperar_vuelo()


# D-44: el rival defiende tu jugada antes de que la tires (Presión, Intercepción, Bloqueo o Despeje):
# su tirada, con quién la juega y sobre quién.
func animar_defensa_rival(ev: Dictionary) -> void:
    if not ev.get("ok", false):
        return
    var titulo := "%s · %s" % [_sigla(_equipo_v), String(ev.get("card_name", "")).to_upper()]
    var d := String(ev.get("defender", ""))
    if d != "":
        titulo += " · %s sobre %s" % [apellido(String(rival_engine._player_by_id(d).get("name", ""))),
                apellido(String(engine._player_by_id(String(ev.get("target", ""))).get("name", "")))]
    await mostrar_tirada(titulo, ev["chance"], ev["roll"], ev["success"], _colores_v[0].lightened(0.3))
    await _esperar(0.5)
    await ocultar_tirada()


# La pelota según el tipo de carta y el resultado: pase al receptor o al que lo corta; regate hacia
# adelante o al que roba; remate al arco, a las manos del arquero o al rebote.
func _animar_balon(ev: Dictionary, card: Card, local: bool, portador: String, receptor: String, marcas: Dictionary, zona: int) -> void:
    var at := "L:" if local else "V:"
    var de := "V:" if local else "L:"
    var dir := 1.0 if local else -1.0
    var forma := Trayectoria.para_carta(card)
    var yo := _jug(at + portador)
    if yo == null:
        return
    var ok: bool = ev["success"]
    var robado: bool = ev.get("stolen", false)
    if card.kind == Card.Kind.PAUSE:
        await _esperar(0.3)
        return
    if MatchEngine.is_pass(card):
        var destino := ""
        if ok:
            destino = at + receptor
        else:
            var corta := String(ev.get("stealer", ""))
            if corta == "":
                var m: Array = []   # quien marca al receptor, en la zona que sea (D-46: puede ser la misma)
                for z in marcas:
                    if (marcas[z] as Dictionary).has(receptor):
                        m = marcas[z][receptor]
                if m.is_empty():
                    m = (marcas.get(zona, {}) as Dictionary).get(portador, [])
                if not m.is_empty():
                    corta = String(MatchEngine._best_by(m, "lectura")["id"])
            destino = de + corta if corta != "" else at + receptor
        if _jug(destino) == null:
            return
        yo.patear(Trayectoria.forma(forma)["patada"])
        await _esperar(Jugador.CONTACTO_PATADA / float(Trayectoria.forma(forma)["patada"]))
        cancha.volar(forma, _llegada(destino))
        await _esperar_vuelo()
        if not ok and not robado:
            await _esperar(0.15)
            cancha.volar("pase_corto", yo.junto_al_pie(Vector3(cancha.arco_x(not local), 0, yo.position.z), Cancha.RADIO_PELOTA))
            await _esperar_vuelo()
        return
    if card.kind == Card.Kind.SHOT:
        var arco := cancha.arco_x(not local)
        var lado := 1.0 if hash(ev.get("roll", 0.0)) % 2 == 0 else -1.0
        var meta := Vector3(arco, 0.9, lado * 2.1)
        var arquero := MatchEngine.keeper_of(rival_engine.duel_players if local else engine.duel_players)
        var guardian := _jug(de + String(arquero.get("id", "")))
        yo.patear(Trayectoria.forma(forma)["patada"])
        await _esperar(Jugador.CONTACTO_PATADA / float(Trayectoria.forma(forma)["patada"]))
        if ok:
            cancha.volar(forma, meta + Vector3(dir * 1.0, -0.4, 0))
            if guardian != null:
                guardian.ir_a(Vector3(arco - dir * 1.0, 0, -lado * 1.6), 0.35 / _velocidad)
            await _esperar_vuelo()
            return
        var atajo := Vector3(arco - dir * 0.9, 0.8, lado * 1.4)
        if guardian != null:
            guardian.ir_a(Vector3(atajo.x, 0, atajo.z), 0.3 / _velocidad)
        cancha.volar(forma, atajo)
        await _esperar_vuelo()
        if ev.get("rebound", false):
            cancha.volar("pase_corto", Vector3(arco - dir * 6.0, Cancha.RADIO_PELOTA, lado * 3.0))
            await _esperar_vuelo()
        return
    # Regate o control: el portador avanza con la pelota, o se la quitan.
    var marca: Array = (marcas.get(zona, {}) as Dictionary).get(portador, [])
    var rival := _jug(de + String(MatchEngine._best_by(marca, "quite")["id"])) if not marca.is_empty() else null
    if ok:
        var hacia := yo.position + Vector3(dir * 3.0, 0, 0)
        if int(ev.get("field_zone", zona)) != zona:
            hacia = Vector3(cancha.centro_zona(int(ev["field_zone"]), local) - dir * 1.0, 0, 0.6)
        var dura := clampf(yo.position.distance_to(hacia) / 7.0, 0.35, 1.4)
        yo.ir_a(hacia, dura / _velocidad)
        cancha.volar("conduccion", hacia + Vector3(dir * 0.6, Cancha.RADIO_PELOTA, 0))
        await _esperar(dura)
        return
    if rival != null:
        rival.ir_a(yo.position + Vector3(dir * 0.7, 0, 0.3), 0.3 / _velocidad)
        cancha.volar("conduccion", _llegada(de + String(MatchEngine._best_by(marca, "quite")["id"])))
        await _esperar_vuelo()
        if not robado:
            cancha.volar("conduccion", yo.junto_al_pie(Vector3(cancha.arco_x(not local), 0, yo.position.z), Cancha.RADIO_PELOTA))
            await _esperar_vuelo()
    else:
        await _esperar(0.4)


# ------------------------------------------------------------------ El ataque del rival (I-60)

func acelerar() -> void:
    if not _acelerado:
        _velocidad *= 3.0
    _acelerado = true
    cancha.velocidad = _velocidad
    refrescar()


func saltar() -> void:
    _saltar = true

# Anima el Momento del rival ya resuelto por CoachBot: pasos = [{zona, marcas, ev, card}] de match_view.
# Más rápido por defecto (playtest 2026-11-04): cada jugada pasa a RAPIDO_RIVAL y solo lo importante
# (importante()) va a velocidad normal, con una pausa para leerlo. ACELERAR lo triplica; SALTAR deja todo de golpe.
# D-44: con la defensa por duelos, match_view la llama con una jugada a la vez (nuevo = false después de la
# primera del Momento: sigue ACELERADO si lo pediste y la cámara no salta).
func mirar_ataque_rival(pasos: Array, nuevo: bool = true) -> void:
    modo = Modo.RIVAL
    intencion = {}
    _local_ataca = false
    if nuevo:
        _acelerado = false
    _saltar = false
    armar_mano()
    for i in pasos.size():
        var paso: Dictionary = pasos[i]
        var ev: Dictionary = paso["ev"]
        if ev.is_empty():
            continue
        var clave := importante(ev, paso.get("card"))
        _velocidad = (1.0 if clave else RAPIDO_RIVAL) * (3.0 if _acelerado else 1.0)
        cancha.velocidad = _velocidad
        _zona = int(paso["zona"])
        _portador = "V:" + String(ev.get("carrier", paso.get("portador", "")))
        _formar(_posiciones(rival_engine, false, _zona, _portador, paso["marcas"]), 0.5)
        _pelota_al_portador(i == 0 and nuevo)
        _rotular()
        _encuadrar()
        _poner_con_balon()
        _camino.queue_redraw()
        if i == 0 and nuevo and not _saltar:
            cancha.fijar_camara()
        await _esperar(0.4)
        var card: Card = paso.get("card")
        var titulo := _sigla(_equipo_v) + " · "
        if ev.get("corner", false):
            titulo += "CÓRNER · a " + apellido(String(rival_engine._player_by_id(String(ev.get("receiver", ""))).get("name", "")))
        elif ev.get("hold", false) or card == null:
            titulo += "AGUANTA"
        else:
            titulo += card.display_name.to_upper()
            var r := String(ev.get("receiver", ""))
            if r != "":
                titulo += " · a " + apellido(String(rival_engine._player_by_id(r).get("name", "")))
        var resta := 0.0   # D-44: lo que le restó tu Presión o tu Bloqueo
        for d: Dictionary in ev.get("defended", []):
            resta += float(d["value"])
        if resta != 0.0:
            titulo += " · %d" % roundi(resta * 100.0)
        await mostrar_tirada(titulo, ev["chance"], ev["roll"], ev["success"], _colores_v[0].lightened(0.3))
        if (card != null or ev.get("corner", false)) and not ev.get("hold", false):
            await _jugada_balon(ev, card, false, String(ev.get("carrier", "")), String(ev.get("receiver", "")), paso["marcas"], _zona)
        await _esperar(0.7 if clave else 0.15)   # lo importante se queda un momento en pantalla
        await ocultar_tirada()
    _velocidad = 1.0
    cancha.velocidad = 1.0
    _saltar = false
    _tirada.visible = false


# Lo que merece mirarse con calma en el ataque rival: un pase o un regate que cambia de zona, un remate,
# un robo y un gol. Los pases dentro de la zona y los fallos sin robo pasan rápido.
static func importante(ev: Dictionary, card: Card) -> bool:
    if ev.get("goal", false) or ev.get("stolen", false) or ev.get("saved", false) or ev.has("outcome") or ev.get("corner", false):
        return true
    if card != null and card.kind == Card.Kind.SHOT:
        return true
    return ev.get("success", false) and int(ev.get("field_zone", -1)) != int(ev.get("play_zone", -1))


# ------------------------------------------------------------------ Carteles de TV (T-16)

var _cartel: Control
var cartel_texto := ""          # lo que dice el cartel a la vista ("" si no hay): lo leen las capturas
var cartel_listo := false       # el cartel ya terminó de entrar


func _nuevo_cartel(texto: String) -> Control:
    _quitar_cartel()
    var raiz := Control.new()
    raiz.mouse_filter = Control.MOUSE_FILTER_IGNORE
    add_child(raiz)
    _cartel = raiz
    cartel_texto = texto
    cartel_listo = false
    return raiz


func _quitar_cartel() -> void:
    if _cartel != null and is_instance_valid(_cartel):
        _cartel.queue_free()
    _cartel = null
    cartel_texto = ""
    cartel_listo = false


func _fondo_color(c: Color) -> Array:
    return [c.lightened(0.28), c, c.darkened(0.28), c.darkened(0.12)]


# Gráfica con la letra achicada hasta que quepa en `ancho_max` (nunca bajo `minimo`).
func _grafica_que_quepa(padre: Control, texto: String, tam: int, minimo: int, ancho_max: float, color: Color, fondo: Array, margen: float) -> Control:
    var g := Grafica.new()
    padre.add_child(g)
    g.margen = margen
    g.configurar(texto, tam, color, fondo)
    while g.size.x > ancho_max and tam > minimo:
        tam -= 2
        g.configurar(texto, tam, color, fondo)
    return g


# Cartel de la transmisión (avisos del partido): gráfica de TV inclinada que entra desde la izquierda; lo
# que va después del primer "·" baja a una segunda placa oscura. Reemplaza la caja redondeada de antes.
func cartel(texto: String, color: Color, espera: float) -> void:
    var raiz := _nuevo_cartel(texto)
    var partes := texto.replace("★ ", "").split("·", false, 1)
    var claro := color.get_luminance() > 0.5
    var arriba := _grafica_que_quepa(raiz, String(partes[0]).strip_edges(), 46, 22, _ancho - 120.0,
            Color("#0b111b") if claro else Color.WHITE, _fondo_color(color), 18.0)
    var y := _alto_senal * 0.26
    var x_arriba := (_ancho - arriba.size.x) * 0.5
    arriba.position = Vector2(-arriba.size.x - 20.0, y)
    var t := create_tween().set_parallel(true)
    t.tween_property(arriba, "position:x", x_arriba, 0.2).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
    if partes.size() > 1:
        var abajo := _grafica_que_quepa(raiz, String(partes[1]).strip_edges(), 24, 16, _ancho - 160.0, Color.WHITE, Grafica.SEMI_NOCHE, 14.0)
        abajo.position = Vector2(_ancho + 20.0, y + arriba.size.y + 5.0)
        t.tween_property(abajo, "position:x", (_ancho - abajo.size.x) * 0.5 - arriba.size.y * Grafica.SKEW * 0.5, 0.2) \
                .set_delay(0.06).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
    await t.finished
    if _cartel != raiz:
        return
    cartel_listo = true
    await get_tree().create_timer(espera).timeout
    if _cartel != raiz or not is_instance_valid(raiz):
        return
    cartel_listo = false
    var s := create_tween()
    s.tween_property(raiz, "modulate:a", 0.0, 0.15)
    await s.finished
    if _cartel == raiz:
        _quitar_cartel()


# Cartel de gol: gráfica de TV grande (Barlow Condensed 800 cursiva, sombra dura, inclinada) con el
# goleador y el marcador nuevo debajo. Entra desde la izquierda con rebote, la fila del marcador desde la
# derecha, un fogonazo sobre la cancha y dos latidos; se va por el otro lado. Todo por código (D-41).
func cartel_gol(local: bool, goleador: String, goles_l: int, goles_v: int, detalle: String = "") -> void:
    var col: Array = _colores_l if local else _colores_v
    var texto := "¡GOOOOL!" if local else "¡GOL DE %s!" % String(_equipo_v.get("short_name", "")).to_upper()
    var raiz := _nuevo_cartel(texto)
    var destello := ColorRect.new()
    destello.mouse_filter = Control.MOUSE_FILTER_IGNORE
    destello.color = Color(1, 1, 1, 0.5)
    destello.size = Vector2(_ancho, _alto_senal)
    raiz.add_child(destello)
    var titulo := _grafica_que_quepa(raiz, texto, 104 if local else 76, 40, _ancho - 160.0,
            Color("#1a1408") if local else _texto_club(col), Paleta.PLACA_DORADA if local else _fondo_club(col), 30.0)
    var fila := Control.new()
    fila.mouse_filter = Control.MOUSE_FILTER_IGNORE
    raiz.add_child(fila)
    var partes: Array = []
    if goleador != "":
        partes.append([goleador if detalle == "" else "%s · %s" % [goleador, detalle], Color("#0b111b"), Grafica.PLATA])
    partes.append([_sigla(_equipo_l), _texto_club(_colores_l), _fondo_club(_colores_l)])
    partes.append(["%d - %d" % [goles_l, goles_v], Color.WHITE, Paleta.TV_AZUL])
    partes.append([_sigla(_equipo_v), _texto_club(_colores_v), _fondo_club(_colores_v)])
    var x := 0.0
    var alto := 0.0
    for p: Array in partes:
        var g := Grafica.new()
        fila.add_child(g)
        g.margen = 14.0
        g.configurar(String(p[0]), 34, p[1], p[2])
        g.position = Vector2(x, 0)
        x += g.size.x - g.size.y * Grafica.SKEW
        alto = g.size.y
    var ancho_fila := x + alto * Grafica.SKEW
    var y := _alto_senal * 0.2
    var x_fila := (_ancho - ancho_fila) * 0.5 - titulo.size.y * Grafica.SKEW * 0.5   # sigue la inclinación del título
    titulo.pivot_offset = titulo.size * 0.5
    titulo.position = Vector2(-titulo.size.x - 40.0, y)
    fila.position = Vector2(_ancho + 40.0, y + titulo.size.y + 10.0)
    var t := create_tween().set_parallel(true)
    t.tween_property(destello, "color:a", 0.0, 0.35)
    t.tween_property(titulo, "position:x", (_ancho - titulo.size.x) * 0.5, 0.28).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
    t.tween_property(fila, "position:x", x_fila, 0.26).set_delay(0.14).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
    await t.finished
    if _cartel != raiz:
        return
    cartel_listo = true
    var latido := create_tween().set_loops(2)
    latido.tween_property(titulo, "scale", Vector2(1.05, 1.05), 0.16)
    latido.tween_property(titulo, "scale", Vector2.ONE, 0.16)
    await get_tree().create_timer(1.5).timeout
    if _cartel != raiz or not is_instance_valid(raiz):
        return
    cartel_listo = false
    var s := create_tween().set_parallel(true)
    s.tween_property(titulo, "position:x", _ancho + 40.0, 0.2).set_ease(Tween.EASE_IN)
    s.tween_property(fila, "position:x", -ancho_fila - 40.0, 0.2).set_ease(Tween.EASE_IN)
    await s.finished
    if _cartel == raiz:
        _quitar_cartel()


# ------------------------------------------------------------------ Cuadro a cuadro

func _process(delta: float) -> void:
    if cancha == null:
        return
    _reloj += delta
    _animar_aguja(delta)
    if _presionado != null and not _movido and not _cuenta.visible and _reloj - _pres_t > MANTENER_S and not ocupado:
        _mostrar_cuenta(_presionado)
    if _arrastre != null:
        _actualizar_apuntado()
    _colocar_zonas()
    _colocar_placa()   # primero la placa del pase: las etiquetas la esquivan
    _colocar_etiquetas(delta)
    _flecha.queue_redraw()


# ------------------------------------------------------------------ Placa del % junto al receptor

# Lo que dice la placa del pase apuntado: {pct, robo, misma_zona}; {} si no se está apuntando.
# D-44, en la defensa: arrastrando, tu % junto al rival apuntado ("texto": la carta y tu defensor); sin
# arrastrar, el % de la jugada anunciada del rival junto al que va a recibir o a rematar ("rival": true).
# "clave" es el jugador junto al que va.
func placa_info() -> Dictionary:
    if modo == Modo.DEFENSA:
        return _placa_defensa()
    if modo == Modo.ATAQUE and engine != null and engine.corner_pending and not ocupado:
        var cr := _companero_bajo_mouse(engine.corner_receivers())   # D-48: el % del centro junto al que apuntas
        if cr == "":
            cr = engine.best_corner_receiver()
        return {"pct": roundi(engine.corner_chance(cr) * 100.0), "robo": 0, "misma_zona": false, "clave": "L:" + cr, "texto": "CÓRNER"}
    if _arrastre == null or _apuntado == "" or not MatchEngine.is_pass(_arrastre.card):
        return {}
    var c: Card = _arrastre.card
    return {"pct": roundi(engine.success_chance(c, -1, _apuntado) * 100.0),
        "robo": roundi(engine.steal_chance(c, -1, _apuntado) * 100.0),
        "misma_zona": engine.pass_zone(c, _apuntado) == engine.zone and engine.target_zone(c) != engine.zone,
        "clave": "L:" + _apuntado}


func _placa_defensa() -> Dictionary:
    if engine == null or not engine.duel_defense_on():
        return {}
    if _arrastre != null:
        if _apuntado == "":
            return {}
        var c: Card = _arrastre.card
        return {"pct": roundi(engine.success_chance(c) * 100.0), "robo": 0, "misma_zona": false, "clave": "V:" + _apuntado,
            "texto": "%s · %s" % [c.display_name.to_upper(), apellido(String(engine.defense_defender(c).get("name", "")))]}
    if intencion.is_empty() or ocupado:
        return {}
    var r := String(intencion.get("receiver", intencion.get("corner", "")))
    var c: Card = intencion.get("card")
    var texto := "CÓRNER" if intencion.has("corner") else ("AGUANTA" if c == null else c.display_name.to_upper())
    return {"pct": intencion_pct(), "robo": 0, "misma_zona": false, "rival": true,
        "clave": "V:" + (r if r != "" else String(rival_engine.carrier.get("id", ""))),
        "texto": "%s · %s" % [_sigla(_equipo_v), texto]}


func placa_visible() -> bool:
    return _placa.visible


# Al lado del apuntado, donde menos tape: arriba de la cabeza, a la derecha o a la izquierda del cuerpo,
# sin montarse sobre otros jugadores ni el zócalo (las etiquetas la esquivan a ella).
func _colocar_placa() -> void:
    var info := placa_info()
    _placa.visible = not info.is_empty()
    if info.is_empty():
        return
    _placa.set_meta("info", info)
    var ancho := 150.0
    if info.has("texto"):
        ancho = maxf(ancho, Paleta.letra("tv").get_string_size(String(info["texto"]), HORIZONTAL_ALIGNMENT_LEFT, -1, 16).x + 34.0)
    _placa.size = Vector2(ancho, 68 if (int(info["robo"]) >= 10 or info["misma_zona"] or info.has("texto")) else 46)
    var j := _jug(String(info["clave"]))
    if j == null:
        return
    var cuerpo := _rect_cuerpo(j)
    var s := _placa.size
    var huecos := [
        Vector2(cuerpo.get_center().x - s.x * 0.5, cuerpo.position.y - s.y - 8),
        Vector2(cuerpo.end.x + 10, cuerpo.position.y),
        Vector2(cuerpo.position.x - s.x - 10, cuerpo.position.y),
        Vector2(cuerpo.end.x + 10, cuerpo.get_center().y),
        Vector2(cuerpo.position.x - s.x - 10, cuerpo.get_center().y),
    ]
    var ocupados: Array[Rect2] = [_rect_con_balon(), Rect2(0, 0, _ancho, 44)]
    for clave: String in cancha.jugadores:
        ocupados.append(_rect_cuerpo(cancha.jugadores[clave]))
    var limites := Rect2(6, 46, _ancho - 12, _alto_senal - 52)
    var mejor: Vector2 = huecos[0]
    var mejor_costo := INF
    for i in huecos.size():
        var r := Rect2(huecos[i], s)
        var costo := i * 40.0
        for o: Rect2 in ocupados:
            costo += r.intersection(o).get_area()
        if not limites.encloses(r):
            costo += 50000.0
        if costo < mejor_costo:
            mejor_costo = costo
            mejor = huecos[i]
    _placa.position = mejor
    _placa.queue_redraw()


func _dibujar_placa() -> void:
    var info: Dictionary = _placa.get_meta("info", {})
    if info.is_empty():
        return
    var s := _placa.size
    var dx := 46.0 * Grafica.SKEW
    var colores: Array = Paleta.placa(int(info["pct"]) / 100.0)
    var fondo: Array = colores[0]
    var arriba := PackedVector2Array([Vector2(dx, 0), Vector2(s.x, 0), Vector2(s.x - dx * 0.5, 23), Vector2(dx * 0.5, 23)])
    var abajo := PackedVector2Array([Vector2(dx * 0.5, 23), Vector2(s.x - dx * 0.5, 23), Vector2(s.x - dx, 46), Vector2(0, 46)])
    _placa.draw_colored_polygon(PackedVector2Array([Vector2(dx, 4), Vector2(s.x + 4, 4), Vector2(s.x - dx + 4, 50), Vector2(4, 50)]), Color(0, 0, 0, 0.55))
    _placa.draw_colored_polygon(arriba, fondo[0].lerp(fondo[1], 0.5))
    _placa.draw_colored_polygon(abajo, fondo[2].lerp(fondo[3], 0.5))
    _placa.draw_polyline(PackedVector2Array([Vector2(dx, 0), Vector2(s.x, 0), Vector2(s.x - dx, 46), Vector2(0, 46), Vector2(dx, 0)]), CONTORNO_FLECHA, 2.0, true)
    var f := Paleta.letra("tv")
    var pct := "%d%%" % int(info["pct"])
    var w := f.get_string_size(pct, HORIZONTAL_ALIGNMENT_LEFT, -1, 42).x
    _placa.draw_string(f, Vector2((s.x - w) * 0.5 + 2, 40), pct, HORIZONTAL_ALIGNMENT_LEFT, -1, 42, Color(0, 0, 0, 0.45))
    _placa.draw_string(f, Vector2((s.x - w) * 0.5, 38), pct, HORIZONTAL_ALIGNMENT_LEFT, -1, 42, colores[1])
    var extra: Array = []
    if info.has("texto"):
        extra.append(String(info["texto"]))
    if info["misma_zona"]:
        extra.append("NO AVANZA")
    if int(info["robo"]) >= 10:
        extra.append("ROBO %d%%" % int(info["robo"]))
    if not extra.is_empty():
        var t := " · ".join(extra)
        _placa.draw_rect(Rect2(4, 47, s.x - 12, 21), Color(0.043, 0.067, 0.106, 0.92))
        var tw := f.get_string_size(t, HORIZONTAL_ALIGNMENT_LEFT, -1, 16).x
        _placa.draw_string(f, Vector2((s.x - tw) * 0.5, 63), t, HORIZONTAL_ALIGNMENT_LEFT, -1, 16, CORAL if int(info["robo"]) >= 10 else Color.WHITE)
