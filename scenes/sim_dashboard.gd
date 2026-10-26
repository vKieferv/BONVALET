extends Control

# Dashboard de simulación (Duelo 1v1 + Liga). La UI se construye por código.
# Layout adaptable: todo vive dentro de un ScrollContainer, los grupos de paneles
# son GridContainer que cambian de columnas según el ancho, y los textos largos hacen wrap.

const MATCH_OPTIONS := [100, 1000, 5000]
const COLOR_GOAL := Color("#3fb950")
const COLOR_FLOW := Color("#39c5cf")
const COLOR_TIRED := Color("#f0883e")
const COLOR_INJURY := Color("#f85149")
const COLOR_MUTED := Color("#9da7b3")
const COLOR_GOLD := Color("#e3b341")

const TABLE_HEADERS := ["Pos", "Arquetipo", "PJ", "PG", "PE", "PP", "GF", "GC", "Pts", "% Cansancio", "% Lesiones"]
const TABLE_WIDTHS := [50, 140, 80, 80, 80, 80, 80, 80, 70, 120, 110]

var _profiles: Array = []
var _templates: Array = []
var _thread: Thread = null
var _active_progress: ProgressBar

# Parámetros comunes
var _sl_energy: HSlider
var _sl_regen: HSlider
var _sl_matches: HSlider
var _sl_rival: HSlider
var _sl_defense: HSlider

# Duelo 1v1
var _opt_a: OptionButton
var _opt_b: OptionButton
var _info_a: Label
var _info_b: Label
var _btn_duel: Button
var _prog_duel: ProgressBar
var _res_a: Dictionary
var _res_b: Dictionary
var _cmp_label: Label

# Liga
var _btn_league: Button
var _prog_league: ProgressBar
var _league_note: Label
var _table_grid: GridContainer
var _matrix_grid: GridContainer
var _audit_grid: GridContainer


func _ready() -> void:
    get_window().min_size = Vector2i(900, 600)
    _profiles = BotProfile.presets()
    _templates = CardDB.load_templates("res://data/cards.json")
    _build_ui()
    _refresh_profile_info()
    _update_slider_labels()
    _render_table([])
    _render_matrix(_profile_names(), [])
    _render_audit([])


func _exit_tree() -> void:
    if _thread != null:
        _thread.wait_to_finish()


func _profile_names() -> Array:
    var out: Array = []
    for p in _profiles:
        out.append(p.profile_name)
    return out


# ================================================================== UI

func _build_ui() -> void:
    var bg := ColorRect.new()
    bg.color = Color("#12161d")
    bg.set_anchors_preset(Control.PRESET_FULL_RECT)
    add_child(bg)

    var scroll := ScrollContainer.new()
    scroll.set_anchors_preset(Control.PRESET_FULL_RECT)
    scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_AUTO
    add_child(scroll)

    var margin := MarginContainer.new()
    margin.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    for side in ["left", "right", "top", "bottom"]:
        margin.add_theme_constant_override("margin_" + side, 20)
    scroll.add_child(margin)

    var root := VBoxContainer.new()
    root.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    root.add_theme_constant_override("separation", 12)
    margin.add_child(root)

    root.add_child(_label("Dashboard de Simulación — Futbolista Deckbuilder", 26))
    root.add_child(_build_params_panel())

    var tabs := TabContainer.new()
    tabs.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    tabs.add_theme_font_size_override("font_size", 18)
    root.add_child(tabs)
    var duel := _build_duel_tab()
    duel.name = "Duelo 1v1"
    tabs.add_child(duel)
    var league := _build_league_tab()
    league.name = "Liga (todos contra todos)"
    tabs.add_child(league)


func _build_params_panel() -> Control:
    var panel := _panel()
    var v := VBoxContainer.new()
    v.add_theme_constant_override("separation", 8)
    panel.add_child(v)
    v.add_child(_label("Parámetros (comunes a ambos modos)", 20))
    var grid := _make_adaptive_grid(520, 2)
    v.add_child(grid)
    _sl_energy = _add_slider(grid, "Tope de energía (Stamina 60)", 30, 120, 1, 58)
    _sl_regen = _add_slider(grid, "Regeneración NORMAL (% del tope)", 0.10, 0.40, 0.01, 0.22)
    _sl_matches = _add_slider(grid, "Partidos (por equipo / por duelo)", 0, 2, 1, 1)
    _sl_rival = _add_slider(grid, "Dificultad base del rival", 0.05, 0.35, 0.01, 0.15)
    _sl_defense = _add_slider(grid, "Influencia defensiva del rival", 0.0, 0.2, 0.01, 0.10)
    return panel


# ---------------- Duelo 1v1

func _build_duel_tab() -> Control:
    var v := VBoxContainer.new()
    v.add_theme_constant_override("separation", 12)

    var teams := _make_adaptive_grid(420, 2)
    v.add_child(teams)
    var ta := _team_panel("Equipo A", 0)
    var tb := _team_panel("Equipo B", 3)
    teams.add_child(ta["panel"])
    teams.add_child(tb["panel"])
    _opt_a = ta["opt"]
    _info_a = ta["info"]
    _opt_b = tb["opt"]
    _info_b = tb["info"]

    _btn_duel = _make_start_button("▶ INICIAR SIMULACIÓN", _on_duel_pressed)
    v.add_child(_btn_duel)
    _prog_duel = _make_progress()
    v.add_child(_prog_duel)

    var results := _make_adaptive_grid(460, 2)
    v.add_child(results)
    _res_a = _build_result_panel("Equipo A")
    _res_b = _build_result_panel("Equipo B")
    results.add_child(_res_a["panel"])
    results.add_child(_res_b["panel"])

    _cmp_label = _label("Configura y pulsa «Iniciar Simulación».", 18, COLOR_MUTED, true)
    _cmp_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    v.add_child(_cmp_label)
    return v


func _team_panel(title: String, selected: int) -> Dictionary:
    var panel := _panel()
    panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    var v := VBoxContainer.new()
    v.add_theme_constant_override("separation", 6)
    panel.add_child(v)
    v.add_child(_label(title, 18))
    var opt := OptionButton.new()
    for p in _profiles:
        opt.add_item(p.profile_name)
    opt.select(selected)
    opt.item_selected.connect(func(_i: int) -> void: _refresh_profile_info())
    v.add_child(opt)
    var info := _label("", 13, COLOR_MUTED, true)
    v.add_child(info)
    return {"panel": panel, "opt": opt, "info": info}


func _build_result_panel(who: String) -> Dictionary:
    var panel := _panel()
    panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    var v := VBoxContainer.new()
    v.add_theme_constant_override("separation", 8)
    panel.add_child(v)
    var title := _label(who, 20, Color.WHITE, true)
    v.add_child(title)
    var d := {"panel": panel, "title": title}
    d["goal"] = _bar_row(v, "% Goles (por Momento Clave)", COLOR_GOAL, 100.0)
    d["flow"] = _bar_row(v, "% Flow (momentos con Flow)", COLOR_FLOW, 100.0)
    d["tired"] = _bar_row(v, "% Cansancio (jugadas con fatiga)", COLOR_TIRED, 100.0)
    d["injury"] = _bar_row(v, "% Lesiones (partidos) — escala 0–25%", COLOR_INJURY, 25.0)
    var summary := _label("—", 15, COLOR_MUTED, true)
    v.add_child(summary)
    d["summary"] = summary
    var audit := _label("", 14, COLOR_MUTED, true)
    v.add_child(audit)
    d["audit"] = audit
    return d


func _bar_row(parent: Control, title: String, color: Color, max_v: float) -> Dictionary:
    var box := VBoxContainer.new()
    parent.add_child(box)
    box.add_child(_label(title, 14, COLOR_MUTED, true))
    var row := HBoxContainer.new()
    box.add_child(row)
    var bar := ProgressBar.new()
    bar.min_value = 0
    bar.max_value = max_v
    bar.show_percentage = false
    bar.custom_minimum_size = Vector2(60, 26)
    bar.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    bar.size_flags_vertical = Control.SIZE_SHRINK_CENTER
    bar.add_theme_stylebox_override("fill", _flat(color, 6))
    bar.add_theme_stylebox_override("background", _flat(Color("#2a3140"), 6))
    row.add_child(bar)
    var val := _label("—", 18)
    val.custom_minimum_size = Vector2(80, 0)
    val.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
    row.add_child(val)
    return {"bar": bar, "label": val}


# ---------------- Liga

func _build_league_tab() -> Control:
    var v := VBoxContainer.new()
    v.add_theme_constant_override("separation", 12)

    _league_note = _label("", 14, COLOR_MUTED, true)
    v.add_child(_league_note)
    _btn_league = _make_start_button("▶ SIMULAR LIGA", _on_league_pressed)
    v.add_child(_btn_league)
    _prog_league = _make_progress()
    v.add_child(_prog_league)

    # Tabla de posiciones
    var tpanel := _panel()
    v.add_child(tpanel)
    var tv := VBoxContainer.new()
    tv.add_theme_constant_override("separation", 8)
    tpanel.add_child(tv)
    tv.add_child(_label("Tabla de Posiciones", 20))
    var sc := ScrollContainer.new()
    sc.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_AUTO
    sc.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
    sc.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    tv.add_child(sc)
    _table_grid = GridContainer.new()
    _table_grid.columns = TABLE_HEADERS.size()
    _table_grid.add_theme_constant_override("h_separation", 6)
    _table_grid.add_theme_constant_override("v_separation", 6)
    sc.add_child(_table_grid)

    # Auditoría de fatiga por Momento Clave
    var apanel := _panel()
    v.add_child(apanel)
    var av := VBoxContainer.new()
    av.add_theme_constant_override("separation", 8)
    apanel.add_child(av)
    av.add_child(_label("Auditoría de fatiga por Momento Clave", 20))
    av.add_child(_label("% de jugadas hechas con cansancio y, entre paréntesis, jugadas cansadas por partido. Los Momentos 4 y 5 no ocurren en todos los partidos.", 13, COLOR_MUTED, true))
    var asc := ScrollContainer.new()
    asc.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_AUTO
    asc.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
    asc.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    av.add_child(asc)
    _audit_grid = GridContainer.new()
    _audit_grid.add_theme_constant_override("h_separation", 6)
    _audit_grid.add_theme_constant_override("v_separation", 6)
    asc.add_child(_audit_grid)

    # Matriz de duelos
    var mpanel := _panel()
    v.add_child(mpanel)
    var mv := VBoxContainer.new()
    mv.add_theme_constant_override("separation", 8)
    mpanel.add_child(mv)
    mv.add_child(_label("Matriz de Duelos (Head-to-Head)", 20))
    mv.add_child(_label("% de victorias de la FILA contra la COLUMNA. Pasa el mouse por una celda para ver victorias / empates / derrotas.", 13, COLOR_MUTED, true))
    var msc := ScrollContainer.new()
    msc.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_AUTO
    msc.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
    msc.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    mv.add_child(msc)
    _matrix_grid = GridContainer.new()
    _matrix_grid.add_theme_constant_override("h_separation", 6)
    _matrix_grid.add_theme_constant_override("v_separation", 6)
    msc.add_child(_matrix_grid)
    return v


# ---------------- Helpers de UI

func _add_slider(parent: Control, title: String, mn: float, mx: float, step: float, val: float) -> HSlider:
    var row := HBoxContainer.new()
    row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    parent.add_child(row)
    var t := _label(title, 15)
    t.custom_minimum_size = Vector2(215, 0)
    row.add_child(t)
    var s := HSlider.new()
    s.min_value = mn
    s.max_value = mx
    s.step = step
    s.value = val
    s.custom_minimum_size = Vector2(120, 0)
    s.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    s.size_flags_vertical = Control.SIZE_SHRINK_CENTER
    row.add_child(s)
    var l := _label("", 15, COLOR_MUTED)
    l.custom_minimum_size = Vector2(90, 0)
    l.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
    row.add_child(l)
    s.set_meta("value_label", l)
    s.value_changed.connect(func(_v: float) -> void: _update_slider_labels())
    return s


func _make_adaptive_grid(min_cell: int, max_cols: int) -> GridContainer:
    var g := GridContainer.new()
    g.columns = max_cols
    g.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    g.add_theme_constant_override("h_separation", 12)
    g.add_theme_constant_override("v_separation", 12)
    g.resized.connect(_on_grid_resized.bind(g, min_cell, max_cols))
    return g


func _on_grid_resized(g: GridContainer, min_cell: int, max_cols: int) -> void:
    g.columns = clampi(int(g.size.x / float(min_cell)), 1, max_cols)


func _make_start_button(text: String, handler: Callable) -> Button:
    var b := Button.new()
    b.text = text
    b.custom_minimum_size = Vector2(0, 64)
    b.add_theme_font_size_override("font_size", 24)
    b.add_theme_stylebox_override("normal", _flat(Color("#238636")))
    b.add_theme_stylebox_override("hover", _flat(Color("#2ea043")))
    b.add_theme_stylebox_override("pressed", _flat(Color("#1a6e2b")))
    b.add_theme_stylebox_override("disabled", _flat(Color("#3b4350")))
    b.pressed.connect(handler)
    return b


func _make_progress() -> ProgressBar:
    var p := ProgressBar.new()
    p.max_value = 100
    p.show_percentage = false
    p.custom_minimum_size = Vector2(0, 10)
    return p


func _label(text: String, size: int = 16, color: Color = Color.WHITE, wrap: bool = false) -> Label:
    var l := Label.new()
    l.text = text
    l.add_theme_font_size_override("font_size", size)
    l.add_theme_color_override("font_color", color)
    if wrap:
        l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
        l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
        l.custom_minimum_size = Vector2(120, 0)
    return l


func _panel() -> PanelContainer:
    var p := PanelContainer.new()
    var sb := _flat(Color("#1c232e"), 10)
    sb.set_content_margin_all(14)
    p.add_theme_stylebox_override("panel", sb)
    p.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    return p


func _flat(color: Color, radius: int = 8) -> StyleBoxFlat:
    var sb := StyleBoxFlat.new()
    sb.bg_color = color
    sb.set_corner_radius_all(radius)
    return sb


func _cell(text: String, width: int, color: Color = Color.WHITE, align: int = HORIZONTAL_ALIGNMENT_CENTER, size: int = 16) -> Label:
    var l := Label.new()
    l.text = text
    l.custom_minimum_size = Vector2(width, 30)
    l.horizontal_alignment = align as HorizontalAlignment
    l.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
    l.add_theme_font_size_override("font_size", size)
    l.add_theme_color_override("font_color", color)
    return l


func _clear(node: Node) -> void:
    for c in node.get_children():
        node.remove_child(c)
        c.queue_free()


func _refresh_profile_info() -> void:
    var pa: BotProfile = _profiles[_opt_a.selected]
    var pb: BotProfile = _profiles[_opt_b.selected]
    _info_a.text = pa.describe() + _exploit_note(pa, pb)
    _info_b.text = pb.describe() + _exploit_note(pb, pa)


func _exploit_note(me: BotProfile, rival: BotProfile) -> String:
    if me.punishes_passivity and rival.default_posture == MatchEngine.Posture.LOW:
        return "\n⚡ Regla anti-pasividad activa vs %s: +%d%% en remates y -%d energía en remates" % [
            rival.profile_name, roundi(MatchEngine.PASSIVITY_SHOT_BONUS * 100.0), MatchEngine.PASSIVITY_COST_REDUCTION]
    return ""


func _update_slider_labels() -> void:
    var n: int = MATCH_OPTIONS[int(_sl_matches.value)]
    _set_slider_text(_sl_energy, "%d pts" % int(_sl_energy.value))
    var rn: float = _sl_regen.value
    _set_slider_text(_sl_regen, "%d%%  (L %d / H %d)" % [
        roundi(rn * 100.0),
        roundi(rn * MatchEngine.RECOVERY_RATIO[MatchEngine.Posture.LOW] * 100.0),
        roundi(rn * MatchEngine.RECOVERY_RATIO[MatchEngine.Posture.HIGH] * 100.0)])
    _set_slider_text(_sl_matches, str(n))
    _set_slider_text(_sl_rival, "%.2f" % _sl_rival.value)
    _set_slider_text(_sl_defense, "off" if _sl_defense.value <= 0.0 else "%.2f" % _sl_defense.value)
    var k := _profiles.size()
    _league_note.text = "Cada arquetipo juega %d partidos contra cada uno de los otros %d. Son %d partidos de liga (%d simulaciones de equipo). Con 5000 puede tardar un buen rato." % [
        n, k - 1, n * k * (k - 1) / 2, n * k * (k - 1)]


func _set_slider_text(s: HSlider, text: String) -> void:
    (s.get_meta("value_label") as Label).text = text


# ================================================================== Ejecución (en hilos)

func _cfg() -> Dictionary:
    return {
        "energy_max": _sl_energy.value,
        "regen_normal_pct": _sl_regen.value,
        "rival_difficulty": _sl_rival.value,
        "defense_influence": _sl_defense.value,
    }


func _begin_run(active_btn: Button, active_prog: ProgressBar, text: String) -> void:
    _btn_duel.disabled = true
    _btn_league.disabled = true
    active_btn.text = text
    _active_progress = active_prog
    active_prog.value = 0


func _end_run() -> void:
    _thread.wait_to_finish()
    _thread = null
    _btn_duel.disabled = false
    _btn_league.disabled = false
    _btn_duel.text = "▶ INICIAR SIMULACIÓN"
    _btn_league.text = "▶ SIMULAR LIGA"
    _active_progress.value = 100


func _set_progress(f: float) -> void:
    _active_progress.value = f * 100.0


# ---------------- Duelo

func _on_duel_pressed() -> void:
    if _thread != null:
        return
    var n: int = MATCH_OPTIONS[int(_sl_matches.value)]
    var pa: BotProfile = _profiles[_opt_a.selected]
    var pb: BotProfile = _profiles[_opt_b.selected]
    _begin_run(_btn_duel, _prog_duel, "Simulando %d partidos..." % n)
    _cmp_label.text = "Simulando..."
    _thread = Thread.new()
    _thread.start(_worker_duel.bind(pa, pb, n, _cfg()))


func _worker_duel(pa: BotProfile, pb: BotProfile, n: int, cfg: Dictionary) -> void:
    var cb_a := func(f: float) -> void: call_deferred("_set_progress", f * 0.5)
    var cb_b := func(f: float) -> void: call_deferred("_set_progress", 0.5 + f * 0.5)
    var ca := SimRunner.cfg_vs(cfg, pb)
    var cb := SimRunner.cfg_vs(cfg, pa)
    var ra := SimRunner.run(pa, n, ca, _templates, cb_a)
    var rb := SimRunner.run(pb, n, cb, _templates, cb_b)
    call_deferred("_on_duel_done", ra, rb, pa, pb)


func _on_duel_done(ra: Dictionary, rb: Dictionary, pa: BotProfile, pb: BotProfile) -> void:
    _end_run()
    _show_result(_res_a, "Equipo A — " + pa.profile_name, SimRunner.metrics(ra))
    _show_result(_res_b, "Equipo B — " + pb.profile_name, SimRunner.metrics(rb))
    var ga: PackedInt32Array = ra["goals"]
    var gb: PackedInt32Array = rb["goals"]
    var wa := 0
    var wb := 0
    var dr := 0
    for i in ga.size():
        if ga[i] > gb[i]:
            wa += 1
        elif gb[i] > ga[i]:
            wb += 1
        else:
            dr += 1
    var n := float(ga.size())
    _cmp_label.text = "%d partidos:  gana A %.0f%%  |  empate %.0f%%  |  gana B %.0f%%" % [
        ga.size(), 100.0 * wa / n, 100.0 * dr / n, 100.0 * wb / n]


func _show_result(res: Dictionary, title: String, m: Dictionary) -> void:
    (res["title"] as Label).text = title
    _set_bar(res["goal"], m["goal_pct"])
    _set_bar(res["flow"], m["flow_pct"])
    _set_bar(res["tired"], m["tired_pct"])
    _set_bar(res["injury"], m["injury_pct"])
    (res["summary"] as Label).text = "Goles/partido: %.2f  |  Élite/partido: %.2f  |  Rupturas de Flow/partido: %.2f" % [
        m["goals_per_match"], m["elite_per_match"], m["flow_breaks_per_match"]]
    var parts: Array = []
    for i in m["by_moment"].size():
        var bm: Dictionary = m["by_moment"][i]
        parts.append("M%d %.0f%% (%.2f)" % [i + 1, bm["pct"], bm["per_match"]])
    (res["audit"] as Label).text = "Fatiga por Momento Clave — % de jugadas cansadas (jugadas cansadas/partido):\n" + "  |  ".join(parts)


func _set_bar(row: Dictionary, v: float) -> void:
    var bar: ProgressBar = row["bar"]
    create_tween().tween_property(bar, "value", v, 0.6)
    (row["label"] as Label).text = "%.1f%%" % v


# ---------------- Liga

func _on_league_pressed() -> void:
    if _thread != null:
        return
    var n: int = MATCH_OPTIONS[int(_sl_matches.value)]
    _begin_run(_btn_league, _prog_league, "Simulando liga (%d partidos por duelo)..." % n)
    _thread = Thread.new()
    _thread.start(_worker_league.bind(n, _cfg()))


func _worker_league(n: int, cfg: Dictionary) -> void:
    var cb := func(f: float) -> void: call_deferred("_set_progress", f)
    var r := LeagueRunner.run(_profiles, n, cfg, _templates, cb)
    call_deferred("_on_league_done", r)


func _on_league_done(r: Dictionary) -> void:
    _end_run()
    _render_table(r["rows"])
    _render_matrix(r["names"], r["h2h"])
    _render_audit(r["rows"])


func _render_table(rows: Array) -> void:
    _clear(_table_grid)
    for c in TABLE_HEADERS.size():
        var align := HORIZONTAL_ALIGNMENT_LEFT if c == 1 else HORIZONTAL_ALIGNMENT_CENTER
        _table_grid.add_child(_cell(TABLE_HEADERS[c], TABLE_WIDTHS[c], COLOR_MUTED, align, 14))
    for pos in rows.size():
        var r: Dictionary = rows[pos]
        var vals := [str(pos + 1), r["name"], str(r["pj"]), str(r["pg"]), str(r["pe"]), str(r["pp"]),
            str(r["gf"]), str(r["gc"]), str(r["pts"]),
            "%.1f%%" % r["tired_pct"], "%.1f%%" % r["injury_pct"]]
        for c in vals.size():
            var color := Color.WHITE
            if c == 1 and pos == 0:
                color = COLOR_GOLD
            elif c == 8:
                color = COLOR_GOAL
            elif c == 9:
                color = COLOR_TIRED
            elif c == 10:
                color = COLOR_INJURY
            var align := HORIZONTAL_ALIGNMENT_LEFT if c == 1 else HORIZONTAL_ALIGNMENT_CENTER
            _table_grid.add_child(_cell(vals[c], TABLE_WIDTHS[c], color, align, 17))


func _render_audit(rows: Array) -> void:
    _clear(_audit_grid)
    _audit_grid.columns = MatchEngine.MAX_MOMENTS + 1
    _audit_grid.add_child(_cell("Arquetipo", 140, COLOR_MUTED, HORIZONTAL_ALIGNMENT_LEFT, 14))
    for m in MatchEngine.MAX_MOMENTS:
        _audit_grid.add_child(_cell("Momento %d" % (m + 1), 130, COLOR_MUTED, HORIZONTAL_ALIGNMENT_CENTER, 14))
    for r in rows:
        _audit_grid.add_child(_cell(r["name"], 140, Color.WHITE, HORIZONTAL_ALIGNMENT_LEFT, 16))
        for m in MatchEngine.MAX_MOMENTS:
            var d: Dictionary = r["by_moment"][m]
            var pct: float = d["pct"]
            var col := COLOR_GOAL if pct < 25.0 else (COLOR_TIRED if pct < 50.0 else COLOR_INJURY)
            _audit_grid.add_child(_cell("%.0f%% (%.2f)" % [pct, d["per_match"]], 130, col, HORIZONTAL_ALIGNMENT_CENTER, 16))


func _render_matrix(names: Array, h2h: Array) -> void:
    _clear(_matrix_grid)
    var k := names.size()
    _matrix_grid.columns = k + 1
    _matrix_grid.add_child(_cell("", 110))
    for nm in names:
        _matrix_grid.add_child(_cell(nm, 100, COLOR_MUTED, HORIZONTAL_ALIGNMENT_CENTER, 14))
    for i in k:
        _matrix_grid.add_child(_cell(names[i], 110, COLOR_MUTED, HORIZONTAL_ALIGNMENT_LEFT, 14))
        for j in k:
            if i == j or h2h.is_empty():
                _matrix_grid.add_child(_matrix_cell("—" if i == j else "·", Color("#232a36"), ""))
            else:
                var d: Dictionary = h2h[i][j]
                var decided: float = d["w"] + d["l"]
                var t: float = 0.5 if decided <= 0.0 else d["w"] / decided
                var col: Color
                if t < 0.5:
                    col = Color("#8b2f2f").lerp(Color("#3a4352"), t * 2.0)
                else:
                    col = Color("#3a4352").lerp(Color("#2f8f46"), (t - 0.5) * 2.0)
                var tip := "%s vs %s\nVictorias %.0f%%  |  Empates %.0f%%  |  Derrotas %.0f%%" % [
                    names[i], names[j], 100.0 * d["w"], 100.0 * d["d"], 100.0 * d["l"]]
                _matrix_grid.add_child(_matrix_cell("%.0f%%" % (100.0 * d["w"]), col, tip))


func _matrix_cell(text: String, color: Color, tip: String) -> Control:
    var p := PanelContainer.new()
    p.add_theme_stylebox_override("panel", _flat(color, 6))
    p.custom_minimum_size = Vector2(100, 44)
    p.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    p.tooltip_text = tip
    var l := Label.new()
    l.text = text
    l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    l.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
    l.add_theme_font_size_override("font_size", 18)
    p.add_child(l)
    return p
