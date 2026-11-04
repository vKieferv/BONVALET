# Prueba de humo de la escena del partido: juega partidos completos de match_view
# (un rival por arquetipo, rotando la postura) eligiendo siempre la primera carta jugable,
# tanto en ataque como en las fases defensivas (cada tercera defensa usa el Despeje de Emergencia).
# Los partidos pares se juegan por duelos (T-11) con el mouse simulado sobre la pantalla nueva: arrastra
# pases a un compañero y regates o remates a la cancha, elige otro portador, mantiene una lámina para ver
# la cuenta, defiende con clics y mira (o salta) el ataque del rival, comparando PA, %, portador, marcas,
# desgaste y robo con el motor. Los impares, por zonas (D-36, T-10) y con el modo actual.
# Uso: godot --headless --path . -s res://tests/smoke_match.gd [-- --matches=5]
# Sale con código 1 si un partido se cuelga, el marcador no cuadra, la postura cambia durante
# una jugada, nunca hay fase defensiva o no se prueba el contragolpe contra tu LOW.
extends SceneTree

const TIME_SCALE := 20.0
const MAX_FRAMES_PER_MATCH := 80000
const MouseDuelos := preload("res://tests/mouse_duelos.gd")

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
# Modo de duelos (T-11): se juega con el mouse simulado sobre PantallaDuelos.
var mouse: MouseDuelos
var _acting := false           # una jugada con el mouse en curso (es asíncrona)
var _match_swapped := false    # ya se eligió otro portador en este partido
var _rival_seen := -1          # índice del último ataque rival que se miró
var rival_attacks := 0
var duel_matches := 0
var duel_plays := 0
var duel_passes := 0
var duel_checks := 0
var duel_defense_plays := 0
var carrier_swaps := 0
var counts_seen := 0
var rival_steps := 0
var rival_skips := 0
var rival_fast := 0
var same_zone_mouse := 0       # pases a la misma zona (D-46) hechos con el mouse
var duel_intents := 0          # D-44: jugadas anunciadas del rival que se defendieron con el mouse
var duel_emergencies := 0
var rival_defended_plays := 0   # D-44: tus jugadas que el rival defendió antes de tirarlas
var rival_cut_plays := 0        # ...y las que te cortó
var drag_kinds := {Card.Kind.PRESS: 0, Card.Kind.INTERCEPT: 0, Card.Kind.BLOCK: 0}


func _initialize() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--matches="):
			total_matches = maxi(1, int(arg.get_slice("=", 1)))
	mouse = MouseDuelos.new(self)
	for pair in [["U. de Chile", "UCH"], ["U. Católica", "UC"], ["Colo-Colo", "CC"]]:
		if PantallaDuelos.sigla(pair[0]) != pair[1]:
			errors.append("La sigla de %s sale %s (se espera %s)" % [pair[0], PantallaDuelos.sigla(pair[0]), pair[1]])
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

	if _acting:
		return false   # el mouse simulado está en medio de una jugada de duelos
	if view._menu.visible and not view._busy:
		_check_result()
		played += 1
		if played >= total_matches:
			return _finish()
		_start_match()
		return false

	if view._rival_engine != null and view._rival_engine.exploit_rival_space:
		exploit_seen = true
	if view._duel_mode:
		_step_duel()
		return false
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
	# Los pares por duelos (T-11, la pantalla nueva); los impares, por zonas (T-10) y el modo actual.
	var mode := 0 if played % 2 == 0 else (1 if played % 4 == 1 else 2)
	view._mode_option.selected = mode
	view._on_start_pressed()
	if view._engine != null and (view._engine.zone_mode != (mode < 2) or view._engine.duel_mode != (mode == 0)):
		errors.append("El modo elegido no llegó al motor (partido %d, modo %d)" % [played + 1, mode])
	if mode == 0:
		duel_matches += 1
		_match_swapped = false
		if view._pantalla == null or view._rival_engine == null or not view._rival_engine.duel_mode:
			errors.append("Por duelos no se armó la pantalla nueva o el rival no juega por duelos (partido %d)" % (played + 1))
		elif view._pitch.visible or view._scoreboard.visible:
			errors.append("Por duelos la pantalla de siempre sigue a la vista (partido %d)" % (played + 1))
	elif view._pantalla != null:
		errors.append("Fuera de duelos quedó la pantalla de duelos (partido %d)" % (played + 1))
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
	if view._pantalla != null and view._pantalla.texto_marcador() != "%d - %d" % [real, view._rival_goals]:
		errors.append("La barra de TV dice %s y el partido terminó %d - %d" % [view._pantalla.texto_marcador(), real, view._rival_goals])
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
	if duel_matches > 0:
		if duel_passes == 0 or duel_plays == duel_passes:
			errors.append("Por duelos faltó arrastrar un pase (%d) o soltar otra jugada (%d en total)" % [duel_passes, duel_plays])
		if carrier_swaps == 0:
			errors.append("Por duelos nunca se eligió otro portador antes de jugar")
		if counts_seen == 0:
			errors.append("Por duelos nunca se vio la cuenta completa al mantener una lámina")
		if rival_steps == 0 or rival_skips == 0:
			errors.append("Por duelos no se vio el ataque del rival (%d jugadas) o no se probó SALTAR (%d)" % [rival_steps, rival_skips])
		if same_zone_mouse == 0:
			errors.append("Por duelos nunca se pasó a un compañero de la misma zona (D-46)")
		if duel_checks == 0:
			errors.append("Por duelos nunca se comparó la pantalla con el motor")
		if duel_defense_plays == 0:
			errors.append("Por duelos nunca se defendió con una lámina")
		for k in drag_kinds:
			if drag_kinds[k] == 0:
				errors.append("Por duelos nunca se arrastró una carta de tipo %d sobre un rival (D-44)" % k)
		print("  duelos D-44: el rival defendió %d de tus jugadas (%d cortadas)" % [rival_defended_plays, rival_cut_plays])
		print("  duelos D-44: %d jugadas del rival anunciadas · arrastradas: %d presiones, %d intercepciones, %d bloqueos · %d despejes de emergencia" % [
			duel_intents, drag_kinds[Card.Kind.PRESS], drag_kinds[Card.Kind.INTERCEPT], drag_kinds[Card.Kind.BLOCK], duel_emergencies])
		print("  duelos: %d pases a la misma zona (D-46) hechos con el mouse" % same_zone_mouse)
		print("  duelos: %d partidos · %d jugadas con el mouse (%d pases) · %d revisiones contra el motor · %d portadores elegidos · %d cuentas · %d jugadas del rival vistas (%d saltadas, %d aceleradas) · %d defensas con lámina" % [
			duel_matches, duel_plays, duel_passes, duel_checks, carrier_swaps, counts_seen, rival_steps, rival_skips, rival_fast, duel_defense_plays])
	print("  aguantaste el balón %d veces · %d jugadas por zonas revisadas" % [holds, zone_checks])
	print("  el rival jugó %d cartas defensivas contra tus ataques" % rival_defense_plays)
	print("smoke_match: %d partidos, %d defensas (%d despejes de emergencia), Ejecutor Natural: %d tuyas y %d del rival, %d chequeos de postura, %d cartas en pantalla verificadas contra el motor (%d con efecto), contragolpe visto: %s" % [
		played, defenses, emergencies, natural_plays[0], rival_natural_plays[0], lock_checks, card_checks, effect_checks, "sí" if exploit_seen else "no"])
	for e in errors:
		print("  ERROR: " + e)
	quit(1 if errors.size() > 0 else 0)
	return true


# ------------------------------------------------------------------ Modo de duelos (T-11)

# Un paso del partido por duelos con el mouse simulado: mirar (o saltar) el ataque rival, revisar la
# pantalla contra el motor y hacer la próxima jugada. Las jugadas son asíncronas (_acting).
func _step_duel() -> void:
	var p: PantallaDuelos = view._pantalla
	if p == null:
		return
	if p.modo == PantallaDuelos.Modo.RIVAL:
		if _rival_seen != rival_attacks:
			_rival_seen = rival_attacks
			_watch_rival(p)
		return
	if view._busy:
		return
	_check_duel(p)
	if view._in_defense:
		if not _defense_open:
			_defense_open = true
			defenses += 1
		_check_posture_lock()
		_duel_defense(p)
	elif view._in_moment:
		_check_posture_lock()
		_duel_attack(p)


# Ataque del rival: unos se miran enteros, otros acelerados y otros se saltan.
func _watch_rival(p: PantallaDuelos) -> void:
	_acting = true
	var k := rival_attacks
	await mouse.cuadros(2)
	if k % 3 == 1 and p.modo == PantallaDuelos.Modo.RIVAL:
		await mouse.clic(p._boton_saltar.get_global_rect().get_center())
		rival_skips += 1
	elif k % 3 == 2 and p.modo == PantallaDuelos.Modo.RIVAL:
		await mouse.clic(p._boton_acelerar.get_global_rect().get_center())
		rival_fast += 1
	var left := 6000
	var last := {}
	while p.modo == PantallaDuelos.Modo.RIVAL and left > 0:
		if not p.ultima_tirada.is_empty() and p.ultima_tirada != last:
			last = p.ultima_tirada
			rival_steps += 1
		await mouse.cuadros(1)
		left -= 1
	rival_attacks += 1
	_acting = false


func _duel_defense(p: PantallaDuelos) -> void:
	_acting = true
	var e: MatchEngine = view._engine
	if e.duel_defense_on():
		await _duel_drag_defense(p)
	elif defenses % 3 == 0 and e.can_emergency_clear():
		emergencies += 1
		await mouse.clic(p._boton_aguantar.get_global_rect().get_center())   # en la defensa dice DESPEJE
	else:
		var played_card := false
		for ui in p.laminas():
			if e.can_play(ui.card):
				var plays_before: int = e.stats["defense_plays"]
				await mouse.clic(ui.get_global_rect().get_center())
				played_card = int(e.stats["defense_plays"]) == plays_before + 1
				if not played_card:
					errors.append("Un clic en la lámina de defensa %s no la jugó" % ui.card.display_name)
				duel_defense_plays += 1
				break
		if not played_card and view._in_defense:
			await mouse.clic(p._boton_ceder.get_global_rect().get_center())   # dejar pasar
	await _wait_idle()
	_acting = false


# D-44 (T-15): el rival anunció su jugada. Se compara su intención con su motor y se defiende arrastrando la
# lámina sobre el rival: el apuntado, la placa (tu %), tu defensor resaltado y la tirada contra el motor. Las
# láminas de inicio solo traen Marca y Despeje: la primera vez que el rival pasa (o remata) se agrega a la
# mano una Intercepción (o un Bloqueo) para probarlos también. Cada tanto se deja pasar o se despeja de
# emergencia contra un remate.
func _duel_drag_defense(p: PantallaDuelos) -> void:
	var e: MatchEngine = view._engine
	var r: MatchEngine = view._rival_engine
	var it: Dictionary = view._intent_actual
	var ic: Card = it.get("card")
	await mouse.cuadros(2)
	if not view._in_defense or it.is_empty():
		return
	duel_intents += 1
	var rival_pct := roundi((r.hold_chance() if ic == null else r.success_chance(ic, -1, String(it.get("receiver", "")))) * 100.0)
	if p.intencion_pct() != rival_pct or not p.intencion_texto().ends_with("%d%%" % rival_pct):
		errors.append("La intención del rival dice '%s' y su motor tira contra %d%%" % [p.intencion_texto(), rival_pct])
	var plate := p.placa_info()
	if plate.is_empty() or int(plate["pct"]) != rival_pct:
		errors.append("La placa de la jugada del rival dice %s y su motor %d%%" % [plate.get("pct", "nada"), rival_pct])
	if ic != null and ic.kind == Card.Kind.SHOT and e.can_emergency_clear() and duel_emergencies == 0 and duel_intents > 3:
		duel_emergencies += 1
		await mouse.clic(p._boton_aguantar.get_global_rect().get_center())   # DESPEJE de emergencia
		await _wait_idle()
		if e.in_defense:
			errors.append("El Despeje de emergencia no cerró la defensa")
		return
	if ic != null:
		var want := ""
		if ic.kind == Card.Kind.SHOT and drag_kinds[Card.Kind.BLOCK] == 0:
			want = "bloqueo"
		elif MatchEngine.is_pass(ic) and drag_kinds[Card.Kind.INTERCEPT] == 0:
			want = "intercepcion"
		if want != "":
			var extra := Card.from_dict(CardDB.load_catalog("res://data/cards.json")[want])
			if e.ap >= e.ap_cost_of(extra):
				e.deck.hand.append(extra)
				view._build_hand()
				await mouse.cuadros(2)
	var pick: CardUI = null
	for ui in p.laminas():
		if e.can_play(ui.card) and ui.card.kind != Card.Kind.CLEARANCE:
			if pick == null or drag_kinds[ui.card.kind] < drag_kinds[pick.card.kind]:
				pick = ui
	if pick == null or duel_intents % 4 == 0:
		await mouse.clic(p._boton_ceder.get_global_rect().get_center())   # DEJAR PASAR esta jugada
		await _wait_idle()
		return
	var c: Card = pick.card
	var target := e.defense_target(c)
	var to := p.punto_de("V:" + target)
	if c.kind == Card.Kind.INTERCEPT and p._linea_rival_2d.size() > 4:
		to = p._linea_rival_2d[p._linea_rival_2d.size() / 2]   # sobre la línea del pase, no sobre el receptor
	var from := pick.get_global_rect().get_center()
	await mouse.arrastrar_hasta(from, to)
	for k in 30:   # los jugadores todavía pueden estar llegando a su lugar: se sigue al rival
		var now := p.punto_de("V:" + target)
		if c.kind == Card.Kind.INTERCEPT and p._linea_rival_2d.size() > 4:
			now = p._linea_rival_2d[p._linea_rival_2d.size() / 2]
		if now.distance_to(to) < 1.0 and k > 2:
			break
		to = now
		mouse.mover(to)
		await mouse.cuadros(1)
	await mouse.cuadros(2)
	var shown := e.success_chance(c)
	if p.apuntado() != target:
		errors.append("Arrastrar %s sobre %s apuntó a '%s'" % [c.display_name, target, p.apuntado()])
	var info := p.placa_info()
	if info.is_empty() or int(info["pct"]) != roundi(shown * 100.0) or String(info["clave"]) != "V:" + target:
		errors.append("La placa de %s dice %s junto a %s; el motor tira contra %d%% sobre %s" % [c.display_name,
			info.get("pct", "nada"), info.get("clave", "-"), roundi(shown * 100.0), target])
	var defender := String(e.defense_defender(c).get("id", ""))
	if p.defensor_resaltado() != "L:" + defender:
		errors.append("Se resalta a %s y la carta la juega %s" % [p.defensor_resaltado(), defender])
	var plays_before: int = e.stats["defense_plays"]
	mouse.soltar(to)
	await mouse.cuadros(2)
	if int(e.stats["defense_plays"]) != plays_before + 1:
		errors.append("Soltar %s sobre el rival no la jugó" % c.display_name)
	elif int(p.ultima_tirada.get("pct", -1)) != roundi(shown * 100.0):
		errors.append("La tirada de %s muestra %s y se tiró contra %d%%" % [c.display_name, p.ultima_tirada.get("pct", "-"), roundi(shown * 100.0)])
	else:
		drag_kinds[c.kind] += 1
		duel_defense_plays += 1
	await _wait_idle()


func _duel_attack(p: PantallaDuelos) -> void:
	_acting = true
	var e: MatchEngine = view._engine
	var carrier := String(e.carrier.get("id", ""))
	# Antes de la primera jugada, una vez por partido: salir con otro compañero de la zona (un clic sobre él).
	if not _match_swapped and e.moment_plays == 0:
		var others: Array = e.zone_players(e.zone).filter(func(pl): return pl["id"] != carrier)
		_match_swapped = true
		if not others.is_empty():
			var id := String(others[0]["id"])
			await mouse.clic(p.punto_de("L:" + id))
			await _wait_idle()
			if String(e.carrier.get("id", "")) != id:
				errors.append("Un clic en %s no lo dejó con la pelota (sigue %s)" % [id, e.carrier.get("id", "")])
			else:
				carrier_swaps += 1
				if p.portador() != "L:" + id:
					errors.append("La pantalla no cambió al portador elegido")
			_acting = false
			return
	# Una vez: mantener una lámina quieta muestra la cuenta, y soltarla no la juega.
	if counts_seen == 0 and not p.laminas().is_empty():
		var ui: CardUI = p.laminas()[0]
		var card: Card = ui.card
		var plays_before: int = e.stats["plays"]
		var center := ui.get_global_rect().get_center()
		mouse.apretar(center)
		var n := 0
		while not p.cuenta_visible() and n < 300:
			await mouse.cuadros(1)
			n += 1
		if not p.cuenta_visible():
			errors.append("Mantener la lámina %s no mostró la cuenta" % card.display_name)
		else:
			counts_seen += 1
			_check_count_lines(p, card, "")
		mouse.soltar(center)
		await mouse.cuadros(2)
		if int(e.stats["plays"]) != plays_before or p.cuenta_visible():
			errors.append("Soltar después de ver la cuenta jugó la carta o dejó la cuenta abierta")
		_acting = false
		return
	if holds == 0 and e.can_hold():
		holds += 1
		await mouse.clic(p._boton_aguantar.get_global_rect().get_center())
		await _wait_idle()
		_acting = false
		return
	for ui in p.laminas():
		var c: Card = ui.card
		if not e.can_play(c):
			continue
		var from := ui.get_global_rect().get_center()
		var receiver := ""
		var same := false
		var target := p.punto_de("L:" + carrier)
		if MatchEngine.is_pass(c):
			var options: Array = e.receivers(c)
			receiver = String(options[duel_plays % options.size()]["id"])
			var same_options: Array = options.filter(func(r): return e.pass_zone(c, r["id"]) == e.zone and e.target_zone(c) != e.zone)
			if duel_passes % 3 == 1 and not same_options.is_empty():   # D-46: también se pasa en la misma zona
				receiver = String(same_options[0]["id"])
			same = same_options.any(func(r): return r["id"] == receiver)
			if same:
				same_zone_mouse += 1
			target = p.punto_de("L:" + receiver)
		else:
			target.y = minf(target.y, p._alto_senal - 30.0)
		await mouse.arrastrar_hasta(from, target)
		if receiver != "":
			# El receptor puede venir corriendo y la cámara deslizándose (a 20×): el mouse lo sigue hasta que
			# se queda quieto en la pantalla, como haría alguien mirándolo.
			for i in 120:
				await mouse.cuadros(1)
				var now := p.punto_de("L:" + receiver)
				mouse.mover(now)
				if now.distance_to(target) < 1.0 and p.apuntado() == receiver:
					break
				target = now
			var visible_area := Rect2(0, 44, p._ancho, p._alto_senal - 44)
			if not visible_area.has_point(target):
				errors.append("El receptor %s queda fuera de la señal (%s): no se le puede pasar con el mouse" % [receiver, target])
		await mouse.cuadros(2)
		var shown := ui.chance_label.text if is_instance_valid(ui) else ""
		var expected := "%d%%" % roundi(e.success_chance(c, -1, receiver) * 100.0)
		if receiver != "":
			if p.apuntado() != receiver:
				errors.append("Arrastrando %s sobre %s, la pantalla apunta a '%s'" % [c.display_name, receiver, p.apuntado()])
			_check_count_lines(p, c, receiver)
			var plate := p.placa_info()
			if not p.placa_visible() or "%d%%" % int(plate.get("pct", -1)) != expected:
				errors.append("Apuntando %s a %s, la placa junto al receptor dice %s (visible: %s) y el motor %s" % [c.display_name, receiver, plate.get("pct", "—"), p.placa_visible(), expected])
			if same and not plate.get("misma_zona", false):
				errors.append("El pase en la misma zona no dice NO AVANZA en la placa")
		if shown != expected:
			errors.append("Apuntando %s, la lámina dice %s y el motor tira contra %s" % [c.display_name, shown, expected])
		var plays_before: int = e.stats["plays"]
		var rival_def: MatchEngine = view._rival_engine
		var rdef_before: int = rival_def.stats["defense_plays"]
		var rhit_before: float = float(rival_def.defense_result.get("pressure", 0.0)) + float(rival_def.defense_result.get("block", 0.0))
		mouse.soltar(target)
		await mouse.cuadros(1)
		# D-44: el rival puede defender la jugada antes de que se tire; se espera su tirada.
		var waited := 0
		while int(rival_def.stats["defense_plays"]) != rdef_before and int(e.stats["plays"]) == plays_before \
				and not e.moment_over and waited < 3000:
			await mouse.cuadros(1)
			waited += 1
		if int(rival_def.stats["defense_plays"]) != rdef_before:
			rival_defended_plays += 1
			var hit := float(rival_def.defense_result.get("pressure", 0.0)) + float(rival_def.defense_result.get("block", 0.0)) - rhit_before
			expected = "%d%%" % maxi(5, int(expected.trim_suffix("%")) - roundi(hit * 100.0))
		if int(rival_def.stats["defense_plays"]) != rdef_before and e.moment_over and int(e.stats["plays"]) == plays_before:
			rival_cut_plays += 1   # te cortó antes de tirar
		elif int(e.stats["plays"]) != plays_before + 1:
			errors.append("Soltar %s no la jugó (apuntaba a '%s', receptor '%s', se puede: %s, ocupado: %s)" % [c.display_name,
				p.apuntado(), receiver, e.can_play(c, receiver), view._busy])
		elif int(p.ultima_tirada.get("pct", -1)) != int(expected.trim_suffix("%")):
			errors.append("La tirada de %s se ve contra %d%% y la lámina decía %s" % [c.display_name, int(p.ultima_tirada.get("pct", -1)), expected])
		duel_plays += 1
		if receiver != "":
			duel_passes += 1
		await _wait_idle()
		_acting = false
		return
	# Sin jugadas: aguantar si queda, o CEDER JUGADA.
	if e.can_hold():
		holds += 1
		await mouse.clic(p._boton_aguantar.get_global_rect().get_center())
	else:
		await mouse.clic(p._boton_ceder.get_global_rect().get_center())
	await _wait_idle()
	_acting = false


func _wait_idle() -> void:
	var n := 0
	await mouse.cuadros(1)
	while view._busy and n < 6000:
		await mouse.cuadros(1)
		n += 1


# La pantalla de duelos contra el motor: PA, mazo, descarte, portador, zona, marcas de cada etiqueta y, en
# cada lámina, su %, sus PA, su desgaste, su línea (ROBA) y su cinta.
func _check_duel(p: PantallaDuelos) -> void:
	if ui_checked_errors:
		return
	var e: MatchEngine = view._engine
	if not (view._in_moment or e.in_defense) or p.arrastrando():
		return
	duel_checks += 1
	if p.pa_texto() != "%d" % e.ap:
		errors.append("La moneda dice %s PA y el turno tiene %d" % [p.pa_texto(), e.ap])
	if p.mazo_texto() != "MAZO %d" % e.deck.draw_pile.size() or p.descarte_texto() != "DESCARTE %d" % e.deck.discard_pile.size():
		errors.append("La pantalla dice '%s' y '%s'; el motor, %d y %d" % [p.mazo_texto(), p.descarte_texto(),
			e.deck.draw_pile.size(), e.deck.discard_pile.size()])
	if view._in_moment and p.modo == PantallaDuelos.Modo.ATAQUE:
		var carrier := String(e.carrier.get("id", ""))
		if p.portador() != "L:" + carrier:
			errors.append("La pantalla tiene la pelota en %s y el motor en %s" % [p.portador(), carrier])
		var surname := PantallaDuelos.apellido(String(e.carrier.get("name", "")))
		if not p.texto_con_balon().contains(surname):
			errors.append("CON EL BALÓN dice '%s' y el portador es %s" % [p.texto_con_balon(), surname])
		if p.zona_camino() != e.zone:
			errors.append("El camino marca la zona %d y el motor está en la %d" % [p.zona_camino(), e.zone])
		var labels := p.etiquetas()
		if labels.is_empty():
			errors.append("Atacando por duelos no hay etiquetas sobre tus jugadores")
		for key: String in labels:
			var info: Dictionary = p._info.get(key, {})
			var real := e.markers_of(int(info.get("zona", -1)), key.substr(2)).size()
			if int(labels[key]["puntos"]) != real:
				errors.append("%s muestra %d marcas y el motor le pone %d" % [labels[key]["texto"], labels[key]["puntos"], real])
			if real == 0 and key != p.portador() and not String(labels[key]["texto"]).ends_with("LIBRE"):
				errors.append("%s está libre y su etiqueta no lo dice" % labels[key]["texto"])
	for ui in p.laminas():
		var c: Card = ui.card
		if c.type == Card.Type.PENALTY:
			continue
		card_checks += 1
		var choose := p.modo == PantallaDuelos.Modo.ATAQUE and MatchEngine.is_pass(c)
		var useless := p.modo == PantallaDuelos.Modo.DEFENSA and e.duel_defense_on() and c.kind != Card.Kind.CLEARANCE and e.defense_target(c) == ""
		if choose:
			if ui.chance_label.visible:
				errors.append("El pase %s muestra %s antes de apuntar (debería decir ELIGE)" % [c.display_name, ui.chance_label.text])
		elif useless:
			if ui.chance_label.visible:
				errors.append("La lámina %s no sirve contra la jugada del rival y muestra %s" % [c.display_name, ui.chance_label.text])
		elif ui.chance_label.text != "%d%%" % roundi(e.success_chance(c) * 100.0) or not ui.chance_label.visible:
			errors.append("La lámina %s muestra %s pero el motor tira contra %d%%" % [c.display_name, ui.chance_label.text, roundi(e.success_chance(c) * 100.0)])
		if ui.ap_label.text != "%d" % e.ap_cost_of(c):
			errors.append("La lámina %s cuesta %s en pantalla y %d en el motor" % [c.display_name, ui.ap_label.text, e.ap_cost_of(c)])
		if c.kind != Card.Kind.PAUSE and ui.cost_label.text != "%d" % roundi(e.stamina_cost_of(c)):
			errors.append("La lámina %s desgasta '%s' en pantalla y %d en el motor" % [c.display_name, ui.cost_label.text, roundi(e.stamina_cost_of(c))])
		if c.draw > 0 and not ui.effect_label.text.contains("ROBA %d" % c.draw):
			errors.append("La lámina %s roba %d y su línea dice '%s'" % [c.display_name, c.draw, ui.effect_label.text])
		var reason := CardUI.unplayable_reason(e, c)
		if ui.ribbon.visible != (reason != ""):
			errors.append("La lámina %s tiene la cinta %s y el motivo es '%s'" % [c.display_name, ui.ribbon.visible, reason])
	ui_checked_errors = not errors.is_empty()


# La cuenta completa: el acierto y el robo son los del motor (lo que se tira).
func _check_count_lines(p: PantallaDuelos, c: Card, receiver: String) -> void:
	var e: MatchEngine = view._engine
	var r := receiver
	if MatchEngine.is_pass(c) and r == "" and p.modo == PantallaDuelos.Modo.ATAQUE:
		r = e.best_receiver(c)
	var lines := {}
	for l: Array in p.cuenta_de(c, receiver):
		lines[l[0]] = l[1]
	if lines.get("Acierto", "") != "%d%%" % roundi(e.success_chance(c, -1, r) * 100.0):
		errors.append("La cuenta de %s dice acierto %s y el motor %d%%" % [c.display_name, lines.get("Acierto", "?"), roundi(e.success_chance(c, -1, r) * 100.0)])
	var steal := roundi(e.steal_chance(c, -1, r) * 100.0)
	if steal > 0 and lines.get("Robo si falla", "") != "%d%%" % steal:
		errors.append("La cuenta de %s dice robo %s y el motor %d%%" % [c.display_name, lines.get("Robo si falla", "—"), steal])
