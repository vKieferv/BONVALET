# Prueba de humo de la escena del partido: juega partidos completos de match_view
# (un rival por arquetipo, rotando la postura) eligiendo siempre la primera carta jugable,
# tanto en ataque como en las fases defensivas (cada tercera defensa usa el Despeje de Emergencia).
# Uno de cada dos partidos marca la casilla "Partido por zonas (prueba)" (D-36, T-10).
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
var effect_checks := 0         # cartas con efecto (avanza, roba, corta) cuya línea de efecto se revisó
var zone_checks := 0           # jugadas por zonas cuya línea de zona se comparó con el motor
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
	if match_frames % 150 == 0 and not ui_checked_errors:
		for t in Paleta.textos_chicos(view):   # ningún texto de juego bajo 14 px (D-37)
			errors.append("Texto bajo %d px en el partido: %s" % [Paleta.TEXTO_MIN, t])
		ui_checked_errors = not errors.is_empty()
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
	view._zone_check.button_pressed = played % 2 == 1   # uno de cada dos, partido por zonas (T-10)
	view._on_start_pressed()
	if view._engine != null and view._engine.zone_mode != (played % 2 == 1):
		errors.append("La casilla de zonas no llegó al motor (partido %d)" % (played + 1))
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
		if view._in_moment and e.zone_mode:
			zone_checks += 1
			var zone_line := "ZONA: " + String(MatchEngine.ZONE_NAMES[e.zone]).to_upper()
			if not view._progress_label.text.begins_with(zone_line):
				errors.append("Por zonas la línea dice '%s' pero el motor está en %s" % [view._progress_label.text, zone_line])
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
			var ap := "%d" % e.ap_cost_of(ui.card)   # moneda de PA de la lámina
			if ui.ap_label.text != ap:
				errors.append("La carta %s muestra %s pero cuesta %s" % [ui.card.display_name, ui.ap_label.text, ap])
			if ui.card.kind != Card.Kind.PAUSE:
				var wear := "%d" % roundi(e.stamina_cost_of(ui.card))   # junto a la gota, en el pie
				if ui.cost_label.text != wear:
					errors.append("La carta %s muestra '%s' pero desgasta '%s'" % [ui.card.display_name, ui.cost_label.text, wear])
			_check_effect_line(ui)
			# La carta que no se puede jugar lleva la cinta con el motivo (no se apaga); la jugable, sin cinta.
			var reason := CardUI.unplayable_reason(e, ui.card)
			if ui.ribbon.visible != (reason != "") or (reason != "" and ui.ribbon.text != reason):
				errors.append("La carta %s muestra la cinta '%s' (visible: %s) pero el motivo es '%s'" % [
					ui.card.display_name, ui.ribbon.text, ui.ribbon.visible, reason])
			if not ui.chance_label.visible:
				errors.append("La carta %s no muestra la placa con el %%" % ui.card.display_name)
	ui_checked_errors = not errors.is_empty()


# Las palabras clave de la lámina nombran lo que hace (avances, robo, corte) y solo se ven si tienen texto.
func _check_effect_line(ui: CardUI) -> void:
	var fx: String = ui.effect_label.text
	var expected: Array = []
	if ui.card.steps > 1:
		expected.append("AVANZA %d" % ui.card.steps)
	if ui.card.draw > 0:
		expected.append("ROBA %d" % ui.card.draw)
	if ui.card.kind in [Card.Kind.INTERCEPT, Card.Kind.CLEARANCE]:
		expected.append("CORTA")
	if ui.card.kind == Card.Kind.INTERCEPT or ui.card.counter:
		expected.append("CONTRAGOLPE")
	if not expected.is_empty():
		effect_checks += 1
	for word in expected:
		if not fx.contains(word):
			errors.append("La carta %s debería decir '%s' en su efecto (dice '%s')" % [ui.card.display_name, word, fx])
	if ui.effect_label.visible != (fx != ""):
		errors.append("La línea de efecto de %s está %s con el texto '%s'" % [ui.card.display_name,
				"visible" if ui.effect_label.visible else "oculta", fx])


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
		errors.append("Nunca hubo en la mano una carta con efecto (Despeje, Toque-toque...) para revisar su texto")
	if played > 1 and zone_checks == 0:
		errors.append("Nunca se revisó la línea del partido por zonas")
	print("  aguantaste el balón %d veces · %d jugadas por zonas revisadas" % [holds, zone_checks])
	print("  el rival jugó %d cartas defensivas contra tus ataques" % rival_defense_plays)
	print("smoke_match: %d partidos, %d defensas (%d despejes de emergencia), Ejecutor Natural: %d tuyas y %d del rival, %d chequeos de postura, %d cartas en pantalla verificadas contra el motor (%d con efecto), contragolpe visto: %s" % [
		played, defenses, emergencies, natural_plays[0], rival_natural_plays[0], lock_checks, card_checks, effect_checks, "sí" if exploit_seen else "no"])
	for e in errors:
		print("  ERROR: " + e)
	quit(1 if errors.size() > 0 else 0)
	return true
