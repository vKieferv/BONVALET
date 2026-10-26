# Pruebas del modo carrera sin escenas: planteles, mazo por club, Ejecutor Natural por titulares
# y reglas de la semana (sponsor, evento social, entrenamiento, partido).
# Uso: godot --headless --path . -s res://tests/career_rules.gd
extends SceneTree

const LEAGUE_ID := "chile_2006"
const REAL_SQUADS := ["colo_colo", "universidad_de_chile", "universidad_catolica"]

var failures: Array[String] = []
var checks := 0
var league: LeagueManager
var squads: SquadManager


func _initialize() -> void:
	league = LeagueManager.new()
	_check(league.load_all(), "LeagueManager no carga: %s" % [league.load_errors])
	squads = SquadManager.new()
	_check(squads.load_all(league), "SquadManager no carga: %s" % [squads.load_errors])
	_test_all_squads()
	_test_real_squads()
	_test_generator_is_deterministic()
	_test_decks_for_every_club()
	_test_natural_executor_by_lineup()
	_test_week_flow()
	_test_rivals_and_sponsor_scale()
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
	# La figura sin carta propia recibe la carta firma genérica.
	_check(squads.find_player("universidad_de_chile", "herly_alcazar").get("signature_card_id") == "firma_herly_alcazar",
			"Alcázar (figura de la U) debería tener carta firma genérica")


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
	# Funado: +1 de energía en sus cartas.
	if zapatazo != null:
		var base := e.cost_of(zapatazo)
		e.owner_cost_surcharge = {"humberto_suazo": 1}
		_check(e.cost_of(zapatazo) == base + 1, "el funado debería pagar +1 de energía en sus cartas")


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
