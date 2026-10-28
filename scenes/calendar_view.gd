extends Control

# Calendario semanal del modo carrera. La UI se construye por código; las reglas viven en Career.
#   Bloque 1 · Sponsor y prensa: contrato con un sponsor paródico y el evento social de la semana.
#   Bloque 2 · UNA por semana (D-21): entrenamiento táctico (1 de 3 cartas nuevas; con el mazo en su
#              tope, eliges cuál sale), sesión de video (mejorar una carta) o kinesiología.
#              "Ver mazo" muestra tu mazo actual.
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
var _event_confirm_button: Button
var _event_preview: Label
var _event_result: Label
var _event_pick: int = -1   # -1: sin elegir, 0: rechazar, 1: aceptar
var _training_buttons := {}
var _training_status: Label
var _training_impact: Label
var _training_reco: Label
var _b2_detail: VBoxContainer   # lo que pide la opción abierta: las cartas ofrecidas o tu mazo para el video
var _b2_view := ""              # opción del Bloque 2 abierta y sin resolver ("tactical" | "video")
var _replace_for := -1          # carta de la oferta que espera elegir cuál sale (mazo en su tope)
var _b2_result := ""            # qué dejó el Bloque 2 al resolverse (solo en pantalla)
var _deck_button: Button
var _deck_panel: PanelContainer
var _deck_title: Label
var _deck_list: VBoxContainer
var _deck_open := false
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


func _interactive_card_button(text: String, handler: Callable, tint: Color = Color("#1f2a3b")) -> Button:
    var b := _button(text, handler)
    b.alignment = HORIZONTAL_ALIGNMENT_LEFT
    b.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
    b.custom_minimum_size = Vector2(0, 56)
    var normal := _flat(tint, 6)
    normal.border_color = tint.lightened(0.35)
    normal.set_border_width_all(2)
    var hover := _flat(tint.lightened(0.08), 6)
    hover.border_color = COLOR_GOLD
    hover.set_border_width_all(2)
    var pressed := _flat(tint.lightened(0.14), 6)
    pressed.border_color = COLOR_GOLD
    pressed.set_border_width_all(3)
    b.add_theme_stylebox_override("normal", normal)
    b.add_theme_stylebox_override("hover", hover)
    b.add_theme_stylebox_override("pressed", pressed)
    b.add_theme_stylebox_override("focus", hover)
    b.mouse_entered.connect(func() -> void:
        create_tween().tween_property(b, "scale", Vector2(1.02, 1.02), 0.08))
    b.mouse_exited.connect(func() -> void:
        create_tween().tween_property(b, "scale", Vector2.ONE, 0.08))
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
    _accept_button = _interactive_card_button("Aceptar", _on_event_pick.bind(true), Color("#2f3b1f"))
    _decline_button = _interactive_card_button("Rechazar", _on_event_pick.bind(false), Color("#3d2a1f"))
    _accept_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    _decline_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    event_row.add_child(_accept_button)
    event_row.add_child(_decline_button)
    b1.add_child(event_row)
    _event_preview = _label("", 14, COLOR_GOLD)
    b1.add_child(_event_preview)
    _event_confirm_button = _button("CONFIRMAR DECISIÓN", _on_event_confirm)
    _event_confirm_button.custom_minimum_size = Vector2(0, 44)
    b1.add_child(_event_confirm_button)
    _event_result = _label("", 14)
    b1.add_child(_event_result)

    # Bloque 2 · Entrenamiento táctico, sesión de video o kinesiología
    var b2 := _block("BLOQUE 2 · ENTRENAMIENTO, VIDEO O KINESIOLOGÍA")
    b2.add_child(_label("Elige UNA por semana: una carta nueva, mejorar una carta o descansar.", 15, COLOR_MUTED))
    for kind in Career.TRAINING_KINDS:
        var b := _interactive_card_button("", _on_training.bind(kind), Color("#243246"))
        b.toggle_mode = true
        b.alignment = HORIZONTAL_ALIGNMENT_LEFT
        b.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
        b.custom_minimum_size = Vector2(0, 56)
        _training_buttons[kind] = b
        b2.add_child(b)
    _b2_detail = VBoxContainer.new()
    _b2_detail.add_theme_constant_override("separation", 8)
    b2.add_child(_b2_detail)
    _training_status = _label("", 14, COLOR_MUTED)
    b2.add_child(_training_status)
    _training_impact = _label("", 14, COLOR_GOLD)
    b2.add_child(_training_impact)
    _training_reco = _label("", 14, COLOR_OK)
    b2.add_child(_training_reco)
    _deck_button = _button("VER MAZO", _on_view_deck)
    b2.add_child(_deck_button)

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

    # Ver mazo: tu mazo actual (cartas, mejoras, tamaño), a lo ancho bajo los bloques.
    _deck_panel = PanelContainer.new()
    var deck_sb := _flat(COLOR_PANEL)
    deck_sb.border_color = COLOR_GOLD
    deck_sb.border_width_top = 4
    deck_sb.set_content_margin_all(16)
    _deck_panel.add_theme_stylebox_override("panel", deck_sb)
    _deck_panel.visible = false
    var deck_box := VBoxContainer.new()
    deck_box.add_theme_constant_override("separation", 6)
    _deck_panel.add_child(deck_box)
    _deck_title = _label("", 18, COLOR_GOLD)
    deck_box.add_child(_deck_title)
    _deck_list = VBoxContainer.new()
    _deck_list.add_theme_constant_override("separation", 4)
    deck_box.add_child(_deck_list)
    root.add_child(_deck_panel)

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
        _deck_panel.visible = false
        return

    var t := _career.team()
    _title.text = "MODO CARRERA · %s · SEMANA %d" % [String(t["short_name"]).to_upper(), _career.week]
    _status.text = "Presupuesto $%d M · Popularidad %d · Disciplina %d · Fatiga %d%% · DT: %s" % [
        int(_career.budget), _career.popularity, _career.discipline, int(_career.fatigue), _league.dt_name(t)]
    _refresh_block1()
    _refresh_block2()
    _refresh_block3()
    _refresh_deck_panel()
    _refresh_history()


func _set_blocks_enabled(on: bool) -> void:
    _sponsor_option.disabled = not on
    _accept_button.disabled = not on
    _decline_button.disabled = not on
    _event_confirm_button.disabled = not on
    for b in _training_buttons.values():
        b.disabled = not on
    _deck_button.disabled = not on
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
    _event_confirm_button.disabled = resolved or locked or _event_pick < 0
    if not resolved:
        _event_result.text = ""
        _event_preview.text = _event_preview_text(ev, _event_pick)
        _event_preview.add_theme_color_override("font_color", COLOR_GOLD if _event_pick >= 0 else COLOR_MUTED)
        _accept_button.text = ("✓ " if _event_pick == 1 else "") + _accept_button.text
        _decline_button.text = ("✓ " if _event_pick == 0 else "") + _decline_button.text
        if _event_pick >= 0:
            _event_confirm_button.text = "CONFIRMAR: " + ("DAR PERMISO" if _event_pick == 1 else "CONCENTRACIÓN EN HOTEL")
        else:
            _event_confirm_button.text = "CONFIRMAR DECISIÓN"
    if resolved:
        _event_pick = -1
        _event_result.text = "\n".join(_career.event_result["lines"])
        _event_result.add_theme_color_override("font_color", COLOR_BAD if _career.event_result["funa"] else COLOR_OK)
        _event_preview.text = ""
        _event_confirm_button.text = "DECISIÓN CERRADA"


func _event_preview_text(ev: Dictionary, pick: int) -> String:
    if pick < 0:
        return "Elige una opción para ver su impacto inmediato en popularidad, disciplina y riesgo."
    if pick == 1:
        var reward: Dictionary = ev.get("reward", {})
        var risk: Dictionary = ev.get("risk", {})
        return "Si aceptas: +%d%% acierto (Momentos 1-%d) · popularidad %+d.\nRiesgo de funa %d%%: disciplina %+d y titular con +%d%% desgaste." % [
            roundi(float(reward.get("opening_bonus", 0.0)) * 100.0),
            int(reward.get("opening_moments", 2)),
            int(reward.get("popularity", 0)),
            roundi(float(risk.get("chance", 0.0)) * 100.0),
            int(risk.get("discipline", 0)),
            roundi(float(risk.get("funado_stamina_extra", 0.5)) * 100.0)]
    var dec: Dictionary = ev.get("decline", {})
    return "Si rechazas: disciplina %+d · popularidad %+d · sin riesgo de funa." % [
        int(dec.get("discipline", 0)), int(dec.get("popularity", 0))]


func _refresh_block2() -> void:
    var open := _career.block2_open()
    if not open:
        _b2_view = ""
        _replace_for = -1
    for kind in _training_buttons:
        var b: Button = _training_buttons[kind]
        var chosen: bool = _career.training == kind
        var shown: bool = chosen or _b2_view == kind
        b.text = ("✓ " if chosen else "") + _career.training_terms(kind)
        b.set_pressed_no_signal(shown)
        for state in ["font_color", "font_pressed_color", "font_hover_pressed_color"]:
            b.add_theme_color_override(state, COLOR_GOLD if shown else Color.WHITE)
        b.disabled = not open
    _clear(_b2_detail)
    if _b2_view == "tactical":
        _fill_offer()
    elif _b2_view == "video":
        _fill_video()
    var now := _career.start_stamina_preview()
    var done := ""
    if _career.training != "":
        var t: Dictionary = _career.data.get("training", {}).get(_career.training, {})
        done = "✓ Bloque 2: %s. %s\n" % [t.get("name", _career.training), _b2_result]
    _training_status.text = done + ("Fatiga actual: %d%%. Sin cambios arrancarías con %d%% de estamina (%s, Mano: %d). " +
            "La estamina vuelve a ese valor en cada partido; la fatiga se arrastra y sube más si terminas agotado.") % [
            int(_career.fatigue), now["pct"], now["zone"], now["hand"]]
    _training_impact.text = _training_impact_text()
    _training_reco.text = _training_recommendation()
    _deck_button.disabled = false
    _deck_button.text = "OCULTAR MAZO" if _deck_open else "VER MAZO (%d CARTAS)" % _career.deck_size()


func _training_impact_text() -> String:
    var kind := _career.training if _career.training != "" else _b2_view
    if kind == "":
        return "Impacto neto: elige una opción para comparar beneficio hoy vs costo para el partido."
    var t: Dictionary = _career.data.get("training", {}).get(kind, {})
    var fatigue_delta := int(t.get("fatigue", 0))
    var after := _career.start_stamina_preview(float(fatigue_delta))
    var benefit := ""
    match kind:
        "tactical":
            benefit = "Beneficio hoy: +1 carta al mazo (o reemplazo en tope)."
        "video":
            benefit = "Beneficio hoy: mejoras 1 carta (+acierto o −PA)."
        _:
            benefit = "Beneficio hoy: recuperación física inmediata."
    return "%s Costo para el partido: fatiga %+d → arrancas con %d%% (%s, Mano: %d)." % [
        benefit, fatigue_delta, after["pct"], after["zone"], after["hand"]]


func _training_recommendation() -> String:
    var now := _career.start_stamina_preview()
    if _career.training != "":
        return "Bloque 2 resuelto. Enfócate en preparar el partido."
    if _career.fatigue >= 60.0:
        return "Recomendación: estás muy cargado (%d%% fatiga). Kinesiología te ayuda a no llegar agotado." % int(_career.fatigue)
    if now["zone"] != "ÓPTIMO":
        return "Recomendación: prioriza recuperación o video antes de sumar más carga táctica."
    return "Recomendación: estás en buena zona física. Táctico o video son opciones seguras."


# Entrenamiento táctico: las cartas ofrecidas y "No tomar ninguna"; con el mazo en su tope, después
# de elegir, cuál de tus cartas sale.
func _fill_offer() -> void:
    if _replace_for >= 0:
        _fill_replace()
        return
    _b2_detail.add_child(_label("Te ofrecen estas cartas: elige una (tu mazo: %d de %d)." % [
            _career.deck_size(), DeckManager.DECK_MAX], 14, COLOR_GOLD))
    if _career.deck_full():
        _b2_detail.add_child(_label("Tu mazo está en el tope: la que elijas reemplaza a una de tus cartas.", 14, COLOR_WARN))
    for i in _career.training_offer.size():
        var id := String(_career.training_offer[i])
        var copies := _career.deck.filter(func(e): return e["id"] == id).size()
        var text := _card_text(Card.from_dict(_squads.catalog[id]))
        if copies > 0:
            text += "\nYa tienes %d en el mazo." % copies
        _b2_detail.add_child(_choice_button(text, _on_offer_chosen.bind(i)))
    _b2_detail.add_child(_interactive_card_button("No tomar ninguna", _on_offer_declined, Color("#263246")))


func _fill_replace() -> void:
    var incoming := Card.from_dict(_squads.catalog[_career.training_offer[_replace_for]])
    _b2_detail.add_child(_label("Tu mazo está en el tope (%d). Elige cuál de tus cartas sale para que entre %s:" % [
            DeckManager.DECK_MAX, incoming.display_name], 14, COLOR_WARN))
    for g in _deck_groups(false):
        var index: int = g["indices"][0]
        var reason := _career.replace_error(_replace_for, index)
        var text := "Sacar %s%s" % [g["card"].display_name, " (tienes %d)" % g["indices"].size() if g["indices"].size() > 1 else ""]
        if reason != "":
            text += "\nNo se puede: %s" % reason
        var b := _choice_button(text, _on_replace_chosen.bind(index))
        b.disabled = reason != ""
        _b2_detail.add_child(b)
    _b2_detail.add_child(_interactive_card_button("Cancelar", _on_replace_cancel, Color("#263246")))


# Sesión de video: tus cartas del DT con sus dos mejoras (las copias iguales en una fila: se mejora una).
func _fill_video() -> void:
    _b2_detail.add_child(_label("Elige una carta y su mejora (una por carta): +%d%% de acierto en todas sus tiradas o %d PA menos." % [
            roundi(CardDB.UPGRADE_BONUS * 100.0), CardDB.UPGRADE_AP], 14, COLOR_GOLD))
    for g in _deck_groups(false):
        var index: int = g["indices"][0]
        var count: int = g["indices"].size()
        _b2_detail.add_child(_label(_card_text(g["card"]) + (" · tienes %d" % count if count > 1 else ""), 13))
        var mejora := String(_career.deck[index]["mejora"])
        if mejora != "":
            _b2_detail.add_child(_label("Ya mejorada: %s." % _upgrade_text(mejora), 13, COLOR_MUTED))
            continue
        var row := HBoxContainer.new()
        row.add_theme_constant_override("separation", 8)
        for m in CardDB.UPGRADES:
            var b := _interactive_card_button(_upgrade_text(m), _on_upgrade.bind(index, m), Color("#243246"))
            b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
            b.disabled = not _career.can_upgrade(index, m)
            if b.disabled:
                b.tooltip_text = "Solo cartas que cuestan %d PA o más." % CardDB.UPGRADE_AP
            row.add_child(b)
        _b2_detail.add_child(row)


# Ver mazo: todas las cartas del partido (las tuyas del DT y las firmas de los titulares), con sus mejoras.
func _refresh_deck_panel() -> void:
    _deck_panel.visible = _deck_open
    if not _deck_open:
        return
    _clear(_deck_list)
    var cards := _career.build_deck()
    var defense := cards.filter(func(c: Card) -> bool: return c.is_defensive()).size()
    _deck_title.text = "TU MAZO · %d CARTAS (TOPE %d) · %d DE ATAQUE Y %d DE DEFENSA" % [
            cards.size(), DeckManager.DECK_MAX, cards.size() - defense, defense]
    for g in _deck_groups(true):
        var c: Card = g["card"]
        var index: int = g["indices"][0]
        var text := "×%d  %s" % [g["indices"].size(), _card_text(c).replace("\n", " · ")]
        if index >= _career.deck.size():
            text += " · firma de %s (titular)" % _squads.find_player(_career.team_id, c.owner_id).get("name", c.owner_id)
        elif String(_career.deck[index]["mejora"]) != "":
            text += " · mejorada: %s" % _upgrade_text(String(_career.deck[index]["mejora"]))
        _deck_list.add_child(_label(text, 14, COLOR_GOLD if c.type == Card.Type.ELITE else Color.WHITE))
    _deck_list.add_child(_label("★ = carta de un jugador del plantel (Ejecutor Natural si es titular). Las firmas de tus titulares no se sacan ni se mejoran.", 13, COLOR_MUTED))


# Cartas del mazo del partido agrupadas por nombre (las copias iguales en una fila, en el orden del
# mazo): [{card, indices}]. Los índices < deck.size() son tus cartas del DT; con firmas, también las de
# los titulares.
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


# Una carta en dos líneas: nombre, tipo y jugada; PA, bono de acierto, desgaste y efecto (lo mismo
# que muestra la carta en el partido, sin los modificadores del rival).
func _card_text(c: Card) -> String:
    var head := "%s%s · %s · %s" % [c.display_name, " ★" if c.owner_id != "" else "",
            CardUI.TYPE_NAMES[c.type], CardUI.KIND_NAMES.get(c.kind, "")]
    var wear := "Recupera %d%% Est." % roundi(MatchEngine.PAUSE_STAMINA_PCT * 100.0) if c.kind == Card.Kind.PAUSE \
            else "Desgaste %d Est." % roundi(c.stamina_cost * MatchEngine.STAMINA_SCALE)
    var stats := "%d PA · %+d%% de acierto · %s" % [c.ap_cost, roundi(c.bonus * 100.0), wear]
    var effect := CardUI.effect_text(c)
    return head + "\n" + stats + ("" if effect == "" else " · " + effect)


func _upgrade_text(mejora: String) -> String:
    return "+%d%% de acierto" % roundi(CardDB.UPGRADE_BONUS * 100.0) if mejora == "acierto" else "−%d PA" % CardDB.UPGRADE_AP


func _choice_button(text: String, handler: Callable) -> Button:
    return _interactive_card_button(text, handler, Color("#263246"))


func _clear(box: Container) -> void:
    for child in box.get_children():
        box.remove_child(child)
        child.queue_free()


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
    _reset_block2_view()
    _save()   # reemplaza la carrera guardada
    _set_blocks_enabled(true)
    _refresh()


func _on_continue_career() -> void:
    if _saved == null:
        return
    Career.current = _saved
    _career = _saved
    _saved = null
    _reset_block2_view()
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


func _on_event_pick(accept: bool) -> void:
    _event_pick = 1 if accept else 0
    _refresh()


func _on_event_confirm() -> void:
    if _career == null:
        return
    if _event_pick < 0:
        return
    _career.resolve_event(_event_pick == 1)
    _event_pick = -1
    _save()
    _refresh()


func _reset_block2_view() -> void:
    _b2_view = ""
    _replace_for = -1
    _b2_result = ""


# Kinesiología se resuelve al tiro; táctico y video abren lo que piden elegir (nada se aplica hasta
# elegir la carta o la mejora, y se puede cambiar de opción mientras tanto).
func _on_training(kind: String) -> void:
    if _career == null or not _career.block2_open():
        _refresh()
        return
    if kind == "physio":
        if _career.choose_physio():
            _b2_result = ""
            _save()
    else:
        _b2_view = kind
        _replace_for = -1
    _refresh()


func _on_offer_chosen(offer_index: int) -> void:
    if _career == null:
        return
    if _career.deck_full():
        _replace_for = offer_index   # primero hay que elegir cuál sale
        _refresh()
        return
    var name := String(_squads.catalog[_career.training_offer[offer_index]]["name"])
    if _career.take_offer(offer_index):
        _b2_result = "%s entra a tu mazo (%d cartas)." % [name, _career.deck_size()]
        _save()
    _refresh()


func _on_replace_chosen(replace_index: int) -> void:
    if _career == null or _replace_for < 0:
        return
    var incoming := String(_squads.catalog[_career.training_offer[_replace_for]]["name"])
    var outgoing: String = _career.build_deck()[replace_index].display_name
    if _career.take_offer(_replace_for, replace_index):
        _b2_result = "%s entra a tu mazo y sale %s." % [incoming, outgoing]
        _save()
    _replace_for = -1
    _refresh()


func _on_replace_cancel() -> void:
    _replace_for = -1
    _refresh()


func _on_offer_declined() -> void:
    if _career != null and _career.decline_offer():
        _b2_result = "No tomaste ninguna carta esta semana."
        _save()
    _refresh()


func _on_upgrade(index: int, mejora: String) -> void:
    if _career == null:
        return
    var name: String = _career.build_deck()[index].display_name
    if _career.upgrade_card(index, mejora):
        _b2_result = "%s queda mejorada: %s." % [name, _upgrade_text(mejora)]
        _save()
    _refresh()


func _on_view_deck() -> void:
    _deck_open = not _deck_open
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
