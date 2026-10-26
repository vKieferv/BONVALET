# Pruebas de reglas del motor y de los datos (sin escenas, deterministas por semilla).
# Uso: godot --headless --path . -s res://tests/engine_rules.gd
# Sale con código 1 si alguna regla no se cumple.
extends SceneTree

const DECK_PATH := "res://data/cards.json"
const LEAGUE_ID := "chile_2006"

var failures: Array[String] = []
var checks := 0


func _initialize() -> void:
	_test_deck_and_league_rules()
	_test_possession_filter()
	_test_natural_executor()
	_test_defense_and_emergency()
	_test_kamikaze_phases()
	_test_big_clubs_punish_low()
	_test_team_database()
	_test_chance_matches_roll()
	_test_exhausted_penalty_is_visible()
	_test_signature_styles()
	_test_bot_defense_styles()
	_test_duel_runner()
	print("engine_rules: %d comprobaciones, %d fallas" % [checks, failures.size()])
	for f in failures:
		print("  FALLA: " + f)
	quit(1 if failures.size() > 0 else 0)


func _check(cond: bool, msg: String) -> void:
	checks += 1
	if not cond:
		failures.append(msg)


func _new_engine(seed: int, player_id: String = "") -> MatchEngine:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed
	var player := PlayerStats.new()
	player.player_id = player_id
	var deck := DeckManager.new(CardDB.load_deck(DECK_PATH), [], rng)
	return MatchEngine.new(player, deck, rng, 0.15)


func _card(kind: Card.Kind, bonus: float, cost: int = 3, owner: String = "") -> Card:
	var c := Card.new()
	c.id = "prueba"
	c.kind = kind
	c.bonus = bonus
	c.energy_cost = cost
	c.owner_id = owner
	return c


func _league() -> LeagueManager:
	var league := LeagueManager.new()
	_check(league.load_all(), "LeagueManager no carga: %s" % [league.load_errors])
	return league


func _test_deck_and_league_rules() -> void:
	var cards := CardDB.load_deck(DECK_PATH)
	var deck := DeckManager.new(cards, [], RandomNumberGenerator.new())
	_check(deck.size_error() == "", "cards.json: " + deck.size_error())
	var league := _league()
	var r := league.validate_deck(cards, LEAGUE_ID)
	_check(r["valid"], "cards.json no pasa validate_deck: %s" % [r["errors"]])
	_check(r["sub21"] >= 2, "cards.json necesita al menos 2 cartas Sub-21 (tiene %d)" % r["sub21"])

	# Negativos: 7 extranjeros o menos de 2 Sub-21 deben rechazarse con su mensaje.
	var foreign := CardDB.load_deck(DECK_PATH)
	for i in 7:
		foreign[i].is_foreigner = true
	var rf := league.validate_deck(foreign, LEAGUE_ID)
	_check(not rf["valid"] and " ".join(rf["errors"]).contains("extranjeros"), "7 extranjeros deberían rechazarse")
	var by_nationality := CardDB.load_deck(DECK_PATH)
	for i in 7:
		by_nationality[i].nationality = "ARG"
	_check(not league.validate_deck(by_nationality, LEAGUE_ID)["valid"], "7 cartas con nationality ARG deberían contar como extranjeras")
	var chilean := CardDB.load_deck(DECK_PATH)
	for c in chilean:
		c.nationality = "CHI"
	_check(league.validate_deck(chilean, LEAGUE_ID)["foreigners"] == 0, "nationality CHI no debería contar como extranjera")
	var no_youth := CardDB.load_deck(DECK_PATH)
	for c in no_youth:
		c.age = 0
	var ry := league.validate_deck(no_youth, LEAGUE_ID)
	_check(not ry["valid"] and " ".join(ry["errors"]).contains("Sub-21"), "un mazo sin Sub-21 debería rechazarse")


func _test_possession_filter() -> void:
	var e := _new_engine(7)
	e.start()
	e.begin_moment()
	for c in e.deck.hand:
		_check(not c.is_defensive(), "mano de ataque con carta defensiva: " + c.id)
	e.abort_moment()
	e.advance(MatchEngine.Posture.NORMAL)
	e.begin_defense(0.15)
	_check(e.in_defense and e.deck.hand.size() > 0, "la defensa debería abrir con mano")
	for c in e.deck.hand:
		_check(c.is_defensive() or c.type == Card.Type.PENALTY, "mano de defensa con carta de ataque: " + c.id)
	e.end_defense()
	_check(not e.in_defense and e.deck.hand.is_empty(), "end_defense debería cerrar la fase y descartar la mano")


func _test_natural_executor() -> void:
	var e := _new_engine(3, "suazo")
	e.start()
	e.begin_moment()
	var owned := _card(Card.Kind.PASS, 0.10, 2, "suazo")
	var other := _card(Card.Kind.PASS, 0.10, 2, "otro")
	_check(e.is_natural_executor(owned) and not e.is_natural_executor(other), "is_natural_executor compara owner_id con player_id")
	var diff := e.success_chance(owned) - e.success_chance(other)
	_check(is_equal_approx(diff, MatchEngine.NATURAL_EXECUTOR_BONUS),
			"el Ejecutor Natural debería sumar %.2f (suma %.2f)" % [MatchEngine.NATURAL_EXECUTOR_BONUS, diff])

	# Señal + Flow doble: con dificultad muy baja el acierto queda en 95%; la semilla es fija.
	var emitted := [0]
	e.natural_executor_played.connect(func(_c: Card) -> void: emitted[0] += 1)
	e.current_moment()["difficulty"] = -1.0
	e.current_moment()["steps_required"] = 4
	e.streak = 0
	e.deck.hand.append(owned)
	var ev := e.play_card(e.deck.hand.size() - 1)
	_check(ev["ok"] and ev["natural"], "jugar la carta propia debería marcar natural en el evento")
	_check(emitted[0] == 1, "natural_executor_played debería emitirse una vez (se emitió %d)" % emitted[0])
	if ev["success"]:
		_check(e.streak == MatchEngine.NATURAL_FLOW_CHARGE,
				"el Ejecutor Natural debería cargar la racha de Flow x%d (racha %d)" % [MatchEngine.NATURAL_FLOW_CHARGE, e.streak])


func _test_defense_and_emergency() -> void:
	var e := _new_engine(11)
	e.start()
	var before := e.player.energy
	e.begin_defense(0.15)
	_check(e.can_emergency_clear(), "con energía llena el despeje de emergencia debería estar disponible")
	var cost := e.emergency_cost()
	var ev := e.emergency_clear()
	_check(ev["ok"] and not e.in_defense, "el despeje de emergencia debería cerrar la defensa")
	_check(is_equal_approx(e.player.energy, before - cost), "el despeje de emergencia debería costar %d de energía" % cost)
	_check(e.defense_result["emergency"] and is_equal_approx(e.defense_result["block"], MatchEngine.EMERGENCY_SHOT_PENALTY),
			"el despeje de emergencia debería castigar los remates rivales")

	# Lo que deja la defensa se aplica a los remates del atacante y se limpia al avanzar.
	var atk := _new_engine(12)
	atk.start()
	atk.begin_moment()
	var shot := _card(Card.Kind.SHOT, 0.10)
	var p0 := atk.success_chance(shot)
	atk.opponent_block = MatchEngine.EMERGENCY_SHOT_PENALTY
	_check(is_equal_approx(p0 - atk.success_chance(shot), MatchEngine.EMERGENCY_SHOT_PENALTY), "opponent_block debería restar a los remates")
	var n := atk.moments.size()
	_check(atk.grant_extra_moment(10) == (n < MatchEngine.MAX_MOMENTS), "grant_extra_moment respeta el tope de momentos")
	atk.abort_moment()
	atk.advance(MatchEngine.Posture.NORMAL)
	_check(atk.opponent_block == 0.0 and atk.opponent_pressure == 0.0, "advance() debería limpiar la defensa rival")


func _test_kamikaze_phases() -> void:
	var e := _new_engine(5)
	BotProfile.kamikaze().configure_engine(e)
	e.start()
	_check(e.moments.size() >= 3, "Kamikaze (HIGH) debería tener al menos 3 momentos")
	if e.moments.size() < 3:
		return
	for m in e.moments:
		m["difficulty"] = 0.15
	var card := _card(Card.Kind.PASS, 0.05, 4)
	e.moment_idx = 0
	var p_early := e.success_chance(card)
	var cost_early := e.cost_of(card)
	e.moment_idx = 2
	var p_late := e.success_chance(card)
	var cost_late := e.cost_of(card)
	_check(is_equal_approx(p_early - p_late, 0.20), "Kamikaze: +20 pts en M1-M2 (diferencia %.2f)" % (p_early - p_late))
	_check(cost_late == cost_early * 2, "Kamikaze: fatiga doble desde M3 (%d -> %d)" % [cost_early, cost_late])


func _test_big_clubs_punish_low() -> void:
	var league := _league()
	var colo := league.get_team("colo_colo")
	var p := league.profile_for_team(colo)
	_check(p.punishes_passivity and p.passivity_shot_bonus > MatchEngine.PASSIVITY_SHOT_BONUS,
			"un club grande (Colo-Colo) debería castigar tu LOW con bono extra")
	for t in league.get_teams():
		if int(t["facilities_level"]) == 0 and t["archetype"] != "Contragolpe":
			_check(not league.profile_for_team(t).punishes_passivity, "%s no debería castigar la pasividad" % t["short_name"])
			break


# Lo que muestra la carta (success_chance antes de jugar) es exactamente lo que usa la tirada.
# Juega partidos completos en postura HIGH (poca recuperación) para pasar también por AGOTADO.
func _test_chance_matches_roll() -> void:
	var plays := 0
	var successes := 0
	var expected := 0.0
	var exhausted_plays := 0
	var mismatches := 0
	for seed in range(1, 61):
		var e := _new_engine(seed)
		e.posture = MatchEngine.Posture.HIGH
		e.start()
		while not e.finished:
			e.begin_moment()
			while not e.moment_over:
				var idxs := e.playable_indices()
				if idxs.is_empty():
					e.abort_moment()
					break
				var card: Card = e.deck.hand[idxs[0]]
				var shown := e.success_chance(card)
				var total := 0.0
				var zone_penalty := false
				for item in e.chance_breakdown(card):
					total += float(item["value"])
					zone_penalty = zone_penalty or item.get("zone", false)
				var from_breakdown := roundi(clampf(total, MatchEngine.MIN_CHANCE, MatchEngine.MAX_CHANCE) * 100.0) / 100.0
				if e.player.zone() == PlayerStats.Zone.EXHAUSTED:
					exhausted_plays += 1
					if not zone_penalty:
						mismatches += 1
				var ev := e.play_card(idxs[0])
				plays += 1
				expected += shown
				if ev["success"]:
					successes += 1
				if not is_equal_approx(shown, from_breakdown) \
						or not is_equal_approx(ev["chance"], shown) \
						or ev["success"] != (ev["roll"] < ev["chance"]) \
						or ev["success"] != (floori(ev["roll"] * 100.0) < roundi(shown * 100.0)) \
						or not is_equal_approx(shown * 100.0, float(roundi(shown * 100.0))):
					mismatches += 1
			e.advance(MatchEngine.Posture.HIGH)
	_check(mismatches == 0, "%d jugadas donde la tirada no usó el %% mostrado (o el desglose no cuadra)" % mismatches)
	_check(exhausted_plays > 0, "la prueba debería pasar por la zona AGOTADO")
	# Calibración: los éxitos reales deben rondar la suma de las probabilidades mostradas (±4 sigma).
	var sigma := sqrt(expected * (1.0 - expected / float(plays)))
	_check(absf(float(successes) - expected) < 4.0 * sigma,
			"%d éxitos en %d jugadas; los %% mostrados predecían %.0f" % [successes, plays, expected])
	print("  tiradas: %d jugadas (%d en AGOTADO), %d éxitos, esperados %.0f según los %% mostrados" % [
		plays, exhausted_plays, successes, expected])


func _test_exhausted_penalty_is_visible() -> void:
	var e := _new_engine(9)
	e.start()
	e.begin_moment()
	var card := _card(Card.Kind.PASS, 0.10)
	var fresh := e.success_chance(card)
	e.player.energy = e.player.max_energy() * 0.2
	_check(e.player.zone() == PlayerStats.Zone.EXHAUSTED, "20% de energía debería ser AGOTADO")
	var tired := e.success_chance(card)
	_check(is_equal_approx(fresh - tired, MatchEngine.EXHAUSTED_PENALTY),
			"AGOTADO debería restar %d pts al %% visible (restó %d)" % [
				roundi(MatchEngine.EXHAUSTED_PENALTY * 100.0), roundi((fresh - tired) * 100.0)])
	var labels: Array = e.chance_breakdown(card).map(func(i): return i["label"])
	_check(labels.has("AGOTADO"), "el desglose de la carta debería nombrar la penalización AGOTADO")


# Estilos de carta firma: potencia (bloqueo rival a la mitad) y sangre fría (+10 a un fallo).
func _test_signature_styles() -> void:
	var e := _new_engine(21)
	e.start()
	e.begin_moment()
	var plain := _card(Card.Kind.SHOT, 0.20)
	var power := _card(Card.Kind.SHOT, 0.20)
	power.tags = ["potencia"]
	var cold := _card(Card.Kind.SHOT, 0.20)
	cold.tags = ["sangre_fria"]

	var block := 0.24
	var base_plain := e.success_chance(plain)
	var base_power := e.success_chance(power)
	e.opponent_block = block
	_check(is_equal_approx(base_plain - e.success_chance(plain), block), "un remate normal pierde todo el bloqueo")
	_check(is_equal_approx(base_power - e.success_chance(power), block * MatchEngine.POWER_BLOCK_FACTOR),
			"con potencia el bloqueo cuenta la mitad")
	e.opponent_block = 0.0

	var calm := e.success_chance(cold)
	e.fails = MatchEngine.MAX_FAILS - 1
	_check(is_equal_approx(e.success_chance(cold) - calm, MatchEngine.COLD_BLOOD_BONUS), "sangre fría suma con la jugada a un fallo")
	_check(is_equal_approx(e.success_chance(plain), base_plain), "sin el tag, estar a un fallo no cambia nada")
	var labels: Array = e.chance_breakdown(cold).map(func(i): return i["label"])
	_check(labels.has("Sangre fría"), "el desglose debería nombrar Sangre fría")


# Con una mano de cuatro cartas defensivas iguales, cada perfil elige la de su estilo; sin aire, deja pasar.
func _test_bot_defense_styles() -> void:
	var expected := {"Tiki-Taka": Card.Kind.PRESS, "Kamikaze": Card.Kind.PRESS, "Catenaccio": Card.Kind.BLOCK,
		"Contragolpe": Card.Kind.INTERCEPT, "Directo": Card.Kind.CLEARANCE}
	for profile in BotProfile.presets():
		var e := _new_engine(31)
		e.start()
		e.begin_defense(0.15)
		e.deck.hand.clear()
		for kind in [Card.Kind.PRESS, Card.Kind.BLOCK, Card.Kind.INTERCEPT, Card.Kind.CLEARANCE]:
			e.deck.hand.append(_card(kind, 0.10, 2))
		var idx := CoachBot.choose_defense(e, profile)
		_check(idx >= 0 and e.deck.hand[idx].kind == expected[profile.profile_name],
				"%s debería defender con su estilo (%s)" % [profile.profile_name, BotProfile.DEFENSE_FOCUS_NAMES[profile.defense_focus]])
		e.player.energy = 1.0
		_check(CoachBot.choose_defense(e, profile) == -1, "%s sin energía debería dejar pasar" % profile.profile_name)

	# run_defense completa la fase y deja el motor fuera de defensa.
	var d := _new_engine(32)
	d.start()
	var r := CoachBot.run_defense(d, BotProfile.catenaccio(), 0.15)
	_check(not d.in_defense and r.has("plays") and r["plays"].size() <= MatchEngine.DEFENSE_MAX_PLAYS,
			"run_defense debería cerrar la fase con como máximo %d jugadas" % MatchEngine.DEFENSE_MAX_PLAYS)


func _test_duel_runner() -> void:
	var tpl := CardDB.load_templates(DECK_PATH)
	var a := {"profile": BotProfile.tiki_taka(), "templates": tpl, "defends": true}
	var b := {"profile": BotProfile.catenaccio(), "templates": tpl, "defends": true}
	var r1 := DuelRunner.run(a, b, 40)
	var r2 := DuelRunner.run(a, b, 40)
	_check(r1 == r2, "DuelRunner debería ser determinista con las mismas semillas")
	_check(r1["wins_a"] + r1["draws"] + r1["wins_b"] == 40, "cada partido termina en victoria, empate o derrota")
	_check(r1["def_plays_b"] > 0 and r1["def_plays_a"] > 0, "con defends = true ambos lados deberían defender")
	b["defends"] = false
	var r3 := DuelRunner.run(a, b, 40)
	_check(r3["def_plays_b"] == 0 and r3["cuts_by_b"] == 0, "con defends = false ese lado no defiende")


# La base de equipos debe estar completa y bien formada.
func _test_team_database() -> void:
	var league := _league()
	_check(league.teams.size() == 32, "deberían ser 32 clubes (hay %d)" % league.teams.size())
	var signatures := {}
	for t in league.teams:
		var sig = t.get("signature_card")
		if sig != null:
			_check(not signatures.has(sig), "%s es carta firma de %s y de %s" % [sig, signatures.get(sig, ""), t["id"]])
			signatures[sig] = t["id"]
			var nat := String(t.get("signature_nationality", ""))
			_check(nat.length() == 3 and nat == nat.to_upper(), "%s: signature_nationality debe ser un código de 3 letras" % t["id"])
		for key in ["id", "name", "short_name", "code", "division", "archetype", "primary_color", "secondary_color"]:
			_check(t.has(key) and String(t[key]) != "", "%s: falta %s" % [t.get("id", "?"), key])
		_check(t["archetype"] in ["Tiki-Taka", "Directo", "Catenaccio", "Kamikaze", "Contragolpe"],
				"%s: arquetipo desconocido %s" % [t["id"], t["archetype"]])
		_check(int(t.get("facilities_level", -1)) in [0, 1, 2, 3], "%s: facilities_level fuera de 0-3" % t["id"])
