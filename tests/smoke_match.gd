# Prueba de humo de la escena del partido: juega partidos completos de match_view
# (un rival por arquetipo, rotando la postura) eligiendo siempre la primera carta jugable,
# tanto en ataque como en las fases defensivas (cada tercera defensa usa el Despeje de Emergencia).
# Uso: godot --headless --path . -s res://tests/smoke_match.gd [-- --matches=5]
# Sale con código 1 si un partido se cuelga, el marcador no cuadra, la postura cambia durante
# una jugada, nunca hay fase defensiva o no se prueba el contragolpe contra tu LOW.
extends SceneTree

const TIME_SCALE := 20.0
const MAX_FRAMES_PER_MATCH := 80000

var view: Control
var frames := 0
var match_frames := 0
var started := false
var total_matches := 5
var played := 0
var rivals: Array = []         # índices del menú, uno por arquetipo
var errors: Array[String] = []
var lock_checks := 0
var exploit_seen := false
var exploit_expected := false
var defenses := 0
var emergencies := 0
var natural_plays := [0]
var rival_natural_plays := [0]
var rival_defense_plays := 0
var holds := 0
var _defense_open := false
var card_checks := 0
var effect_checks := 0   # líneas de efecto (avanza, roba, corta, contragolpe) verificadas en tooltips
var ui_checked_errors := false   # tras el primer error de UI se deja de revisar (evita miles de líneas)


func _initialize() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--matches="):
			total_matches = maxi(1, int(arg.get_slice("=", 1)))
	view = load("res://scenes/match_view.tscn").instantiate()
	root.add_child(view)
	Engine.time_scale = TIME_SCALE


func _process(_delta: float) -> bool:
	frames += 1
	if frames < 2:
		return false   # los @onready de la escena se resuelven tras el primer frame
	if not started:
		started = true
		_pick_rivals()
		_start_match()
		return false

	match_frames += 1
	if match_frames > MAX_FRAMES_PER_MATCH:
		errors.append("Partido %d colgado (minuto %d)" % [played + 1, int(view._minute)])
		return _finish()

	if view._menu.visible and not view._busy:
		_check_result()
		played += 1
		if played >= total_matches:
			return _finish()
		_start_match()
		return false

	if view._rival_engine != null and view._rival_engine.exploit_rival_space:
		exploit_seen = true
	if not view._in_defense:
		_defense_open = false
	if view._busy:
		return false
	_check_ui_matches_engine()
	if view._in_defense:
		if not _defense_open:
			_defense_open = true
			defenses += 1
		_check_posture_lock()
		if defenses % 3 == 0 and view._engine.can_emergency_clear():
			emergencies += 1
			view._on_emergency_pressed()
		elif not _play_first_card():
			view._on_yield_pressed()   # dejar pasar
	elif view._in_moment:
		_check_posture_lock()
		if holds == 0 and view._engine.can_hold():
			# Aguantar se prueba siempre al menos una vez, aunque la mano tenga jugadas (si no, con pocos
			# partidos podía no ocurrir nunca y la prueba fallaba al azar).
			holds += 1
			view._on_hold_pressed()
		elif not _play_first_card():
			# Sin carta jugable el Momento sigue abierto: aguantar (si queda) o ceder.
			if view._engine.can_hold():
				holds += 1
				view._on_hold_pressed()
			else:
				view._on_yield_pressed()
	return false


func _play_first_card() -> bool:
	for ui in view._hand_box.get_children():
		if view._engine.can_play(ui.card):
			view._on_card_chosen(ui)
			return true
	return false


func _pick_rivals() -> void:
	var seen := {}
	for i in view._rival_option.item_count:
		var t: Dictionary = view._league.get_team(view._rival_option.get_item_metadata(i))
		if not seen.has(t["archetype"]):
			seen[t["archetype"]] = true
			rivals.append(i)
	if rivals.is_empty():
		errors.append("El menú de rivales está vacío (¿fallaron los JSON de liga?)")


func _start_match() -> void:
	if rivals.is_empty():
		return
	match_frames = 0
	view._rival_option.selected = rivals[played % rivals.size()]
	var posture := played % 3   # LOW, NORMAL, HIGH
	var team: Dictionary = view._league.get_team(view._rival_option.get_item_metadata(view._rival_option.selected))
	if view._league.profile_for_team(team).punishes_passivity:
		posture = MatchEngine.Posture.LOW   # para que se pruebe exploit_rival_space
		exploit_expected = true
	view._posture_buttons[posture].button_pressed = true
	view._set_posture(posture)
	view._on_start_pressed()
	if view._engine != null:
		view._engine.natural_executor_played.connect(func(_c: Card) -> void: natural_plays[0] += 1)
	if view._rival_engine != null:
		# Paridad: el rival juega con su plantel (titulares y mazo con dueños).
		view._rival_engine.natural_executor_played.connect(func(_c: Card) -> void: rival_natural_plays[0] += 1)
		if view._rival_engine.player.lineup.size() != 11:
			errors.append("El rival debería tener 11 titulares (tiene %d)" % view._rival_engine.player.lineup.size())
		if not view._rival_engine.deck.active.any(func(c): return c.owner_id != ""):
			errors.append("El mazo del rival debería traer cartas con dueño (canteranos o firma)")


# El % de cada carta en pantalla y el badge de posesión deben reflejar el estado del motor.
func _check_ui_matches_engine() -> void:
	if ui_checked_errors:
		return
	var badge: String = view._possession_label.text
	if view._in_moment and not (badge.contains("(ATAQUE)") and badge.contains(view._local_name.text)):
		errors.append("Atacando, el badge dice '%s'" % badge)
	if view._in_defense and not (badge.contains("(DEFENSA)") and badge.contains(view._rival.profile_name.to_upper())):
		errors.append("Defendiendo, el badge dice '%s'" % badge)
	if view._in_moment or view._engine.in_defense:
		var e: MatchEngine = view._engine
		var orb := "%d/%d" % [e.ap, e.ap_max]
		if view._ap_value.text != orb:
			errors.append("El orbe muestra %s PA pero el turno tiene %s" % [view._ap_value.text, orb])
		if view._in_moment and view._hold_button.disabled != not e.can_hold():
			errors.append("El botón Aguantar está %s pero el motor dice can_hold = %s" % [
				"deshabilitado" if view._hold_button.disabled else "habilitado", e.can_hold()])
		var zone: String = "TU ESTAMINA · " + view.stamina_zone_text(view._player)
		if view._stamina_label.text != zone:
			errors.append("La barra dice '%s' pero la estamina está en '%s'" % [view._stamina_label.text, zone])
		for ui in view._hand_box.get_children():
			if ui.card.type == Card.Type.PENALTY or ui.slot_hidden:
				continue
			card_checks += 1
			var real := "%d%%" % roundi(e.success_chance(ui.card) * 100.0)
			if ui.chance_label.text != real:
				errors.append("La carta %s muestra %s pero el motor tira contra %s" % [ui.card.display_name, ui.chance_label.text, real])
			var ap := "%d PA" % e.ap_cost_of(ui.card)
			if ui.ap_label.text != ap:
				errors.append("La carta %s muestra %s pero cuesta %s" % [ui.card.display_name, ui.ap_label.text, ap])
			if ui.card.kind != Card.Kind.PAUSE:
				var wear := "Desgaste: %d Est." % roundi(e.stamina_cost_of(ui.card))
				if ui.cost_label.text != wear:
					errors.append("La carta %s muestra '%s' pero desgasta '%s'" % [ui.card.display_name, ui.cost_label.text, wear])
			# Sus efectos (avanza 2, roba, corta, contragolpe) se ven en la carta y en su tooltip (pilar 2).
			var effect := CardUI.effect_text(ui.card)
			if ui.effect_label.text != effect or ui.effect_label.visible != (effect != ""):
				errors.append("La carta %s muestra el efecto '%s' pero tiene '%s'" % [ui.card.display_name, ui.effect_label.text, effect])
			for line in CardUI.effect_details(ui.card):
				effect_checks += 1
				if not ui.tooltip_text.contains(line):
					errors.append("El tooltip de %s no explica: %s" % [ui.card.display_name, line])
	ui_checked_errors = not errors.is_empty()


func _check_posture_lock() -> void:
	lock_checks += 1
	var before: int = view._posture
	view._set_posture((before + 1) % 3)
	if view._posture != before:
		errors.append("La postura cambió durante una jugada (partido %d)" % (played + 1))


func _check_result() -> void:
	rival_defense_plays += int(view._rival_engine.stats["defense_plays"])
	var shown := int(view._local_goals.text)
	var real: int = view._engine.stats["goals"]
	if shown != real:
		errors.append("Marcador local %d ≠ goles del motor %d (partido %d)" % [shown, real, played + 1])
	if int(view._away_goals.text) != view._rival_goals:
		errors.append("Marcador visitante no cuadra (partido %d)" % (played + 1))
	print("  Partido %d: %s" % [played + 1, view._menu_summary.text.replace("\n", " | ")])


func _finish() -> bool:
	if exploit_expected and not exploit_seen:
		errors.append("Se jugó en LOW contra un rival que castiga la pasividad y exploit_rival_space nunca se activó")
	if played > 0 and defenses == 0:
		errors.append("Nunca hubo fase defensiva")
	if played > 0 and rival_defense_plays == 0:
		errors.append("El rival nunca defendió tus ataques")
	if played > 0 and holds == 0:
		errors.append("Nunca se probó Aguantar el Balón")
	if played > 0 and effect_checks == 0:
		errors.append("Ninguna carta en pantalla mostró un efecto (el mazo estándar trae Despeje y la carta de rasgo)")
	print("  aguantaste el balón %d veces" % holds)
	print("  el rival jugó %d cartas defensivas contra tus ataques" % rival_defense_plays)
	print("  %d efectos de carta verificados en sus tooltips" % effect_checks)
	print("smoke_match: %d partidos, %d defensas (%d despejes de emergencia), Ejecutor Natural: %d tuyas y %d del rival, %d chequeos de postura, %d cartas en pantalla verificadas contra el motor, contragolpe visto: %s" % [
		played, defenses, emergencies, natural_plays[0], rival_natural_plays[0], lock_checks, card_checks, "sí" if exploit_seen else "no"])
	for e in errors:
		print("  ERROR: " + e)
	quit(1 if errors.size() > 0 else 0)
	return true
