extends Control

# T-16: la previa de TV del partido (D-35, D-37): reemplaza el panel tipo web del menú del partido rápido y
# del final. Tapa toda la pantalla (nada del partido viejo se ve detrás) con la señal de 2006: barra de la
# transmisión, los dos escudos generados, gráficas inclinadas y la entrada al estadio como botón.
#   - previa: tu club contra el rival; el rival se elige tocando su escudo (o con las flechas) y el modo,
#     tocando su gráfica. La entrada dice IR AL PARTIDO.
#   - final: el marcador grande, el resultado y las cifras del partido.
#   - aviso: un título y un texto (mazo no válido, sin equipos).
# No guarda estado propio: lee y escribe los OptionButton de match_view (los tests los siguen usando).

const Grafica := preload("res://scenes/prueba_3d/grafica_tv.gd")
const SPONSORS := [["CERVEZA GLACIAR", "#dfe9f2", "#1d4f7a"], ["TELNET", "#1d3f9e", "#ffffff"], ["DIARIO EL CHISME", "#c8321f", "#ffffff"]]
const GRIS := Color("#8d9ab0")
const TINTA_TV := Color("#0b111b")

var _liga: LeagueManager
var _local := {}
var _rivales: OptionButton
var _modos: OptionButton
var _al_iniciar: Callable
var _raiz: Control              # lienzo de 1280×720 centrado en la ventana
var _filtro: ColorRect
var _modo := ""                 # "previa", "final" o "aviso"
var _datos := {}
var _visto_rival := -1
var _visto_modo := -1


func armar(liga: LeagueManager, local: Dictionary, rivales: OptionButton, modos: OptionButton, al_iniciar: Callable) -> void:
    _liga = liga
    _local = local
    _rivales = rivales
    _modos = modos
    _al_iniciar = al_iniciar
    set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
    mouse_filter = Control.MOUSE_FILTER_STOP   # nada de lo que queda debajo recibe el mouse
    _raiz = Control.new()
    _raiz.size = Vector2(1280, 720)
    _raiz.mouse_filter = Control.MOUSE_FILTER_IGNORE
    add_child(_raiz)
    _filtro = ColorRect.new()   # líneas de la señal y viñeta, como en la cancha
    _filtro.mouse_filter = Control.MOUSE_FILTER_IGNORE
    var sh := Shader.new()
    sh.code = """shader_type canvas_item;
void fragment() {
    float linea = step(2.0, mod(FRAGCOORD.y, 3.0)) * 0.07;
    float vin = smoothstep(0.62, 1.05, length((UV - 0.5) * vec2(1.82, 2.0))) * 0.2;
    COLOR = vec4(0.0, 0.0, 0.0, 1.0 - (1.0 - linea) * (1.0 - vin));
}"""
    var mat := ShaderMaterial.new()
    mat.shader = sh
    _filtro.material = mat
    add_child(_filtro)
    resized.connect(_ajustar)
    _ajustar()


func _ajustar() -> void:
    _raiz.position = ((size - _raiz.size) * 0.5).round()
    _filtro.size = size
    queue_redraw()


func mostrar_previa() -> void:
    _modo = "previa"
    _datos = {}
    _rehacer()


# rival: el club; lineas: las cifras del partido; boton: el texto de la entrada; otro: si se puede volver
# a la previa para cambiar de rival (partido rápido).
func mostrar_final(titulo: String, rival: Dictionary, goles_l: int, goles_v: int, lineas: Array, boton: String, otro: bool) -> void:
    _modo = "final"
    _datos = {"titulo": titulo, "rival": rival, "gl": goles_l, "gv": goles_v, "lineas": lineas, "boton": boton, "otro": otro}
    _rehacer()


func mostrar_aviso(titulo: String, texto: String, boton: String) -> void:
    _modo = "aviso"
    _datos = {"titulo": titulo, "texto": texto, "boton": boton}
    _rehacer()


func modo() -> String:
    return _modo


func _process(_delta: float) -> void:
    if not visible or _modo != "previa" or _rivales == null:
        return
    var m := _modos.selected if _modos != null else -1
    if _rivales.selected != _visto_rival or m != _visto_modo:   # alguien cambió la selección por fuera
        _rehacer()


# ------------------------------------------------------------------ Fondo

func _draw() -> void:
    draw_rect(Rect2(Vector2.ZERO, size), Paleta.TV_FONDO)
    var o := _raiz.position if _raiz != null else Vector2.ZERO
    # Banda del estudio detrás de los escudos: inclinada, con filo dorado arriba.
    var a := o.y + 96.0
    var b := o.y + 412.0
    var dx := (b - a) * Grafica.SKEW
    draw_colored_polygon(PackedVector2Array([Vector2(-40 + dx, a), Vector2(size.x + 40, a), Vector2(size.x + 40 - dx, b), Vector2(-40, b)]), Color("#111a28"))
    draw_rect(Rect2(0, a, size.x, 3), Paleta.DORADO)
    draw_rect(Rect2(0, b - 2.0, size.x, 2), Color(1, 1, 1, 0.08))
    # Barra de la transmisión.
    draw_rect(Rect2(0, 0, size.x, 44), Color("#070b12"))
    draw_rect(Rect2(0, 44, size.x, 2), Color(1, 1, 1, 0.10))
    # Carteles de los sponsors (parodias) al pie, como en la cancha.
    var f := Paleta.letra("tv")
    var y := size.y - 40.0
    var x := o.x - 1280.0
    var i := 0
    while x < size.x:
        var s: Array = SPONSORS[i % SPONSORS.size()]
        var fondo := Color(String(s[1]))
        draw_rect(Rect2(x, y, 318, 40), fondo.darkened(0.12))
        draw_rect(Rect2(x, y, 318, 20), fondo)
        var w := f.get_string_size(String(s[0]), HORIZONTAL_ALIGNMENT_LEFT, -1, 24).x
        draw_string(f, Vector2(x + (318 - w) * 0.5, y + 29), String(s[0]), HORIZONTAL_ALIGNMENT_LEFT, -1, 24, Color(String(s[2])))
        x += 320.0
        i += 1
    draw_rect(Rect2(0, y - 3, size.x, 3), Color(0, 0, 0, 0.6))


# ------------------------------------------------------------------ Piezas

func _grafica(texto: String, tam: int, color: Color, fondo: Array, margen: float = 9.0, ancho_max: float = 0.0) -> Control:
    var g := Grafica.new()
    _raiz.add_child(g)
    g.margen = margen
    g.configurar(texto, tam, color, fondo)
    while ancho_max > 0.0 and g.size.x > ancho_max and tam > 18:
        tam -= 2
        g.configurar(texto, tam, color, fondo)
    return g


func _centrar(g: Control, x: float, y: float) -> void:
    g.position = Vector2(x - g.size.x * 0.5, y)


func _boton(g: Control, al_pulsar: Callable) -> void:
    g.mouse_filter = Control.MOUSE_FILTER_STOP
    g.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
    g.gui_input.connect(func(ev: InputEvent) -> void:
        if ev is InputEventMouseButton and ev.pressed and ev.button_index == MOUSE_BUTTON_LEFT:
            al_pulsar.call())


func _rotulo(texto: String, pos: Vector2) -> Label:
    var l := Paleta.etiqueta(texto, "condensada", 16, GRIS, 2)
    l.position = pos
    _raiz.add_child(l)
    return l


func _fondo_club(team: Dictionary) -> Array:
    var c: Color = _liga.team_colors(team)[0]
    return [c.lightened(0.18), c, c.darkened(0.2), c.darkened(0.06)]


func _texto_club(team: Dictionary) -> Color:
    var c: Color = _liga.team_colors(team)[0]
    return Color("#111111") if c.get_luminance() > 0.55 else Color.WHITE


func _club(team: Dictionary, x: float, sub: String) -> void:
    var e := Escudo.crear(team, 176.0)
    e.position = Vector2(x - e.size.x * 0.5, 122)
    _raiz.add_child(e)
    var n := _grafica(String(team.get("short_name", "?")).to_upper(), 40, _texto_club(team), _fondo_club(team), 16.0, 360.0)
    _centrar(n, x, 312)
    if sub != "":
        var s := _grafica(sub, 18, Color.WHITE, Grafica.SEMI_NOCHE, 10.0)
        _centrar(s, x - 8.0, 312 + n.size.y + 6.0)


func _entrada(texto: String, encabezado: String, centro_x: float, y: float) -> Button:
    var ancho := Paleta.letra("tv").get_string_size(texto, HORIZONTAL_ALIGNMENT_LEFT, -1, 34).x + 112.0
    var b := Mesa.entrada(Rect2(centro_x - ancho * 0.5, y, ancho, 78), -2.0, encabezado, texto, "N° 2006", 34, func() -> void:
        if _al_iniciar.is_valid():
            _al_iniciar.call())
    _raiz.add_child(b)
    return b


func _cabecera(izquierda: String, derecha: String) -> void:
    var a := _grafica(izquierda, 20, TINTA_TV, Paleta.PLACA_DORADA, 12.0)
    a.position = Vector2(16, 22.0 - a.size.y * 0.5)
    var b := _grafica(derecha, 20, TINTA_TV, Grafica.PLATA, 12.0)
    b.position = Vector2(a.position.x + a.size.x - a.size.y * Grafica.SKEW, 22.0 - b.size.y * 0.5)
    var transparente := [Color(0, 0, 0, 0), Color(0, 0, 0, 0), Color(0, 0, 0, 0), Color(0, 0, 0, 0)]
    var vivo := Grafica.new()
    _raiz.add_child(vivo)
    vivo.configurar("EN VIVO", 16, Color.WHITE, transparente, 1, Color("#ff3b2f"))
    vivo.position = Vector2(1280 - 18 - vivo.size.x, 22.0 - vivo.size.y * 0.5)


# ------------------------------------------------------------------ Armado de cada pantalla

func _rehacer() -> void:
    if _raiz == null:
        return
    for hijo in _raiz.get_children():
        _raiz.remove_child(hijo)
        hijo.queue_free()
    match _modo:
        "previa":
            _armar_previa()
        "final":
            _armar_final()
        "aviso":
            _armar_aviso()


func _rival_elegido() -> Dictionary:
    if _rivales == null or _rivales.item_count == 0:
        return {}
    return _liga.get_team(String(_rivales.get_item_metadata(maxi(0, _rivales.selected))))


func _elegir_rival(i: int) -> void:
    if _rivales.item_count == 0:
        return
    _rivales.selected = posmod(i, _rivales.item_count)
    _rehacer()


func _armar_previa() -> void:
    _visto_rival = _rivales.selected
    _visto_modo = _modos.selected if _modos != null else -1
    var rival := _rival_elegido()
    _cabecera("LA PREVIA", "PARTIDO RÁPIDO")
    _club(_local, 330, "TU EQUIPO")
    if rival.is_empty():
        return
    _club(rival, 950, ("%s · %s" % [rival.get("division", ""), rival.get("archetype", "")]).to_upper())
    var vs := Paleta.etiqueta("VS", "tv", 120, Paleta.DORADO)
    Paleta.sombra_tv(vs, 6)
    vs.size = Vector2(300, 150)
    vs.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    vs.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
    vs.position = Vector2(490, 150)
    _raiz.add_child(vs)
    # Flechas a los lados del rival.
    var izq := _grafica("<", 34, Color.WHITE, Paleta.TV_AZUL, 12.0)
    izq.position = Vector2(950 - 210 - izq.size.x, 316)
    _boton(izq, func() -> void: _elegir_rival(_rivales.selected - 1))
    var der := _grafica(">", 34, Color.WHITE, Paleta.TV_AZUL, 12.0)
    der.position = Vector2(950 + 204, 316)
    _boton(der, func() -> void: _elegir_rival(_rivales.selected + 1))
    # Los clubes de cada división: se elige tocando el escudo.
    _rotulo("ELIGE AL RIVAL", Vector2(84, 428))
    var divisiones: Array = []
    var por_division := {}
    for i in _rivales.item_count:
        var t := _liga.get_team(String(_rivales.get_item_metadata(i)))
        var d := String(t.get("division", ""))
        if not por_division.has(d):
            por_division[d] = []
            divisiones.append(d)
        por_division[d].append([i, t])
    var y := 456.0
    for d: String in divisiones:
        var fila: Array = por_division[d]
        var rot := _rotulo(d.to_upper(), Vector2(84, y + 12.0))
        rot.add_theme_color_override("font_color", Color.WHITE)
        var paso := minf(48.0, 980.0 / maxf(1.0, fila.size()))
        var x := 214.0
        for par: Array in fila:
            var i: int = par[0]
            var elegido := i == _rivales.selected
            if elegido:
                var luz := ColorRect.new()
                luz.mouse_filter = Control.MOUSE_FILTER_IGNORE
                luz.color = Paleta.DORADO
                luz.position = Vector2(x - 4.0, y + 44.0)
                luz.size = Vector2(42, 4)
                _raiz.add_child(luz)
            var e := Escudo.crear(par[1], 40.0)
            e.position = Vector2(x, y)
            e.pivot_offset = e.size * 0.5
            e.scale = Vector2(1.2, 1.2) if elegido else Vector2.ONE
            e.modulate = Color.WHITE if elegido else Color(0.82, 0.82, 0.82)
            _raiz.add_child(e)
            _boton(e, func() -> void: _elegir_rival(i))
            x += paso
        y += 54.0
    # El modo del partido: gráficas como las de la postura (la elegida, dorada).
    if _modos != null:
        _rotulo("MODO", Vector2(84, 606))
        var x := 214.0
        for i in _modos.item_count:
            var activo := i == _modos.selected
            var g := _grafica(_modos.get_item_text(i).trim_prefix("Modo: ").to_upper(), 20, TINTA_TV if activo else Color.WHITE,
                    Paleta.PLACA_DORADA if activo else Grafica.SEMI_NOCHE, 12.0)
            g.position = Vector2(x, 600)
            g.tooltip_text = _modos.tooltip_text
            _boton(g, func() -> void:
                _modos.selected = i
                _rehacer())
            x += g.size.x - g.size.y * Grafica.SKEW + 4.0
    _entrada("IR AL PARTIDO", "ESTADIO · HOY", 1040, 584)


func _armar_final() -> void:
    var rival: Dictionary = _datos["rival"]
    var gl: int = _datos["gl"]
    var gv: int = _datos["gv"]
    _cabecera(String(_datos["titulo"]), "RESUMEN")
    _club(_local, 330, "")
    _club(rival, 950, "")
    var marcador := _grafica("%d - %d" % [gl, gv], 112, Color.WHITE, Paleta.TV_AZUL, 30.0)
    _centrar(marcador, 640, 128)
    var res := "VICTORIA" if gl > gv else ("DERROTA" if gl < gv else "EMPATE")
    var fondo: Array = Paleta.PLACA_VERDE if gl > gv else (Paleta.PLACA_CORAL if gl < gv else Paleta.PLACA_DORADA)
    var placa := _grafica(res, 40, TINTA_TV if gl == gv else Color.WHITE, fondo, 18.0)
    _centrar(placa, 640 - 14.0, 128 + marcador.size.y + 10.0)
    var y := 432.0
    for linea: String in _datos["lineas"]:
        var g := _grafica(linea.to_upper(), 20, Color.WHITE, Grafica.SEMI_NOCHE, 14.0, 1100.0)
        _centrar(g, 640, y)
        y += g.size.y + 8.0
    var boton := String(_datos["boton"])
    _entrada(boton, "ESTADIO · HOY", 640 if not _datos["otro"] else 760, 584)
    if _datos["otro"]:
        var otro := _grafica("CAMBIAR RIVAL", 24, Color.WHITE, Paleta.TV_AZUL, 14.0)
        otro.position = Vector2(760 - 330 - otro.size.x * 0.5, 606)
        _boton(otro, mostrar_previa)


func _armar_aviso() -> void:
    _cabecera("TRANSMISIÓN", "AVISO")
    var t := _grafica(String(_datos["titulo"]), 56, Color.WHITE, Paleta.PLACA_CORAL, 22.0, 1100.0)
    _centrar(t, 640, 150)
    var l := Paleta.etiqueta(String(_datos["texto"]), "texto", 20, Paleta.PAPEL_CREMA)
    l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
    l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    l.position = Vector2(190, 270)
    l.size = Vector2(900, 280)
    _raiz.add_child(l)
    if String(_datos["boton"]) != "":
        _entrada(String(_datos["boton"]), "ESTADIO · HOY", 640, 584)
