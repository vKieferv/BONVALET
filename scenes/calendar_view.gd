extends Control

# Semana del modo carrera como la mesa del DT vista desde arriba (D-37). La UI se arma por código y
# las reglas viven en Career. Los pasos de la semana son los separadores de un archivador:
#   1 · Prensa: hoja de calendario, libreta (caja, popularidad, disciplina, fatiga), Diario El Chisme
#       con el evento, contratos de los sponsors paródicos y las dos decisiones como post-its con timbres.
#   2 · Entrenamiento, UNA opción por semana (D-21): portapapeles (táctico: abre el sobre con las 3
#       láminas ofrecidas; con el mazo en su tope eliges cuál sale), cassette VHS (video: mejorar una
#       lámina) o ficha médica (kinesiología). El sobre abre "Ver mazo". A la derecha, la promo del
#       domingo en el televisor, el informe del rival, la pizarra con tu once y la entrada al estadio.
#   3 · Partido: la entrada valida el mazo (prepare_match) y abre match_view; apagada mientras falte
#       algo ("falta el paso N").
# Una acción a la vez: chinchetas numeradas en lo pendiente, ✓ en lo hecho y la luz de la lámpara
# sobre lo que toca decidir. Sin carrera, la mesa muestra la ficha para elegir club, Comenzar y
# Continuar. Las dos páginas se rearman en cada _refresh (la que no se ve queda oculta).
# La carrera se guarda sola (Career.save_path) tras cada acción y al volver del partido.

const MATCH_SCENE := "res://scenes/match_view.tscn"
const CARD_SCENE := preload("res://scenes/card_ui.tscn")
const DEFAULT_TEAM := "colo_colo"
const MESA := Vector2(1280, 720)
const PASOS := ["prensa", "entrenamiento", "partido"]
const PASO_TITULO := {"prensa": "1 · PRENSA", "entrenamiento": "2 · ENTRENAMIENTO", "partido": "3 · PARTIDO"}
# Dónde va cada cosa sobre la mesa (maqueta v3, 1280×720) y adónde apunta la lámpara.
const R_CONTRATOS := Rect2(896, 60, 356, 390)
const R_POSTITS := Rect2(590, 450, 540, 250)
const R_ENTRENAMIENTOS := Rect2(20, 30, 270, 640)
const R_CENTRO := Rect2(300, 40, 640, 660)
const R_ENTRADA := Rect2(950, 590, 310, 110)
const R_INICIO := Rect2(160, 80, 1020, 580)
const CONTRATOS := [[Rect2(912, 78, 300, 176), 3.5], [Rect2(930, 232, 304, 190), -2.5], [Rect2(906, 300, 300, 176), 1.5]]
const SPONSOR_COLOR := {"cerveza_glaciar": Color("#1d5f8a"), "telnet": Color("#1b3f8f")}
const OFERTA := [[Vector2(360, 150), -7.0], [Vector2(544, 104), 0.0], [Vector2(748, 150), 6.0]]
# Imanes de la pizarra, en el orden de SquadManager.FORMATION (POR, DFC×2, LAT×2, MCD×2, MCO, EXT, DEL×2).
const PIZARRA := [Vector2(155, 222), Vector2(111, 186), Vector2(199, 186), Vector2(43, 170), Vector2(267, 170),
    Vector2(107, 138), Vector2(203, 138), Vector2(155, 106), Vector2(251, 96), Vector2(107, 62), Vector2(203, 62)]

var _league: LeagueManager
var _squads: SquadManager
var _career: Career
var _saved: Career            # carrera guardada que ofrece "Continuar" (null = no hay o no es válida)

var _mesa: Control            # 1280×720 centrada en la pantalla; las páginas se arman adentro
var _lamp: ColorRect
var _page := "prensa"         # separador abierto del archivador: "prensa" | "entrenamiento"
var _club_id := DEFAULT_TEAM  # club elegido en la ficha de inicio
var _status_text := ""
var _tab_rects := {}
var _first_aim := true

# Nodos que se rearman en cada _refresh (las pruebas los leen).
var _club_option: OptionButton
var _start_button: Button
var _continue_button: Button
var _status: Label
var _club_label: Label        # tu club en la hoja del calendario
var _b2_detail: Control       # lo que pide la opción abierta: las láminas ofrecidas o tu mazo para el video
var _training_status: Label
var _deck_panel: Control
var _deck_list: GridContainer
var _check_label: Label
var _go_button: Button

var _b2_view := ""            # opción del Bloque 2 abierta y sin resolver ("tactical" | "video")
var _replace_for := -1        # lámina de la oferta que espera elegir cuál sale (mazo en su tope)
var _b2_result := ""          # qué dejó el Bloque 2 al resolverse (solo en pantalla)
var _b2_card := -1            # índice en el mazo de la lámina que tomaste o mejoraste (solo en pantalla)
var _deck_open := false
var _check_text := ""         # lo que dijo la última validación de la entrada (errores o avisos)
var _check_bad := false

# Datos para los dibujos de esta mesa (se calculan al armarla).
var _photo := Rect2()
var _pizarra: Array = []      # [{pos, name, star, gk}]
var _imanes: Array = []       # [color de campo, color del arquero]


func _ready() -> void:
    _career = Career.current
    if _career != null:
        _league = _career.league
        _squads = _career.squads
    else:
        _league = LeagueManager.new()
        if not _league.load_all():
            push_error("LeagueManager: " + "; ".join(_league.load_errors))
        _squads = SquadManager.new()
        if not _squads.load_all(_league):
            push_error("SquadManager: " + "; ".join(_squads.load_errors))
    if _career != null:
        _save()   # vuelve del partido con la semana nueva ya registrada
    else:
        _saved = Career.load_saved(_league, _squads)
        if _saved != null:
            _club_id = _saved.team_id
    add_child(Mesa.madera())
    _mesa = Control.new()
    _mesa.mouse_filter = Control.MOUSE_FILTER_IGNORE
    _mesa.set_anchors_preset(Control.PRESET_CENTER)
    _mesa.offset_left = -MESA.x / 2.0
    _mesa.offset_top = -MESA.y / 2.0
    _mesa.offset_right = MESA.x / 2.0
    _mesa.offset_bottom = MESA.y / 2.0
    add_child(_mesa)
    _lamp = Mesa.lampara()
    add_child(_lamp)
    resized.connect(func() -> void: _aim.call_deferred(false))
    _refresh()


# ================================================================== Estado → mesa

func _refresh() -> void:
    for child in _mesa.get_children():
        _mesa.remove_child(child)
        child.queue_free()
    _tab_rects.clear()
    if _career == null:
        _build_inicio(_pagina("inicio"))
    else:
        _build_prensa(_pagina("prensa"))
        _build_entrenamiento(_pagina("entrenamiento"))
        _build_tabs()
    _aim.call_deferred(not _first_aim)
    _first_aim = false


func _pagina(nombre: String) -> Control:
    var p := Control.new()
    p.name = nombre
    p.size = MESA
    p.mouse_filter = Control.MOUSE_FILTER_IGNORE
    p.visible = _career == null or nombre == _page
    _mesa.add_child(p)
    return p


func _show_page(p: String) -> void:
    _page = p
    _refresh()


# La luz de la lámpara sobre lo que toca decidir ahora.
func _aim(animar: bool) -> void:
    var r := _focus_rect()
    Mesa.enfocar(_lamp, Rect2(r.position + _mesa.position, r.size), animar)


func _focus_rect() -> Rect2:
    if _career == null:
        return R_INICIO
    var done := _career.blocks_done()
    if _career.pending_match:
        return R_ENTRADA if _page == "entrenamiento" else _tab_rects.get("partido", R_CONTRATOS)
    if _page == "prensa":
        if _career.sponsor_id == "":
            return R_CONTRATOS
        if _career.event_result.is_empty():
            return R_POSTITS
        return _tab_rects.get("partido" if done["block2"] else "entrenamiento", R_CONTRATOS)
    if _deck_open:
        return R_CENTRO
    if _career.block2_open():
        return R_CENTRO if _b2_view != "" else R_ENTRENAMIENTOS
    if not done["block1"]:
        return _tab_rects.get("prensa", R_ENTRADA)
    return R_ENTRADA


# "TORNEO 2006": la temporada sale de la liga (league_config.json), no del código. La liga chilena 2006 es
# la base; una liga de otro paquete trae la suya (D-26, I-55).
func _torneo() -> String:
    var season = _league.get_league(Career.LEAGUE_ID).get("season")
    return "TORNEO" if season == null else "TORNEO %d" % int(season)


func _missing_steps() -> Array:
    var done := _career.blocks_done()
    var out: Array = []
    if not done["block1"]:
        out.append(1)
    if not done["block2"]:
        out.append(2)
    return out


func _can_go() -> bool:
    return _missing_steps().is_empty() and not _league.get_team(_career.rival_id).is_empty()


# ================================================================== Separadores del archivador

func _build_tabs() -> void:
    var done := _career.blocks_done()
    var hecho := {"prensa": done["block1"], "entrenamiento": done["block2"], "partido": false}
    var f := Paleta.letra("condensada_negra", 2)
    var anchos := {}
    var total := 0.0
    for p in PASOS:
        anchos[p] = f.get_string_size(PASO_TITULO[p], HORIZONTAL_ALIGNMENT_LEFT, -1, 17).x + 36.0 + (24.0 if hecho[p] else 0.0)
        total += anchos[p] - 4.0
    var x := MESA.x - 30.0 - total if _page == "prensa" else 330.0
    for p in PASOS:
        var activa: bool = p == _page
        var r := Rect2(x, 0, anchos[p], 46.0 if activa else 36.0)
        var handler := _on_go if p == "partido" else _show_page.bind(p)
        var tab := Mesa.objeto(r, 0.0, _draw_tab.bind(p, activa, hecho[p]), handler)
        tab.z_index = 2 if activa else 1
        tab.disabled = activa or (p == "partido" and not _can_go())
        if p == "partido":
            tab.tooltip_text = "Ir al partido" if _can_go() else "Falta el paso %s" % " y ".join(_missing_steps().map(func(v): return str(v)))
        var l := Paleta.etiqueta(PASO_TITULO[p], "condensada_negra" if activa else "condensada", 17 if activa else 16,
                Paleta.SEPARADORES[p][1], 2)
        l.position = Vector2(18, r.size.y - 30)
        tab.add_child(l)
        if hecho[p]:
            var check := Icono.crear("check", Paleta.SEPARADORES[p][1], 16)
            check.position = Vector2(r.size.x - 36, r.size.y - 27)
            tab.add_child(check)
        _mesa.add_child(tab)
        _tab_rects[p] = r
        x += anchos[p] - 4.0


func _draw_tab(b: Button, paso: String, activa: bool, _hecho: bool) -> void:
    var col: Color = Paleta.SEPARADORES[paso][0]
    if not activa:
        col = col.darkened(0.12)
    var sb := Paleta.caja(col, 0, [Color(0, 0, 0, 0.6), 8 if activa else 6, 4])
    sb.corner_radius_bottom_left = 6
    sb.corner_radius_bottom_right = 6
    b.draw_style_box(sb, Rect2(Vector2(0, -8), b.size + Vector2(0, 8)))


# ================================================================== 1 · Prensa

func _build_prensa(page: Control) -> void:
    var c := _career
    var rival := _league.get_team(c.rival_id)
    var locked := c.pending_match
    var ev := c.week_event()

    # Hoja del calendario: semana, tu club y el rival del domingo.
    var cal := Mesa.objeto(Rect2(30, 22, 250, 214), -3.0, _draw_calendario)
    page.add_child(cal)
    var head := Paleta.etiqueta(_torneo(), "condensada_negra", 19, Color.WHITE, 3)
    head.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    head.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
    head.size = Vector2(250, 40)
    cal.add_child(head)
    var num := Paleta.etiqueta(str(c.week), "condensada_negra", 104, Paleta.TINTA_MESA)
    num.position = Vector2(16, 24)
    cal.add_child(num)
    var nx := 16.0 + num.get_minimum_size().x + 10.0
    var sem := Paleta.etiqueta("SEMANA", "condensada_negra", 26, Paleta.TINTA_MESA, 1)
    sem.position = Vector2(nx, 62)
    cal.add_child(sem)
    _club_label = Paleta.etiqueta(String(c.team()["short_name"]).to_upper(), "condensada", 16, Paleta.TINTA_SEPIA, 1)
    _club_label.position = Vector2(nx, 94)
    cal.add_child(_club_label)
    var dom := Mesa.plumon("domingo: %s" % rival.get("short_name", "?"), 19, Paleta.PLUMON_ROJO, -2.0, false)
    dom.position = Vector2(18, 156)
    cal.add_child(dom)

    # Libreta: caja, popularidad, disciplina y fatiga del plantel.
    var lib := Mesa.objeto(Rect2(44, 268, 236, 214), 1.8, _draw_libreta)
    var start := c.start_stamina_preview()
    lib.tooltip_text = ("Caja del club: %s\nPopularidad (la hinchada): %d\nDisciplina (el camarín): %d\n" +
            "Fatiga del plantel: %d%%. Sin cambios arrancarías el partido con %d%% de estamina (%s, mano de %d).") % [
            Mesa.plata(c.budget), c.popularity, c.discipline, int(c.fatigue), start["pct"], start["zone"], start["hand"]]
    page.add_child(lib)
    var filas := [["CAJA", "", Paleta.TINTA_SEPIA, Mesa.plata(c.budget)],
        ["", "megafono", Paleta.TIMBRE_NARANJA, str(c.popularity)],
        ["", "tarjeta", Paleta.TIMBRE_DORADO, str(c.discipline)],
        ["", "bateria", Paleta.TIMBRE_VERDE, "%d%%" % int(c.fatigue)]]
    for i in filas.size():
        var y := 14.0 + i * 34.0
        if filas[i][0] != "":
            var l := Paleta.etiqueta(filas[i][0], "condensada_negra", 16, filas[i][2], 1)
            l.position = Vector2(44, y + 6)
            lib.add_child(l)
        else:
            var ic := Icono.crear(filas[i][1], filas[i][2], 20)
            if filas[i][1] == "bateria":
                ic.nivel = clampf(1.0 - c.fatigue / 100.0, 0.05, 1.0)
            ic.position = Vector2(44, y + 7)
            lib.add_child(ic)
        var v := Paleta.etiqueta(filas[i][3], "plumon", 20, Paleta.PLUMON)
        v.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
        v.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
        v.position = Vector2(60, y)
        v.size = Vector2(160, 34)
        lib.add_child(v)

    _build_diario(page, ev)
    _build_contratos(page, locked)
    _build_postits(page, ev, locked)
    _build_resultados(page)


func _build_diario(page: Control, ev: Dictionary) -> void:
    var c := _career
    var diario := Mesa.objeto(Rect2(318, 40, 560, 520), -2.0, _draw_diario)
    page.add_child(diario)
    var name := Paleta.etiqueta("Diario El Chisme", "diario", 42, Paleta.TINTA_MESA)
    name.position = Vector2(26, 12)
    diario.add_child(name)
    var ed := Paleta.etiqueta("SEMANA %d" % c.week, "condensada", 15, Paleta.TINTA_SEPIA, 1)
    diario.add_child(ed)
    ed.position = Vector2(534 - ed.get_minimum_size().x, 36)
    var tag := Mesa.placa_tv("EXCLUSIVO", 17, [Paleta.ROJO_DIARIO], Color.WHITE)
    tag.position = Vector2(30, 84)
    diario.add_child(tag)
    var sec := Paleta.etiqueta("FARÁNDULA DEPORTIVA", "condensada", 15, Paleta.TINTA_SEPIA, 2)
    sec.position = Vector2(tag.size.x + 44, 86)
    diario.add_child(sec)
    var title := Paleta.etiqueta("¡%s!" % String(ev.get("title", "Sin novedades")), "diario", 52, Paleta.TINTA_MESA)
    title.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
    title.add_theme_constant_override("line_spacing", -12)
    title.position = Vector2(26, 112)
    title.size = Vector2(508, 0)
    diario.add_child(title)
    var tam := 52
    while title.get_line_count() > 2 and tam > 36:
        tam -= 4
        title.add_theme_font_size_override("font_size", tam)
    var th := title.get_minimum_size().y
    _photo = Rect2(26, 112 + th + 6, 508, 176)
    var body := Paleta.etiqueta(String(ev.get("text", "")), "texto_regular", 15, Color("#2e2820"))
    body.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
    body.position = Vector2(26, _photo.end.y + 10)
    body.size = Vector2(240, 0)
    diario.add_child(body)
    var res := c.event_result
    if not res.is_empty():
        diario.tooltip_text = "\n".join(res["lines"])
        var texto := "PASÓ PIOLA" if res["accepted"] else "CONCENTRADOS"
        var tinta := Paleta.TIMBRE_VERDE
        if res["funa"]:
            texto = "¡FUNA! · %s" % Mesa.apellido(c.funado_name()).to_upper()
            tinta = Paleta.TIMBRE_ROJO
        var stamp := Mesa.sello(texto, tinta, -9.0, 36)
        diario.add_child(stamp)
        stamp.position = _photo.get_center() - stamp.get_minimum_size() / 2.0


func _build_contratos(page: Control, locked: bool) -> void:
    var c := _career
    var sponsors := c.sponsors()
    for i in mini(sponsors.size(), CONTRATOS.size()):
        var s: Dictionary = sponsors[i]
        var id := String(s["id"])
        var r: Rect2 = CONTRATOS[i][0]
        var o := Mesa.objeto(r, CONTRATOS[i][1], _draw_contrato.bind(id, i), _on_sponsor.bind(id))
        o.disabled = locked
        o.tooltip_text = c.sponsor_terms(s)
        page.add_child(o)
        var col: Color = SPONSOR_COLOR.get(id, Paleta.TINTA_MESA)
        var nombre := Paleta.etiqueta(String(s["name"]).to_upper(), "condensada_negra", 22, col, 1)
        nombre.position = Vector2(60, 12)
        o.add_child(nombre)
        var offer := c.sponsor_offer(s)
        var filas := [["POR SEMANA", offer["weekly"]], ["POR VICTORIA", offer["win_bonus"]]]
        for j in filas.size():
            var y := 54.0 + j * 34.0
            var l := Paleta.etiqueta(filas[j][0], "condensada", 17, Paleta.TINTA_MESA)
            l.position = Vector2(18, y)
            o.add_child(l)
            var v := Paleta.etiqueta(Mesa.plata(float(filas[j][1])), "condensada_negra", 20, Paleta.TINTA_MESA)
            o.add_child(v)
            v.position = Vector2(r.size.x - 18 - v.get_minimum_size().x, y - 2)
        if s.get("conduct_clause", false):
            var st := Mesa.sello("SI TE FUNAN, NO PAGA", Paleta.TIMBRE_ROJO, -8.0, 15)
            o.add_child(st)
            st.position = r.size - st.get_minimum_size() - Vector2(12, 12)
        if id == c.sponsor_id:
            var pin := Mesa.chincheta(0, true, 34)
            pin.position = Vector2(-16, -18)
            o.add_child(pin)
            if c.sponsor_week_lost:
                var lost := Mesa.sello("ESTA SEMANA NO PAGA", Paleta.TIMBRE_ROJO, 4.0, 15)
                lost.position = Vector2(16, 118)
                o.add_child(lost)
    var chosen := c.get_sponsor(c.sponsor_id)
    var note_y := 432.0 if sponsors.size() <= 2 else 490.0
    if chosen.is_empty():
        var pin := Mesa.chincheta(1)
        pin.position = Vector2(894, 60)
        page.add_child(pin)
        var note := Mesa.plumon("1 · ¿con quién firmamos?", 18, Paleta.PLUMON_CREMA, -3.0)
        note.position = Vector2(948, note_y)
        page.add_child(note)
    else:
        var note := Mesa.plumon("1 · firmamos con %s" % chosen["name"], 18, Color("#c9f5da"), -3.0)
        note.position = Vector2(948, note_y)
        page.add_child(note)


func _build_postits(page: Control, ev: Dictionary, locked: bool) -> void:
    var c := _career
    var res := c.event_result
    var resolved := not res.is_empty()
    var terms := c.event_terms(ev).split("\n")
    var r: Dictionary = ev.get("reward", {})
    var k: Dictionary = ev.get("risk", {})
    var d: Dictionary = ev.get("decline", {})

    # Aceptar: lo que suma y el riesgo, en timbres.
    var acc := Mesa.objeto(Rect2(600, 470, 250, 214), 3.0, _draw_postit.bind(Paleta.POSTIT_AMARILLO), _on_event.bind(true))
    acc.disabled = resolved or locked
    acc.tooltip_text = "\n".join(terms.slice(0, 2))
    page.add_child(acc)
    var box := _postit_box(acc, String(ev.get("accept_label", "Aceptar")), 27)
    box.add_child(Mesa.timbre("%+d%% · M1-%d" % [roundi(float(r.get("opening_bonus", 0.0)) * 100.0), int(r.get("opening_moments", 2))],
            "mira", Paleta.TIMBRE_VERDE, -3.0))
    var pop := int(r.get("popularity", 0))
    if pop != 0:
        box.add_child(Mesa.timbre("%+d" % pop, "megafono", Paleta.TIMBRE_VERDE if pop > 0 else Paleta.TIMBRE_ROJO, 2.0))
    box.add_child(Mesa.timbre("%d%% FUNA" % roundi(float(k.get("chance", 0.0)) * 100.0), "dado", Paleta.TIMBRE_ROJO, -2.0))
    var risk := HBoxContainer.new()
    risk.add_theme_constant_override("separation", 5)
    var dark := Color("#8a1f14")
    risk.add_child(Icono.crear("tarjeta", dark, 15))
    risk.add_child(Paleta.etiqueta("%+d ·" % int(k.get("discipline", 0)), "condensada_negra", 16, dark))
    risk.add_child(Icono.crear("gota", dark, 14))
    risk.add_child(Paleta.etiqueta("+%d%% A UN TITULAR" % roundi(float(k.get("funado_stamina_extra", 0.5)) * 100.0), "condensada_negra", 16, dark))
    for n in risk.get_children():
        n.size_flags_vertical = Control.SIZE_SHRINK_CENTER
    box.add_child(risk)
    Mesa.ignorar(box)

    # Negarse: sin riesgo.
    var dec := Mesa.objeto(Rect2(876, 486, 236, 190), -3.0, _draw_postit.bind(Paleta.POSTIT_VERDE), _on_event.bind(false))
    dec.disabled = resolved or locked
    dec.tooltip_text = terms[2] if terms.size() > 2 else ""
    page.add_child(dec)
    var box2 := _postit_box(dec, String(ev.get("decline_label", "Rechazar")), 25)
    var disc := int(d.get("discipline", 0))
    if disc != 0:
        box2.add_child(Mesa.timbre("%+d" % disc, "tarjeta", Paleta.TIMBRE_VERDE if disc > 0 else Paleta.TIMBRE_ROJO, 3.0))
    var dpop := int(d.get("popularity", 0))
    if dpop != 0:
        box2.add_child(Mesa.timbre("%+d" % dpop, "megafono", Paleta.TIMBRE_VERDE if dpop > 0 else Paleta.TIMBRE_ROJO, -3.0))
    box2.add_child(Paleta.etiqueta("SIN RIESGO", "condensada_negra", 16, Color("#33421f")))
    Mesa.ignorar(box2)

    if resolved:
        var pin := Mesa.chincheta(0, true, 34)
        pin.position = Vector2(-14, -16)
        (acc if res["accepted"] else dec).add_child(pin)
    else:
        var pin := Mesa.chincheta(2)
        pin.position = Vector2(608, 450)
        page.add_child(pin)
        var note := Mesa.plumon("2 · ¿qué hacemos?", 22, Paleta.PLUMON_CREMA, -5.0)
        note.position = Vector2(378, 612)
        page.add_child(note)


func _postit_box(postit: Button, titulo: String, tam: int) -> VBoxContainer:
    var box := VBoxContainer.new()
    box.add_theme_constant_override("separation", 8)
    box.position = Vector2(16, 12)
    box.size = Vector2(postit.size.x - 32, postit.size.y - 24)
    var t := Mesa.plumon(titulo, tam, Paleta.PLUMON, 0.0, false)
    t.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
    t.add_theme_constant_override("line_spacing", -6)
    box.add_child(t)
    postit.add_child(box)
    box.child_entered_tree.connect(func(n: Node) -> void:
        if n is Control and n != t:
            (n as Control).size_flags_horizontal = Control.SIZE_SHRINK_BEGIN)
    return box


# Recorte con los últimos resultados (si ya se jugó algún partido).
func _build_resultados(page: Control) -> void:
    var c := _career
    if c.history.is_empty():
        return
    var rows := c.history.slice(maxi(0, c.history.size() - 4))
    var rec := Mesa.objeto(Rect2(44, 512, 236, 46 + rows.size() * 26), -1.5, _draw_recorte)
    page.add_child(rec)
    var t := Paleta.etiqueta("RESULTADOS", "condensada_negra", 16, Paleta.TINTA_MESA, 2)
    t.position = Vector2(14, 8)
    rec.add_child(t)
    for i in rows.size():
        var h: Dictionary = rows[i]
        var rival := _league.get_team(h["rival_id"])
        var col := Paleta.TIMBRE_VERDE if h["gf"] > h["ga"] else (Paleta.TIMBRE_ROJO if h["gf"] < h["ga"] else Paleta.TINTA_MESA)
        var l := Paleta.etiqueta("S%d · %s %d-%d · %s" % [h["week"], String(rival.get("short_name", "?")).to_upper(),
                h["gf"], h["ga"], Mesa.plata(float(h["income"]))], "condensada", 15, col)
        l.position = Vector2(14, 34 + i * 26)
        rec.add_child(l)


# ================================================================== 2 · Entrenamiento y partido

func _build_entrenamiento(page: Control) -> void:
    var c := _career
    var open := c.block2_open()
    var rival := _league.get_team(c.rival_id)
    var training: Dictionary = c.data.get("training", {})
    if not open:
        _b2_view = ""
        _replace_for = -1
    var specs := {"tactical": [Rect2(40, 34, 226, 270), -1.0], "video": [Rect2(30, 344, 240, 140), 4.0],
        "physio": [Rect2(50, 536, 226, 120), -3.0]}
    for kind in Career.TRAINING_KINDS:
        var o := Mesa.objeto(specs[kind][0], specs[kind][1], _draw_entrenamiento.bind(kind), _on_training.bind(kind))
        o.disabled = not open
        o.tooltip_text = c.training_terms(kind)
        page.add_child(o)
        var fatiga := int(training.get(kind, {}).get("fatigue", 0))
        var tinta := Paleta.TIMBRE_NARANJA if fatiga > 0 else (Paleta.TIMBRE_VERDE if fatiga < 0 else
                (Paleta.TIMBRE_CLARO if kind == "video" else Paleta.TINTA_SEPIA))
        var stamp := Mesa.timbre("%+d" % fatiga if fatiga != 0 else "0", "bateria", tinta, -4.0, 19)
        o.add_child(stamp)
        var w := stamp.get_combined_minimum_size()
        var brown := Color("#3b3220")
        match kind:
            "tactical":
                stamp.position = Vector2(28, 182)
                var extra := Paleta.etiqueta("+1 LÁMINA", "condensada_negra", 16, brown)
                o.add_child(extra)
                extra.position = Vector2(202 - extra.get_minimum_size().x, 192)
                var dymo := Mesa.dymo("TÁCTICO", -1.5)
                dymo.position = Vector2(18, 226)
                o.add_child(dymo)
            "video":
                stamp.position = Vector2(228 - w.x, 92)
                var who := Mesa.plumon("vs %s · fecha %d" % [rival.get("short_name", "?"), c.week], 17, Paleta.PLUMON, 0.0, false)
                who.position = Vector2(26, 13)
                o.add_child(who)
                var what := Paleta.etiqueta("MEJORA 1 LÁMINA", "condensada_negra", 15, brown)
                what.position = Vector2(26, 42)
                o.add_child(what)
                var dymo := Mesa.dymo("VIDEO", -3.0)
                dymo.position = Vector2(-6, 122)
                o.add_child(dymo)
            "physio":
                stamp.position = Vector2(214 - w.x, 70)
                var cruz := Icono.crear("cruz", Paleta.ROJO_DIARIO, 16)
                cruz.position = Vector2(12, 8)
                o.add_child(cruz)
                var t := Paleta.etiqueta("FICHA MÉDICA", "condensada_negra", 16, Paleta.ROJO_DIARIO, 2)
                t.position = Vector2(34, 6)
                o.add_child(t)
                var what := Paleta.etiqueta("DESCANSO DEL PLANTEL", "condensada_negra", 16, Color("#2e2820"))
                what.position = Vector2(12, 40)
                o.add_child(what)
                var dymo := Mesa.dymo("KINESIOLOGÍA", 2.0)
                dymo.position = Vector2(10, 104)
                o.add_child(dymo)
        if c.training == kind:
            var pin := Mesa.chincheta(0, true, 34)
            pin.position = o.size - Vector2(48, 46)
            o.add_child(pin)
    if open and _b2_view == "" and not _deck_open:
        var pin := Mesa.chincheta(1)
        pin.position = Vector2(20, 16)
        page.add_child(pin)

    _b2_detail = Control.new()
    _b2_detail.size = MESA
    _b2_detail.mouse_filter = Control.MOUSE_FILTER_IGNORE
    page.add_child(_b2_detail)
    _training_status = Mesa.plumon("", 20, Paleta.PLUMON_CREMA, -1.5)
    _training_status.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    _training_status.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
    _training_status.position = Vector2(320, 392)
    _training_status.size = Vector2(600, 0)
    var torn := open and _b2_view == "tactical" and _replace_for < 0
    var album := _deck_open or (open and (_b2_view == "video" or _replace_for >= 0))
    if not album:
        _build_sobre(page, torn)
    if _deck_open:
        pass
    elif open and _b2_view == "tactical":
        _fill_offer()
    elif open and _b2_view == "video":
        _fill_video()
    elif open:
        _header(1, "¿qué entrenamos esta semana?")
    else:
        _fill_result()
    _b2_detail.add_child(_training_status)
    _build_deck_panel(page)

    _build_tv(page, rival)
    _build_pizarra(page)
    _build_entrada(page, rival)


# Chincheta numerada y lo que toca, escrito a mano arriba del centro de la mesa.
func _header(n: int, texto: String) -> void:
    var note := Mesa.plumon(texto, 26, Paleta.PLUMON_CREMA, -2.0)
    _b2_detail.add_child(note)
    var w := note.get_minimum_size().x
    var x := 620.0 - (w + 46.0) / 2.0
    var pin := Mesa.chincheta(n)
    pin.position = Vector2(x, 44)
    _b2_detail.add_child(pin)
    note.position = Vector2(x + 46, 44)


func _build_sobre(page: Control, torn: bool) -> void:
    var sobre := Mesa.objeto(Rect2(372, 476, 470, 214), -2.0, _draw_sobre.bind(torn), _on_view_deck)
    sobre.tooltip_text = "Ver tu mazo (%d láminas)" % _career.deck_size()
    page.add_child(sobre)
    var title := Mesa.placa_tv("LÁMINAS · " + _torneo(), 32, [Paleta.TV_FONDO], Paleta.DORADO)
    title.position = Vector2((470 - title.size.x) / 2.0, 118)
    sobre.add_child(title)
    var sub := Paleta.etiqueta("TU MAZO: %d DE %d" % [_career.deck_size(), DeckManager.DECK_MAX], "condensada_negra", 17, Color.WHITE, 3)
    Paleta.sombra_tv(sub)
    sobre.add_child(sub)
    sub.position = Vector2((470 - sub.get_minimum_size().x) / 2.0, 170)
    var ver := Mesa.dymo("VER MAZO", 3.0, 15)
    ver.position = Vector2(340, 40)
    sobre.add_child(ver)


# Entrenamiento táctico: las 3 láminas sobre el sobre abierto y "o ninguna"; con el mazo en su tope,
# después de elegir, cuál de tus láminas sale.
func _fill_offer() -> void:
    var c := _career
    if _replace_for >= 0:
        _fill_replace()
        return
    _header(2, "elige una lámina")
    if c.deck_full():
        var full := Mesa.plumon("tu mazo está lleno: la que elijas reemplaza a una tuya", 17, Paleta.PLUMON_ALERTA, -1.0)
        full.position = Vector2(380, 84)
        _b2_detail.add_child(full)
    var note := Mesa.plumon("abre el sobre", 19, Paleta.PLUMON_CREMA, -8.0)
    note.position = Vector2(270, 76)
    _b2_detail.add_child(note)
    var arrow := Control.new()
    arrow.mouse_filter = Control.MOUSE_FILTER_IGNORE
    arrow.draw.connect(func() -> void:
        var pts := Icono.bezier(Vector2(272, 168), Vector2(300, 128), Vector2(330, 118), Vector2(372, 132))
        arrow.draw_polyline(pts, Paleta.PLUMON_CREMA, 3.5, true)
        arrow.draw_polyline(PackedVector2Array([Vector2(358, 120), Vector2(374, 133), Vector2(356, 142)]), Paleta.PLUMON_CREMA, 3.5, true))
    _b2_detail.add_child(arrow)
    for i in c.training_offer.size():
        var id := String(c.training_offer[i])
        var ui := _lamina(Card.from_dict(_squads.catalog[id]), CardUI.TAMANO_SEMANA)
        ui.position = OFERTA[i][0]
        ui.pivot_offset = ui.size / 2.0
        ui.rotation = deg_to_rad(OFERTA[i][1])
        ui.chosen.connect(_on_offer_ui.bind(i))
        _b2_detail.add_child(ui)
        var copies := c.deck.filter(func(e): return e["id"] == id).size()
        if copies > 0:
            var have := Mesa.plumon("ya tienes %d" % copies, 17, Paleta.PLUMON_CREMA, -2.0)
            have.position = OFERTA[i][0] + Vector2(40, 272)
            _b2_detail.add_child(have)
    var none := Button.new()
    none.text = "o ninguna"
    none.flat = true
    none.add_to_group("ninguna")
    Paleta.estilo_texto(none, "plumon", 20, Paleta.PLUMON_CREMA)
    none.add_theme_color_override("font_hover_color", Color.WHITE)
    none.position = Vector2(770, 428)
    none.rotation = deg_to_rad(-4.0)
    none.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
    none.pressed.connect(_on_offer_declined)
    _b2_detail.add_child(none)


func _fill_replace() -> void:
    var c := _career
    var incoming := Card.from_dict(_squads.catalog[c.training_offer[_replace_for]])
    _header(2, "¿cuál sale para que entre %s?" % incoming.display_name)
    var grid := _album(_b2_detail, "tu mazo está en el tope (%d láminas)" % DeckManager.DECK_MAX,
            "ELIGE LA QUE DEJA SU LUGAR · LAS FIRMAS DE TUS TITULARES NO SALEN", "CANCELAR", _on_replace_cancel)
    for g in _deck_groups(false):
        var index: int = g["indices"][0]
        var ui := _lamina(g["card"], CardUI.TAMANO_MINI)
        _badge(ui, g["indices"].size())
        var reason := c.replace_error(_replace_for, index)
        if reason != "":
            ui.set_ribbon("NO SALE")
            ui.interactive = false
            ui.tooltip_text = "No puede salir: %s" % reason
        else:
            ui.chosen.connect(_on_replace_ui.bind(index))
        grid.add_child(ui)


# Sesión de video: tus láminas del DT con sus dos mejoras (las copias iguales en una: se mejora una).
func _fill_video() -> void:
    var c := _career
    var rival := _league.get_team(c.rival_id)
    _header(2, "elige una lámina y su mejora")
    var grid := _album(_b2_detail, "sesión de video · vs %s" % rival.get("short_name", "?"),
            "+%d DE ACIERTO EN TODAS SUS TIRADAS O %d PA MENOS · UNA MEJORA POR LÁMINA" % [
            roundi(CardDB.UPGRADE_BONUS * 100.0), CardDB.UPGRADE_AP], "", Callable())
    for g in _deck_groups(false):
        var index: int = g["indices"][0]
        var cell := VBoxContainer.new()
        cell.add_theme_constant_override("separation", 6)
        var ui := _lamina(g["card"], CardUI.TAMANO_MINI)
        ui.interactive = false
        _badge(ui, g["indices"].size())
        cell.add_child(ui)
        var mejora := String(c.deck[index]["mejora"])
        if mejora != "":
            ui.set_ribbon("YA MEJORADA")
            ui.tooltip_text += "\nYa mejorada: %s." % _upgrade_text(mejora)
        else:
            var row := HBoxContainer.new()
            row.add_theme_constant_override("separation", 4)
            for m in CardDB.UPGRADES:
                var b := _mejora_button(m)
                b.pressed.connect(_on_upgrade.bind(index, m))
                b.disabled = not c.can_upgrade(index, m)
                b.tooltip_text = "Mejora: %s." % _upgrade_text(m) if not b.disabled else \
                        "Solo láminas que cuestan %d PA o más." % CardDB.UPGRADE_AP
                row.add_child(b)
            cell.add_child(row)
        grid.add_child(cell)


# Timbre que se aprieta: +10 de acierto (mira) o −1 PA (moneda).
func _mejora_button(mejora: String) -> Button:
    var b := Button.new()
    b.add_to_group("mejora")
    b.text = "+%d" % roundi(CardDB.UPGRADE_BONUS * 100.0) if mejora == "acierto" else "−%d PA" % CardDB.UPGRADE_AP
    b.custom_minimum_size = Vector2(54, 32)
    b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    var tinta := Paleta.TIMBRE_VERDE if mejora == "acierto" else Color("#8a5a10")
    Paleta.estilo_texto(b, "condensada_negra", 16, tinta)
    for state in ["font_hover_color", "font_pressed_color", "font_focus_color", "font_hover_pressed_color"]:
        b.add_theme_color_override(state, tinta.darkened(0.3))
    b.add_theme_color_override("font_disabled_color", Color(Paleta.TINTA_SEPIA, 0.5))
    for state in ["normal", "hover", "pressed", "disabled", "focus"]:
        var sb := StyleBoxFlat.new()
        sb.bg_color = Color(1, 1, 1, 0.35 if state == "hover" else 0.0)
        sb.set_border_width_all(3)
        sb.border_color = Color(tinta, 0.35 if state == "disabled" else 0.9)
        sb.content_margin_left = 22
        sb.content_margin_right = 4
        b.add_theme_stylebox_override(state, sb)
    var icon := Icono.crear("mira" if mejora == "acierto" else "pa", tinta, 15)
    icon.position = Vector2(5, 8)
    b.add_child(icon)
    b.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
    return b


# Bloque 2 ya resuelto: la lámina que entró o se mejoró, sobre la mesa, y qué dejó la semana.
func _fill_result() -> void:
    var c := _career
    var t: Dictionary = c.data.get("training", {}).get(c.training, {})
    var cards := c.build_deck()
    if _b2_card >= 0 and _b2_card < cards.size() and c.training in ["tactical", "video"]:
        var ui := _lamina(cards[_b2_card], CardUI.TAMANO_SEMANA)
        ui.position = Vector2(532, 96)
        ui.interactive = false
        _b2_detail.add_child(ui)
        var st := Mesa.sello("AL MAZO" if c.training == "tactical" else "MEJORADA",
                Paleta.TIMBRE_VERDE if c.training == "tactical" else Paleta.TIMBRE_DORADO, -12.0, 26)
        st.position = Vector2(690, 120)
        _b2_detail.add_child(st)
        _training_status.position.y = 380
    else:
        _training_status.position.y = 300
    if c.training != "":
        _training_status.text = "%s · %s" % [t.get("name", c.training), _b2_result] if _b2_result != "" \
                else "%s: listo esta semana." % t.get("name", c.training)


# Ver mazo: todas las láminas del partido (las tuyas del DT y las firmas de los titulares).
func _build_deck_panel(page: Control) -> void:
    _deck_panel = Control.new()
    _deck_panel.size = MESA
    _deck_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
    _deck_panel.visible = _deck_open
    page.add_child(_deck_panel)
    if not _deck_open:
        _deck_list = GridContainer.new()
        _deck_panel.add_child(_deck_list)
        return
    var c := _career
    var cards := c.build_deck()
    var defense := cards.filter(func(card: Card) -> bool: return card.is_defensive()).size()
    _deck_list = _album(_deck_panel, "tu mazo: %d de %d" % [cards.size(), DeckManager.DECK_MAX],
            "%d DE ATAQUE · %d DE DEFENSA · ★ = DE UN JUGADOR DEL PLANTEL" % [cards.size() - defense, defense],
            "CERRAR", _on_view_deck)
    for g in _deck_groups(true):
        var card: Card = g["card"]
        var index: int = g["indices"][0]
        var ui := _lamina(card, CardUI.TAMANO_MINI)
        ui.interactive = false
        _badge(ui, g["indices"].size())
        if index >= c.deck.size():
            ui.tooltip_text += "\nFirma de %s (titular): no se saca ni se mejora." % \
                    _squads.find_player(c.team_id, card.owner_id).get("name", card.owner_id)
        elif String(c.deck[index]["mejora"]) != "":
            ui.tooltip_text += "\nMejorada: %s." % _upgrade_text(String(c.deck[index]["mejora"]))
        _deck_list.add_child(ui)


# Página del álbum con su título escrito a mano y una grilla de láminas chicas.
func _album(parent: Control, titulo: String, sub: String, boton: String, al_cerrar: Callable) -> GridContainer:
    var page := Mesa.objeto(Rect2(298, 92, 644, 604), 0.0, _draw_album)
    parent.add_child(page)
    var t := Mesa.plumon(titulo, 22, Paleta.PLUMON, -1.0, false)
    t.position = Vector2(24, 12)
    page.add_child(t)
    var s := Paleta.etiqueta(sub, "condensada", 15, Paleta.TINTA_SEPIA, 1)
    s.position = Vector2(26, 46)
    page.add_child(s)
    if boton != "":
        var b := Button.new()
        b.text = boton
        Paleta.estilo_texto(b, "condensada_negra", 16, Paleta.DYMO_LETRA, 3)
        var sb := Paleta.caja(Paleta.DYMO, 0, [Color(0, 0, 0, 0.5), 4, 3])
        sb.content_margin_left = 12
        sb.content_margin_right = 12
        for state in ["normal", "hover", "pressed", "focus"]:
            b.add_theme_stylebox_override(state, sb)
        b.rotation = deg_to_rad(1.5)
        b.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
        b.pressed.connect(al_cerrar)
        page.add_child(b)
        b.position = Vector2(644 - 24 - b.get_combined_minimum_size().x, 12)
    var scroll := ScrollContainer.new()
    scroll.position = Vector2(20, 76)
    scroll.size = Vector2(608, 512)
    scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
    page.add_child(scroll)
    var grid := GridContainer.new()
    grid.columns = 5
    grid.add_theme_constant_override("h_separation", 8)
    grid.add_theme_constant_override("v_separation", 12)
    scroll.add_child(grid)
    return grid


func _badge(ui: CardUI, count: int) -> void:
    if count <= 1:
        return
    var l := Paleta.etiqueta("×%d" % count, "condensada_negra", 16, Paleta.PAPEL_CREMA)
    var sb := Paleta.caja(Paleta.TINTA, 3)
    sb.content_margin_left = 6
    sb.content_margin_right = 6
    l.add_theme_stylebox_override("normal", sb)
    var w := Paleta.letra("condensada_negra").get_string_size(l.text, HORIZONTAL_ALIGNMENT_LEFT, -1, 16).x + 12.0
    l.position = Vector2(ui.custom_minimum_size.x - w - 2, ui.custom_minimum_size.y - 26)
    ui.add_child(l)


func _lamina(c: Card, tam: Vector2) -> CardUI:
    var ui: CardUI = CARD_SCENE.instantiate()
    ui.custom_minimum_size = tam
    ui.size = tam
    ui.setup(c, -1)
    return ui


# Televisor de tubo con la promo del domingo, y el informe del rival en un post-it.
func _build_tv(page: Control, rival: Dictionary) -> void:
    var c := _career
    var tv := Mesa.objeto(Rect2(952, 40, 300, 230), 0.0, _draw_tv)
    page.add_child(tv)
    var fecha := Mesa.placa_tv("FECHA %d" % c.week, 15, Paleta.PLACA_DORADA, Paleta.TV_FONDO)
    fecha.position = Vector2(20, 30)
    tv.add_child(fecha)
    var cuando := Mesa.placa_tv("ESTE DOMINGO", 15, Paleta.TV_AZUL, Color.WHITE)
    cuando.position = Vector2(18 + fecha.size.x, 30)
    tv.add_child(cuando)
    var mine := Escudo.crear(c.team(), 40)
    mine.position = Vector2(150 - 30 - mine.size.x, 66)
    tv.add_child(mine)
    var vs := Paleta.etiqueta("VS", "tv", 26, Color.WHITE)
    Paleta.sombra_tv(vs)
    tv.add_child(vs)
    vs.position = Vector2(150 - vs.get_minimum_size().x / 2.0, 68)
    if not rival.is_empty():
        var theirs := Escudo.crear(rival, 40)
        theirs.position = Vector2(180, 66)
        tv.add_child(theirs)
    var names := Paleta.etiqueta("%s · %s" % [String(c.team()["short_name"]).to_upper(),
            String(rival.get("short_name", "?")).to_upper()], "tv", 24, Color.WHITE)
    Paleta.sombra_tv(names)
    names.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    tv.add_child(names)
    var tam := 24
    while names.get_minimum_size().x > 256 and tam > 16:
        tam -= 2
        names.add_theme_font_size_override("font_size", tam)
    names.position = Vector2(16, 114)
    names.size = Vector2(268, 30)
    var stadium := Paleta.etiqueta(String(rival.get("stadium", "")).to_upper(), "condensada", 14, Paleta.TV_FONDO)
    stadium.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    stadium.clip_text = true
    stadium.position = Vector2(28, 169)
    stadium.size = Vector2(244, 20)
    tv.add_child(stadium)

    # Informe del rival: solo lo que el juego sabe (estilo y figura).
    var lines: Array = ["%s: %s" % [rival.get("short_name", "?"), rival.get("archetype", "?")]]
    if rival.get("signature_card") != null and String(rival["signature_card"]) != "":
        lines.append("ojo: %s" % Mesa.apellido(String(rival["signature_card"])))
    # Su mazo crece con la semana (T-06): mazo de inicio + week − 1 cartas de su crecimiento.
    lines.append("mazo: %d cartas" % _career.build_rival_deck().size())
    var post := Mesa.objeto(Rect2(1112, 232, 150, 104), 6.0, _draw_postit.bind(Paleta.POSTIT_AMARILLO))
    post.tooltip_text = "Rival: %s (%s) · DT %s" % [rival.get("name", "?"), rival.get("division", "?"), _league.dt_name(rival)]
    page.add_child(post)
    var l := Mesa.plumon("\n".join(lines), 15, Paleta.PLUMON, 0.0, false)
    l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
    l.position = Vector2(10, 8)
    l.size = Vector2(130, 0)
    post.add_child(l)


# Pizarra con imanes: tu once en la formación, ★ en los que tienen lámina propia, y la fatiga del plantel.
func _build_pizarra(page: Control) -> void:
    var c := _career
    var owners := {}
    for card in c.build_deck():
        owners[card.owner_id] = true
    var cols := _league.team_colors(c.team())
    var dark: Color = cols[0] if cols[0].get_luminance() < cols[1].get_luminance() else cols[1]
    var light: Color = cols[1] if dark == cols[0] else cols[0]
    _imanes = [dark, light]
    _pizarra.clear()
    var lines := {}
    var starters := _squads.pick_starters(c.team_id)
    for i in starters.size():
        var p: Dictionary = starters[i]
        _pizarra.append({"pos": PIZARRA[mini(i, PIZARRA.size() - 1)], "name": Mesa.apellido(String(p["name"])).to_upper(),
            "star": owners.has(p["id"]), "gk": i == 0})
        var line: String = SquadGenerator.LINES.get(String(p["role"]), "")
        if line != "POR":
            lines[line] = int(lines.get(line, 0)) + 1
    var board := Mesa.objeto(Rect2(948, 296, 310, 276), 0.0, _draw_pizarra)
    var start := c.start_stamina_preview()
    board.tooltip_text = "Tu once titular. ★ = tiene lámina propia en el mazo (Ejecutor Natural).\n" + \
            "Fatiga del plantel %d%%: sin cambios arrancas el partido con %d%% de estamina (%s, mano de %d)." % [
            int(c.fatigue), start["pct"], start["zone"], start["hand"]]
    page.add_child(board)
    var form := "-".join([lines.get("DEF", 0), lines.get("MED", 0), lines.get("DEL", 0)].map(func(v): return str(v)))
    var fl := Mesa.plumon(form, 18, Paleta.PLUMON, 0.0, false)
    fl.position = Vector2(14, 6)
    board.add_child(fl)
    var fat := Mesa.dymo("PLANTEL %d%%" % int(c.fatigue), 0.0, 15, "bateria", Color("#7ee0a1") if c.fatigue < 30.0 else Paleta.CUESTA_MAS)
    board.add_child(fat)
    fat.position = Vector2(296 - fat.get_combined_minimum_size().x, 8)


# Entrada al estadio: valida el mazo e inicia el partido; apagada con "falta el paso N".
func _build_entrada(page: Control, rival: Dictionary) -> void:
    var c := _career
    _go_button = Mesa.entrada(Rect2(954, 598, 300, 96), -2.0, "ENTRADA · DOMINGO", "IR AL PARTIDO",
            "N.º %06d" % c.week, 32, _on_go)
    _go_button.disabled = not _can_go()
    page.add_child(_go_button)
    var missing := _missing_steps()
    var text := ""
    var col := Paleta.PLUMON_ALERTA
    if c.pending_match:   # se cerró el juego durante el partido: se juega desde el principio
        text = "partido pendiente: se juega desde el principio"
    elif _check_text != "":
        text = _check_text
        col = Paleta.PLUMON_ALERTA if _check_bad else Color("#c9f5da")
    elif rival.is_empty():
        text = "sin rival disponible"
    elif not missing.is_empty():
        text = ("falta el paso %d" % missing[0]) if missing.size() == 1 else "faltan los pasos 1 y 2"
    else:
        text = "listo: vamos al estadio"
        col = Color("#c9f5da")
    _check_label = Mesa.plumon(text, 16, col, -2.0)
    _check_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
    _check_label.size = Vector2(300, 0)
    page.add_child(_check_label)
    _check_label.position = Vector2(968, 716 - _check_label.get_minimum_size().y)


# ================================================================== Pantalla inicial (sin carrera)

func _build_inicio(page: Control) -> void:
    var team := _league.get_team(_club_id)
    if team.is_empty():
        _club_id = DEFAULT_TEAM
        team = _league.get_team(_club_id)
    var t1 := Mesa.placa_tv("MODO CARRERA", 24, Paleta.PLACA_DORADA, Paleta.TV_FONDO)
    t1.position = Vector2(176, 30)
    page.add_child(t1)
    var t2 := Mesa.placa_tv(String(_league.get_league(Career.LEAGUE_ID).get("name", "Torneo")).to_upper(), 24, Paleta.TV_AZUL, Color.WHITE)
    t2.position = Vector2(174 + t1.size.x, 30)
    page.add_child(t2)

    # Carpeta con la ficha del club elegido.
    var folder := Mesa.objeto(Rect2(170, 92, 600, 560), -1.2, _draw_carpeta)
    page.add_child(folder)
    var tab := Mesa.dymo("FICHA DEL CLUB", -1.0, 16)
    tab.position = Vector2(40, 6)
    folder.add_child(tab)
    var crest := Escudo.crear(team, 150)
    crest.position = Vector2(56, 82)
    folder.add_child(crest)
    var name := Paleta.etiqueta(String(team.get("name", "")).to_upper(), "condensada_negra", 40, Paleta.TINTA_MESA)
    name.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
    name.add_theme_constant_override("line_spacing", -8)
    name.position = Vector2(206, 78)
    name.size = Vector2(340, 0)
    folder.add_child(name)
    var y := 78.0 + name.get_minimum_size().y + 6.0
    var facts := ["%s · %s" % [String(team.get("division", "")).to_upper(), String(team.get("archetype", "")).to_upper()],
        "DT: %s" % _league.dt_name(team).to_upper(), String(team.get("stadium", "")).to_upper()]
    if team.get("signature_card") != null:
        facts.append("FIGURA: %s" % String(team["signature_card"]).to_upper())
    for i in facts.size():
        var l := Paleta.etiqueta(facts[i], "condensada_negra" if i == 0 else "condensada", 20 if i == 0 else 16,
                Paleta.TINTA_MESA if i == 0 else Paleta.TINTA_SEPIA, 1)
        l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
        l.position = Vector2(206, y)
        l.size = Vector2(340, 0)
        folder.add_child(l)
        y += l.get_minimum_size().y + 2.0
    var pick := Mesa.plumon("elige tu club:", 20, Paleta.PLUMON, -1.0, false)
    pick.position = Vector2(56, 300)
    folder.add_child(pick)
    _club_option = OptionButton.new()
    _club_option.position = Vector2(56, 336)
    _club_option.size = Vector2(320, 46)
    Paleta.estilo_texto(_club_option, "condensada", 18, Paleta.TINTA_MESA)
    for state in ["font_hover_color", "font_pressed_color", "font_focus_color", "font_hover_pressed_color"]:
        _club_option.add_theme_color_override(state, Paleta.TINTA)
    for state in ["normal", "hover", "pressed", "focus"]:
        var sb := Paleta.caja(Paleta.PAPEL_CREMA if state != "hover" else Color("#fff8e6"), 3)
        sb.set_border_width_all(2)
        sb.border_color = Paleta.TINTA_SEPIA if state != "focus" else Paleta.DORADO
        sb.content_margin_left = 12
        _club_option.add_theme_stylebox_override(state, sb)
    for tm in _league.get_teams():
        if tm.get("suspended", false):
            continue
        _club_option.add_item("%s · %s · %s" % [tm["short_name"], tm["division"], tm["archetype"]])
        _club_option.set_item_metadata(_club_option.item_count - 1, tm["id"])
        if tm["id"] == _club_id:
            _club_option.select(_club_option.item_count - 1)
    _club_option.item_selected.connect(_on_club_selected)
    folder.add_child(_club_option)
    # La lámina de rasgo del estilo del club: la carta que trae su DT.
    var trait_id := String(CardDB.load_deck_lists().get("rasgos", {}).get(team.get("archetype", ""), ""))
    if _squads.catalog.has(trait_id):
        var lam := _lamina(Card.from_dict(_squads.catalog[trait_id]), CardUI.TAMANO_SEMANA)
        lam.interactive = false
        lam.position = Vector2(396, 262)
        lam.pivot_offset = CardUI.TAMANO_SEMANA / 2.0
        lam.rotation = deg_to_rad(4.0)
        folder.add_child(lam)
        var cap := Mesa.plumon("la lámina de rasgo de tu DT", 16, Paleta.PLUMON, 2.0, false)
        cap.position = Vector2(56, 470)
        folder.add_child(cap)
    var mazo := _squads.starter_templates(_club_id).size() + _squads.signature_count(_club_id)
    var deck_note := Mesa.plumon("mazo de inicio: %d láminas" % mazo, 18, Paleta.PLUMON, -1.0, false)
    deck_note.position = Vector2(56, 400)
    folder.add_child(deck_note)

    # Entradas: comenzar o continuar la carrera guardada.
    _start_button = Mesa.entrada(Rect2(830, 250, 340, 110), -2.0, "ENTRADA · CARRERA NUEVA", "COMENZAR CARRERA",
            "N.º 000001", 28, _on_start_career)
    page.add_child(_start_button)
    var head := "SIN CARRERA GUARDADA"
    var text := "CONTINUAR CARRERA"
    if _saved != null:
        head = "CARRERA GUARDADA · %s" % String(_saved.team()["short_name"]).to_upper()
        text = "CONTINUAR · SEMANA %d" % _saved.week
    _continue_button = Mesa.entrada(Rect2(840, 392, 340, 110), 1.5, head, text,
            "N.º %06d" % (_saved.week if _saved != null else 0), 26, _on_continue_career)
    _continue_button.disabled = _saved == null
    page.add_child(_continue_button)
    var status := _status_text if _status_text != "" else "Elige tu club y comienza la carrera."
    if _saved != null:
        status += " Comenzar una carrera nueva reemplaza la guardada."
    elif FileAccess.file_exists(Career.save_path):   # hay archivo pero no se pudo leer
        status += " No se pudo leer la carrera guardada: " + "; ".join(Career.last_load_errors)
    _status = Mesa.plumon(status, 18, Paleta.PLUMON_CREMA, -1.5)
    _status.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
    _status.position = Vector2(836, 530)
    _status.size = Vector2(360, 0)
    page.add_child(_status)


# ================================================================== Dibujos de la mesa

func _draw_calendario(b: Button) -> void:
    var s := b.size
    var hoja := Mesa.hoja_rota(Rect2(Vector2.ZERO, s))
    _sombra_poligono(b, hoja)
    b.draw_colored_polygon(hoja, Paleta.PAPEL_CALENDARIO)
    Paleta.dibujar_grano(b, Rect2(Vector2.ZERO, s))
    b.draw_rect(Rect2(0, 0, s.x, 40), Paleta.TIMBRE_ROJO)


func _draw_libreta(b: Button) -> void:
    var s := b.size
    Mesa.papel(b, Rect2(Vector2.ZERO, s), Paleta.PAPEL_LIBRETA, [Color(0, 0, 0, 0.55), 14, 10])
    for y in range(47, int(s.y), 34):
        b.draw_line(Vector2(0, y), Vector2(s.x, y), Paleta.LINEA_LIBRETA, 1.0)
    b.draw_line(Vector2(34, 0), Vector2(34, s.y), Paleta.MARGEN_LIBRETA, 2.0)
    for i in 7:
        var x := 10.0 + i * (206.0 / 6.0)
        b.draw_style_box(Paleta.caja(Paleta.ANILLO_LIBRETA, 5), Rect2(x, -8, 10, 16))


func _draw_diario(b: Button) -> void:
    var s := b.size
    Mesa.papel(b, Rect2(Vector2.ZERO, s), Paleta.PAPEL_DIARIO, [Color(0, 0, 0, 0.6), 22, 14])
    Mesa.cinta_adhesiva(b, Vector2(26, 8), -38.0)
    Mesa.cinta_adhesiva(b, Vector2(s.x - 26, 8), 36.0)
    b.draw_line(Vector2(26, 66), Vector2(s.x - 26, 66), Paleta.TINTA_MESA, 1.5)
    b.draw_line(Vector2(26, 71), Vector2(s.x - 26, 71), Paleta.TINTA_MESA, 1.5)
    # Foto en trama: la fiesta del plantel (siluetas, bola de espejos y una estrella).
    var r := _photo
    b.draw_rect(r, Paleta.FOTO_DIARIO)
    b.draw_texture_rect(Paleta.trama(), r, true, Color(Color("#2e2820"), 0.85))
    var k := Vector2(r.size.x / 508.0, r.size.y / 196.0)
    b.draw_set_transform(r.position, 0.0, k)
    var ink := Paleta.FOTO_TINTA
    b.draw_line(Vector2(254, 0), Vector2(254, 22), Color("#2e2820"), 2.0)
    b.draw_circle(Vector2(254, 44), 24, Color("#d9d0bb"), true, -1.0, true)
    for seg in [[Vector2(232, 36), Vector2(276, 36)], [Vector2(230, 48), Vector2(278, 48)], [Vector2(238, 26), Vector2(238, 62)],
            [Vector2(254, 20), Vector2(254, 68)], [Vector2(270, 26), Vector2(270, 62)]]:
        b.draw_line(seg[0], seg[1], Color("#6b604e"), 2.0)
    for p in [[110.0, 96.0, 20.0, 70.0, 150.0, 122.0], [210.0, 112.0, 18.0, 174.0, 246.0, 136.0], [330.0, 104.0, 19.0, 292.0, 368.0, 130.0]]:
        b.draw_circle(Vector2(p[0], p[1]), p[2], ink, true, -1.0, true)
        var body := Icono.bezier(Vector2(p[3], 196), Vector2(p[3] + 2, 150), Vector2(p[0] - 18, p[5]), Vector2(p[0], p[5]))
        body.append_array(Icono.bezier(Vector2(p[0], p[5]), Vector2(p[0] + 18, p[5]), Vector2(p[4] - 2, 150), Vector2(p[4], 196)))
        b.draw_colored_polygon(body, ink)
    for arm in [[Vector2(92, 128), Vector2(64, 70), Vector2(74, 66), Vector2(102, 122)], [Vector2(128, 128), Vector2(152, 72), Vector2(162, 76), Vector2(136, 132)],
            [Vector2(226, 140), Vector2(250, 92), Vector2(260, 97), Vector2(236, 146)], [Vector2(312, 136), Vector2(290, 86), Vector2(300, 82), Vector2(322, 132)],
            [Vector2(348, 136), Vector2(372, 88), Vector2(382, 93), Vector2(358, 142)]]:
        b.draw_colored_polygon(PackedVector2Array(arm), ink)
    b.draw_colored_polygon(PackedVector2Array([Vector2(440, 40), Vector2(452, 80), Vector2(494, 72), Vector2(460, 98), Vector2(482, 136),
            Vector2(444, 114), Vector2(410, 146), Vector2(422, 104), Vector2(380, 88), Vector2(424, 82)]), Color(Paleta.PAPEL_CALENDARIO, 0.92))
    b.draw_set_transform(Vector2.ZERO)


func _draw_contrato(b: Button, id: String, i: int) -> void:
    var s := b.size
    Mesa.papel(b, Rect2(Vector2.ZERO, s), Paleta.PAPEL_BLANCO, [Color(0, 0, 0, 0.6), 18, 12])
    var col: Color = SPONSOR_COLOR.get(id, Paleta.TINTA_MESA)
    b.draw_line(Vector2(18, 46), Vector2(s.x - 18, 46), col, 2.0)
    # Logo paródico de cada marca (una montaña nevada, unas ondas de teléfono).
    if id == "cerveza_glaciar":
        Icono.relleno(b, PackedVector2Array([Vector2(18, 38), Vector2(27, 22), Vector2(33, 30), Vector2(39, 18), Vector2(52, 38)]), Color("#7cc4ec"))
        b.draw_polyline(PackedVector2Array([Vector2(18, 38), Vector2(27, 22), Vector2(33, 30), Vector2(39, 18), Vector2(52, 38), Vector2(18, 38)]), col, 2.0, true)
    elif id == "telnet":
        b.draw_polyline(Icono.bezier(Vector2(22, 34), Vector2(28, 22), Vector2(42, 22), Vector2(48, 34)), col, 3.0, true)
        b.draw_polyline(Icono.bezier(Vector2(28, 38), Vector2(31, 31), Vector2(39, 31), Vector2(42, 38)), col, 3.0, true)
    var f := Paleta.letra("condensada")
    for j in 2:
        var y := 54.0 + j * 34.0 + 21.0
        var lw := f.get_string_size("POR SEMANA" if j == 0 else "POR VICTORIA", HORIZONTAL_ALIGNMENT_LEFT, -1, 17).x
        Mesa.linea_punteada(b, Vector2(18 + lw + 6, y), Vector2(s.x - 96, y), Paleta.PUNTEADO, 2.0, 4.0)
    if i == 1:   # clip sobre el segundo contrato
        var o := Vector2(26, -22)
        var clip := PackedVector2Array([o + Vector2(6, 44), o + Vector2(6, 10)])
        clip.append_array(_mover(Icono.bezier(Vector2(6, 10), Vector2(6, 4), Vector2(16, 4), Vector2(16, 10)), o))
        clip.append(o + Vector2(16, 50))
        clip.append_array(_mover(Icono.bezier(Vector2(16, 50), Vector2(16, 58), Vector2(4, 58), Vector2(4, 50)), o))
        clip.append(o + Vector2(4, 18))
        b.draw_polyline(clip, Color("#9aa3ab"), 2.6, true)


func _draw_postit(b: Button, colores: Array) -> void:
    var s := b.size
    b.draw_style_box(Paleta.caja(colores[1], 0, Paleta.SOMBRA_POSTIT), Rect2(Vector2.ZERO, s))
    b.draw_polygon(PackedVector2Array([Vector2.ZERO, Vector2(s.x, 0), s, Vector2(0, s.y)]),
            PackedColorArray([colores[0], colores[0], colores[1], colores[1]]))
    Paleta.dibujar_grano(b, Rect2(Vector2.ZERO, s), 0.6)


func _draw_recorte(b: Button) -> void:
    Mesa.papel(b, Rect2(Vector2.ZERO, b.size), Paleta.PAPEL_BLANCO, [Color(0, 0, 0, 0.5), 12, 8])


func _draw_entrenamiento(b: Button, kind: String) -> void:
    var s := b.size
    var elegido := _b2_view == kind or _career.training == kind
    match kind:
        "tactical":
            b.draw_style_box(Paleta.caja(Color("#8b5c31"), 12, Paleta.SOMBRA_OBJETO), Rect2(Vector2.ZERO, s))
            b.draw_polygon(PackedVector2Array([Vector2(12, 0), Vector2(s.x - 12, 0), Vector2(s.x - 12, s.y), Vector2(12, s.y)]),
                    PackedColorArray([Color(1, 1, 1, 0.08), Color(1, 1, 1, 0.08), Color(0, 0, 0, 0.1), Color(0, 0, 0, 0.1)]))
            var paper := Rect2(14, 26, 198, 196)
            Mesa.papel(b, paper, Paleta.PAPEL_LIBRETA, [Color(0, 0, 0, 0.3), 2, 1])
            var o := paper.position + Vector2(12, 26)
            var red := Paleta.TIMBRE_ROJO
            var navy := Paleta.PLUMON
            for x in [[Vector2(14, 20), Vector2(28, 34)], [Vector2(150, 14), Vector2(164, 28)]]:
                b.draw_line(o + x[0], o + x[1], red, 3.0, true)
                b.draw_line(o + Vector2(x[1].x, x[0].y), o + Vector2(x[0].x, x[1].y), red, 3.0, true)
            for p in [Vector2(40, 80), Vector2(96, 60), Vector2(150, 76)]:
                b.draw_arc(o + p, 9, 0, TAU, 24, navy, 3.0, true)
            var dash := PackedVector2Array()
            for p in Icono.bezier(Vector2(50, 76), Vector2(66, 64), Vector2(74, 62), Vector2(86, 62)):
                dash.append(o + p)
            for j in range(0, dash.size() - 1, 2):
                b.draw_line(dash[j], dash[j + 1], navy, 3.0, true)
            var curve := PackedVector2Array()
            for p in Icono.bezier(Vector2(104, 54), Vector2(130, 30), Vector2(160, 30), Vector2(184, 38)):
                curve.append(o + p)
            b.draw_polyline(curve, navy, 3.0, true)
            b.draw_polyline(PackedVector2Array([o + Vector2(174, 30), o + Vector2(185, 38), o + Vector2(174, 46)]), navy, 3.0, true)
            b.draw_polygon(PackedVector2Array([Vector2(63, -10), Vector2(163, -10), Vector2(163, 28), Vector2(63, 28)]),
                    PackedColorArray([Color("#e3e7ea"), Color("#e3e7ea"), Color("#7d858d"), Color("#7d858d")]))
        "video":
            b.draw_style_box(Paleta.caja(Color("#1f1f22"), 6, Paleta.SOMBRA_OBJETO), Rect2(Vector2.ZERO, s))
            Mesa.papel(b, Rect2(16, 12, 208, 56), Paleta.PAPEL_CALENDARIO, [Color(0, 0, 0, 0.2), 1, 1])
            b.draw_style_box(Paleta.caja(Color("#0c0c0d"), 18), Rect2(16, 82, 110, 36))
            for x in [35.0, 107.0]:
                b.draw_circle(Vector2(x, 100), 13, Color("#3a3a3d"), true, -1.0, true)
                b.draw_circle(Vector2(x, 100), 9, Color("#6d6d70"), true, -1.0, true)
                b.draw_circle(Vector2(x, 100), 4, Color.WHITE, true, -1.0, true)
        "physio":
            Mesa.papel(b, Rect2(Vector2.ZERO, s), Paleta.PAPEL_BLANCO, [Color(0, 0, 0, 0.55), 14, 10])
            b.draw_line(Vector2(0, 32), Vector2(s.x, 32), Paleta.ROJO_DIARIO, 2.0)
    if elegido:   # la opción abierta o elegida se marca con plumón dorado
        var ring := StyleBoxFlat.new()
        ring.draw_center = false
        ring.set_border_width_all(3)
        ring.border_color = Paleta.DORADO
        ring.set_corner_radius_all(14)
        b.draw_style_box(ring, Rect2(Vector2(-6, -6), s + Vector2(12, 12)))


func _draw_sobre(b: Button, torn: bool) -> void:
    var s := b.size
    var poly := PackedVector2Array()
    var teeth := 40
    for i in teeth + 1:
        var y := s.y * (0.0 if i % 2 == 1 else 0.08)
        if torn and i % 3 == 0:
            y += s.y * 0.03
        poly.append(Vector2(s.x * i / float(teeth), y))
    poly.append(s)
    poly.append(Vector2(0, s.y))
    _sombra_poligono(b, poly)
    b.draw_colored_polygon(poly, Color("#c8321f"))
    var d := Vector2(cos(deg_to_rad(30.0)), sin(deg_to_rad(30.0)))   # dirección de las franjas
    var perp := Vector2(-d.y, d.x)
    var paso := 52.0
    for i in range(-12, 14):
        var o := perp * (i * paso)
        var band := PackedVector2Array([o - d * 600.0, o + d * 600.0, o + d * 600.0 + perp * 26.0, o - d * 600.0 + perp * 26.0])
        for part in Geometry2D.intersect_polygons(poly, band):
            b.draw_colored_polygon(part, Color("#e2a21f"))
    var sheen := PackedVector2Array([Vector2(s.x * 0.36, 0), Vector2(s.x * 0.5, 0), Vector2(s.x * 0.44, s.y), Vector2(s.x * 0.3, s.y)])
    for part in Geometry2D.intersect_polygons(poly, sheen):
        b.draw_colored_polygon(part, Color(1, 1, 1, 0.22))
    if Mesa.encima(b):
        b.draw_polyline(poly + PackedVector2Array([poly[0]]), Paleta.DORADO, 3.0, true)


func _draw_tv(b: Button) -> void:
    var s := b.size
    b.draw_style_box(Paleta.caja(Color("#c9c1af"), 22, [Color(0, 0, 0, 0.75), 22, 14]), Rect2(Vector2.ZERO, s))
    var screen := Rect2(16, 16, s.x - 32, s.y - 46)
    var sb := Paleta.caja(Color("#15306a"), 16)
    sb.set_border_width_all(10)
    sb.border_color = Color(0.02, 0.05, 0.12, 0.85)
    sb.border_blend = true
    b.draw_style_box(sb, screen)
    var plate := Rect2(26, 168, s.x - 52, 22)
    b.draw_polygon(PackedVector2Array([plate.position, Vector2(plate.end.x, plate.position.y), plate.end, Vector2(plate.position.x, plate.end.y)]),
            PackedColorArray([Color(1, 1, 1, 0.92), Color(1, 1, 1, 0.92), Color(0.86, 0.89, 0.92, 0.92), Color(0.86, 0.89, 0.92, 0.92)]))
    for y in range(int(screen.position.y) + 4, int(screen.end.y) - 4, 3):
        b.draw_line(Vector2(screen.position.x + 6, y), Vector2(screen.end.x - 6, y), Color(0, 0, 0, 0.18), 1.0)
    var glare := PackedVector2Array()
    for j in 24:
        var a := TAU * j / 24.0
        glare.append(Vector2(90, 46) + Vector2(cos(a) * 80.0, sin(a) * 28.0))
    b.draw_colored_polygon(glare, Color(1, 1, 1, 0.07))
    for x in [s.x - 60.0, s.x - 40.0]:
        b.draw_circle(Vector2(x, s.y - 15), 6, Color("#8f8879"), true, -1.0, true)


func _draw_pizarra(b: Button) -> void:
    var s := b.size
    b.draw_style_box(Paleta.caja(Color("#b8bfc6"), 2, [Color(0, 0, 0, 0.7), 18, 12]), Rect2(Vector2.ZERO, s))
    b.draw_rect(Rect2(7, 7, s.x - 14, s.y - 14), Color("#eef1f2"))
    b.draw_rect(Rect2(7, 7, s.x - 14, s.y - 14), Color("#8a9299"), false, 1.0)
    var line := Color("#9fb3c8")
    var o := Vector2(7, 7)
    b.draw_rect(Rect2(o + Vector2(12, 34), Vector2(272, 194)), line, false, 1.5)
    b.draw_line(o + Vector2(12, 131), o + Vector2(284, 131), line, 1.5)
    b.draw_rect(Rect2(o + Vector2(98, 34), Vector2(100, 26)), line, false, 1.5)
    b.draw_rect(Rect2(o + Vector2(98, 202), Vector2(100, 26)), line, false, 1.5)
    var f := Paleta.letra("condensada")
    for p in _pizarra:
        var c: Vector2 = p["pos"]
        var col: Color = _imanes[1] if p["gk"] else _imanes[0]
        b.draw_circle(c + Vector2(0, 3), 11, Color(0, 0, 0, 0.4), true, -1.0, true)
        b.draw_texture_rect(Paleta.moneda([col.lightened(0.45), col, col.darkened(0.55)]), Rect2(c - Vector2(11, 11), Vector2(22, 22)), false)
        if p["star"]:
            b.draw_arc(c, 12.5, 0, TAU, 32, Paleta.DORADO, 2.5, true)
        var w := f.get_string_size(p["name"], HORIZONTAL_ALIGNMENT_LEFT, -1, Paleta.TEXTO_MIN).x
        var x := c.x - (w + (14.0 if p["star"] else 0.0)) / 2.0
        b.draw_string(f, Vector2(x, c.y + 28), p["name"], HORIZONTAL_ALIGNMENT_LEFT, -1, Paleta.TEXTO_MIN, Paleta.TINTA)
        if p["star"]:
            Icono.dibujar(b, "estrella", Rect2(x + w + 2, c.y + 16, 12, 12), Paleta.TIMBRE_DORADO)


func _draw_album(b: Button) -> void:
    var s := b.size
    Mesa.papel(b, Rect2(Vector2.ZERO, s), Color("#f3ead2"), [Color(0, 0, 0, 0.6), 22, 14], 3)
    b.draw_line(Vector2(24, 70), Vector2(s.x - 24, 70), Paleta.BORDE_PIE, 2.0)
    for corner in [Vector2.ZERO, Vector2(s.x, 0), s, Vector2(0, s.y)]:
        var dx := 1.0 if corner.x == 0.0 else -1.0
        var dy := 1.0 if corner.y == 0.0 else -1.0
        b.draw_colored_polygon(PackedVector2Array([corner, corner + Vector2(dx * 34, 0), corner + Vector2(0, dy * 34)]), Color("#2a2420"))


func _draw_carpeta(b: Button) -> void:
    var s := b.size
    b.draw_colored_polygon(PackedVector2Array([Vector2(20, -2), Vector2(230, -2), Vector2(250, 22), Vector2(20, 22)]), Color("#b99550"))
    b.draw_style_box(Paleta.caja(Color("#d9b77a"), 6, [Color(0, 0, 0, 0.65), 24, 14]), Rect2(0, 18, s.x, s.y - 18))
    Mesa.papel(b, Rect2(24, 50, s.x - 48, s.y - 74), Paleta.PAPEL_BLANCO, [Color(0, 0, 0, 0.35), 4, 2])
    Paleta.dibujar_grano(b, Rect2(0, 18, s.x, s.y - 18), 0.8)


func _mover(pts: PackedVector2Array, o: Vector2) -> PackedVector2Array:
    var out := PackedVector2Array()
    for p in pts:
        out.append(p + o)
    return out


func _sombra_poligono(ci: CanvasItem, poly: PackedVector2Array) -> void:
    for step in [[Vector2(0, 12), 0.18], [Vector2(0, 7), 0.22], [Vector2(0, 3), 0.25]]:
        var shadow := PackedVector2Array()
        for p in poly:
            shadow.append(p + step[0])
        ci.draw_colored_polygon(shadow, Color(0, 0, 0, step[1]))


# ================================================================== Mazo

# Cartas del mazo del partido agrupadas por nombre (las copias iguales en una, en el orden del mazo):
# [{card, indices}]. Los índices < deck.size() son tus cartas del DT; con firmas, también las de los
# titulares.
func _deck_groups(with_signatures: bool) -> Array:
    var cards := _career.build_deck()
    var groups: Array = []
    var by_name := {}
    for i in (cards.size() if with_signatures else _career.deck.size()):
        var c: Card = cards[i]
        if not by_name.has(c.display_name):
            by_name[c.display_name] = groups.size()
            groups.append({"card": c, "indices": []})
        groups[by_name[c.display_name]]["indices"].append(i)
    return groups


func _upgrade_text(mejora: String) -> String:
    return "+%d de acierto" % roundi(CardDB.UPGRADE_BONUS * 100.0) if mejora == "acierto" else "−%d PA" % CardDB.UPGRADE_AP


# ================================================================== Acciones

func _on_club_selected(index: int) -> void:
    _club_id = String(_club_option.get_item_metadata(index))
    _refresh()


func _on_start_career() -> void:
    var c := Career.new()
    if not c.setup(_league, _squads, _club_id):
        _status_text = "No se pudo iniciar la carrera: " + "; ".join(c.load_errors)
        _refresh()
        return
    Career.current = c
    _career = c
    _page = "prensa"
    _reset_block2_view()
    _save()   # reemplaza la carrera guardada
    _refresh()


func _on_continue_career() -> void:
    if _saved == null:
        return
    Career.current = _saved
    _career = _saved
    _saved = null
    _page = "prensa"
    _reset_block2_view()
    _refresh()


func _save() -> void:
    _check_text = ""
    if _career != null and not _career.save():
        push_warning("No se pudo guardar la carrera en %s" % Career.save_path)


func _on_sponsor(id: String) -> void:
    if _career == null:
        return
    _page = "prensa"
    if _career.choose_sponsor(id):
        _save()
    _refresh()


func _on_event(accept: bool) -> void:
    if _career == null:
        return
    _page = "prensa"
    _career.resolve_event(accept)
    _save()
    _refresh()


func _reset_block2_view() -> void:
    _b2_view = ""
    _replace_for = -1
    _b2_result = ""
    _b2_card = -1
    _deck_open = false


# Kinesiología se resuelve al tiro; táctico y video abren lo que piden elegir (nada se aplica hasta
# elegir la lámina o la mejora, y se puede cambiar de opción mientras tanto).
func _on_training(kind: String) -> void:
    _page = "entrenamiento"
    _deck_open = false
    if _career == null or not _career.block2_open():
        _refresh()
        return
    if kind == "physio":
        if _career.choose_physio():
            _b2_result = ""
            _b2_card = -1
            _save()
    else:
        _b2_view = kind
        _replace_for = -1
    _refresh()


func _on_offer_ui(_ui: CardUI, offer_index: int) -> void:
    _on_offer_chosen(offer_index)


func _on_offer_chosen(offer_index: int) -> void:
    if _career == null:
        return
    if _career.deck_full():
        _replace_for = offer_index   # primero hay que elegir cuál sale
        _refresh()
        return
    var name := String(_squads.catalog[_career.training_offer[offer_index]]["name"])
    if _career.take_offer(offer_index):
        _b2_result = "%s entra a tu mazo (%d láminas)." % [name, _career.deck_size()]
        _b2_card = _career.deck.size() - 1
        _save()
    _refresh()


func _on_replace_ui(_ui: CardUI, replace_index: int) -> void:
    _on_replace_chosen(replace_index)


func _on_replace_chosen(replace_index: int) -> void:
    if _career == null or _replace_for < 0:
        return
    var incoming := String(_squads.catalog[_career.training_offer[_replace_for]]["name"])
    var outgoing: String = _career.build_deck()[replace_index].display_name
    if _career.take_offer(_replace_for, replace_index):
        _b2_result = "%s entra a tu mazo y sale %s." % [incoming, outgoing]
        _b2_card = replace_index
        _save()
    _replace_for = -1
    _refresh()


func _on_replace_cancel() -> void:
    _replace_for = -1
    _refresh()


func _on_offer_declined() -> void:
    if _career != null and _career.decline_offer():
        _b2_result = "no tomaste ninguna lámina esta semana."
        _b2_card = -1
        _save()
    _refresh()


func _on_upgrade(index: int, mejora: String) -> void:
    if _career == null:
        return
    var name: String = _career.build_deck()[index].display_name
    if _career.upgrade_card(index, mejora):
        _b2_result = "%s queda mejorada: %s." % [name, _upgrade_text(mejora)]
        _b2_card = index
        _save()
    _refresh()


func _on_view_deck() -> void:
    _page = "entrenamiento"
    _deck_open = not _deck_open
    _refresh()


# La entrada: prepare_match() (validate_deck y el resto de las reglas) antes de abrir el partido.
func _on_go() -> void:
    if _career == null:
        return
    var r := _career.prepare_match()
    if not r["ok"]:
        _page = "entrenamiento"
        _check_text = "no se puede jugar: " + "; ".join(r["errors"])
        _check_bad = true
        _refresh()
        return
    var check: Dictionary = r["check"]
    var lines: Array = ["mazo válido: %d láminas · %d extranjeros · %d Sub-21" % [r["deck_size"], check["foreigners"], check["sub21"]]]
    lines.append_array(r["warnings"])
    _save()   # con pending_match: si se cierra el juego durante el partido, se vuelve a la entrada
    _check_text = "\n".join(lines)
    _check_bad = not r["warnings"].is_empty()
    if _check_label != null and is_instance_valid(_check_label):
        _check_label.text = _check_text
    get_tree().change_scene_to_file(MATCH_SCENE)
