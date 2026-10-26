# Pruebas del modo carrera sin escenas: planteles, mazo por club, Ejecutor Natural por titulares
# y reglas de la semana (sponsor, evento social, entrenamiento, partido) y el guardado de la carrera.
# Uso: godot --headless --path . -s res://tests/career_rules.gd
extends SceneTree

const LEAGUE_ID := "chile_2006"
const REAL_SQUADS := ["colo_colo", "universidad_de_chile", "universidad_catolica"]
const TEST_SAVE := "user://test_carrera.json"   # nunca la partida real (user://carrera.json)

var failures: Array[String] = []
var checks := 0
var league: LeagueManager
var squads: SquadManager


func _initialize() -> void:
	Career.save_path = TEST_SAVE
	league = LeagueManager.new()
	_check(league.load_all(), "LeagueManager no carga: %s" % [league.load_errors])
	squads = SquadManager.new()
	_check(squads.load_all(league), "SquadManager no carga: %s" % [squads.load_errors])
	_test_all_squads()
	_test_real_squads()
	_test_generator_is_deterministic()
	_test_decks_for_every_club()
	_test_natural_executor_by_lineup()
	_test_big_clubs_bring_their_stars()
	_test_week_flow()
	_test_career_stamina()
	_test_rivals_and_sponsor_scale()
	_test_save_round_trip()
	_test_save_pending_match()
	_test_save_errors()
	if FileAccess.file_exists(TEST_SAVE):
		DirAccess.remove_absolute(TEST_SAVE)
	print("career_rules: %d comprobaciones, %d fallas" % [checks, failures.size()])
	for f in failures:
		print("  FALLA: " + f)
	quit(1 if failures.size() > 0 else 0)


func _check(cond: bool, msg: String) -> void:
	checks += 1
	if not cond:
		failures.append(msg)


func _test_all_squads() -> void:
	var all_ids := {}
	for t in league.teams:
		var errors := squads.squad_errors(t["id"])
		_check(errors.is_empty(), "plantel de %s: %s" % [t["id"], errors])
		for p in squads.get_squad(t["id"]):
			_check(not all_ids.has(p["id"]), "id de jugador repetido entre clubes: %s" % p["id"])
			all_ids[p["id"]] = true
			for key in ["name", "nationality", "position", "role", "stamina_max", "skill_rating"]:
				_check(p.has(key) and p[key] != null, "%s: falta %s" % [p["id"], key])
		_check(squads.pick_starters(t["id"]).size() == 11, "%s debería tener 11 titulares" % t["id"])


func _test_real_squads() -> void:
	for id in REAL_SQUADS:
		_check(not squads.is_generated(id), "%s debería usar su plantel real" % id)
	var starters := squads.lineup_ids("colo_colo")
	_check(starters.has("humberto_suazo"), "Suazo debería ser titular en Colo-Colo")
	_check(squads.find_player("colo_colo", "humberto_suazo").get("signature_card_id") == "zapatazo", "Suazo es dueño del Zapatazo")
	# Cartas firma propias de los grandes; una figura sin carta propia recibe la genérica.
	_check(squads.find_player("universidad_de_chile", "herly_alcazar").get("signature_card_id") == "arremetida_alcazar",
			"Alcázar debería tener su Arremetida")
	_check(squads.find_player("universidad_catolica", "juan_manuel_arostegui").get("signature_card_id") == "sangre_fria_arostegui",
			"Aróstegui debería tener su Sangre fría")
	var figure := String(league.get_team("everton")["signature_card"])
	var everton_figure: Array = squads.get_squad("everton").filter(func(p): return p["name"] == figure)
	_check(not everton_figure.is_empty() and String(everton_figure[0]["signature_card_id"]).begins_with("firma_"),
			"la figura de Everton (sin carta propia) debería recibir la carta firma genérica")


func _test_generator_is_deterministic() -> void:
	var other := SquadManager.new()
	other.load_all(league)
	for id in ["everton", "magallanes", "nublense"]:
		var a: Array = squads.get_squad(id)
		var b: Array = other.get_squad(id)
		_check(a.size() == b.size() and a[0]["name"] == b[0]["name"] and a[17]["name"] == b[17]["name"],
				"el plantel generado de %s debería ser igual en cada carga" % id)
	var figure := String(league.get_team("everton")["signature_card"])
	var has_figure := squads.get_squad("everton").any(func(p): return p["name"] == figure)
	_check(has_figure, "el plantel generado de Everton debería incluir a su figura real (%s)" % figure)


func _test_decks_for_every_club() -> void:
	var templates := CardDB.load_templates("res://data/cards.json")
	var limit := int(league.get_rules(LEAGUE_ID).get("sub21_age_limit", 21))
	for t in league.teams:
		var deck := squads.build_match_deck(t["id"], templates)
		var size_error := DeckManager.new(deck, [], RandomNumberGenerator.new()).size_error()
		_check(size_error == "", "%s: %s" % [t["id"], size_error])
		var r := league.validate_deck(deck, LEAGUE_ID)
		_check(r["valid"], "%s: el mazo no pasa validate_deck: %s" % [t["id"], r["errors"]])
		for c in deck:
			if c.tags.has("canterano"):
				var p := squads.find_player(t["id"], c.owner_id)
				_check(not p.is_empty() and int(p["age"]) < limit, "%s: la carta de canterano debería ser de un Sub-21 del plantel" % t["id"])


func _test_natural_executor_by_lineup() -> void:
	var templates := CardDB.load_templates("res://data/cards.json")
	var deck := squads.build_match_deck("colo_colo", templates)
	var zapatazo: Card = null
	for c in deck:
		if c.id == "zapatazo":
			zapatazo = c
	_check(zapatazo != null and zapatazo.owner_id == "humberto_suazo", "el mazo de Colo-Colo debería traer el Zapatazo de Suazo")
	var rng := RandomNumberGenerator.new()
	rng.seed = 4
	var player := PlayerStats.new()
	player.lineup = squads.lineup_ids("colo_colo")
	var e := MatchEngine.new(player, DeckManager.new(deck, [], rng), rng, 0.15)
	if zapatazo != null:
		_check(e.is_natural_executor(zapatazo), "Suazo titular: el Zapatazo debería activar el Ejecutor Natural")
		player.lineup = []
		_check(not e.is_natural_executor(zapatazo), "sin Suazo en cancha el Zapatazo no debería activar el Ejecutor Natural")
	# Funado: +50% de desgaste de estamina en sus cartas, mismos PA.
	if zapatazo != null:
		var base_wear := e.stamina_cost_of(zapatazo)
		var base_ap := e.ap_cost_of(zapatazo)
		e.owner_stamina_mult = {"humberto_suazo": 1.5}
		_check(is_equal_approx(e.stamina_cost_of(zapatazo), base_wear * 1.5) and e.ap_cost_of(zapatazo) == base_ap,
				"el funado debería gastar +50% de estamina en sus cartas, con los mismos PA")


# Paridad: un club rival arma el mismo mazo que tendría como club propio. Los grandes traen la
# carta firma de su figura titular, y con sus titulares en cancha el Ejecutor Natural se activa.
func _test_big_clubs_bring_their_stars() -> void:
	var templates := CardDB.load_templates("res://data/cards.json")
	for id in REAL_SQUADS:
		var as_dicts := squads.build_match_templates(id, templates)
		var deck := squads.build_match_deck(id, templates)
		_check(as_dicts.size() == deck.size(), "%s: el mazo en diccionarios y en cartas debería ser el mismo" % id)
		var player := PlayerStats.new()
		player.lineup = squads.lineup_ids(id)
		var rng := RandomNumberGenerator.new()
		var e := MatchEngine.new(player, DeckManager.new(deck, [], rng), rng, 0.15)
		var figure := String(league.get_team(id)["signature_card"])
		var star_card := false
		for c in deck:
			var owner := squads.find_player(id, c.owner_id)
			if c.type == Card.Type.ELITE and owner.get("name", "") == figure:
				star_card = true
				_check(e.is_natural_executor(c), "%s: la carta firma de %s debería activar el Ejecutor Natural" % [id, figure])
		_check(star_card, "%s: el mazo debería traer la carta firma de %s" % [id, figure])


func _test_week_flow() -> void:
	var c := Career.new()
	_check(c.setup(league, squads, "colo_colo", 1234), "Career no arranca: %s" % [c.load_errors])
	_check(not c.prepare_match()["ok"], "sin completar los bloques no se debería poder jugar")
	_check(c.choose_sponsor("telnet"), "debería poder elegir Telnet")
	var ev := c.resolve_event(true)
	_check(ev.has("lines") and not ev["lines"].is_empty(), "el evento debería devolver su resultado")
	_check(c.match_mods.get("opening_bonus", 0.0) > 0.0, "aceptar la fiesta debería dar el bono de apertura")
	if ev["funa"]:
		_check(c.sponsor_week_lost, "con funa y Telnet (cláusula de conducta) se pierde el pago de la semana")
		_check(c.match_mods.get("funado_id", "") != "", "con funa debería haber un jugador funado")
	_check(c.choose_training("tactical"), "debería poder elegir entrenamiento táctico")
	var fatigue_before := c.fatigue
	var r := c.prepare_match()
	_check(r["ok"], "con los bloques completos el partido debería validarse: %s" % [r["errors"]])
	_check(c.pending_match and c.fatigue == fatigue_before + 10.0, "el entrenamiento táctico suma 10 de fatiga")

	var rng := RandomNumberGenerator.new()
	var player := PlayerStats.new()
	var e := MatchEngine.new(player, DeckManager.new(c.build_deck(), [], rng), rng, 0.15)
	c.configure_match(e, player)
	_check(is_equal_approx(e.form_bonus, 0.03) and player.lineup.size() == 11 and player.fatigue == c.fatigue,
			"configure_match debería pasar forma, titulares y fatiga al partido")

	var budget := c.budget
	var rival := c.rival_id
	var lost := c.sponsor_week_lost
	var entry := c.record_match(2, 1)
	_check(entry.get("rival_id", "") == rival and c.week == 2 and not c.pending_match, "record_match cierra la semana")
	# Con funa + cláusula de conducta se pierde el fijo, pero el bono por victoria se paga igual.
	_check(c.budget > budget, "ganar con sponsor debería sumar presupuesto (pago perdido: %s)" % lost)
	_check(c.event_result.is_empty() and c.training == "" and c.rival_id != rival, "la semana 2 empieza limpia y con otro rival")


# Integración del modelo PA + Estamina en la carrera: la funa (+50% de desgaste) llega al partido,
# la fatiga define la estamina inicial (que se restablece en cada partido), la kinesiología la mejora
# y la fatiga post-partido depende de la estamina que quedó.
func _test_career_stamina() -> void:
	var c: Career = null
	for seed in range(1, 200):
		var t := Career.new()
		t.setup(league, squads, "colo_colo", seed)
		t.choose_sponsor("cerveza_glaciar")
		if t.resolve_event(true)["funa"]:
			c = t
			break
	_check(c != null, "alguna semilla debería producir una funa al aceptar la fiesta")
	if c == null:
		return
	var funado: String = c.match_mods.get("funado_id", "")
	_check(funado != "" and c.funado_name() != "", "la funa debería tener un funado con nombre")
	_check(c.choose_training("physio") and c.prepare_match()["ok"], "la semana con funa debería poder jugarse")

	var rng := RandomNumberGenerator.new()
	rng.seed = 9
	var player := PlayerStats.new()
	var deck := c.build_deck()
	var e := MatchEngine.new(player, DeckManager.new(deck, [], rng), rng, 0.15)
	c.configure_match(e, player)
	var clean := MatchEngine.new(PlayerStats.new(), DeckManager.new([], [], rng), rng, 0.15)
	var owned: Card = null
	for card in deck:
		if card.owner_id == funado:
			owned = card
	_check(owned != null, "el funado debería tener una carta en el mazo (por eso se le elige)")
	if owned != null:
		_check(is_equal_approx(e.stamina_cost_of(owned), clean.stamina_cost_of(owned) * 1.5),
				"en el partido, las cartas del funado deberían gastar +50% de estamina")
		_check(e.ap_cost_of(owned) == clean.ap_cost_of(owned), "la funa no cambia los PA")

	# La fatiga define la estamina inicial y la estamina se restablece en cada partido.
	c.fatigue = 60.0
	c.configure_match(e, player)
	e.start()
	_check(is_equal_approx(player.energy_pct(), 0.7), "con fatiga 60 se arranca con 70%% de estamina (%.2f)" % player.energy_pct())
	player.energy = 1.0
	e.start()
	_check(is_equal_approx(player.energy_pct(), 0.7), "cada partido restablece la estamina según la fatiga")
	_check(c.start_stamina_preview(-25.0)["pct"] > c.start_stamina_preview()["pct"],
			"la kinesiología debería mejorar la estamina con que se arranca")
	_check(c.start_stamina_preview()["pct"] == 70, "el calendario debería anticipar el 70%")

	# Fatiga post-partido: terminar agotado cansa más que terminar entero.
	var m: Dictionary = c.data["match"]
	var before := c.fatigue
	var entry := c.record_match(1, 0, 0.1)
	var expected := float(m["fatigue_base"]) + float(m["fatigue_from_wear"]) * 0.9
	_check(is_equal_approx(c.fatigue, clampf(before + expected, 0.0, 100.0)),
			"fatiga post-partido = base + desgaste x estamina gastada (%.1f -> %.1f)" % [before, c.fatigue])
	_check(entry["fatigue_gained"] > roundi(float(m["fatigue_base"]) + float(m["fatigue_from_wear"]) * 0.1),
			"terminar agotado debería sumar más fatiga que terminar entero")
	_check(c.match_mods.is_empty() and c.funado_name() == "", "la semana siguiente empieza sin funa")


func _test_rivals_and_sponsor_scale() -> void:
	var c := Career.new()
	c.setup(league, squads, "colo_colo", 7)
	var seen := {}
	for w in 25:
		c.week = w + 1
		var r := c.next_rival()
		_check(r != "colo_colo" and not league.get_team(r).get("suspended", false), "rival inválido: %s" % r)
		_check(league.get_team(r)["division"] == "Primera A", "el rival debería ser de la misma división")
		seen[r] = true
	_check(not seen.has("deportes_concepcion"), "Deportes Concepción (suspendido) no debería jugar")
	var telnet := c.get_sponsor("telnet")
	var big: int = c.sponsor_offer(telnet)["weekly"]
	var small := Career.new()
	small.setup(league, squads, "magallanes", 7)
	_check(small.sponsor_offer(telnet)["weekly"] < big, "un club de Primera B nivel 0 debería recibir menos que Colo-Colo")


# Guardado: una semana completa y otra a medias, guardar, cargar → mismo estado, y el azar sigue
# igual (el evento de la semana siguiente sale igual en la original y en la cargada).
func _test_save_round_trip() -> void:
	var c := Career.new()
	c.setup(league, squads, "colo_colo", 4321)
	c.choose_sponsor("telnet")
	c.resolve_event(true)
	c.choose_training("tactical")
	_check(c.prepare_match()["ok"], "la semana 1 de la prueba de guardado debería poder jugarse")
	c.record_match(2, 1, 0.3)
	c.choose_sponsor("cerveza_glaciar")
	c.resolve_event(true)   # semana 2 a medias: evento resuelto, sin entrenamiento
	_check(c.save(), "save() debería escribir %s" % TEST_SAVE)
	var loaded := Career.load_saved(league, squads)
	_check(loaded != null, "la carrera guardada debería cargar: %s" % [Career.last_load_errors])
	if loaded == null:
		return
	var a := c.to_dict()
	var b := loaded.to_dict()
	_check(a.size() == b.size(), "to_dict debería tener los mismos campos tras cargar")
	for key in a:
		_check(b.has(key) and typeof(a[key]) == typeof(b[key]) and a[key] == b[key],
				"campo %s distinto tras cargar: %s -> %s" % [key, a[key], b.get(key)])
	_check(loaded.history.size() == 1 and typeof(loaded.history[0]["gf"]) == TYPE_INT, "el historial vuelve con enteros")
	_check(loaded.blocks_done()["block1"] and not loaded.blocks_done()["block2"], "la semana a medias sigue a medias")

	# El azar sigue igual: misma semana 3 y mismo resultado del evento en las dos.
	for x in [c, loaded]:
		x.choose_training("physio")
		x.prepare_match()
		x.record_match(0, 0)
		x.choose_sponsor("telnet")
		x.resolve_event(true)
	_check(c.week == 3 and loaded.week == 3, "ambas carreras deberían llegar a la semana 3")
	_check(c.event_result == loaded.event_result and c.match_mods == loaded.match_mods,
			"el evento de la semana 3 debería salir igual tras cargar: %s vs %s" % [c.event_result, loaded.event_result])
	_check(c.rng.state == loaded.rng.state and c.rng.randi() == loaded.rng.randi(),
			"el estado del azar debería seguir igual tras cargar")


# Si se cerró el juego durante el partido, la carrera vuelve al Bloque 3 con ese partido por jugar,
# sin volver a sumar la fatiga del entrenamiento.
func _test_save_pending_match() -> void:
	var c := Career.new()
	c.setup(league, squads, "universidad_catolica", 77)
	c.choose_sponsor("telnet")
	c.resolve_event(false)
	c.choose_training("tactical")
	c.prepare_match()
	c.save()
	var loaded := Career.load_saved(league, squads)
	_check(loaded != null and loaded.pending_match, "el partido pendiente debería seguir pendiente tras cargar")
	if loaded == null:
		return
	var fatigue := loaded.fatigue
	_check(loaded.prepare_match()["ok"] and loaded.fatigue == fatigue, "el partido pendiente se juega sin sumar fatiga otra vez")
	_check(not loaded.choose_training("physio"), "con el partido pendiente los bloques 1 y 2 quedan cerrados")
	_check(loaded.rival_id == c.rival_id and not loaded.record_match(1, 1).is_empty() and loaded.week == 2,
			"el partido pendiente cierra la semana al jugarse")


# Errores de carga: devuelven null con el motivo en Career.last_load_errors, sin errores de script.
func _test_save_errors() -> void:
	if FileAccess.file_exists(TEST_SAVE):
		DirAccess.remove_absolute(TEST_SAVE)
	_check(Career.load_saved(league, squads) == null and not Career.last_load_errors.is_empty(),
			"sin archivo de guardado la carga debería devolver null con motivo")

	var good := Career.new()
	good.setup(league, squads, "colo_colo", 5)
	var cases := {"JSON roto": "{\"version\": 1, \"team_id\": "}
	var other_version := good.to_dict()
	other_version["version"] = 2
	cases["otra versión"] = JSON.stringify(other_version)
	var unknown_club := good.to_dict()
	unknown_club["team_id"] = "club_inventado"
	cases["club desconocido"] = JSON.stringify(unknown_club)
	var bad_field := good.to_dict()
	bad_field["week"] = "tres"
	cases["campo con otro tipo"] = JSON.stringify(bad_field)
	var no_rng := good.to_dict()
	no_rng.erase("rng_state")
	cases["sin estado del azar"] = JSON.stringify(no_rng)
	cases["lista en vez de objeto"] = "[1, 2, 3]"
	for name in cases:
		var f := FileAccess.open(TEST_SAVE, FileAccess.WRITE)
		f.store_string(cases[name])
		f.close()
		var loaded := Career.load_saved(league, squads)
		_check(loaded == null and not Career.last_load_errors.is_empty(),
				"guardado con %s: la carga debería devolver null con motivo" % name)
	DirAccess.remove_absolute(TEST_SAVE)
