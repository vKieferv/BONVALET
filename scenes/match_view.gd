extends Control

# Escena del Partido Jugable (estilo transmisión de TV).
# Conecta la UI con MatchEngine / PlayerStats / DeckManager. El rival juega un "partido
# fantasma" (otro MatchEngine movido por CoachBot) que avanza Momento a Momento. Antes de cada
# ataque rival hay una fase defensiva: tu mano pasa a cartas de defensa y lo que logres
# (presión, bloqueo, intercepción, despeje) se aplica a ese ataque.

signal defense_finished

const CARD_SCENE := preload("res://scenes/card_ui.tscn")
const DECK_PATH := "res://data/cards.json"
const BASE_DIFFICULTY := 0.15
const DEFAULT_REGEN := 0.22
const LEAGUE_ID := "chile_2006"
const CALENDAR_SCENE := "res://scenes/calendar_view.tscn"
const QUICK_TEAM_ID := "colo_colo"   # tu club en el partido rápido (sin modo carrera)

const COLOR_OK := Color("#3fb950")
const COLOR_WARN := Color("#f0883e")
const COLOR_BAD := Color("#f85149")
const COLOR_GOLD := Color("#e3b341")
const COLOR_FLOW := Color("#ff6a00")
const COLOR_NATURAL := Color("#ffd24a")

@onready var _pitch: Pitch = %PitchContainer
@onready var _scoreboard: PanelContainer = %TopScoreboard
@onready var _local_goals: Label = %LocalGoals
@onready var _away_goals: Label = %AwayGoals
@onready var _away_name: Label = %AwayName
@onready var _local_name: Label = %LocalName
@onready var _minute_label: Label = %MinuteLabel
@onready var _player_bar: ProgressBar = %PlayerEnergyBar
@onready var _rival_bar: ProgressBar = %RivalEnergyBar
@onready var _flow_badge: PanelContainer = %FlowBadge
@onready var _flow_label: Label = %FlowLabel
@onready var _posture_buttons: Array = [%PostureLow, %PostureNormal, %PostureHigh]
@onready var _posture_hint: Label = %PostureHint
@onready var _banner: PanelContainer = %BroadcastBanner
@onready var _banner_label: Label = %BannerLabel
@onready var _backdrop: Panel = %Backdrop
@onready var _hand_box: HBoxContainer = %HandBox
@onready var _hand_title: Label = %HandTitle
@onready var _progress_label: Label = %ProgressLabel
@onready var _energy_readout: Label = %EnergyReadout
@onready var _yield_button: Button = %YieldButton
@onready var _emergency_button: Button = %EmergencyButton
@onready var _fx: Control = %FxLayer
@onready var _menu: PanelContainer = %MenuPanel
@onready var _menu_title: Label = %MenuTitle
@onready var _menu_summary: Label = %MenuSummary
@onready var _rival_option: OptionButton = %RivalOption
@onready var _start_button: Button = %StartButton

var _templates: Array = []
var _engine: MatchEngine
var _player: PlayerStats
var _rival: BotProfile
var _rival_team: Dictionary = {}
var _league: LeagueManager
var _squads: SquadManager
var _career: Career            # null = partido rápido
var _rival_engine: MatchEngine
var _rival_goals := 0
var _posture: MatchEngine.Posture = MatchEngine.Posture.NORMAL
var _posture_locked := false
var _minute := 0.0
var _busy := false
var _in_moment := false
var _in_defense := false
var _prev_hand: Array = []
var _active_clone: CardUI

var _ball: Panel
var _flow_glow: ColorRect
var _screen_glow: ColorRect
var _flow_tween: Tween
var _player_fill: StyleBoxFlat
var _rival_fill: StyleBoxFlat


func _ready() -> void:
    _templates = CardDB.load_templates(DECK_PATH)
    if Career.current != null and Career.current.pending_match:
        _career = Career.current
        _league = _career.league
        _squads = _career.squads
    else:
        _league = LeagueManager.new()
        if not _league.load_all():
            push_error("LeagueManager: " + "; ".join(_league.load_errors))
        _squads = SquadManager.new()
        if not _squads.load_all(_league):
            push_error("SquadManager: " + "; ".join(_squads.load_errors))
    _populate_rival_menu()
    _style_ui()
    _setup_posture_buttons()
    _start_button.pressed.connect(_on_start_pressed)
    _yield_button.pressed.connect(_on_yield_pressed)
    _emergency_button.pressed.connect(_on_emergency_pressed)
    _reset_hud()
    _local_name.text = String(_league.get_team(_my_team_id()).get("short_name", "TÚ")).to_upper()
    if _career != null:
        # Modo carrera: el rival y la semana ya están definidos en el calendario.
        _rival_option.visible = false
        _rival_team = _league.get_team(_career.rival_id)
        _rival = _league.profile_for_team(_rival_team)
        _begin_match()
    else:
        _show_menu("TRANSMISIÓN EN VIVO", "Partido rápido con %s. Elige al rival y empieza el partido." % _local_name.text)


func _my_team_id() -> String:
    return _career.team_id if _career != null else QUICK_TEAM_ID


# ================================================================== Estilo

func _flat(color: Color, radius: int = 8) -> StyleBoxFlat:
    var sb := StyleBoxFlat.new()
    sb.bg_color = color
    sb.set_corner_radius_all(radius)
    return sb


func _style_ui() -> void:
    var sb := _flat(Color(0.03, 0.06, 0.12, 0.93), 10)
    sb.border_color = COLOR_GOLD
    sb.border_width_bottom = 4
    sb.set_content_margin_all(10)
    _scoreboard.add_theme_stylebox_override("panel", sb)
    _local_goals.add_theme_color_override("font_color", COLOR_GOLD)
    _away_goals.add_theme_color_override("font_color", COLOR_GOLD)

    _player_fill = _flat(COLOR_OK, 5)
    _rival_fill = _flat(COLOR_OK, 5)
    _player_bar.add_theme_stylebox_override("fill", _player_fill)
    _player_bar.add_theme_stylebox_override("background", _flat(Color("#1b2230"), 5))
    _rival_bar.add_theme_stylebox_override("fill", _rival_fill)
    _rival_bar.add_theme_stylebox_override("background", _flat(Color("#1b2230"), 5))

    _flow_badge.add_theme_stylebox_override("panel", _flat(Color("#1b1208"), 8))
    _flow_glow = ColorRect.new()
    _flow_glow.mouse_filter = Control.MOUSE_FILTER_IGNORE
    _flow_glow.material = FlowGlow.make_material(COLOR_FLOW, 1.4)
    _flow_glow.visible = false
    _flow_badge.add_child(_flow_glow)

    # Resplandor de pantalla completa mientras hay Flow (detrás del HUD, encima de la cancha)
    _screen_glow = ColorRect.new()
    _screen_glow.set_anchors_preset(Control.PRESET_FULL_RECT)
    _screen_glow.mouse_filter = Control.MOUSE_FILTER_IGNORE
    _screen_glow.material = FlowGlow.make_material(COLOR_FLOW, 0.35)
    _screen_glow.visible = false
    add_child(_screen_glow)
    move_child(_screen_glow, 1)

    var bd := _flat(Color(0.02, 0.05, 0.12, 0.74), 0)
    bd.border_color = COLOR_GOLD
    bd.border_width_top = 4
    _backdrop.add_theme_stylebox_override("panel", bd)
    _hand_title.add_theme_color_override("font_color", COLOR_GOLD)

    var ms := _flat(Color(0.03, 0.06, 0.12, 0.97), 14)
    ms.border_color = COLOR_GOLD
    ms.set_border_width_all(3)
    ms.set_content_margin_all(24)
    _menu.add_theme_stylebox_override("panel", ms)

    _ball = Panel.new()
    _ball.size = Vector2(22, 22)
    _ball.mouse_filter = Control.MOUSE_FILTER_IGNORE
    var bs := _flat(Color.WHITE, 11)
    bs.border_color = Color("#222222")
    bs.set_border_width_all(2)
    _ball.add_theme_stylebox_override("panel", bs)
    _ball.visible = false
    _pitch.add_child(_ball)


func _setup_posture_buttons() -> void:
    var group := ButtonGroup.new()
    for i in _posture_buttons.size():
        var b: Button = _posture_buttons[i]
        b.toggle_mode = true
        b.button_group = group
        b.pressed.connect(_set_posture.bind(i))
    _posture_buttons[1].button_pressed = true


# ================================================================== Postura / HUD

func _set_posture(p: int) -> void:
    if _posture_locked:
        return
    _posture = p as MatchEngine.Posture
    if _engine != null:
        _engine.posture = _posture   # entre momentos: define la recuperación del próximo
    _update_posture_hint()


# La postura se elige entre Momentos Clave y ataques rivales: durante uno queda fija (evita
# recuperar en LOW y cambiar a NORMAL justo antes de rematar, o salir de LOW al ver un contragolpe).
func _lock_posture(locked: bool) -> void:
    _posture_locked = locked
    for b in _posture_buttons:
        b.disabled = locked
    _update_posture_hint()


func _update_posture_hint() -> void:
    var base: float = _player.regen_normal_pct if _player != null else DEFAULT_REGEN
    var rec := roundi(base * MatchEngine.RECOVERY_RATIO[_posture] * 100.0)
    match _posture:
        MatchEngine.Posture.LOW:
            _posture_hint.text = "LOW: recuperas %d%% entre momentos · remates −%d pts · máx. %d momentos" % [
                rec, roundi(MatchEngine.LOW_SHOT_PENALTY * 100.0), MatchEngine.LOW_MAX_MOMENTS]
            if _rival != null and _rival.punishes_passivity:
                _posture_hint.text += " · %s castiga el repliegue" % _rival.profile_name
        MatchEngine.Posture.NORMAL:
            _posture_hint.text = "NORMAL: recuperas %d%% entre momentos" % rec
        _:
            _posture_hint.text = "HIGH: recuperas solo %d%% · más probabilidad de momentos extra" % rec
    if _posture_locked:
        _posture_hint.text = "[FIJA DURANTE LA JUGADA] " + _posture_hint.text


func _reset_hud() -> void:
    _local_goals.text = "0"
    _away_goals.text = "0"
    _set_minute(0.0)
    _player_bar.value = 100.0
    _rival_bar.value = 100.0
    _player_fill.bg_color = COLOR_OK
    _rival_fill.bg_color = COLOR_OK
    _clear_hand()
    _hand_title.text = "TU MANO"
    _progress_label.text = ""
    _energy_readout.text = ""
    _yield_button.disabled = true
    _yield_button.text = "Ceder jugada"
    _emergency_button.disabled = true
    _emergency_button.text = "Despeje de emergencia"
    _ball.visible = false
    _update_flow_badge()
    _lock_posture(false)


func _update_hud() -> void:
    if _player == null:
        return
    _update_bars()
    _update_flow_badge()
    var zone_text := "ÓPTIMO"
    match _player.zone():
        PlayerStats.Zone.TIRED:
            zone_text = "CANSADO (costos +%d%%)" % roundi((MatchEngine.TIRED_COST_MULT - 1.0) * 100.0)
        PlayerStats.Zone.EXHAUSTED:
            zone_text = "AGOTADO (riesgo de lesión)"
    _energy_readout.text = "ENERGÍA %d/%d · %s" % [int(_player.energy), int(_player.max_energy()), zone_text]
    if _in_moment:
        var m := _engine.current_moment()
        _progress_label.text = "Jugada %d/%d · Fallos %d/%d" % [
            _engine.progress, m["steps_required"], _engine.fails, MatchEngine.MAX_FAILS]
    elif _in_defense:
        var d := _engine.defense_result
        _progress_label.text = "Defensa %d/%d · Presión +%d · Bloqueo +%d" % [
            _engine.defense_plays, MatchEngine.DEFENSE_MAX_PLAYS,
            roundi(d["pressure"] * 100.0), roundi(d["block"] * 100.0)]
    else:
        _progress_label.text = ""
    _yield_button.disabled = not (_in_moment or _in_defense) or _busy
    _emergency_button.text = "Despeje de emergencia (−%d)" % _engine.emergency_cost()
    _emergency_button.disabled = not _in_defense or _busy or not _engine.can_emergency_clear()
    _update_hand_stats()


func _update_bars() -> void:
    _set_bar(_player_bar, _player_fill, _player.energy_pct())


# Verde > Naranja > Rojo según la zona de energía.
func _set_bar(bar: ProgressBar, fill: StyleBoxFlat, pct: float) -> void:
    pct = clampf(pct, 0.0, 1.0)
    var col := COLOR_OK if pct >= 0.70 else (COLOR_WARN if pct >= 0.30 else COLOR_BAD)
    create_tween().tween_property(bar, "value", pct * 100.0, 0.35)
    create_tween().tween_property(fill, "bg_color", col, 0.3)


func _update_flow_badge() -> void:
    var on := _engine != null and _engine.flow_active
    _flow_glow.visible = on
    _screen_glow.visible = on
    if on:
        if _flow_tween == null or not _flow_tween.is_valid():
            _flow_tween = create_tween().set_loops()
            _flow_tween.tween_property(_flow_label, "modulate", Color("#ffd24a"), 0.35)
            _flow_tween.tween_property(_flow_label, "modulate", COLOR_FLOW, 0.35)
    else:
        if _flow_tween != null:
            _flow_tween.kill()
            _flow_tween = null
        _flow_label.modulate = Color(1, 1, 1, 0.3)


func _set_minute(v: float) -> void:
    _minute = v
    _minute_label.text = "%02d'" % int(v)


func _tween_clock(target: float) -> void:
    if target <= _minute:
        return
    var t := create_tween()
    t.tween_method(_set_minute, _minute, target, clampf((target - _minute) * 0.04, 0.4, 1.4))
    await t.finished


# ================================================================== Banner

func _banner_show(text: String, color: Color, hold: float) -> void:
    _banner_label.text = text
    var sb := _flat(color.darkened(0.55), 10)
    sb.border_color = color
    sb.set_border_width_all(3)
    sb.set_content_margin_all(12)
    _banner.add_theme_stylebox_override("panel", sb)
    _banner.pivot_offset = _banner.size / 2.0
    _banner.visible = true
    _banner.modulate.a = 0.0
    _banner.scale = Vector2(0.6, 0.6)
    var t := create_tween().set_parallel(true)
    t.tween_property(_banner, "modulate:a", 1.0, 0.15)
    t.tween_property(_banner, "scale", Vector2.ONE, 0.22).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
    await t.finished
    await get_tree().create_timer(hold).timeout
    var t2 := create_tween()
    t2.tween_property(_banner, "modulate:a", 0.0, 0.18)
    await t2.finished
    _banner.visible = false


# ================================================================== Menú / flujo del partido

func _show_menu(title: String, summary: String) -> void:
    _menu_title.text = title
    _menu_summary.text = summary
    _menu.visible = true


# Menú de rivales = los 32 clubes (Primera A y Primera B) con su arquetipo.
func _populate_rival_menu() -> void:
    _rival_option.clear()
    for t in _league.get_teams():
        _rival_option.add_item("%s · %s · %s" % [t["short_name"], t["division"], t["archetype"]])
        _rival_option.set_item_metadata(_rival_option.item_count - 1, t["id"])


func _on_start_pressed() -> void:
    if _career != null:
        get_tree().change_scene_to_file(CALENDAR_SCENE)
        return
    if _rival_option.item_count == 0:
        _show_menu("SIN EQUIPOS", "No se pudo cargar la base de equipos:\n" + "\n".join(_league.load_errors))
        return
    var team_id: String = _rival_option.get_item_metadata(_rival_option.selected)
    _rival_team = _league.get_team(team_id)
    _rival = _league.profile_for_team(_rival_team)
    _begin_match()


func _begin_match() -> void:
    var rng := RandomNumberGenerator.new()
    rng.randomize()
    _player = PlayerStats.new()
    _player.lineup = _squads.lineup_ids(_my_team_id())   # titulares: activan el Ejecutor Natural de sus cartas
    var cards := _squads.build_match_deck(_my_team_id(), _templates)
    var deck := DeckManager.new(cards, [], rng)
    var errors: Array = _league.validate_deck(cards, LEAGUE_ID)["errors"].duplicate()
    if deck.size_error() != "":
        errors.append(deck.size_error())
    if not errors.is_empty():
        _show_menu("MAZO NO VÁLIDO", "\n".join(errors))
        return
    _engine = MatchEngine.new(_player, deck, rng,
            LeagueManager.attack_difficulty_vs(_rival_team, _rival, BASE_DIFFICULTY))
    _engine.posture = _posture
    if _career != null:
        _career.configure_match(_engine, _player)   # fatiga, hype, forma y funados de la semana
    _engine.natural_executor_played.connect(_on_natural_executor)
    _engine.start()
    _setup_rival_engine()
    _rival_goals = 0
    _busy = false
    _in_moment = false
    _in_defense = false
    _prev_hand.clear()
    _reset_hud()
    _away_name.text = _rival.profile_name.to_upper()
    _away_name.add_theme_color_override("font_color", _league.team_display_color(_rival_team))
    _menu.visible = false
    await _banner_show("¡COMIENZA EL PARTIDO!", COLOR_GOLD, 0.9)
    _next_step()


# Partido "fantasma" del rival: mismo motor, movido por CoachBot con su perfil.
func _setup_rival_engine() -> void:
    var rng := RandomNumberGenerator.new()
    rng.randomize()
    var deck := DeckManager.new(CardDB.build_deck(_templates), [], rng)
    _rival_engine = MatchEngine.new(PlayerStats.new(), deck, rng,
            LeagueManager.team_attack_difficulty(_rival_team, BASE_DIFFICULTY))
    _rival.configure_engine(_rival_engine)
    _rival_engine.start()


func _rival_exploits_posture() -> bool:
    return _rival.punishes_passivity and _posture == MatchEngine.Posture.LOW


# Juega el siguiente Momento Clave del rival con lo que dejó tu defensa. Se resuelve justo
# cuando le toca, así un perfil que castiga la pasividad aprovecha tu postura LOW de ese momento.
func _play_rival_moment(exploited: bool, defense: Dictionary) -> Dictionary:
    var e := _rival_engine
    e.exploit_rival_space = exploited
    e.opponent_pressure = defense.get("pressure", 0.0)
    e.opponent_block = defense.get("block", 0.0)
    var m := e.begin_moment()
    var goals_before: int = e.stats["goals"]
    while not e.moment_over:
        var idx := CoachBot.choose(e, _rival)
        if idx < 0:
            e.abort_moment()
            break
        e.play_card(idx)
    var ev := {
        "minute": m["minute"],
        "goal": e.stats["goals"] > goals_before,
        "energy_pct": e.player.energy_pct(),
    }
    e.advance(_rival.default_posture as MatchEngine.Posture)
    return ev


# Línea de tiempo: se intercalan los momentos del jugador y los del rival por minuto.
func _next_step() -> void:
    var p_min := 9999
    if not _engine.finished:
        p_min = int(_engine.current_moment()["minute"])
    var r_min := 9999
    if not _rival_engine.finished:
        r_min = int(_rival_engine.current_moment()["minute"])
    if p_min == 9999 and r_min == 9999:
        await _tween_clock(90.0)
        _end_match("FINAL DEL PARTIDO")
    elif r_min <= p_min:
        if await _rival_event():
            _next_step()
    else:
        await _player_moment_start()


# Ataque rival: fase defensiva y luego su Momento Clave. false si el partido terminó (lesión).
func _rival_event() -> bool:
    var minute: int = _rival_engine.current_moment()["minute"]
    await _tween_clock(float(minute))
    _ball_place(0.78, 0.5)
    var nm := _rival.profile_name.to_upper()
    var exploited := _rival_exploits_posture()
    if exploited:
        await _banner_show("¡CONTRAGOLPE DE %s! APROVECHA TU REPLIEGUE" % nm, COLOR_WARN, 0.8)
    else:
        await _banner_show("¡ATACA %s! A DEFENDER" % nm, COLOR_WARN, 0.8)

    var defense := await _defend()
    if _engine.injured:
        _end_match("LESIÓN — FIN DEL PARTIDO")
        return false
    if defense["cancelled"]:
        _rival_engine.skip_moment()
        _rival_engine.advance(_rival.default_posture as MatchEngine.Posture)
        var counter := "  ·  ¡CONTRAGOLPE LISTO!" if _engine.counter_ready else ""
        await _banner_show("¡RECUPERASTE EL BALÓN!" + counter, COLOR_OK, 0.9)
        return true

    var ev := _play_rival_moment(exploited, defense)
    if ev["goal"]:
        _rival_goals += 1
        _away_goals.text = str(_rival_goals)
        _ball_place(0.015, 0.5)
        await _banner_show("¡GOL DE %s!" % nm, COLOR_BAD, 1.3)
    else:
        await _banner_show("ATACA %s... ¡SE SALVÓ!" % nm, COLOR_WARN, 0.9)
    if defense["emergency"] and _rival_engine.grant_extra_moment(minute):
        await _banner_show("EL BALÓN VUELVE A %s" % nm, COLOR_WARN, 0.7)
    _set_bar(_rival_bar, _rival_fill, ev["energy_pct"])
    return true


# Fase defensiva: mano de defensa (presión, bloqueo, intercepción, despeje), Despeje de
# Emergencia o dejar pasar. Devuelve lo que se aplica al ataque rival.
func _defend() -> Dictionary:
    _lock_posture(true)
    _engine.begin_defense(LeagueManager.defense_difficulty_vs(_rival_team, BASE_DIFFICULTY))
    if _engine.in_defense:
        _in_defense = true
        _hand_title.text = "DEFENSA · ATACA %s" % _rival.profile_name.to_upper()
        _yield_button.text = "Dejar pasar"
        _build_hand()
        _update_hud()
        await defense_finished
        _in_defense = false
        _yield_button.text = "Ceder jugada"
        _clear_hand()
        _hand_title.text = "TU MANO"
    else:
        await _banner_show("SIN CARTAS PARA DEFENDER", COLOR_BAD, 0.7)
    _lock_posture(false)
    _update_hud()
    return _engine.end_defense()


func _player_moment_start() -> void:
    _lock_posture(true)   # antes de begin_moment: la recuperación ya usa la postura fijada
    var m := _engine.begin_moment()
    await _tween_clock(float(m["minute"]))
    _ball_place(0.22, 0.5)
    if _engine.moment_over:
        await _banner_show("SIN JUGADAS DISPONIBLES", COLOR_WARN, 0.9)
        _finish_player_moment()
        return
    _in_moment = true
    _hand_title.text = "TU MANO · MOMENTO CLAVE"
    _build_hand()
    _update_hud()
    if _engine.progress > 0:
        await _banner_show("¡CONTRAGOLPE! ARRANCAS CON %d JUGADA" % _engine.progress, COLOR_OK, 1.0)
    else:
        await _banner_show("¡OPORTUNIDAD DE GOL!", COLOR_GOLD, 1.0)


func _finish_player_moment() -> void:
    _in_moment = false
    _lock_posture(false)
    _clear_hand()
    _hand_title.text = "TU MANO"
    _local_goals.text = str(_engine.stats["goals"])
    if _engine.injured:
        _update_hud()
        _end_match("LESIÓN — FIN DEL PARTIDO")
        return
    _engine.advance(_posture)
    _update_hud()
    _next_step()


func _on_yield_pressed() -> void:
    if _busy:
        return
    if _in_defense:
        _engine.end_defense()
        defense_finished.emit()
        return
    if not _in_moment:
        return
    _busy = true
    _yield_button.disabled = true
    _engine.abort_moment()
    await _banner_show("JUGADA CEDIDA · SE ENFRÍA EL PARTIDO", COLOR_WARN, 0.7)
    _busy = false
    _finish_player_moment()


func _on_emergency_pressed() -> void:
    if _busy or not _in_defense or not _engine.can_emergency_clear():
        return
    _busy = true
    var ev := _engine.emergency_clear()
    _update_hud()
    await _banner_show("¡DESPEJE DE EMERGENCIA! · REMATES RIVALES −%d" % roundi(
            MatchEngine.EMERGENCY_SHOT_PENALTY * 100.0), COLOR_WARN, 0.8)
    if ev["injury"]:
        await _banner_show("¡LESIÓN!", COLOR_BAD, 0.9)
    _busy = false
    defense_finished.emit()


func _end_match(title: String) -> void:
    _in_moment = false
    _in_defense = false
    _busy = false
    _lock_posture(false)
    _clear_hand()
    var s: Dictionary = _engine.stats
    var mine: int = s["goals"]
    var res := "VICTORIA" if mine > _rival_goals else ("DERROTA" if mine < _rival_goals else "EMPATE")
    _hand_title.text = "FIN"
    var summary := "%s\n%s %d - %d %s\nJugadas: %d · Momentos con Flow: %d\nDefensa: %d jugadas · %d intercepciones · %d despejes de emergencia" % [
        res, _local_name.text, mine, _rival_goals, _rival.profile_name, s["plays"], s["flow_moments"],
        s["defense_plays"], s["interceptions"], s["emergencies"]]
    if _career != null:
        var entry := _career.record_match(mine, _rival_goals)
        if not entry.is_empty():
            summary += "\nIngreso del sponsor: $%d M" % entry["income"]
        _start_button.text = "VOLVER AL CALENDARIO"
    else:
        _start_button.text = "JUGAR OTRA VEZ"
    _show_menu(title, summary)


# ================================================================== Mano de cartas

func _build_hand() -> void:
    for c in _hand_box.get_children():
        _hand_box.remove_child(c)
        c.queue_free()
    var cards: Array = _engine.deck.hand
    for i in cards.size():
        var ui: CardUI = CARD_SCENE.instantiate()
        _hand_box.add_child(ui)
        ui.setup(cards[i], i)
        ui.chosen.connect(_on_card_chosen)
        if not _prev_hand.has(cards[i]):
            ui.appear(0.04 * i)
    _prev_hand = cards.duplicate()
    _update_hand_stats()


func _clear_hand() -> void:
    for c in _hand_box.get_children():
        _hand_box.remove_child(c)
        c.queue_free()
    _prev_hand.clear()


# Recalcula costo y probabilidad de cada carta (cambio de postura, cansancio, Flow...).
func _update_hand_stats() -> void:
    # Según el motor, no según la UI: al cerrarse la defensa la mano sigue en pantalla un instante.
    if _engine == null or not (_in_moment or _engine.in_defense):
        return
    for node in _hand_box.get_children():
        var ui: CardUI = node
        var card: Card = ui.card
        var usable := _engine.can_play(card) and not _busy
        ui.update_stats(_engine.cost_of(card), card.energy_cost, _engine.success_chance(card), usable,
                card.flow_uses > 0 and _engine.flow_active)


func _on_card_chosen(ui: CardUI) -> void:
    if _busy or not (_in_moment or _in_defense):
        return
    var card: Card = ui.card
    if not _engine.can_play(card):
        ui.shake()
        return
    _busy = true
    _yield_button.disabled = true
    _emergency_button.disabled = true
    _active_clone = _spawn_clone(ui)
    ui.hide_slot()
    await _fly_to_center(_active_clone)
    var ev := _engine.play_card(ui.hand_index)
    await _present_result(ev, _active_clone)
    _active_clone = null
    _busy = false
    if _in_defense:
        if _engine.in_defense:
            _build_hand()
            _update_hud()
        else:
            defense_finished.emit()
    elif _engine.moment_over:
        _finish_player_moment()
    else:
        _build_hand()
        _update_hud()


# Ejecutor Natural: la carta la jugó su dueño. Resplandor dorado sobre la carta lanzada.
func _on_natural_executor(_card: Card) -> void:
    if _active_clone != null:
        _active_clone.natural_glow(COLOR_NATURAL)


func _spawn_clone(src: CardUI) -> CardUI:
    var c: CardUI = CARD_SCENE.instantiate()
    _fx.add_child(c)
    c.setup(src.card, -1)
    c.interactive = false
    c.update_stats(_engine.cost_of(src.card), src.card.energy_cost, _engine.success_chance(src.card), true,
            src.card.flow_uses > 0 and _engine.flow_active)
    c.global_position = src.global_position
    c.pivot_offset = c.size / 2.0
    return c


func _fly_to_center(c: CardUI) -> void:
    var target := _pitch.field_rect().get_center() - c.size / 2.0
    var t := create_tween().set_parallel(true).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
    t.tween_property(c, "position", target, 0.35)
    t.tween_property(c, "scale", Vector2(1.35, 1.35), 0.35)
    await t.finished


func _present_result(ev: Dictionary, clone: CardUI) -> void:
    if not ev.get("ok", false):
        clone.queue_free()
        return
    var ok: bool = ev["success"]
    clone.flash(COLOR_OK if ok else COLOR_BAD)
    _move_ball(ev)
    _update_hud()
    if ev["natural"]:
        await _banner_show("¡EJECUTOR NATURAL!", COLOR_NATURAL, 0.6)
    if ev["goal"]:
        _local_goals.text = str(_engine.stats["goals"])
        await _banner_show("¡GOOOOL!", COLOR_OK, 1.3)
    else:
        await _banner_show(_result_text(ev["kind"], ok), COLOR_OK if ok else COLOR_BAD, 0.7)
    if ev["flow_started"]:
        await _banner_show("¡MODO FLOW!", COLOR_FLOW, 0.6)
    if ev["flow_broken"]:
        await _banner_show("¡SE ROMPIÓ EL FLOW!", COLOR_WARN, 0.6)
    if ev.has("penalties_added"):
        await _banner_show("¡JUGADOR EXHAUSTO!", COLOR_BAD, 0.7)
    if ev["injury"]:
        await _banner_show("¡LESIÓN!", COLOR_BAD, 0.9)
    var t := create_tween().set_parallel(true)
    t.tween_property(clone, "modulate:a", 0.0, 0.25)
    t.tween_property(clone, "scale", Vector2(0.8, 0.8), 0.25)
    await t.finished
    clone.queue_free()


func _result_text(kind: int, ok: bool) -> String:
    if ok:
        match kind:
            Card.Kind.PASS:
                return "¡BUEN PASE!"
            Card.Kind.CONTROL:
                return "¡CONTROL PERFECTO!"
            Card.Kind.DRIBBLE:
                return "¡QUÉ REGATE!"
            Card.Kind.CROSS:
                return "¡CENTRO PELIGROSO!"
            Card.Kind.PAUSE:
                return "PAUSA · RECUPERAS AIRE"
            Card.Kind.PRESS:
                return "¡PRESIÓN ASFIXIANTE!"
            Card.Kind.BLOCK:
                return "¡BLOQUEO!"
            Card.Kind.INTERCEPT:
                return "¡INTERCEPTADO!"
            Card.Kind.CLEARANCE:
                return "¡DESPEJADO!"
            _:
                return "¡AL PALO!"
    match kind:
        Card.Kind.PASS, Card.Kind.CROSS:
            return "¡PASE INTERCEPTADO!"
        Card.Kind.SHOT:
            return "¡REMATE BLOQUEADO!"
        Card.Kind.PRESS, Card.Kind.BLOCK, Card.Kind.INTERCEPT, Card.Kind.CLEARANCE:
            return "¡TE SUPERARON!"
        _:
            return "¡BALÓN PERDIDO!"


# ================================================================== Balón

func _field_point(fx: float, fy: float) -> Vector2:
    var r := _pitch.field_rect()
    return r.position + Vector2(r.size.x * fx, r.size.y * fy) - _ball.size / 2.0


func _ball_place(fx: float, fy: float) -> void:
    _ball.position = _field_point(fx, fy)
    _ball.visible = true


# Atacas hacia la derecha; el rival, hacia tu arco (izquierda).
func _move_ball(ev: Dictionary) -> void:
    var fx: float
    if ev["defense"]:
        fx = 0.55 if ev["success"] else 0.22
    else:
        var req := float(_engine.current_moment()["steps_required"])
        var ratio := clampf(float(_engine.progress) / req, 0.0, 1.0)
        fx = lerpf(0.22, 0.84, ratio)
        if ev["goal"]:
            fx = 0.985
        elif not ev["success"]:
            fx = maxf(0.12, fx - 0.12)
    var fy := 0.5 + randf_range(-0.18, 0.18)
    create_tween().tween_property(_ball, "position", _field_point(fx, fy), 0.4).set_trans(Tween.TRANS_SINE)
