extends Control

# Calendario semanal del modo carrera. La UI se construye por código; las reglas viven en Career.
#   Bloque 1 · Sponsor y prensa: contrato con un sponsor paródico y el evento social de la semana.
#   Bloque 2 · Entrenamiento o kinesiología.
#   Bloque 3 · El partido: valida el mazo (validate_deck) y abre match_view.
# La carrera se guarda sola (Career.save_path) tras cada acción de bloque y al volver del partido;
# "Continuar carrera" la recupera en la misma semana.

const MATCH_SCENE := "res://scenes/match_view.tscn"
const DEFAULT_TEAM := "colo_colo"
const COLOR_BG := Color("#0b1220")
const COLOR_PANEL := Color(0.03, 0.06, 0.12, 0.95)
const COLOR_GOLD := Color("#e3b341")
const COLOR_OK := Color("#3fb950")
const COLOR_WARN := Color("#f0883e")
const COLOR_BAD := Color("#f85149")
const COLOR_MUTED := Color("#9da7b3")
const NARROW_WIDTH := 1100.0   # por debajo, los bloques van en una columna

var _league: LeagueManager
var _squads: SquadManager
var _career: Career
var _saved: Career            # carrera guardada que ofrece "Continuar" (null = no hay o no es válida)

var _title: Label
var _status: Label
var _club_option: OptionButton
var _start_button: Button
var _continue_button: Button
var _blocks: GridContainer
var _block_panels: Array = []
var _sponsor_option: OptionButton
var _sponsor_terms: Label
var _event_title: Label
var _event_text: Label
var _event_terms: Label
var _accept_button: Button
var _decline_button: Button
var _event_result: Label
var _training_buttons := {}
var _training_status: Label
var _rival_label: Label
var _lineup_label: Label
var _check_label: Label
var _go_button: Button
var _history_label: Label


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
    _build_ui()
    resized.connect(_update_columns)
    _update_columns()
    _refresh()


# ================================================================== Construcción de la UI

func _flat(color: Color, radius: int = 10) -> StyleBoxFlat:
    var sb := StyleBoxFlat.new()
    sb.bg_color = color
    sb.set_corner_radius_all(radius)
    return sb


func _label(text: String, size: int = 16, color: Color = Color.WHITE) -> Label:
    var l := Label.new()
    l.text = text
    l.add_theme_font_size_override("font_size", size)
    l.add_theme_color_override("font_color", color)
    l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
    l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    return l


func _button(text: String, handler: Callable) -> Button:
    var b := Button.new()
    b.text = text
    b.custom_minimum_size = Vector2(0, 40)
    b.pressed.connect(handler)
    return b


func _block(title: String) -> VBoxContainer:
    var panel := PanelContainer.new()
    var sb := _flat(COLOR_PANEL)
    sb.border_color = COLOR_GOLD
    sb.border_width_top = 4
    sb.set_content_margin_all(16)
    panel.add_theme_stylebox_override("panel", sb)
    panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    panel.custom_minimum_size = Vector2(320, 0)
    var box := VBoxContainer.new()
    box.add_theme_constant_override("separation", 10)
    panel.add_child(box)
    box.add_child(_label(title, 18, COLOR_GOLD))
    _blocks.add_child(panel)
    _block_panels.append(panel)
    return box


func _build_ui() -> void:
    var bg := ColorRect.new()
    bg.color = COLOR_BG
    bg.set_anchors_preset(Control.PRESET_FULL_RECT)
    bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
    add_child(bg)

    var scroll := ScrollContainer.new()
    scroll.set_anchors_preset(Control.PRESET_FULL_RECT)
    scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
    add_child(scroll)
    var margin := MarginContainer.new()
    margin.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    for side in ["left", "right", "top", "bottom"]:
        margin.add_theme_constant_override("margin_" + side, 24)
    scroll.add_child(margin)
    var root := VBoxContainer.new()
    root.add_theme_constant_override("separation", 16)
    margin.add_child(root)

    _title = _label("MODO CARRERA", 30, COLOR_GOLD)
    root.add_child(_title)
    _status = _label("", 16, COLOR_MUTED)
    root.add_child(_status)

    var club_row := HBoxContainer.new()
    club_row.add_theme_constant_override("separation", 12)
    var club_label := _label("Tu club:", 16)
    club_label.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
    club_label.autowrap_mode = TextServer.AUTOWRAP_OFF   # en un espacio angosto se partiría letra por letra
    club_row.alignment = BoxContainer.ALIGNMENT_BEGIN
    club_row.add_child(club_label)
    _club_option = OptionButton.new()
    _club_option.custom_minimum_size = Vector2(320, 40)
    for t in _league.get_teams():
        if t.get("suspended", false):
            continue
        _club_option.add_item("%s · %s · %s" % [t["short_name"], t["division"], t["archetype"]])
        _club_option.set_item_metadata(_club_option.item_count - 1, t["id"])
        if t["id"] == DEFAULT_TEAM:
            _club_option.select(_club_option.item_count - 1)
    club_row.add_child(_club_option)
    _start_button = _button("COMENZAR CARRERA", _on_start_career)
    club_row.add_child(_start_button)
    _continue_button = _button("CONTINUAR CARRERA", _on_continue_career)
    club_row.add_child(_continue_button)
    root.add_child(club_row)

    _blocks = GridContainer.new()
    _blocks.add_theme_constant_override("h_separation", 16)
    _blocks.add_theme_constant_override("v_separation", 16)
    root.add_child(_blocks)

    # Bloque 1 · Sponsor y prensa
    var b1 := _block("BLOQUE 1 · SPONSOR Y PRENSA")
    b1.add_child(_label("Sponsor de la camiseta", 15, COLOR_MUTED))
    _sponsor_option = OptionButton.new()
    _sponsor_option.custom_minimum_size = Vector2(0, 40)
    _sponsor_option.item_selected.connect(_on_sponsor_selected)
    b1.add_child(_sponsor_option)
    _sponsor_terms = _label("", 14)
    b1.add_child(_sponsor_terms)
    b1.add_child(HSeparator.new())
    _event_title = _label("", 17, COLOR_GOLD)
    b1.add_child(_event_title)
    _event_text = _label("", 14)
    b1.add_child(_event_text)
    _event_terms = _label("", 14, COLOR_WARN)
    b1.add_child(_event_terms)
    var event_row := HBoxContainer.new()
    event_row.add_theme_constant_override("separation", 10)
    _accept_button = _button("Aceptar", _on_event.bind(true))
    _decline_button = _button("Rechazar", _on_event.bind(false))
    _accept_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    _decline_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    event_row.add_child(_accept_button)
    event_row.add_child(_decline_button)
    b1.add_child(event_row)
    _event_result = _label("", 14)
    b1.add_child(_event_result)

    # Bloque 2 · Entrenamiento y kinesiología
    var b2 := _block("BLOQUE 2 · ENTRENAMIENTO Y KINESIOLOGÍA")
    b2.add_child(_label("Una sesión por semana.", 15, COLOR_MUTED))
    var group := ButtonGroup.new()
    for kind in ["tactical", "physio"]:
        var b := _button("", _on_training.bind(kind))
        b.toggle_mode = true
        b.button_group = group
        b.alignment = HORIZONTAL_ALIGNMENT_LEFT
        b.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
        b.custom_minimum_size = Vector2(0, 56)
        _training_buttons[kind] = b
        b2.add_child(b)
    _training_status = _label("", 14, COLOR_MUTED)
    b2.add_child(_training_status)

    # Bloque 3 · El partido
    var b3 := _block("BLOQUE 3 · EL PARTIDO (DOMINGO)")
    _rival_label = _label("", 16)
    b3.add_child(_rival_label)
    _lineup_label = _label("", 14, COLOR_MUTED)
    b3.add_child(_lineup_label)
    _check_label = _label("", 14)
    b3.add_child(_check_label)
    _go_button = _button("IR AL PARTIDO", _on_go)
    _go_button.custom_minimum_size = Vector2(0, 52)
    b3.add_child(_go_button)

    _history_label = _label("", 14, COLOR_MUTED)
    root.add_child(_history_label)


func _update_columns() -> void:
    if _blocks != null:
        _blocks.columns = 1 if size.x < NARROW_WIDTH else 3


# ================================================================== Estado → UI

func _refresh() -> void:
    var active := _career != null
    _club_option.disabled = active
    if active:
        _select_club(_career.team_id)   # al continuar o volver del partido, el selector muestra tu club
    _start_button.visible = not active
    _continue_button.visible = not active
    for p in _block_panels:
        p.modulate = Color.WHITE if active else Color(1, 1, 1, 0.45)
    if not active:
        _title.text = "MODO CARRERA · TORNEO NACIONAL 2006"
        _status.text = "Elige tu club y comienza la carrera."
        _continue_button.disabled = _saved == null
        if _saved != null:
            _continue_button.text = "CONTINUAR · %s · SEMANA %d" % [_saved.team()["short_name"], _saved.week]
            _status.text += " Comenzar una carrera nueva reemplaza la guardada."
        else:
            _continue_button.text = "CONTINUAR CARRERA"
            if FileAccess.file_exists(Career.save_path):   # hay archivo pero no se pudo leer
                _status.text += " No se pudo leer la carrera guardada: " + "; ".join(Career.last_load_errors)
        _set_blocks_enabled(false)
        return

    var t := _career.team()
    _title.text = "MODO CARRERA · %s · SEMANA %d" % [String(t["short_name"]).to_upper(), _career.week]
    _status.text = "Presupuesto $%d M · Popularidad %d · Disciplina %d · Fatiga %d%% · DT: %s" % [
        int(_career.budget), _career.popularity, _career.discipline, int(_career.fatigue), _league.dt_name(t)]
    _refresh_block1()
    _refresh_block2()
    _refresh_block3()
    _refresh_history()


func _set_blocks_enabled(on: bool) -> void:
    _sponsor_option.disabled = not on
    _accept_button.disabled = not on
    _decline_button.disabled = not on
    for b in _training_buttons.values():
        b.disabled = not on
    _go_button.disabled = not on


func _refresh_block1() -> void:
    var locked := _career.pending_match
    _sponsor_option.clear()
    _sponsor_option.add_item("— Elige un sponsor —")
    for s in _career.sponsors():
        _sponsor_option.add_item(s["name"])
        _sponsor_option.set_item_metadata(_sponsor_option.item_count - 1, s["id"])
        if s["id"] == _career.sponsor_id:
            _sponsor_option.select(_sponsor_option.item_count - 1)
    _sponsor_option.disabled = locked
    var sponsor := _career.get_sponsor(_career.sponsor_id)
    _sponsor_terms.text = _career.sponsor_terms(sponsor) if not sponsor.is_empty() \
            else "Cada sponsor paga distinto según tu división e instalaciones."

    var ev := _career.week_event()
    _event_title.text = "EVENTO DE LA SEMANA · %s" % String(ev.get("title", "")).to_upper()
    _event_text.text = ev.get("text", "")
    _event_terms.text = _career.event_terms(ev)
    _accept_button.text = ev.get("accept_label", "Aceptar")
    _decline_button.text = ev.get("decline_label", "Rechazar")
    var resolved := not _career.event_result.is_empty()
    _accept_button.disabled = resolved or locked
    _decline_button.disabled = resolved or locked
    if resolved:
        _event_result.text = "\n".join(_career.event_result["lines"])
        _event_result.add_theme_color_override("font_color", COLOR_BAD if _career.event_result["funa"] else COLOR_OK)
    else:
        _event_result.text = ""


func _refresh_block2() -> void:
    for kind in _training_buttons:
        var b: Button = _training_buttons[kind]
        var chosen: bool = _career.training == kind
        b.text = ("✓ " if chosen else "") + _career.training_terms(kind)
        b.set_pressed_no_signal(chosen)
        for state in ["font_color", "font_pressed_color", "font_hover_pressed_color"]:
            b.add_theme_color_override(state, COLOR_GOLD if chosen else Color.WHITE)
        b.disabled = _career.pending_match
    var now := _career.start_stamina_preview()
    _training_status.text = ("Fatiga actual: %d%%. Sin cambios arrancarías con %d%% de estamina (%s, Mano: %d). " +
            "La estamina vuelve a ese valor en cada partido; la fatiga se arrastra y sube más si terminas agotado.") % [
            int(_career.fatigue), now["pct"], now["zone"], now["hand"]]


func _refresh_block3() -> void:
    var rival := _league.get_team(_career.rival_id)
    if rival.is_empty():
        _rival_label.text = "Sin rival disponible."
    else:
        _rival_label.text = "Rival: %s (%s) · %s · DT %s\nEstadio: %s" % [
            rival["name"], rival["division"], rival["archetype"], _league.dt_name(rival), rival.get("stadium", "?")]
    var owners := {}
    for c in _career.build_deck():
        owners[c.owner_id] = true
    var names: Array = []
    for p in _squads.pick_starters(_career.team_id):
        names.append(("★ " if owners.has(p["id"]) else "") + String(p["name"]) + " (" + String(p["role"]) + ")")
    _lineup_label.text = "Titulares: " + ", ".join(names) + "\n★ = tiene carta propia en el mazo (Ejecutor Natural)."
    var done := _career.blocks_done()
    var missing: Array = []
    if not done["block1"]:
        missing.append("Bloque 1")
    if not done["block2"]:
        missing.append("Bloque 2")
    _go_button.disabled = not missing.is_empty() or rival.is_empty()
    if _career.pending_match:   # se cerró el juego durante el partido: se juega desde el principio
        _check_label.text = "Partido pendiente: se juega desde el principio."
        _check_label.add_theme_color_override("font_color", COLOR_WARN)
    elif not missing.is_empty():
        _check_label.text = "Completa: " + ", ".join(missing) + "."
        _check_label.add_theme_color_override("font_color", COLOR_MUTED)
    elif _check_label.text == "" or _check_label.text.begins_with("Completa"):
        _check_label.text = "Listo para validar el mazo e ir al partido."
        _check_label.add_theme_color_override("font_color", COLOR_OK)


func _refresh_history() -> void:
    if _career.history.is_empty():
        _history_label.text = ""
        return
    var lines: Array = ["RESULTADOS"]
    for h in _career.history.slice(maxi(0, _career.history.size() - 5)):
        var rival := _league.get_team(h["rival_id"])
        lines.append("Semana %d · vs %s · %d-%d · ingreso $%d M" % [
            h["week"], rival.get("short_name", "?"), h["gf"], h["ga"], h["income"]])
    _history_label.text = "\n".join(lines)


# ================================================================== Acciones

func _on_start_career() -> void:
    var team_id: String = _club_option.get_item_metadata(_club_option.selected)
    var c := Career.new()
    if not c.setup(_league, _squads, team_id):
        _status.text = "No se pudo iniciar la carrera: " + "; ".join(c.load_errors)
        return
    Career.current = c
    _career = c
    _save()   # reemplaza la carrera guardada
    _set_blocks_enabled(true)
    _refresh()


func _on_continue_career() -> void:
    if _saved == null:
        return
    Career.current = _saved
    _career = _saved
    _saved = null
    _set_blocks_enabled(true)
    _refresh()


func _select_club(team_id: String) -> void:
    for i in _club_option.item_count:
        if _club_option.get_item_metadata(i) == team_id:
            _club_option.select(i)
            return


func _save() -> void:
    if _career != null and not _career.save():
        push_warning("No se pudo guardar la carrera en %s" % Career.save_path)


func _on_sponsor_selected(index: int) -> void:
    if _career == null or index <= 0:
        return
    if _career.choose_sponsor(String(_sponsor_option.get_item_metadata(index))):
        _save()
    _refresh()


func _on_event(accept: bool) -> void:
    if _career == null:
        return
    _career.resolve_event(accept)
    _save()
    _refresh()


func _on_training(kind: String) -> void:
    if _career == null:
        return
    if _career.choose_training(kind):
        _save()
    _refresh()


# Bloque 3: validate_deck() y el resto de las reglas antes de abrir el partido.
func _on_go() -> void:
    if _career == null:
        return
    var r := _career.prepare_match()
    if not r["ok"]:
        _check_label.text = "No se puede jugar:\n• " + "\n• ".join(r["errors"])
        _check_label.add_theme_color_override("font_color", COLOR_BAD)
        return
    var check: Dictionary = r["check"]
    var lines: Array = ["Mazo válido: %d cartas · %d extranjeros · %d Sub-21." % [r["deck_size"], check["foreigners"], check["sub21"]]]
    lines.append_array(r["warnings"])
    _check_label.text = "\n".join(lines)
    _check_label.add_theme_color_override("font_color", COLOR_WARN if not r["warnings"].is_empty() else COLOR_OK)
    _save()   # con pending_match: si se cierra el juego durante el partido, se vuelve al Bloque 3
    get_tree().change_scene_to_file(MATCH_SCENE)
