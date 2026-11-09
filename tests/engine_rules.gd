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
	_test_standard_deck()
	_test_possession_filter()
	_test_natural_executor()
	_test_defense_and_emergency()
	_test_kamikaze_phases()
	_test_moment_steps_by_archetype()
	_test_big_clubs_punish_low()
	_test_team_database()
	_test_chance_matches_roll()
	_test_stamina_zones_draw_not_chance()
	_test_action_points()
	_test_planner()
	_test_hold_ball()
	_test_card_effects()
	_test_signature_styles()
	_test_bot_defense_styles()
	_test_duel_runner()
	_test_zone_mode()
	_test_zone_numbers()
	_test_zone_fails()
	_test_zone_bot()
	_test_duel_skills()
	_test_duel_pass_example()
	_test_duel_rules()
	_test_duel_marks()
	_test_duel_bot()
	_test_duel_d42()
	_test_duel_d43()
	_test_duel_d46()
	_test_duel_d44()
	_test_duel_d48()
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


func _card(kind: Card.Kind, bonus: float, ap: int = 1, owner: String = "") -> Card:
	var c := Card.new()
	c.id = "prueba"
	c.kind = kind
	c.bonus = bonus
	c.ap_cost = ap
	c.stamina_cost = Card.default_stamina(ap, [])
	c.owner_id = owner
	return c


func _league() -> LeagueManager:
	var league := LeagueManager.new()
	_check(league.load_all(), "LeagueManager no carga: %s" % [league.load_errors])
	return league


func _test_deck_and_league_rules() -> void:
	# Toda carta de datos declara sus PA (0-3) y su desgaste: el catálogo entero (también las de count 0,
	# que solo están en el mazo estándar), las firmas y la plantilla de firma.
	var sig = JSON.parse_string(FileAccess.open("res://data/signature_cards.json", FileAccess.READ).get_as_text())
	var all_dicts: Array = CardDB.load_catalog(DECK_PATH).values() + sig["cards"].values() + [sig["template"]]
	_check(CardDB.load_catalog(DECK_PATH).size() == (JSON.parse_string(FileAccess.open(DECK_PATH, FileAccess.READ).get_as_text())["cards"] as Array).size(),
			"el catálogo debería tener todas las cartas de cards.json (ids repetidos?)")
	for d in all_dicts:
		_check(d.has("ap") and int(d["ap"]) >= 0 and int(d["ap"]) <= 3, "%s: ap debe estar entre 0 y 3" % d.get("id", d.get("name")))
		_check(d.has("stamina") and float(d["stamina"]) >= 0.0, "%s: falta stamina" % d.get("id", d.get("name")))
		_check(not d.has("cost"), "%s: 'cost' es del modelo anterior; usa ap y stamina" % d.get("id", d.get("name")))

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
	_check(e.ap == MatchEngine.DEFENSE_AP, "la fase defensiva debería abrir con %d PA" % MatchEngine.DEFENSE_AP)
	_check(e.can_emergency_clear(), "con PA de defensa el despeje de emergencia debería estar disponible")
	var stamina := e.emergency_stamina_cost()
	var ev := e.emergency_clear()
	_check(ev["ok"] and not e.in_defense and e.ap == 0, "el despeje de emergencia gasta todos los PA y cierra la defensa")
	_check(is_equal_approx(e.player.energy, before - stamina),
			"el despeje de emergencia debería costar %d%% de estamina" % roundi(MatchEngine.EMERGENCY_STAMINA_PCT * 100.0))
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
	var card := _card(Card.Kind.PASS, 0.05, 1)
	e.moment_idx = 0
	var p_early := e.success_chance(card)
	var wear_early := e.stamina_cost_of(card)
	var ap_early := e.ap_cost_of(card)
	e.moment_idx = 2
	var p_late := e.success_chance(card)
	var wear_late := e.stamina_cost_of(card)
	_check(is_equal_approx(p_early - p_late, 0.20), "Kamikaze: +20 pts en M1-M2 (diferencia %.2f)" % (p_early - p_late))
	_check(is_equal_approx(wear_late, wear_early * 2.0), "Kamikaze: desgaste doble desde M3 (%.1f -> %.1f)" % [wear_early, wear_late])
	_check(e.ap_cost_of(card) == ap_early, "el desgaste tardío no cambia los PA")


# D-23: mazo estándar (11 cartas del DT + la firma de la figura), carta de rasgo por arquetipo y
# crecimiento de 8 cartas, todo desde data/decks.json resuelto contra el catálogo de cards.json.
func _test_standard_deck() -> void:
	var catalog := CardDB.load_catalog(DECK_PATH)
	var lists := CardDB.load_deck_lists()
	# Las cartas nuevas existen con count 0: el mazo clásico sigue siendo el de 19.
	var classic := CardDB.load_templates(DECK_PATH)
	_check(classic.size() == 19, "el mazo clásico (count) debería seguir con 19 cartas (tiene %d)" % classic.size())
	for id in ["remate_simple", "marca", "toque_toque", "pelotazo", "cerrojo", "remate_en_carrera", "anticipo"]:
		_check(catalog.has(id), "falta la carta %s en el catálogo" % id)
		_check(not classic.any(func(d): return d["id"] == id), "%s tiene count 0: no debería estar en el mazo clásico" % id)
	if catalog.has("pelotazo") and catalog.has("toque_toque") and catalog.has("cerrojo") and catalog.has("anticipo"):
		_check(Card.from_dict(catalog["pelotazo"]).steps == 2, "Pelotazo debería contar 2 avances")
		_check(Card.from_dict(catalog["toque_toque"]).draw == 1, "Toque-toque debería robar 1 carta")
		_check(Card.from_dict(catalog["cerrojo"]).kind == Card.Kind.CLEARANCE and Card.from_dict(catalog["anticipo"]).kind == Card.Kind.INTERCEPT,
				"Cerrojo corta como un Despeje y Anticipo como una Intercepción")
	# Toda carta con efecto lo dice en la carta (CardUI.effect_text, pilar 2).
	for id in catalog:
		var c := Card.from_dict(catalog[id])
		if c.steps > 1 or c.draw > 0 or c.counter or c.kind in [Card.Kind.INTERCEPT, Card.Kind.CLEARANCE]:
			_check(CardUI.effect_text(c) != "" and CardUI.effect_tip(c) != "", "%s tiene un efecto que la carta no muestra" % id)

	# decks.json: solo cartas del catálogo, un rasgo y 8 cartas de crecimiento por arquetipo.
	var archetypes := ["Tiki-Taka", "Directo", "Catenaccio", "Kamikaze", "Contragolpe"]
	var standard: Array = lists.get("estandar", [])
	_check(standard.size() == 11 and standard.count(CardDB.TRAIT_SLOT) == 1,
			"el mazo estándar debería tener 11 cartas, una de ellas el lugar del rasgo (%d)" % standard.size())
	for id in standard:
		_check(id == CardDB.TRAIT_SLOT or catalog.has(id), "decks.json estandar: carta desconocida %s" % id)
	var rasgos: Dictionary = lists.get("rasgos", {})
	var growth: Dictionary = lists.get("crecimiento", {})
	for arch in archetypes:
		_check(catalog.has(rasgos.get(arch, "")), "%s debería tener una carta de rasgo del catálogo" % arch)
		var pool: Array = growth.get(arch, [])
		_check(pool.size() == 8, "%s debería tener 8 cartas de crecimiento (tiene %d)" % [arch, pool.size()])
		for id in pool:
			_check(catalog.has(id), "decks.json crecimiento de %s: carta desconocida %s" % [arch, id])
		var ids := CardDB.deck_ids(lists, arch, 0)
		_check(ids.size() == 11 and ids.count(rasgos.get(arch, "")) == 1 and not ids.has(CardDB.TRAIT_SLOT),
				"%s: el mazo estándar debería tener 11 cartas con su rasgo en lugar de %s" % [arch, CardDB.TRAIT_SLOT])
		var mid := CardDB.deck_ids(lists, arch, 4)
		_check(mid.size() == 15 and mid.slice(11) == pool.slice(0, 4), "%s +4: las primeras 4 de su crecimiento, en orden" % arch)
		_check(CardDB.deck_ids(lists, arch, 99).size() == 19, "%s: el crecimiento no suma más de sus 8 cartas" % arch)
	# Ofertas del entrenamiento táctico (D-20, T-05): una lista por arquetipo y una general, solo cartas
	# del catálogo, sin repetir y nunca una carta de rasgo; alcanzan para 2 de tu estilo + 1 general.
	var offers: Dictionary = lists.get("ofertas", {})
	for list_name in archetypes + ["general"]:
		var pool: Array = offers.get(list_name, [])
		var unique := {}
		for id in pool:
			_check(catalog.has(id), "decks.json ofertas de %s: carta desconocida %s" % [list_name, id])
			_check(not rasgos.values().has(id), "decks.json ofertas de %s: %s es una carta de rasgo y no se ofrece" % [list_name, id])
			unique[id] = true
		_check(unique.size() == pool.size(), "decks.json ofertas de %s: cartas repetidas" % list_name)
		var needed := Career.OFFER_SIZE if list_name == "general" else Career.OFFER_STYLE
		_check(pool.size() >= needed, "decks.json ofertas de %s: tiene %d cartas y la oferta pide %d" % [list_name, pool.size(), needed])
	var base_shot: Dictionary = catalog.get("remate_simple", {})
	if not base_shot.is_empty():
		var sharper := CardDB.upgraded(base_shot, "acierto")
		var cheaper := CardDB.upgraded(base_shot, "pa")
		_check(is_equal_approx(float(sharper["bonus"]), float(base_shot["bonus"]) + CardDB.UPGRADE_BONUS) and sharper["ap"] == base_shot["ap"]
				and int(cheaper["ap"]) == int(base_shot["ap"]) - CardDB.UPGRADE_AP and cheaper["bonus"] == base_shot["bonus"],
				"las mejoras de video suman %d pts o restan %d PA" % [roundi(CardDB.UPGRADE_BONUS * 100.0), CardDB.UPGRADE_AP])
		_check(String(sharper["name"]).ends_with(CardDB.UPGRADE_SUFFIX) and not base_shot.has("mejora"), "la carta mejorada lleva + y el catálogo no cambia")
	_check(not CardDB.can_upgrade(catalog.get("pase_corto", {}), "pa"), "una carta de 0 PA no admite la mejora de PA")

	# El mazo de inicio de un club de cada arquetipo: 12 cartas con su rasgo y la firma de su figura.
	var league := _league()
	var squads := SquadManager.new()
	_check(squads.load_all(league), "SquadManager no carga: %s" % [squads.load_errors])
	var seen := {}
	for t in league.get_teams("Primera A"):
		var arch := String(t["archetype"])
		if seen.has(arch) or t.get("suspended", false):
			continue
		seen[arch] = true
		var deck := squads.build_match_deck(t["id"], squads.starter_templates(t["id"]))
		_check(deck.size() == 12, "%s (%s): el mazo de inicio debería tener 12 cartas (tiene %d)" % [t["id"], arch, deck.size()])
		_check(deck.filter(func(c: Card) -> bool: return c.id == rasgos.get(arch, "")).size() == 1,
				"%s (%s): el mazo de inicio debería traer una %s" % [t["id"], arch, rasgos.get(arch, "")])
		var figure := String(t.get("signature_card", ""))
		var is_figure := func(c: Card) -> bool: return c.type == Card.Type.ELITE and squads.find_player(t["id"], c.owner_id).get("name", "") == figure
		var firma := deck.filter(is_figure)
		_check(firma.size() == 1, "%s (%s): el mazo de inicio debería traer la firma de %s" % [t["id"], arch, figure])
	_check(seen.size() == archetypes.size(), "Primera A debería tener un club de cada arquetipo (hay %d)" % seen.size())

	# Tamaño del mazo: 10-20 (D-23).
	var rng := RandomNumberGenerator.new()
	var cards: Array = CardDB.build_deck(CardDB.archetype_templates(catalog, lists, "Directo"))
	_check(DeckManager.new(cards.slice(0, DeckManager.DECK_MIN), [], rng).size_error() == "", "un mazo de %d cartas es válido" % DeckManager.DECK_MIN)
	_check(DeckManager.new(cards.slice(0, DeckManager.DECK_MIN - 1), [], rng).size_error() != "", "un mazo de %d cartas es muy chico" % (DeckManager.DECK_MIN - 1))
	_check(DeckManager.DECK_MIN == 10 and DeckManager.DECK_MAX == 20, "el mazo debería ir de 10 a 20 cartas")


# D-16: los Momentos de un club Catenaccio piden 2 jugadas y los del resto 3 (también los extra);
# el espacio rival y el contragolpe no acortan un Momento de 2. D-17: Kamikaze lesión tardía x2.5.
func _test_moment_steps_by_archetype() -> void:
	var league := _league()
	_check(is_equal_approx(BotProfile.kamikaze().late_injury_mult, 2.5), "Kamikaze debería multiplicar la lesión tardía por 2.5")
	for id in ["palestino", "colo_colo", "deportes_la_serena"]:
		var team := league.get_team(id)
		var expected := 2 if team["archetype"] == "Catenaccio" else MatchEngine.MOMENT_STEPS
		var p := league.profile_for_team(team)
		_check(p.moment_steps == expected, "%s (%s) debería pedir %d jugadas por Momento" % [id, team["archetype"], expected])
		var e := _new_engine(61)
		p.configure_engine(e)
		e.start()
		e.grant_extra_moment(10)
		_check(e.moments.all(func(x: Dictionary) -> bool: return int(x["steps_required"]) == expected),
				"%s: todos sus Momentos (también los extra) deberían pedir %d jugadas" % [id, expected])
		e.exploit_rival_space = true
		e.begin_moment()
		var left := int(e.current_moment()["steps_required"]) - e.progress
		_check(left == maxi(2, expected - 1),
				"%s: con espacio rival el Momento debería pedir %d jugadas (pide %d)" % [id, maxi(2, expected - 1), left])
	# Momento de 2 con contragolpe solo: sigue pidiendo 2.
	var c := _new_engine(62)
	BotProfile.catenaccio().configure_engine(c)
	c.start()
	c.counter_ready = true
	c.begin_moment()
	_check(c.moment_over or (int(c.current_moment()["steps_required"]) == 2 and c.progress == 0 and not c.counter_ready),
			"Catenaccio: el contragolpe no debería acortar un Momento de 2 jugadas")


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
# Juega partidos completos en postura HIGH; en la mitad de las semillas fuerza AGOTADO.
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
			if seed % 2 == 0:
				e.player.energy = e.player.max_energy() * 0.2
			while not e.moment_over:
				var idxs := e.playable_indices()
				if idxs.is_empty():
					e.abort_moment()
					break
				var card: Card = e.deck.hand[idxs[0]]
				var shown := e.success_chance(card)
				var total := 0.0
				for item in e.chance_breakdown(card):
					total += float(item["value"])
				var from_breakdown := roundi(clampf(total, MatchEngine.MIN_CHANCE, MatchEngine.MAX_CHANCE) * 100.0) / 100.0
				if e.player.zone() == PlayerStats.Zone.EXHAUSTED:
					exhausted_plays += 1
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


# Las zonas de estamina cambian el robo, nunca el % de acierto, y la estamina nunca bloquea jugadas.
func _test_stamina_zones_draw_not_chance() -> void:
	var e := _new_engine(9)
	e.start()
	e.begin_moment()
	var card := _card(Card.Kind.PASS, 0.10)
	var fresh := e.success_chance(card)
	var full := e.player.base_hand_size()
	_check(e.player.draw_count() == full, "con estamina óptima se roba la mano llena (%d)" % full)
	e.player.energy = e.player.max_energy() * 0.5
	_check(e.player.zone() == PlayerStats.Zone.TIRED and e.player.draw_count() == full - 1, "CANSADO roba 1 carta menos")
	e.player.energy = e.player.max_energy() * 0.2
	_check(e.player.zone() == PlayerStats.Zone.EXHAUSTED and e.player.draw_count() == full - 2, "AGOTADO roba 2 cartas menos")
	_check(e.defense_draw_count() == MatchEngine.DEFENSE_HAND_SIZE - 1, "AGOTADO roba 1 carta defensiva menos")
	_check(is_equal_approx(e.success_chance(card), fresh), "AGOTADO no debería cambiar el % de acierto")
	var labels: Array = e.chance_breakdown(card).map(func(i): return i["label"])
	_check(not labels.has("AGOTADO") and not labels.has("CANSADO"), "el desglose no debería tener penalización por zona")
	e.player.vision = 10
	_check(e.player.draw_count() == PlayerStats.MIN_DRAW, "el robo nunca baja de %d" % PlayerStats.MIN_DRAW)
	e.player.energy = 0.0
	_check(e.can_play(card), "sin estamina se puede jugar igual si alcanzan los PA")


# PA por turno según la postura, desgaste por postura, sin reposición de mano y recargos.
func _test_action_points() -> void:
	for posture in [MatchEngine.Posture.LOW, MatchEngine.Posture.NORMAL, MatchEngine.Posture.HIGH]:
		var p := _new_engine(51)
		p.posture = posture
		p.start()
		p.begin_moment()
		var expected_ap: int = MatchEngine.AP_BY_POSTURE[posture]
		_check(p.ap == expected_ap and p.ap_max == expected_ap,
				"postura %s debería dar %d PA (da %d)" % [MatchEngine.Posture.keys()[posture], expected_ap, p.ap])

	# Todos los Momentos piden MOMENT_STEPS jugadas; el contragolpe arranca con una hecha.
	var m := _new_engine(53)
	m.start()
	_check(m.moments.all(func(x: Dictionary) -> bool: return int(x["steps_required"]) == MatchEngine.MOMENT_STEPS),
			"todos los Momentos deberían pedir %d jugadas" % MatchEngine.MOMENT_STEPS)
	m.counter_ready = true
	m.begin_moment()
	_check(m.moment_over or int(m.current_moment()["steps_required"]) - m.progress == 2,
			"tras un contragolpe el Momento debería pedir solo 2 jugadas")

	var e := _new_engine(52)
	e.start()
	e.begin_moment()
	var c := _card(Card.Kind.PASS, 0.10, 2)
	var wear := e.stamina_cost_of(c)
	e.posture = MatchEngine.Posture.HIGH
	_check(is_equal_approx(e.stamina_cost_of(c), wear * 1.5), "HIGH desgasta +50%")
	e.posture = MatchEngine.Posture.LOW
	_check(is_equal_approx(e.stamina_cost_of(c), wear * 0.75), "LOW desgasta menos (x0.75)")
	e.posture = MatchEngine.Posture.NORMAL

	# Jugar descuenta PA y estamina, y la mano no se repone.
	e.current_moment()["steps_required"] = 3
	e.deck.hand.append(c)
	var hand_before := e.deck.hand.size()
	var ap_before := e.ap
	var energy_before := e.player.energy
	var ev := e.play_card(e.deck.hand.size() - 1)
	_check(ev["ok"] and e.ap == ap_before - 2, "jugar una carta de 2 PA descuenta 2 PA")
	_check(is_equal_approx(e.player.energy, energy_before - wear), "jugar descuenta su desgaste de estamina")
	_check(e.deck.hand.size() == hand_before - 1, "la mano no se repone al jugar")

	# Flow: +1 PA por reuso. Sin PA suficientes no se puede jugar.
	var reuse := _card(Card.Kind.PASS, 0.10, 1)
	reuse.flow_uses = 1
	e.flow_active = true
	_check(e.ap_cost_of(reuse) == 2, "en Flow cada reuso suma 1 PA")
	e.flow_active = false
	e.ap = 0
	_check(not e.can_play(reuse), "sin PA no se puede jugar")

	# Funado: +50% de desgaste en sus cartas, sin tocar los PA.
	var owned := _card(Card.Kind.PASS, 0.10, 1, "funado")
	var base_wear := e.stamina_cost_of(owned)
	e.owner_stamina_mult = {"funado": 1.5}
	_check(is_equal_approx(e.stamina_cost_of(owned), base_wear * 1.5) and e.ap_cost_of(owned) == 1,
			"el funado gasta +50% de estamina con los mismos PA")

	# Contra un rival replegado los remates cuestan 1 PA menos (mínimo 1).
	e.exploit_rival_space = true
	_check(e.ap_cost_of(_card(Card.Kind.SHOT, 0.1, 3)) == 2 and e.ap_cost_of(_card(Card.Kind.SHOT, 0.1, 1)) == 1,
			"los espacios del rival restan 1 PA a los remates, mínimo 1")


# Planificador del bot: el plan cabe en los PA, termina en remate y tiene las jugadas que faltan;
# sin remate en la mano no hay plan y el bot cede.
func _test_planner() -> void:
	var profile := BotProfile.directo()
	var e := _new_engine(61)
	e.start()
	e.begin_moment()
	e.deck.hand.clear()
	var pass1 := _card(Card.Kind.PASS, 0.10, 1)
	var pass0 := _card(Card.Kind.PASS, 0.05, 0)
	var shot2 := _card(Card.Kind.SHOT, 0.20, 2)
	var elite3 := _card(Card.Kind.SHOT, 0.40, 3)
	elite3.type = Card.Type.ELITE
	e.deck.hand.append_array([pass1, pass0, shot2, elite3])
	e.ap = 3
	e.progress = 0
	e.current_moment()["steps_required"] = 2

	var plan := CoachBot.best_plan(e, profile)
	_check(not plan.is_empty(), "con remates en la mano debería haber plan")
	if not plan.is_empty():
		var cards: Array = plan["cards"]
		_check(cards.size() == 2, "con 2 jugadas por hacer el plan debería tener 2 cartas (tiene %d)" % cards.size())
		_check(e.deck.hand[cards[-1]].kind == Card.Kind.SHOT, "el plan debería terminar en un remate")
		_check(plan["ap"] <= e.ap, "el plan debería caber en los PA (%d de %d)" % [plan["ap"], e.ap])
		_check(e.deck.hand[cards[0]].kind != Card.Kind.SHOT or cards.size() == 1, "primero los pasos previos, el remate al final")
		var choice := CoachBot.choose(e, profile)
		_check(choice == cards[0], "choose debería jugar la primera carta del mejor plan")
	# Con 3 PA la élite de 3 solo entra con un paso gratis: ese plan debe existir y ser válido.
	e.deck.hand.erase(shot2)
	var elite_plan := CoachBot.best_plan(e, profile)
	_check(not elite_plan.is_empty() and e.deck.hand[elite_plan["cards"][-1]] == elite3 and elite_plan["ap"] <= 3,
			"con 3 PA la élite de 3 PA debería jugarse tras un paso de 0 PA")

	# Cerrando (falta 1 jugada) el plan es un remate solo.
	e.progress = 1
	var closing := CoachBot.best_plan(e, profile)
	_check(not closing.is_empty() and closing["cards"].size() == 1, "cerrando, el plan debería ser solo el remate")

	# Sin remates en la mano no hay plan de gol: cede (con estamina óptima no usa la Pausa).
	e.deck.hand.clear()
	e.deck.hand.append_array([pass1, pass0])
	e.progress = 0
	_check(CoachBot.best_plan(e, profile).is_empty() and CoachBot.choose(e, profile) == CoachBot.HOLD,
			"sin remate en la mano el bot debería aguantar el balón para robar una mano nueva")
	e.holds = MatchEngine.MAX_HOLDS
	_check(CoachBot.choose(e, profile) == -1, "sin remate y sin Aguantar disponible el bot debería ceder")


# Aguantar el Balón: una vez por Momento, 1 PA (0 si no quedan, con +1 PA al salir bien), 3 de
# estamina, 80% menos la Presión rival; éxito = mano nueva y Flow cortado sin penalización; fallo = robo.
func _test_hold_ball() -> void:
	var e := _new_engine(71)
	e.start()
	e.begin_moment()
	_check(e.can_hold() and e.hold_ap_cost() == 1 and is_equal_approx(e.hold_chance(), MatchEngine.HOLD_BASE_CHANCE),
			"al empezar el Momento se puede aguantar por 1 PA con 80%")
	e.opponent_pressure = MatchEngine.PRESS_EFFECT
	_check(is_equal_approx(e.hold_chance(), MatchEngine.HOLD_BASE_CHANCE - MatchEngine.PRESS_EFFECT),
			"la Presión rival baja la retención")
	var df := _new_engine(74)
	df.start()
	df.begin_defense(0.15)
	_check(not df.can_hold(), "en defensa no se puede aguantar el balón")

	var success_ev := {}
	var fail_ev := {}
	for seed in range(1, 120):
		var h := _new_engine(seed)
		h.start()
		h.begin_moment()
		if h.moment_over:
			continue
		h.flow_active = true
		h.ap = 0                         # sin PA: cuesta 0 y, si sale bien, da +1 PA
		var energy_before := h.player.energy
		var ev := h.hold_ball()
		if ev["success"] and success_ev.is_empty():
			success_ev = ev
			_check(not h.flow_active, "aguantar corta el Flow")
			_check(is_equal_approx(h.player.energy, energy_before - MatchEngine.HOLD_STAMINA),
					"aguantar desgasta exactamente %d de estamina, sin la penalización del Flow" % roundi(MatchEngine.HOLD_STAMINA))
			_check(ev["ap"] == 0 and ev["ap_gained"] == 1 and h.ap == 1, "sin PA, aguantar cuesta 0 y al salir bien da +1 PA")
			_check(h.deck.hand.size() == h.player.draw_count(), "al aguantar se roba una mano nueva según la zona de estamina")
			_check(not h.can_hold(), "solo se puede aguantar una vez por Momento")
		elif not ev["success"] and fail_ev.is_empty():
			fail_ev = ev
			_check(ev["stolen"] and h.moment_over, "si falla, el rival roba el balón y se pierde el Momento")
		if not success_ev.is_empty() and not fail_ev.is_empty():
			break
	_check(not success_ev.is_empty() and not fail_ev.is_empty(), "las semillas deberían dar éxitos y fallos al aguantar")

	var c := _new_engine(72)
	c.start()
	c.begin_moment()
	var ap_before := c.ap
	var ev2 := c.hold_ball()
	_check(ev2["ap"] == 1 and (not ev2["success"] or c.ap == ap_before - 1), "con PA, aguantar cuesta 1 PA")

	# Sin jugadas posibles, el Momento sigue abierto mientras quede un Aguantar.
	var d := _new_engine(73)
	d.start()
	d.begin_moment()
	d.ap = 0
	d.deck.hand.clear()
	d._end_if_stuck({})
	_check(not d.moment_over, "sin jugadas y con Aguantar disponible el Momento no se cierra solo")
	d.holds = MatchEngine.MAX_HOLDS
	d._end_if_stuck({})
	_check(d.moment_over, "sin jugadas y sin Aguantar, la jugada se pierde")


# Efectos opcionales de carta (pensados para las cartas de rasgo del DT): avances, robo, fuerza de
# Presión/Bloqueo y contragolpe. Sin ellos, todo se comporta como siempre.
func _test_card_effects() -> void:
	var plain := Card.from_dict(CardDB.load_templates(DECK_PATH)[0])
	_check(plain.steps == 1 and plain.draw == 0 and plain.effect < 0.0 and not plain.counter,
			"una carta sin efectos debería avanzar 1, no robar, usar la fuerza de su tipo y no dar contragolpe")

	var e := _new_engine(81)
	e.start()
	e.begin_moment()
	e.streak = -10   # que no arranque el Flow (la carta volvería a la mano)
	var pelotazo := _card(Card.Kind.PASS, 0.0, 1)
	pelotazo.steps = 2
	e.deck.hand.append(pelotazo)
	var before := e.progress
	e._resolve_attack(pelotazo, true, false, {})
	_check(e.progress == before + 2, "una jugada de 2 avances debería sumar 2 al progreso del Momento")

	var t := _new_engine(82)
	t.start()
	t.begin_moment()
	t.streak = -10
	var toque := _card(Card.Kind.PASS, 0.0, 0)
	toque.draw = 1
	t.deck.hand.append(toque)
	var ev := {}
	t._resolve_attack(toque, true, false, ev)
	_check(int(ev.get("drawn", 0)) == 1, "una carta que roba 1 debería robar una carta al salir bien")
	var miss := {}
	t._resolve_attack(toque, false, false, miss)
	_check(not miss.has("drawn"), "si la jugada falla no se roba")

	var d := _new_engine(83)
	d.start()
	d.begin_defense(0.15)
	var total := _card(Card.Kind.PRESS, 0.0, 1)
	total.effect = 0.12
	d._resolve_defense(total, true, {})
	_check(is_equal_approx(d.defense_result["pressure"], 0.12), "una Presión reforzada debería sumar su propia fuerza")
	var d2 := _new_engine(84)
	d2.start()
	d2.begin_defense(0.15)
	d2._resolve_defense(_card(Card.Kind.BLOCK, 0.0, 1), true, {})
	_check(is_equal_approx(d2.defense_result["block"], MatchEngine.BLOCK_EFFECT), "un Bloqueo normal suma la fuerza de su tipo")
	var salida := _card(Card.Kind.PRESS, 0.0, 1)
	salida.counter = true
	d2.begin_defense(0.15)
	d2._resolve_defense(salida, true, {})
	_check(d2.counter_ready and not d2.defense_result["cancelled"],
			"una carta de contragolpe debería dejar listo el próximo ataque sin cortar el actual")

	# El planificador cuenta los avances: Pelotazo + remate completa un Momento de 3 jugadas.
	var p := _new_engine(85)
	p.start()
	p.begin_moment()
	p.current_moment()["steps_required"] = 3
	p.progress = 0
	p.ap = 3
	p.deck.hand.clear()
	var largo := _card(Card.Kind.PASS, 0.0, 1)
	largo.steps = 2
	p.deck.hand.append(largo)
	p.deck.hand.append(_card(Card.Kind.SHOT, 0.10, 1))
	var plan := CoachBot.best_plan(p, BotProfile.directo())
	_check(not plan.is_empty() and plan["cards"].size() == 2, "con Pelotazo + remate el bot debería ver un plan de 2 cartas")
	largo.steps = 1
	_check(CoachBot.best_plan(p, BotProfile.directo()).is_empty(), "sin el Pelotazo, un pase + remate no alcanza para 3 jugadas")

	# Sin plan de gol, una carta que roba se juega antes de aguantar el balón.
	p.deck.hand.clear()
	var cava := _card(Card.Kind.PASS, 0.30, 0)
	cava.draw = 1
	p.deck.hand.append(cava)
	p.deck.hand.append(_card(Card.Kind.PASS, 0.0, 0))
	_check(CoachBot.choose(p, BotProfile.directo()) == 0, "sin remate en la mano, el bot debería jugar la carta que roba")


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
		_check(CoachBot.choose_defense(e, profile) == -1, "%s sin aire (estamina bajo su reserva) debería dejar pasar" % profile.profile_name)
		e.player.energy = e.player.max_energy()
		e.ap = 0
		_check(CoachBot.choose_defense(e, profile) == -1, "%s sin PA debería dejar pasar" % profile.profile_name)

	# run_defense completa la fase y deja el motor fuera de defensa.
	var d := _new_engine(32)
	d.start()
	var r := CoachBot.run_defense(d, BotProfile.catenaccio(), 0.15)
	_check(not d.in_defense and r.has("plays") and r["plays"].size() <= MatchEngine.DEFENSE_AP,
			"run_defense debería cerrar la fase dentro de sus %d PA" % MatchEngine.DEFENSE_AP)


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



# ---------- Partido por zonas (D-36, T-10) ----------

# Motor en el modo de zonas con un Momento recién empezado, mano vacía y PA de sobra.
func _zone_engine(seed: int, steps: int = 3) -> MatchEngine:
	var e := _new_engine(seed)
	e.zone_mode = true
	e.moment_steps = steps
	e.start()
	e.begin_moment()
	e.moment_over = false
	e.deck.hand.clear()
	e.ap = 10
	return e


# Juega `card_maker.call()` en motores de zonas con semillas distintas hasta que la jugada salga bien;
# setup(e) prepara cada motor. Devuelve [motor, evento] o [] si ninguna semilla sirve.
func _zone_success(setup: Callable, card_maker: Callable, steps: int = 3) -> Array:
	for seed in range(1, 400):
		var e := _zone_engine(seed, steps)
		setup.call(e)
		var card: Card = card_maker.call()
		e.deck.hand.append(card)
		var ev := e.play_card(e.deck.hand.find(card))
		if ev["success"]:
			return [e, ev]
	return []


func _no_setup(_e: MatchEngine) -> void:
	pass


func _at_medio(e: MatchEngine) -> void:
	e.progress = 1
	e.zone = MatchEngine.Zone.MEDIO


func _sure_pass() -> Card:
	return _card(Card.Kind.PASS, 1.0, 0)


func _sure_pelotazo() -> Card:
	var c := _card(Card.Kind.PASS, 1.0, 0)
	c.steps = 2
	return c


func _sure_far_shot() -> Card:
	var c := _card(Card.Kind.SHOT, 1.0)
	c.long_range = true
	return c


# Defensa rival imposible: toda jugada queda en el 5% (el bono de una carta no baja de 0).
func _make_hard(e: MatchEngine) -> void:
	e.current_moment()["difficulty"] = 2.0


func _weak_pass() -> Card:
	return _card(Card.Kind.PASS, 0.0, 0)   # con _make_hard, 5%: casi siempre falla


# Zona según el avance: Salida → Medio → Área; Momentos de 2 = Salida y Área; contragolpe y espacio
# rival arrancan en el Medio; el Pelotazo se salta una zona. Remates solo en el Área; el tiro lejano,
# también desde el Medio con su castigo.
func _test_zone_mode() -> void:
	var off := _new_engine(80)
	off.start()
	off.begin_moment()
	off.ap = 10
	_check(not off.zone_mode and off.can_play(_card(Card.Kind.SHOT, 0.20)), "sin el modo de zonas un remate se juega en cualquier jugada")
	_check(off.steal_chance(_card(Card.Kind.PASS, 0.0)) == 0.0, "sin el modo de zonas no hay robo al fallar")

	var e := _zone_engine(81)
	_check(e.zone == MatchEngine.Zone.SALIDA, "el Momento arranca en la Salida")
	var r := _zone_success(_no_setup, _sure_pass)
	_check(not r.is_empty() and r[0].zone == MatchEngine.Zone.MEDIO, "un pase que sale bien en la Salida lleva al Medio")
	r = _zone_success(_at_medio, _sure_pass)
	_check(not r.is_empty() and r[0].zone == MatchEngine.Zone.AREA, "un pase que sale bien en el Medio lleva al Área")
	r = _zone_success(_no_setup, _sure_pass, 2)
	_check(not r.is_empty() and r[0].zone == MatchEngine.Zone.AREA, "en un Momento de 2 jugadas (Catenaccio) se pasa de la Salida al Área")
	r = _zone_success(_no_setup, _sure_pelotazo)
	_check(not r.is_empty() and r[0].zone == MatchEngine.Zone.AREA, "el Pelotazo (avanza 2) se salta el Medio")
	r = _zone_success(_at_medio, _sure_far_shot)
	_check(not r.is_empty() and r[1]["goal"] and r[0].moment_over, "un tiro lejano que entra desde el Medio es gol")

	var c := _new_engine(82)
	c.zone_mode = true
	c.start()
	c.counter_ready = true
	c.begin_moment()
	_check(c.zone == MatchEngine.Zone.MEDIO and c.progress == 1, "el contragolpe arranca en el Medio")
	_check(c.stats["counters"] == 1, "el Momento con contragolpe se cuenta")
	var x := _new_engine(83)
	x.zone_mode = true
	x.exploit_rival_space = true
	x.start()
	x.begin_moment()
	_check(x.zone == MatchEngine.Zone.MEDIO and int(x.current_moment()["steps_required"]) == 2,
			"el espacio rival acorta el Momento y arranca en el Medio")

	# Remates: solo en el Área. El tiro lejano, también desde el Medio, con -15 y sin los números del Área.
	var z := _zone_engine(84)
	var shot := _card(Card.Kind.SHOT, 0.20)
	var far := _card(Card.Kind.SHOT, 0.20)
	far.long_range = true
	z.deck.hand.append_array([shot, far])
	_check(not z.can_play(shot) and z.zone_block_reason(shot) == "SOLO EN EL ÁREA", "en la Salida un remate no se juega")
	_check(not z.can_play(far) and z.zone_block_reason(far) == "DESDE EL MEDIO", "el tiro lejano no se juega desde la Salida")
	_check(not z.playable_indices().has(z.deck.hand.find(shot)), "playable_indices no ofrece remates fuera del Área")
	_check(not z.play_card(z.deck.hand.find(shot))["ok"], "play_card rechaza un remate fuera del Área")
	z.zone = MatchEngine.Zone.MEDIO
	_check(not z.can_play(shot) and z.can_play(far), "desde el Medio solo se juega el tiro lejano")
	var labels: Array = z.chance_breakdown(far).map(func(i): return i["label"])
	_check(labels.has("Tiro de lejos"), "el desglose del tiro lejano nombra el castigo de la distancia")
	var medio_far := z.success_chance(far)
	z.zone = MatchEngine.Zone.AREA
	_check(z.can_play(shot) and z.can_play(far), "en el Área se juega cualquier remate")
	_check(is_equal_approx(z.success_chance(far) - medio_far, MatchEngine.LONG_SHOT_PENALTY),
			"en el Área el tiro lejano no tiene el castigo de la distancia")
	var cat := CardDB.load_catalog(DECK_PATH)
	_check(Card.from_dict(cat["tiro_lejano"]).long_range and not Card.from_dict(cat["remate_primera"]).long_range,
			"el Tiro de lejos es la carta marcada como lejana (lejano: true)")


# Números de la zona en el desglose: formación con la postura (6 pts por jugador) y fuerza de línea (×0,5).
func _test_zone_numbers() -> void:
	_check(MatchEngine.lines_for([4, 4, 2], MatchEngine.Posture.HIGH) == [4, 3, 3], "en HIGH un volante sube")
	_check(MatchEngine.lines_for([4, 4, 2], MatchEngine.Posture.LOW) == [5, 3, 2], "en LOW un volante baja")
	_check(MatchEngine.lines_for([5, 3, 2, 3], MatchEngine.Posture.HIGH) == [5, 2, 3], "el 5-3-2 en HIGH queda con 3 arriba")
	_check(MatchEngine.lines_for([5, 3, 3, 3], MatchEngine.Posture.HIGH) == [5, 3, 3], "con el tope de 3 arriba, HIGH no sube a nadie más")
	var e := _zone_engine(85)
	var pass_card := _card(Card.Kind.PASS, 0.10, 0)
	var plain := e.success_chance(pass_card)
	var zone_labels := e.chance_breakdown(pass_card).filter(
			func(i): return String(i["label"]).begins_with("Salida") or i["label"] == "Fuerza de línea")
	_check(zone_labels.is_empty(), "sin formaciones ni líneas no hay números de zona")
	e.formation = [4, 4, 2]
	e.line_strength = [70.0, 66.0, 80.0]
	e.rival_formation = [4, 3, 3]
	e.rival_line_strength = [72.0, 60.0, 64.0]
	e.rival_posture = MatchEngine.Posture.NORMAL
	e.zone_numbers_pts = 0.06   # el valor de prueba de D-30, para que las cuentas sean simples
	# Salida: tus 4 de atrás contra sus 3 de arriba (+6) y fuerza 70 contra 64 (+3).
	var labels: Array = e.chance_breakdown(pass_card).map(func(i): return i["label"])
	_check(labels.has("Salida: 4 contra 3") and labels.has("Fuerza de línea"), "el desglose de la Salida muestra los números y la fuerza")
	_check(is_equal_approx(e.success_chance(pass_card) - plain, 0.06 + 0.03), "Salida: +6 por un jugador más y +3 por 6 puntos de fuerza")
	# Medio: 4 contra 3 (+6), fuerza 66 contra 60 (+3). Área: 2 contra 4 (−12), 80 contra 72 (+4).
	_check(is_equal_approx(e.success_chance(pass_card, MatchEngine.Zone.MEDIO) - plain, 0.06 + 0.03), "Medio: 4 contra 3 y fuerza +6")
	_check(is_equal_approx(e.success_chance(pass_card, MatchEngine.Zone.AREA) - plain, -0.12 + 0.04), "Área: 2 contra 4 y fuerza +8")
	# Si el rival sube en HIGH, en la Salida te esperan 4: sin diferencia de números.
	e.rival_posture = MatchEngine.Posture.HIGH
	_check(is_equal_approx(e.success_chance(pass_card) - plain, 0.03), "con el rival en HIGH la Salida queda 4 contra 4")
	e.zone_numbers_pts = 0.0
	e.zone_line_factor = 0.0
	_check(is_equal_approx(e.success_chance(pass_card), plain), "con 0 pts y factor 0 la zona no suma nada")
	# LOW_SHOT_PENALTY se puede apagar en el modo de zonas (D-36, regla 4); el modo actual no cambia.
	var low := _zone_engine(86)
	low.posture = MatchEngine.Posture.LOW
	low.zone = MatchEngine.Zone.AREA
	var shot := _card(Card.Kind.SHOT, 0.20)
	var with_pen := low.success_chance(shot)
	low.zone_low_shot_penalty = false
	_check(is_equal_approx(low.success_chance(shot) - with_pen, MatchEngine.LOW_SHOT_PENALTY), "sin el castigo plano, LOW no resta a los remates")
	# Sangre fría sin MAX_FAILS: +10 después de cualquier fallo del Momento.
	var cold := _card(Card.Kind.SHOT, 0.20)
	cold.tags = ["sangre_fria"]
	var calm := low.success_chance(cold)
	low.fails = 1
	_check(is_equal_approx(low.success_chance(cold) - calm, MatchEngine.COLD_BLOOD_BONUS), "por zonas, sangre fría suma tras un fallo")
	# zone_data: formación por estilo y fuerza = promedio de skill_rating de cada línea.
	var league := _league()
	var squads := SquadManager.new()
	_check(squads.load_all(league), "SquadManager no carga")
	var palestino := squads.zone_data("palestino")
	_check(palestino["formation"] == [5, 3, 2, 3] and (palestino["line_strength"] as Array).size() == 3,
			"Palestino (Catenaccio) juega 5-3-2 con la fuerza de sus 3 líneas")
	var total := 0.0
	var count := 0
	for p in squads.pick_starters("colo_colo"):
		if p["role"] in ["MCD", "MCO", "EXT"]:
			total += float(p["skill_rating"])
			count += 1
	var colo: Array = squads.zone_data("colo_colo")["line_strength"]
	_check(count > 0 and is_equal_approx(float(colo[1]), total / count), "la fuerza del medio es el promedio de sus titulares MCD, MCO y EXT")


# Fallos por zonas: no cortan; robo en la Salida y el Medio (contragolpe); cuestan media carta de
# estamina; remate fallado = atajada o rebote; sin cartas ni Aguantar se pierde sin contragolpe. El
# robo y la atajada salen de la misma tirada que el %: lo que muestra la carta es lo que se tira.
func _test_zone_fails() -> void:
	var probe := _zone_engine(87)
	_make_hard(probe)
	var w := _weak_pass()
	_check(is_equal_approx(probe.steal_chance(w), roundi(0.95 * MatchEngine.ZONE_STEAL_SALIDA * 100.0) / 100.0),
			"robo en la Salida = fallar × 1/4")
	_check(is_equal_approx(probe.steal_chance(w, MatchEngine.Zone.MEDIO), roundi(0.95 * MatchEngine.ZONE_STEAL_MEDIO * 100.0) / 100.0),
			"robo en el Medio = fallar × 1/6")
	_check(probe.steal_chance(w, MatchEngine.Zone.AREA) == 0.0 and probe.steal_chance(_card(Card.Kind.SHOT, 0.0)) == 0.0,
			"ni el Área ni los remates tienen robo")
	var stolen_seen := 0
	var kept_seen := 0
	for seed in range(1, 200):
		var e := _zone_engine(seed)
		_make_hard(e)
		var card := _weak_pass()
		e.deck.hand.append_array([card, _card(Card.Kind.PASS, 0.10, 0)])
		var shown := e.steal_chance(card)
		var energy_before := e.player.energy
		var stamina := e.stamina_cost_of(card)
		var ev := e.play_card(0)
		if ev["success"] or ev["injury"]:
			continue
		_check(is_equal_approx(ev["steal_chance"], shown), "el robo de la tirada es el que mostraba la carta")
		var should_steal: bool = ev["roll"] >= 1.0 - shown
		_check(ev.get("stolen", false) == should_steal, "robo si y solo si la tirada cae en el robo %% (semilla %d)" % seed)
		_check(is_equal_approx(energy_before - e.player.energy, stamina * 1.5),
				"fallar cuesta el desgaste de la carta y la mitad más (semilla %d)" % seed)
		if should_steal:
			stolen_seen += 1
			_check(e.moment_over and e.stats["steals"] == 1, "un robo pierde el Momento")
		else:
			kept_seen += 1
			_check(not e.moment_over and e.zone == MatchEngine.Zone.SALIDA, "un fallo sin robo no corta el Momento ni avanza")
	_check(stolen_seen > 0 and kept_seen > 0, "las semillas deberían dar fallos con y sin robo")
	# El robo deja contragolpe al rival en DuelRunner (por zonas hay robos y contragolpes).
	var tpl := CardDB.load_templates(DECK_PATH)
	var a := {"profile": BotProfile.tiki_taka(), "templates": tpl, "defends": true, "zone_mode": true,
		"formation": [4, 4, 2], "line_strength": [60.0, 60.0, 60.0]}
	var b := {"profile": BotProfile.directo(), "templates": tpl, "defends": true, "zone_mode": true,
		"formation": [4, 4, 2], "line_strength": [60.0, 60.0, 60.0]}
	var zr := DuelRunner.run(a, b, 60)
	_check(zr["steals"] > 0 and zr["counters"] >= zr["steals"], "por zonas cada robo deja un contragolpe al rival")
	a.erase("zone_mode")
	b.erase("zone_mode")
	_check(DuelRunner.run(a, b, 60)["steals"] == 0, "sin el modo de zonas no hay robos al fallar")

	# Remate fallado en el Área: atajada (fin, sin contragolpe) o rebote (sigues en el Área).
	var saved := 0
	var rebound := 0
	for seed in range(1, 200):
		var e := _zone_engine(seed)
		_make_hard(e)
		e.progress = 2
		e.zone = MatchEngine.Zone.AREA
		var shot := _card(Card.Kind.SHOT, 0.0)
		e.deck.hand.append_array([shot, _card(Card.Kind.SHOT, 0.10)])
		var shown := e.save_chance(shot)
		var ev := e.play_card(0)
		if ev["success"] or ev["injury"]:
			continue
		var should_save: bool = ev["roll"] >= 1.0 - shown
		_check(ev.get("saved", false) == should_save and ev.get("rebound", false) == (not should_save),
				"atajada si y solo si la tirada cae en su %%, si no rebote (semilla %d)" % seed)
		_check(not ev.get("stolen", false), "un remate fallado nunca es robo")
		if should_save:
			saved += 1
			_check(e.moment_over, "con atajada se acaba el Momento")
		else:
			rebound += 1
			_check(not e.moment_over and e.zone == MatchEngine.Zone.AREA, "con rebote sigues en el Área")
	_check(saved > 0 and rebound > 0, "las semillas deberían dar atajadas y rebotes")

	# Sin cartas jugables: Aguantar si queda; si no, se pierde sin contragolpe.
	var stuck_checked := false
	for seed in range(1, 60):
		var e := _zone_engine(seed)
		_make_hard(e)
		e.holds = MatchEngine.MAX_HOLDS
		var card := _weak_pass()
		e.deck.hand.append_array([card, _card(Card.Kind.SHOT, 0.20)])   # el remate no se juega en la Salida
		var ev := e.play_card(0)
		if ev["success"] or ev.get("stolen", false) or ev["injury"]:
			continue
		_check(e.moment_over and ev["out_of_ap"], "sin cartas para seguir ni Aguantar, el Momento se pierde")
		stuck_checked = true
		break
	_check(stuck_checked, "las semillas deberían dar un fallo sin robo que deja la mano sin jugadas")


# El bot por zonas: no planea remates fuera del Área (salvo el lejano desde el Medio), en la Salida
# juega primero la carta más segura y, al llegar al Área sin remate, aguanta.
func _test_zone_bot() -> void:
	var profile := BotProfile.directo()
	var e := _zone_engine(88)
	var safe := _card(Card.Kind.PASS, 0.20, 0)
	var risky := _card(Card.Kind.PASS, 0.0, 0)
	var shot := _card(Card.Kind.SHOT, 0.20, 1)
	e.deck.hand.append_array([risky, shot, safe])
	var plan := CoachBot.best_plan(e, profile)
	_check(not plan.is_empty() and plan["cards"].size() == 3 and e.deck.hand[plan["cards"][-1]] == shot,
			"por zonas el plan llega al Área y remata ahí")
	_check(not plan.is_empty() and e.deck.hand[plan["cards"][0]] == safe, "en la Salida juega primero la carta más segura")
	_check(CoachBot.choose(e, profile) == e.deck.hand.find(safe), "choose juega la carta segura en la Salida")
	# Con solo un tiro lejano: lo planea desde el Medio con un paso, no espera al Área.
	var f := _zone_engine(89)
	var far := _card(Card.Kind.SHOT, 0.60, 1)
	far.long_range = true
	f.deck.hand.append_array([_card(Card.Kind.PASS, 0.20, 0), far])
	var far_plan := CoachBot.best_plan(f, profile)
	_check(not far_plan.is_empty() and far_plan["cards"].size() == 2 and f.deck.hand[far_plan["cards"][-1]] == far,
			"el tiro lejano se planea desde el Medio")
	# En el Área sin remate: aguanta. Antes del Área sin remate: avanza con la carta más segura.
	var h := _zone_engine(90)
	var h_safe := _card(Card.Kind.PASS, 0.20, 0)
	h.deck.hand.append_array([_card(Card.Kind.PASS, 0.0, 0), h_safe])
	_check(CoachBot.best_plan(h, profile).is_empty() and CoachBot.choose(h, profile) == h.deck.hand.find(h_safe),
			"sin remate, antes del Área avanza con la carta más segura")
	h.zone = MatchEngine.Zone.AREA
	h.progress = 2
	_check(CoachBot.choose(h, profile) == CoachBot.HOLD, "en el Área sin remate el bot aguanta")
	# Partidos enteros de bots por zonas terminan (sin bucles) y nadie remata fuera del Área.
	var bad_shots := 0
	for seed in range(1, 30):
		var g := _new_engine(seed)
		g.zone_mode = true
		g.start()
		while not g.finished:
			g.begin_moment()
			while not g.moment_over:
				var zone_before: int = g.zone
				var ev := CoachBot.act(g, profile)
				if ev.get("kind", -1) == Card.Kind.SHOT and zone_before == MatchEngine.Zone.SALIDA:
					bad_shots += 1
			g.advance(MatchEngine.Posture.NORMAL)
	_check(bad_shots == 0, "el bot solo remata en el Área (o de lejos desde el Medio): %d remates desde la Salida" % bad_shots)


# ---------- Modo de duelos (D-40, T-13) ----------

var _duel_squads: SquadManager


func _squads() -> SquadManager:
	if _duel_squads == null:
		_duel_squads = SquadManager.new()
		_check(_duel_squads.load_all(_league()), "SquadManager no carga")
	return _duel_squads


func _pl(players: Array, id: String) -> Dictionary:
	for p in players:
		if p["id"] == id:
			return p
	return {}


# Colo-Colo (4-1-2-1-2, Tiki-Taka) ataca a la U (4-3-3, Contragolpe), los dos en NORMAL, con un
# Momento recién empezado en la Salida, la mano vacía y PA de sobra. Sin apertura, entrenamiento ni
# defensa rival.
func _duel_engine(seed: int, steps: int = 3) -> MatchEngine:
	var squads := _squads()
	var e := _zone_engine(seed, steps)
	var colo := squads.duel_data("colo_colo")
	var u := squads.duel_data("universidad_de_chile")
	e.duel_mode = true
	e.duel_players = colo["players"]
	e.mark_style = colo["style"]
	e.formation = squads.zone_data("colo_colo")["formation"]
	e.rival_players = u["players"]
	e.rival_mark_style = u["style"]
	e.rival_formation = squads.zone_data("universidad_de_chile")["formation"]
	e.zone = MatchEngine.Zone.SALIDA
	e.progress = 0
	e._duel_begin()
	e.moment_over = false
	e.deck.hand.clear()
	e.ap = 10
	return e


# Habilidades = nivel + puesto + perfil (+6), tope 95 (D-32), con las láminas de ejemplo de cartas.md.
func _test_duel_skills() -> void:
	var colo: Array = _squads().duel_data("colo_colo")["players"]
	var u: Array = _squads().duel_data("universidad_de_chile")["players"]
	var m14 := _pl(colo, "matias_fernandez")
	_check([m14["pase"], m14["regate"], m14["remate"], m14["quite"], m14["lectura"]] == [87, 90, 79, 69, 74],
			"M14 (MCO 84, Gambeteador): Pase 87, Regate 90, Remate 79, Quite 69, Lectura 74")
	var suazo := _pl(colo, "humberto_suazo")
	_check([suazo["pase"], suazo["regate"], suazo["remate"], suazo["quite"], suazo["lectura"]] == [76, 86, 95, 61, 66],
			"Suazo (DEL 86, Goleador): Remate 95 con el tope")
	var kalule := _pl(colo, "rodrigo_melendez")
	_check([kalule["pase"], kalule["regate"], kalule["quite"], kalule["lectura"]] == [72, 62, 75, 75] and kalule["perfil"] == "",
			"Kalule (MCD 72, sin perfil): Pase 72, Regate 62, Quite 75, Lectura 75")
	_check(int(_pl(colo, "claudio_bravo")["atajada"]) == 86, "Bravo (POR 80, Atajador): Atajada 86")
	_check(int(_pl(colo, "miguel_aceval")["pase"]) == 66 and int(_pl(u, "manuel_iturra")["lectura"]) == 75
			and int(_pl(u, "mayer_candelo")["lectura"]) == 66, "Aceval Pase 66, Iturra Lectura 75, Candelo Lectura 66")
	var h := Habilidades.new()
	_check(h.load_profiles() and h.perfiles.size() == 3, "perfiles_2006.json trae solo los 3 perfiles de cartas.md")
	var starters := {}
	for p in _squads().pick_starters("colo_colo"):
		starters[p["id"]] = true
	for pid in h.perfiles:
		_check(starters.has(pid), "el perfil de %s es de un titular de Colo-Colo" % pid)
		_check(h.tipos.has(h.perfiles[pid]), "el perfil de %s es de un tipo conocido" % pid)
	# Líneas de la formación: el extremo de la U (4-3-3) juega arriba; en LOW baja un volante.
	var u_lines := MatchEngine.lines_of(u, [4, 3, 3], MatchEngine.Posture.NORMAL)
	_check((u_lines[2] as Array).has(_pl(u, "hugo_droguett")) and (u_lines[1] as Array).size() == 3,
			"en el 4-3-3 el extremo juega arriba y quedan 3 en el medio")
	var c_lines := MatchEngine.lines_of(colo, [4, 4, 2], MatchEngine.Posture.NORMAL)
	var medio: Array = (c_lines[1] as Array).map(func(p): return p["id"])
	medio.sort()
	_check(medio == ["alexis_sanchez", "arturo_vidal", "matias_fernandez", "rodrigo_melendez"],
			"el medio de Colo-Colo es Vidal, Meléndez, Fernández y Sánchez")
	var low := MatchEngine.lines_of(colo, [4, 4, 2], MatchEngine.Posture.LOW)
	_check((low[0] as Array).size() == 5 and (low[0] as Array).has(_pl(colo, "arturo_vidal")),
			"en LOW baja el volante más defensivo")


# La tabla de "Pase con marcas" (cartas.md, D-40): Aceval con el Pase corto en la Salida, la U con
# doble marca a Fernández (Iturra y Díaz), Candelo sobre Sánchez, Vidal y Meléndez libres.
func _test_duel_pass_example() -> void:
	var e := _duel_engine(91)
	e.duel_press_divisor = 0.0   # la tabla es de D-40: la presión de Salas sobre Aceval (D-43) se prueba en _test_duel_d43
	e.duel_outcomes = false   # el ejemplo es el robo de D-36; los desenlaces de D-48 se prueban en _test_duel_d48
	var u: Array = e.rival_players
	e.carrier = _pl(e.duel_players, "miguel_aceval")
	e.marks[MatchEngine.Zone.MEDIO] = {"matias_fernandez": [_pl(u, "manuel_iturra"), _pl(u, "marcelo_diaz")],
		"alexis_sanchez": [_pl(u, "mayer_candelo")], "arturo_vidal": [], "rodrigo_melendez": []}
	e.marks[MatchEngine.Zone.SALIDA] = {"miguel_aceval": [_pl(u, "marcelo_salas")]}
	var cat := CardDB.load_catalog(DECK_PATH)
	var pase := Card.from_dict(cat["pase_corto"])
	e.deck.hand.append(pase)
	var ids: Array = e.receivers(pase).filter(func(r): return e.pass_zone(pase, r["id"]) == MatchEngine.Zone.MEDIO).map(func(r): return r["id"])
	_check(ids.size() == 4 and ids.has("matias_fernandez") and not ids.has("miguel_aceval"),
			"el pase que avanza desde la Salida va a uno de los 4 del medio")
	_check(e.success_chance(pase, -1, "matias_fernandez") == 0.29,
			"Aceval a Fernández (1 vs 2, Iturra Lectura 75): 29%% (da %s)" % e.success_chance(pase, -1, "matias_fernandez"))
	_check(e.success_chance(pase, -1, "arturo_vidal") == 0.57,
			"Aceval a Vidal (libre): 57%% (da %s)" % e.success_chance(pase, -1, "arturo_vidal"))
	_check(e.success_chance(pase, -1, "alexis_sanchez") == 0.45,
			"Aceval a Sánchez (1 vs 1 con Candelo): 45%% (da %s)" % e.success_chance(pase, -1, "alexis_sanchez"))
	_check(e.steal_chance(pase, -1, "arturo_vidal") == 0.11 and e.steal_chance(pase, -1, "alexis_sanchez") == 0.14
			and e.steal_chance(pase, -1, "matias_fernandez") == 0.18, "robo 1/4: 11%, 14% y 18%")
	var labels: Array = e.chance_breakdown(pase, -1, "matias_fernandez").map(func(i): return i["label"])
	_check(labels.has("Duelo: Pase 66 contra Lectura 75 (Manuel Iturra)") and labels.has("Marca de Matías Fernández: 1 contra 2 · Marcelo Díaz (Lectura 67)")
			and not labels.has("Defensa rival") and not labels.has("Base (técnica)"),
			"el desglose escribe el duelo y la marca, sin técnica ni defensa rival: %s" % [labels])
	var amague := Card.from_dict(cat["amague"])
	_check(e.success_chance(amague) == 0.64, "el Amague de Aceval (Regate 66 contra Quite 53 de Salas): 64%% (da %s)" % e.success_chance(amague))
	# Lo mostrado es lo que se tira, y el receptor pasa a ser el portador.
	var shown := e.success_chance(pase, -1, "arturo_vidal")
	var ev := e.play_card(0, "arturo_vidal")
	_check(ev["ok"] and is_equal_approx(ev["chance"], shown) and ev["success"] == (ev["roll"] < shown),
			"la tirada usa el % mostrado para ese receptor")
	if ev["success"]:
		_check(e.carrier["id"] == "arturo_vidal" and e.zone == MatchEngine.Zone.MEDIO, "si el pase sale, Vidal es el portador en el Medio")
	else:
		_check(e.carrier["id"] == "miguel_aceval", "si el pase falla, Aceval sigue con la pelota")
	# Después del pase: Fernández con el Amague contra Iturra (Quite 75) en 1 vs 2 = 53%.
	var f := _duel_engine(92)
	f.zone = MatchEngine.Zone.MEDIO
	f.progress = 1
	f.carrier = _pl(f.duel_players, "matias_fernandez")
	f.marks[MatchEngine.Zone.MEDIO] = {"matias_fernandez": [_pl(u, "manuel_iturra"), _pl(u, "marcelo_diaz")]}
	_check(f.success_chance(amague) == 0.53, "Fernández con el Amague en 1 vs 2: 53%% (da %s)" % f.success_chance(amague))
	# El % que muestra cada carta es el que se tira, en muchas jugadas con receptor elegido.
	var mismatches := 0
	for seed in range(200, 260):
		var g := _duel_engine(seed)
		var card := Card.from_dict(cat["pase_corto"])
		g.deck.hand.append(card)
		var target: String = g.receivers(card)[seed % 4]["id"]
		var p := g.success_chance(card, -1, target)
		var gev := g.play_card(0, target)
		if not is_equal_approx(gev["chance"], p) or gev["success"] != (gev["roll"] < p):
			mismatches += 1
	_check(mismatches == 0, "el %% mostrado por receptor es el que se tira (%d diferencias)" % mismatches)


# Reglas del modo: sin jugadores o sin zonas no cambia nada; portador al empezar y en el contragolpe;
# pase solo a la zona siguiente; remate contra el arquero; Ejecutor Natural solo del portador;
# Pelotazo sin duelo y marcas a la mitad; regate que sigue con la pelota; vuelta atrás.
func _test_duel_rules() -> void:
	var squads := _squads()
	var cat := CardDB.load_catalog(DECK_PATH)
	var off := _zone_engine(93)
	var pase := Card.from_dict(cat["pase_corto"])
	var zone_only := off.chance_breakdown(pase)
	off.duel_mode = true
	_check(off.chance_breakdown(pase) == zone_only, "sin jugadores, el modo de duelos no cambia el desglose")
	off.duel_players = squads.duel_data("colo_colo")["players"]
	off.zone_mode = false
	_check(not off.duel_on(), "el modo de duelos exige el de zonas")

	var e := _duel_engine(94)
	_check(not e.carrier.is_empty() and e.zone_players(MatchEngine.Zone.SALIDA).has(e.carrier),
			"el Momento arranca con un portador de la Salida")
	var other: Dictionary = e.zone_players(MatchEngine.Zone.SALIDA).filter(func(p): return p != e.carrier)[0]
	_check(e.set_carrier(other["id"]) and e.carrier == other, "quien juega elige al portador de la Salida")
	_check(not e.set_carrier("humberto_suazo"), "el portador de la Salida tiene que ser de la línea de atrás")
	e.deck.hand.append(pase)
	_check(not e.can_play(pase, "humberto_suazo"), "desde la Salida no se pasa a un delantero")
	_check(e.can_play(pase, "matias_fernandez"), "desde la Salida se pasa a uno del medio")
	var ce := _duel_engine(95)
	ce.counter_ready = true
	ce.begin_moment()
	_check(ce.zone == MatchEngine.Zone.MEDIO and ce.zone_players(MatchEngine.Zone.MEDIO).has(ce.carrier),
			"el contragolpe arranca con un portador del Medio")
	# Remate en el Área: Remate del portador contra la Atajada del arquero, con sus marcas.
	var s := _duel_engine(96)
	s.zone = MatchEngine.Zone.AREA
	s.progress = 2
	s.carrier = _pl(s.duel_players, "humberto_suazo")
	s.marks[MatchEngine.Zone.AREA] = {"humberto_suazo": [_pl(s.rival_players, "waldo_ponce")]}
	var shot := Card.from_dict(cat["remate_primera"])
	var labels: Array = s.chance_breakdown(shot).map(func(i): return i["label"])
	_check(labels.has("Duelo: Remate 95 contra Atajada 74 (Miguel Pinto)"), "el remate pelea contra el arquero: %s" % [labels])
	_check(is_equal_approx(s.success_chance(shot), 0.90), "Remate de primera de Suazo en 1 vs 1: 39 + 40 + 10,5 = 89,5 → 90%% (da %s)" % s.success_chance(shot))
	s.duel_shot_adjust = -0.10
	_check(is_equal_approx(s.success_chance(shot), 0.80), "con −10 a los remates, 80%")
	s.duel_shot_adjust = 0.0
	# Ejecutor Natural: solo si la carta es del portador (+5); la firma de otro, sin bono.
	var own := _card(Card.Kind.SHOT, 0.20, 1, "humberto_suazo")
	var foreign := _card(Card.Kind.SHOT, 0.20, 1, "matias_fernandez")
	_check(is_equal_approx(s.success_chance(own) - s.success_chance(foreign), MatchEngine.DUEL_NATURAL_BONUS),
			"el Ejecutor Natural vale +5 y solo para el portador")
	_check(s.is_natural_executor(own) and not s.is_natural_executor(foreign), "la firma de otro titular la juega el portador, sin bono")
	# Pelotazo: sin duelo, marcas a la mitad (libre +6, doble −6).
	var p := _duel_engine(97)
	p.marks[MatchEngine.Zone.AREA] = {"humberto_suazo": [_pl(p.rival_players, "waldo_ponce"), _pl(p.rival_players, "nicolas_sartori")],
		"hector_mancilla": []}
	var pelotazo := Card.from_dict(cat["pelotazo"])
	var to_suazo := p.chance_breakdown(pelotazo, -1, "humberto_suazo")
	_check(not to_suazo.any(func(i): return String(i["label"]).begins_with("Duelo")), "el Pelotazo no pelea")
	_check(is_equal_approx(p.success_chance(pelotazo, -1, "hector_mancilla") - p.success_chance(pelotazo, -1, "humberto_suazo"), 0.12),
			"el Pelotazo a un libre (+6) contra uno en doble marca (−6)")
	_check(p.receivers(pelotazo).filter(func(r): return p.pass_zone(pelotazo, r["id"]) != p.zone).all(
			func(r): return p.zone_players(MatchEngine.Zone.AREA).has(r)), "el Pelotazo que avanza va al Área")
	# Regate: si sale, sigue con la pelota y el rival reparte el Medio contándolo a él.
	var dribbled := false
	for seed in range(100, 200):
		var d := _duel_engine(seed)
		var carrier: Dictionary = d.carrier
		var am := Card.from_dict(cat["amague"])
		am.bonus = 1.0
		d.deck.hand.append(am)
		var ev := d.play_card(0)
		if not ev["success"]:
			continue
		_check(d.carrier == carrier and d.zone == MatchEngine.Zone.MEDIO and d.carrier_extra, "con el regate sigue con la pelota al Medio")
		_check((d.marks[MatchEngine.Zone.MEDIO] as Dictionary).has(carrier["id"]), "el rival reparte el Medio contándolo a él")
		_check(d.stats["dribble_entries"] == 1, "el regate que entra al Medio se cuenta")
		dribbled = true
		break
	_check(dribbled, "las semillas deberían dar un regate que sale")
	# Vuelta atrás ("atras": true): no se juega en la Salida; desde el Medio vuelve y el rival reparte.
	var back_dict: Dictionary = (cat["pase_corto"] as Dictionary).duplicate()
	back_dict["atras"] = true
	back_dict["bonus"] = 1.0
	var b := _duel_engine(98)
	var back := Card.from_dict(back_dict)
	_check(back.back, "la carta con \"atras\" vuelve atrás")
	b.deck.hand.append(back)
	_check(not b.can_play(back) and b.zone_block_reason(back) == "NO HAY ZONA ANTERIOR", "en la Salida no se vuelve atrás")
	var went_back := false
	for seed in range(100, 200):
		var g := _duel_engine(seed)
		g.zone = MatchEngine.Zone.MEDIO
		g.progress = 1
		g.carrier = g.zone_players(MatchEngine.Zone.MEDIO)[0]
		g.marks.erase(MatchEngine.Zone.SALIDA)
		var bk := Card.from_dict(back_dict)
		g.deck.hand.append(bk)
		_check(g.receivers(bk).all(func(r): return g.zone_players(MatchEngine.Zone.SALIDA).has(r)), "la vuelta atrás va a la Salida")
		var ev := g.play_card(0)
		if not ev["success"]:
			continue
		_check(g.zone == MatchEngine.Zone.SALIDA and g.progress == 0 and g.zone_players(MatchEngine.Zone.SALIDA).has(g.carrier),
				"la vuelta atrás deja la pelota en la Salida con un defensa")
		_check(g.marks.has(MatchEngine.Zone.SALIDA) and g.stats["back_plays"] == 1, "al volver atrás el rival reparte de nuevo")
		went_back = true
		break
	_check(went_back, "las semillas deberían dar una vuelta atrás que sale")


# Marcas por estilo: la figura recibe más marca; si son menos, alguien queda libre.
func _test_duel_marks() -> void:
	var colo: Array = _squads().duel_data("colo_colo")["players"]
	var u: Array = _squads().duel_data("universidad_de_chile")["players"]
	var medio: Array = MatchEngine.lines_of(colo, [4, 4, 2], MatchEngine.Posture.NORMAL)[1]
	var u_medio: Array = MatchEngine.lines_of(u, [4, 3, 3], MatchEngine.Posture.NORMAL)[1]
	var rng := RandomNumberGenerator.new()
	rng.seed = 7
	var m := CoachBot.assign_marks(medio, u_medio, "Contragolpe", rng)
	_check((m["matias_fernandez"] as Array).size() == 2 and m["matias_fernandez"][0]["id"] == "manuel_iturra",
			"Contragolpe: doble marca a Fernández, con Iturra (el mejor) adelante")
	var counts: Array = m.values().map(func(a): return (a as Array).size())
	counts.sort()
	_check(counts == [0, 0, 1, 2], "Contragolpe en el medio: dos libres, uno en 1 vs 1 y Fernández en 1 vs 2")
	var z := CoachBot.assign_marks(medio, u_medio, "Tiki-Taka", rng)
	var zc: Array = z.values().map(func(a): return (a as Array).size())
	zc.sort()
	_check(zc == [0, 1, 1, 1] and (z["matias_fernandez"] as Array).size() == 1, "zonal: uno sobre cada uno y uno libre")
	var area: Array = MatchEngine.lines_of(colo, [4, 4, 2], MatchEngine.Posture.NORMAL)[2]
	var back5: Array = MatchEngine.lines_of(u, [5, 3, 2, 3], MatchEngine.Posture.NORMAL)[0]
	var cat := CoachBot.assign_marks(area, back5, "Catenaccio", rng)
	_check((cat["humberto_suazo"] as Array).size() >= 2 and (cat["hector_mancilla"] as Array).size() >= 2,
			"Catenaccio con 5 atrás: doble marca a los dos delanteros")
	var same_a := RandomNumberGenerator.new()
	same_a.seed = 3
	var same_b := RandomNumberGenerator.new()
	same_b.seed = 3
	_check(CoachBot.assign_marks(medio, u_medio, "Directo", same_a) == CoachBot.assign_marks(medio, u_medio, "Directo", same_b),
			"las marcas son deterministas dado el RNG")


# Los bots juegan el modo de duelos: eligen receptor entre los válidos, los partidos terminan, la pelota
# pasa por varios titulares y con el modo apagado DuelRunner no tiene portador.
func _test_duel_bot() -> void:
	var squads := _squads()
	var e := _duel_engine(99)
	var pase := _card(Card.Kind.PASS, 0.10, 0)
	e.deck.hand.append(pase)
	var r := CoachBot.choose_receiver(e, pase)
	_check(e.receivers(pase).any(func(x): return x["id"] == r), "el bot elige un receptor de la zona siguiente")
	var tpl_a := squads.build_match_templates("colo_colo", squads.starter_templates("colo_colo"))
	var tpl_b := squads.build_match_templates("universidad_de_chile", squads.starter_templates("universidad_de_chile"))
	var a := {"profile": BotProfile.tiki_taka(), "templates": tpl_a, "lineup": squads.lineup_ids("colo_colo"), "defends": true,
		"zone_mode": true, "duel_mode": true}
	a.merge(squads.zone_data("colo_colo"))
	a.merge(squads.duel_data("colo_colo"))
	var b := {"profile": BotProfile.contragolpe(), "templates": tpl_b, "lineup": squads.lineup_ids("universidad_de_chile"),
		"defends": true, "zone_mode": true, "duel_mode": true}
	b.merge(squads.zone_data("universidad_de_chile"))
	b.merge(squads.duel_data("universidad_de_chile"))
	var out := DuelRunner.run(a, b, 40)
	_check(out["goals_a"] + out["goals_b"] > 0, "por duelos hay goles")
	_check(out["touch_teams"] >= 70 and float(out["touch_distinct"]) / out["touch_teams"] >= 3.0,
			"la pelota pasa por varios titulares (%.1f por partido)" % (float(out["touch_distinct"]) / maxf(1.0, out["touch_teams"])))
	a.erase("duel_mode")
	b.erase("duel_mode")
	_check(DuelRunner.run(a, b, 10)["touch_teams"] == 0, "sin el modo de duelos no hay portador")


# D-42: cada marcador extra resta según su defensa (habilidad ÷ 6) y en una transición solo te esperan
# los rivales que se quedaron atrás al atacar, según su estilo y su postura.
func _test_duel_d42() -> void:
	var cat := CardDB.load_catalog(DECK_PATH)
	var amague := Card.from_dict(cat["amague"])
	var f := _duel_engine(301)
	var u: Array = f.rival_players
	f.zone = MatchEngine.Zone.MEDIO
	f.progress = 1
	f.carrier = _pl(f.duel_players, "matias_fernandez")
	f.marks[MatchEngine.Zone.MEDIO] = {"matias_fernandez": [_pl(u, "manuel_iturra"), _pl(u, "marcelo_diaz")]}
	var with_mid := f.success_chance(amague)
	var mark: Dictionary = f.chance_breakdown(amague).filter(func(i): return String(i["label"]).begins_with("Marca de"))[0]
	_check(is_equal_approx(float(mark["value"]), -67.0 / 6.0 / 100.0) and String(mark["label"]).ends_with("Marcelo Díaz (Quite 67)"),
			"el marcador extra resta su Quite ÷ 6 y sale con su nombre: %s" % [mark])
	_check(with_mid == 0.53, "Amague de Fernández contra Iturra y Díaz: 39 + 18 + 7,5 − 11,2 = 53%% (da %s)" % with_mid)
	f.marks[MatchEngine.Zone.MEDIO] = {"matias_fernandez": [_pl(u, "manuel_iturra"), _pl(u, "marcelo_salas")]}
	_check(f.success_chance(amague) == 0.56, "un delantero que presiona (Salas, Quite 53) resta menos: −8,8 → 56%% (da %s)" % f.success_chance(amague))
	f.duel_mark_divisor = 0.0
	mark = f.chance_breakdown(amague).filter(func(i): return String(i["label"]).begins_with("Marca de"))[0]
	_check(is_equal_approx(float(mark["value"]), -MatchEngine.DUEL_MARK_PTS), "con divisor 0, el −12 fijo de D-40")
	# Pelotazo: sin duelo, el extra resta su Lectura ÷ 6 a la mitad.
	var p := _duel_engine(302)
	p.marks[MatchEngine.Zone.AREA] = {"humberto_suazo": [_pl(p.rival_players, "waldo_ponce"), _pl(p.rival_players, "nicolas_sartori")]}
	var pel := Card.from_dict(cat["pelotazo"])
	var pm: Dictionary = p.chance_breakdown(pel, -1, "humberto_suazo").filter(func(i): return String(i["label"]).begins_with("Marca de"))[0]
	_check(is_equal_approx(float(pm["value"]), -73.0 / 6.0 / 100.0 * MatchEngine.DUEL_PELOTAZO_FACTOR),
			"Pelotazo en doble marca: Sartori (Lectura 73) resta ÷ 6 a la mitad")
	# Transición: cuántos se quedan atrás por estilo y postura.
	_check(MatchEngine.transition_stay("Kamikaze", MatchEngine.Posture.NORMAL) == [2, 2], "Kamikaze deja 2 atrás y 2 en el medio")
	_check(MatchEngine.transition_stay("Kamikaze", MatchEngine.Posture.HIGH) == [1, 2], "en HIGH deja uno menos atrás")
	_check(MatchEngine.transition_stay("Kamikaze", MatchEngine.Posture.LOW) == [3, 2], "en LOW deja uno más atrás")
	_check(MatchEngine.transition_stay("Catenaccio", MatchEngine.Posture.NORMAL) == [5, 3], "Catenaccio deja a todos atrás")
	var totals := func(e: MatchEngine, z: int) -> int:
		var t := 0
		for id in e.marks.get(z, {}):
			t += (e.marks[z][id] as Array).size()
		return t
	var normal := _duel_engine(303)
	normal.rival_mark_style = "Kamikaze"
	normal.begin_moment()
	_check(totals.call(normal, MatchEngine.Zone.AREA) == 4 and not normal.transition, "en un ataque normal te esperan sus 4 de atrás")
	var counter := _duel_engine(304)
	counter.rival_mark_style = "Kamikaze"
	counter.counter_ready = true
	counter.begin_moment()
	_check(counter.transition and totals.call(counter, MatchEngine.Zone.AREA) == 2 and totals.call(counter, MatchEngine.Zone.MEDIO) == 2,
			"en la contra contra un Kamikaze solo te esperan 2 atrás y 2 en el medio")
	_check(counter.stats["transition_moments"] == 1, "el Momento de transición se cuenta")
	var off := _duel_engine(305)
	off.rival_mark_style = "Kamikaze"
	off.duel_transition = false
	off.counter_ready = true
	off.begin_moment()
	_check(totals.call(off, MatchEngine.Zone.AREA) == 4, "sin la regla de transición, la contra encuentra su formación completa")
	# Robo en tu Salida: se cuenta y, si fue en un regate, lo hizo un delantero que presiona.
	var stolen := false
	for seed in range(310, 500):
		var g := _duel_engine(seed)
		g.carrier = _pl(g.duel_players, "celso_ayala")
		g.marks[MatchEngine.Zone.SALIDA] = {"celso_ayala": [_pl(g.rival_players, "marcelo_salas")]}
		g.deck.hand.append(Card.from_dict(cat["amague"]))
		var ev := g.play_card(0)
		if not ev.get("stolen", false):
			continue
		_check(g.stats["salida_steals"] == 1 and g.stats["salida_steals_fwd"] == 1 and ev["stealer"] == "marcelo_salas"
				and g.stats["salida_steal_skill"] == 53, "el robo en la Salida lo hace el delantero que presionaba (Quite 53)")
		stolen = true
		break
	_check(stolen, "las semillas deberían dar un robo en la Salida")


# D-43: presión al portador en sus pases (Quite ÷ 12, línea propia), jugada corta en los Momentos de 2
# (el Área con los que se quedan atrás) y el bot que mira una jugada más al elegir receptor.
func _test_duel_d43() -> void:
	var cat := CardDB.load_catalog(DECK_PATH)
	var e := _duel_engine(401)
	var u: Array = e.rival_players
	e.carrier = _pl(e.duel_players, "miguel_aceval")
	e.marks[MatchEngine.Zone.MEDIO] = {"arturo_vidal": [], "matias_fernandez": [_pl(u, "manuel_iturra"), _pl(u, "marcelo_diaz")]}
	e.marks[MatchEngine.Zone.SALIDA] = {"miguel_aceval": [_pl(u, "marcelo_salas")]}
	var pase := Card.from_dict(cat["pase_corto"])
	e.deck.hand.append(pase)
	var labels: Array = e.chance_breakdown(pase, -1, "arturo_vidal").map(func(i): return i["label"])
	_check(labels.has("Presión de Marcelo Salas (Quite 53)"), "la presión al portador sale en su línea: %s" % [labels])
	_check(e.success_chance(pase, -1, "arturo_vidal") == 0.53, "Aceval a Vidal con Salas encima: 57 − 4,4 = 53%% (da %s)" % e.success_chance(pase, -1, "arturo_vidal"))
	e.duel_press_divisor = 6.0
	_check(e.success_chance(pase, -1, "arturo_vidal") == 0.48, "con la presión completa (÷6): 57 − 8,8 = 48%% (da %s)" % e.success_chance(pase, -1, "arturo_vidal"))
	e.duel_press_divisor = 12.0
	var shown := e.success_chance(pase, -1, "arturo_vidal")
	var ev := e.play_card(0, "arturo_vidal")
	_check(is_equal_approx(ev["chance"], shown) and ev["success"] == (ev["roll"] < shown), "con presión, el % mostrado es el que se tira")
	# Jugada corta: en un Momento de 2 jugadas el Área del rival tiene solo los que se quedan atrás (Tiki-Taka: 3 de 4).
	var count := func(m: MatchEngine, z: int) -> int:
		var t := 0
		for id in m.marks.get(z, {}):
			t += (m.marks[z][id] as Array).size()
		return t
	var short := _duel_engine(402, 2)
	short.rival_mark_style = "Tiki-Taka"
	short.begin_moment()
	_check(short.short_play and count.call(short, MatchEngine.Zone.AREA) == 3, "jugada corta: en el Área esperan 3 de sus 4 defensas")
	var long := _duel_engine(403, 3)
	long.rival_mark_style = "Tiki-Taka"
	long.begin_moment()
	_check(not long.short_play and count.call(long, MatchEngine.Zone.AREA) == 4, "en un Momento de 3 jugadas el Área tiene la defensa completa")
	var off := _duel_engine(404, 2)
	off.rival_mark_style = "Tiki-Taka"
	off.duel_short_play = false
	off.begin_moment()
	_check(count.call(off, MatchEngine.Zone.AREA) == 4, "sin la regla, la jugada corta encuentra la defensa completa")
	# Bot con lookahead: valora la jugada siguiente del receptor (el Amague de Fernández, Regate 90, contra
	# el de Vidal, Regate 64) y deja el motor como estaba.
	var b := _duel_engine(405)
	b.carrier = _pl(b.duel_players, "miguel_aceval")
	var diaz := _pl(u, "marcelo_diaz")
	b.marks[MatchEngine.Zone.MEDIO] = {"arturo_vidal": [diaz], "matias_fernandez": [diaz], "rodrigo_melendez": [diaz], "alexis_sanchez": [diaz]}
	var p2 := Card.from_dict(cat["pase_corto"])
	b.deck.hand.append_array([p2, Card.from_dict(cat["amague"])])
	var before := [b.carrier, b.zone, b.progress]
	var next_f := CoachBot._next_value(b, p2, _pl(b.duel_players, "matias_fernandez"))
	var next_v := CoachBot._next_value(b, p2, _pl(b.duel_players, "arturo_vidal"))
	_check(next_f > next_v, "Fernández puede hacer más después de recibir que Vidal (%s contra %s)" % [next_f, next_v])
	_check([b.carrier, b.zone, b.progress] == before, "mirar una jugada más no cambia el motor")
	_check(CoachBot.choose_receiver(b, p2) == "matias_fernandez", "con el mismo % de recibir, el bot se la da a Fernández")


# D-46: el pase también va a un compañero de la zona en juego; no avanza, cambia el portador y se tira igual
# (su Pase contra la Lectura de quien marca al receptor, con el robo de esa zona si falla).
func _test_duel_d46() -> void:
	var cat := CardDB.load_catalog(DECK_PATH)
	var pase := Card.from_dict(cat["pase_corto"])
	var e := _duel_engine(461)
	e.deck.hand.append(pase)
	var mate: Dictionary = e.zone_players(MatchEngine.Zone.SALIDA).filter(func(p): return p != e.carrier)[0]
	var ids: Array = e.receivers(pase).map(func(r): return r["id"])
	_check(ids.has(mate["id"]) and ids.has("matias_fernandez"), "el pase va a la Salida o al Medio (D-46): %s" % [ids])
	_check(not ids.has(e.carrier["id"]), "el portador no se pasa a sí mismo")
	_check(e.can_play(pase, mate["id"]), "se puede pasar a un compañero de la misma zona")
	_check(e.pass_zone(pase, mate["id"]) == MatchEngine.Zone.SALIDA and e.pass_zone(pase, "matias_fernandez") == MatchEngine.Zone.MEDIO,
			"pass_zone: la misma zona o la siguiente según el receptor")
	_check(e.pass_zone(pase, e.best_receiver(pase)) == MatchEngine.Zone.MEDIO, "el receptor por defecto (y el de los planes del bot) avanza")
	# Su duelo: Pase del portador contra la Lectura de quien marca al receptor, en la Salida.
	var marker: Dictionary = e.defender_line(MatchEngine.Zone.SALIDA)[0]
	e.marks[MatchEngine.Zone.SALIDA] = {mate["id"]: [marker], e.carrier["id"]: []}
	var labels: Array = e.chance_breakdown(pase, -1, mate["id"]).map(func(i): return i["label"])
	var duel := "Duelo: Pase %d contra Lectura %d (%s)" % [int(e.carrier["pase"]), int(marker["lectura"]), marker["name"]]
	_check(labels.has(duel), "el pase en la misma zona pelea con la Lectura de su marca: %s" % [labels])
	_check(e.steal_chance(pase, -1, mate["id"]) > 0.0, "si falla en la Salida, puede ser robo")
	# Si sale: no avanza, la zona sigue y el receptor es el portador. El % mostrado es el que se tira.
	var ok_seen := false
	var fail_seen := false
	for s in 40:
		var t := _duel_engine(470 + s)
		var c := Card.from_dict(cat["pase_corto"])
		t.deck.hand.append(c)
		var m: Dictionary = t.zone_players(MatchEngine.Zone.SALIDA).filter(func(p): return p != t.carrier)[0]
		var shown := t.success_chance(c, -1, m["id"])
		var steal := t.steal_chance(c, -1, m["id"])
		var ev := t.play_card(t.deck.hand.find(c), m["id"])
		_check(is_equal_approx(float(ev["chance"]), shown), "se tira contra el % mostrado para ese receptor")
		if ev["success"]:
			ok_seen = true
			_check(t.progress == 0 and t.zone == MatchEngine.Zone.SALIDA, "el pase en la misma zona no avanza")
			_check(t.carrier == m and ev.get("same_zone", false), "el receptor de la misma zona queda con la pelota")
		else:
			fail_seen = true
			_check(ev.get("stolen", false) == (float(ev["roll"]) >= 1.0 - steal), "el robo sale de la misma tirada")
	_check(ok_seen and fail_seen, "se vio el pase en la misma zona salir y fallar")
	_check(int(_duel_engine(461).stats["same_zone_passes"]) == 0, "la estadística arranca en cero")
	# Apagado (D-40), solo la zona siguiente; en el Área, los del Área (sin repetirlos).
	var off := _duel_engine(462)
	off.duel_same_zone = false
	off.deck.hand.append(pase)
	_check(off.receivers(pase).all(func(r): return off.zone_players(MatchEngine.Zone.MEDIO).has(r)), "sin D-46, solo la zona siguiente")
	var a := _duel_engine(463)
	a.zone = MatchEngine.Zone.AREA
	a.progress = 2
	a.carrier = a.zone_players(MatchEngine.Zone.AREA)[0]
	_check(a.receivers(pase).size() == a.zone_players(MatchEngine.Zone.AREA).size() - 1, "en el Área los receptores no se repiten")
	# El bot: CoachBot.choose_receiver puede elegir la misma zona, pero a la mitad de su puntaje.
	var b := _duel_engine(464)
	b.deck.hand.append(pase)
	var choice := CoachBot.choose_receiver(b, pase)
	_check(choice != "", "el bot elige un receptor con D-46")


# ---------- Defensa por duelos (D-44, T-15) ----------

# La U defiende el ataque de Colo-Colo de _duel_engine: mano vacía y 2 PA de defensa.
func _duel_defender(seed: int, att: MatchEngine) -> MatchEngine:
	var d := _new_engine(seed)
	d.zone_mode = true
	d.duel_mode = true
	d.duel_players = att.rival_players
	d.mark_style = att.rival_mark_style
	d.start()
	d.begin_defense(0.15, att)
	d.deck.hand.clear()
	d.ap = 2
	return d


func _test_duel_d44() -> void:
	var cat := CardDB.load_catalog(DECK_PATH)
	var att := _duel_engine(441)
	var def := _duel_defender(442, att)
	_check(def.defends_by_duels(att) and def.duel_defense_on(), "con duelos de los dos lados se defiende jugada a jugada")
	var presion := Card.from_dict(cat["presion"])
	var bloqueo := Card.from_dict(cat["bloqueo"])
	var inter := Card.from_dict(cat["intercepcion"])
	var despeje := Card.from_dict(cat["despeje"])
	for c in [presion, bloqueo, inter, despeje]:
		def.deck.hand.append(c)
	_check(not def.can_play(presion) and def.can_play(despeje), "sin jugada anunciada solo sirve el Despeje")
	# El rival anuncia un pase al Medio: Presión sobre el portador, Intercepción sobre el receptor, sin Bloqueo.
	var pase := Card.from_dict(cat["pase_corto"])
	att.deck.hand.append(pase)
	var rec := att.best_receiver(pase)
	def.set_defense_intent(pase, rec)
	_check(def.defense_target(presion) == att.carrier["id"] and def.can_play(presion), "la Presión va sobre el portador")
	_check(def.defense_target(inter) == rec and def.can_play(inter), "la Intercepción va sobre la línea del pase (el receptor)")
	_check(not def.can_play(bloqueo), "contra un pase no hay Bloqueo")
	# Tu defensor: el mejor de los que lo marcan para esa carta; sin marca, el mejor de tu línea en la zona.
	var z := att.zone
	var m: Array = att.markers_of(z, att.carrier["id"])
	var want: Dictionary = MatchEngine._best_by(m, "quite") if not m.is_empty() \
			else MatchEngine._best_by(att.defender_line(z), "quite")
	_check(def.defense_defender(presion) == want, "la Presión la juega quien marca al portador (o el mejor de su línea)")
	att.marks[z] = {}
	_check(def.defense_defender(presion) == MatchEngine._best_by(att.defender_line(z), "quite"),
			"si nadie lo marca, el de esa zona con mejor Quite")
	att.marks[z] = {att.carrier["id"]: m}
	var rz := att.pass_zone(pase, rec)
	var rm: Array = att.markers_of(rz, rec)
	if not rm.is_empty():
		_check(def.defense_defender(inter) == MatchEngine._best_by(rm, "lectura"), "la Intercepción la juega la mejor Lectura de quien marca al receptor")
	# Su %: base + carta + tu habilidad contra la suya, en una línea; lo mostrado es lo que se tira.
	var d: Dictionary = def.defense_defender(presion)
	var items := def.chance_breakdown(presion)
	var label := "Duelo de %s: Quite %d contra Regate %d (%s)" % [d["name"], int(d["quite"]), int(att.carrier["regate"]), att.carrier["name"]]
	_check(items.any(func(i): return i["label"] == label), "la Presión pelea Quite contra Regate: %s" % [items.map(func(i): return i["label"])])
	_check(not items.any(func(i): return i["label"] == "Ataque rival"), "sin la dificultad de la defensa de siempre")
	var di: Dictionary = def.defense_defender(inter)
	_check(def.chance_breakdown(inter).any(func(i): return String(i["label"]).begins_with("Duelo de %s: Lectura %d contra Pase %d" % [di["name"], int(di["lectura"]), int(att.carrier["pase"])])),
			"la Intercepción pelea Lectura contra Pase")
	# Anuncia un remate: Bloqueo sobre el portador, Quite contra Remate.
	var remate := Card.from_dict(cat["remate_simple"])
	def.set_defense_intent(remate)
	_check(def.can_play(bloqueo) and not def.can_play(inter), "contra un remate, Bloqueo y no Intercepción")
	_check(def.chance_breakdown(bloqueo).any(func(i): return String(i["label"]).contains("Quite %d contra Remate %d" % [int(def.defense_defender(bloqueo)["quite"]), int(att.carrier["remate"])])),
			"el Bloqueo pelea Quite contra Remate")
	def.set_defense_intent(null, "", true)
	_check(not def.can_play(presion) and def.can_play(despeje), "si aguanta el balón, solo el Despeje")
	# La Presión que sale le resta a la jugada anunciada, en su desglose; lo mostrado al rival es lo que tira.
	var press_ok := false
	var cut_ok := false
	for s in 60:
		var a := _duel_engine(500 + s)
		var df := _duel_defender(600 + s, a)
		var p := Card.from_dict(cat["presion"])
		var i := Card.from_dict(cat["intercepcion"])
		df.deck.hand.append(p)
		df.deck.hand.append(i)
		var pc := Card.from_dict(cat["pase_corto"])
		a.deck.hand.append(pc)
		var r := a.best_receiver(pc)
		df.set_defense_intent(pc, r)
		var before := a.success_chance(pc, -1, r)
		var shown := df.success_chance(p)
		var ev := df.play_card(df.deck.hand.find(p))
		_check(is_equal_approx(float(ev["chance"]), shown), "la defensa se tira contra el % mostrado")
		_check(ev.get("defender", "") == df.defense_defender(p).get("id", "-") or not df.in_defense, "el evento dice quién defendió")
		if ev["success"] and not press_ok:
			press_ok = true
			var after := a.success_chance(pc, -1, r)
			_check(a.chance_breakdown(pc, -1, r).any(func(it): return String(it["label"]).begins_with("Presión de ") and is_equal_approx(float(it["value"]), -0.12)),
					"la Presión que sale resta 12 a la jugada anunciada, en su desglose")
			_check(after < before, "el rival ve su %% más bajo (%s → %s)" % [before, after])
			var aev := a.play_card(a.deck.hand.find(pc), r)
			_check(is_equal_approx(float(aev["chance"]), after) and aev.has("defended"), "el rival tira contra el % con la Presión")
			_check(a.defense_penalties.is_empty(), "la Presión dura una sola jugada")
		elif not ev["success"]:
			continue
		# Intercepción sobre el mismo pase (con 1 PA ya no alcanza: se prueba aparte).
	for s in 80:
		var a := _duel_engine(700 + s)
		var df := _duel_defender(800 + s, a)
		var i := Card.from_dict(cat["intercepcion"])
		df.deck.hand.append(i)
		var pc := Card.from_dict(cat["pase_corto"])
		a.deck.hand.append(pc)
		df.set_defense_intent(pc, a.best_receiver(pc))
		var ev := df.play_card(df.deck.hand.find(i))
		if ev["success"]:
			cut_ok = true
			_check(a.moment_over and int(a.stats["cut_moments"]) == 1 and int(a.stats["goals"]) == 0, "la Intercepción corta el Momento del rival")
			_check(df.counter_ready and not df.in_defense and ev["cancelled"], "y recuperas con contragolpe")
			break
	_check(press_ok and cut_ok, "se vio la Presión y la Intercepción salir")
	# Apagado (duel_defense = false): la defensa de siempre, antes del ataque.
	var off_att := _duel_engine(443)
	var off := _new_engine(444)
	off.zone_mode = true
	off.duel_mode = true
	off.duel_players = off_att.rival_players
	off.duel_defense = false
	off.start()
	off.begin_defense(0.15, off_att)
	_check(not off.duel_defense_on() and not off.defends_by_duels(off_att), "con duel_defense apagado, la defensa de T-10")
	off.end_defense()
	# El bot defiende igual: con la jugada anunciada responde con una carta como mucho.
	var ba := _duel_engine(445)
	var bd := _duel_defender(446, ba)
	bd.deck.hand.append(Card.from_dict(cat["presion"]))
	bd.deck.hand.append(Card.from_dict(cat["presion"]))
	var bp := Card.from_dict(cat["pase_corto"])
	ba.deck.hand.append(bp)
	CoachBot.announce(bd, {"card": bp, "receiver": ba.best_receiver(bp)})
	var plays := 0
	if not CoachBot.defend_play(bd, BotProfile.new()).is_empty():
		plays += 1
	_check(plays <= 1 and bd.deck.hand.size() >= 1, "el bot juega una carta como mucho por jugada")


# ---------- Desenlaces de los fallos (D-48, T-15) ----------

func _test_duel_d48() -> void:
	var cat := CardDB.load_catalog(DECK_PATH)
	for kind in MatchEngine.FAIL_OUTCOMES:
		for row: Array in MatchEngine.FAIL_OUTCOMES[kind]:
			var s := 0.0
			for o in row:
				s += float(o[1])
			_check(is_equal_approx(s, 1.0), "la fila de desenlaces de %s suma 1: %s" % [kind, row])
	# El robo es la CORTADA de la tabla: (1 − %) × su parte.
	var e := _duel_engine(481)
	var pase := Card.from_dict(cat["pase_corto"])
	e.deck.hand.append(pase)
	var r := e.best_receiver(pase)
	var p := e.success_chance(pase, -1, r)
	_check(is_equal_approx(e.steal_chance(pase, -1, r), roundi((1.0 - p) * 0.20 * 100.0) / 100.0), "el robo del pase en la Salida es la cortada (20% de los fallos)")
	# La dividida: 50 + factor × (Quite del portador − el mejor Quite de los que lo marcan).
	var lb := e.loose_ball(pase, r)
	var want := 0.5 + e.duel_skill_factor * float(int(lb["attacker"]["quite"]) - int(lb["defender"]["quite"])) / 100.0
	_check(is_equal_approx(lb["chance"], roundi(clampf(want, 0.05, 0.95) * 100.0) / 100.0), "la dividida es Quite contra Quite: %s" % [lb])
	# Pases fallidos en la Salida: cada desenlace sale de la misma tirada y hace lo suyo.
	var seen := {}
	for s in 300:
		var t := _duel_engine(2000 + s)
		var c := Card.from_dict(cat["pase_corto"])
		t.deck.hand.append(c)
		t.deck.hand.append(Card.from_dict(cat["pase_corto"]))
		var rr := t.best_receiver(c)
		var carrier_before := String(t.carrier["id"])
		var ev := t.play_card(t.deck.hand.find(c), rr)
		if ev["success"]:
			continue
		var o := String(ev.get("outcome", ""))
		seen[o] = true
		var u := (float(ev["roll"]) - float(ev["chance"])) / (1.0 - float(ev["chance"]))
		match o:
			"cortada":
				_check(ev.get("stolen", false) and t.moment_over and u >= 0.8 - 0.0001, "la cortada es robo arriba de los fallos (u %.2f)" % u)
			"lateral":
				_check(t.moment_over and not ev.get("stolen", false) and u >= 0.5 - 0.0001 and u < 0.8, "al lateral: fin sin contragolpe")
			"dividida":
				var d: Dictionary = ev["dividida"]
				_check(d["won"] == (float(d["roll"]) < float(d["chance"])) and t.moment_over != d["won"], "la dividida se tira contra su %%: %s" % [d])
				if d["won"]:
					_check(String(t.carrier["id"]) == carrier_before and t.zone == MatchEngine.Zone.SALIDA, "si la ganas, sigues con la pelota en esa zona")
			_:
				_check(false, "desenlace de pase inesperado: '%s'" % o)
	_check(seen.has("cortada") and seen.has("lateral") and seen.has("dividida"), "se vieron los tres desenlaces del pase: %s" % [seen.keys()])
	# Remates fallidos en el Área: atajada, rebote, córner y afuera; el córner se tira sin carta.
	var shots := {}
	var corner_done := false
	for s in 400:
		var t := _duel_engine(3000 + s)
		t.zone = MatchEngine.Zone.AREA
		t.progress = 2
		t.carrier = t.zone_players(MatchEngine.Zone.AREA)[0]
		var c := Card.from_dict(cat["remate_simple"])
		t.deck.hand.append(c)
		t.deck.hand.append(Card.from_dict(cat["remate_simple"]))
		var ev := t.play_card(t.deck.hand.find(c))
		if ev["success"]:
			continue
		var o := String(ev.get("outcome", ""))
		shots[o] = true
		if o == "atajada" or o == "afuera":
			_check(t.moment_over and not ev.get("stolen", false), "%s: fin del ataque sin contragolpe" % o)
		if o == "corner" and not corner_done:
			_check(not t.moment_over and t.corner_pending and t.playable_indices().is_empty() and not t.can_hold(), "al córner: el Momento sigue y no se juega carta")
			var rec := t.best_corner_receiver()
			var shown := t.corner_chance(rec)
			var labels: Array = t.corner_breakdown(rec).map(func(i): return i["label"])
			_check(labels.has("Córner (pelota parada)"), "el centro del córner tiene su línea: %s" % [labels])
			var cev := t.take_corner(rec)
			_check(is_equal_approx(float(cev["chance"]), shown) and cev["success"] == (float(cev["roll"]) < shown), "el córner se tira contra su %")
			_check(not t.corner_pending, "el córner se tira una vez")
			if cev["success"]:
				corner_done = true
				_check(String(t.carrier["id"]) == rec and t.zone == MatchEngine.Zone.AREA and not t.moment_over, "si el centro llega, el receptor remata en el Área")
				var gol := false
				for k in 30:
					var t2 := t
					if t2.moment_over:
						break
					var ev2 := t2.play_card(0)
					gol = ev2.get("goal", false)
				if gol:
					_check(int(t.stats["corner_goals"]) == 1, "el gol después del córner cuenta como de pelota parada")
			else:
				_check(t.moment_over, "si no llega, despejan")
	_check(shots.has("atajada") and shots.has("rebote") and shots.has("corner") and shots.has("afuera"), "se vieron los desenlaces del remate: %s" % [shots.keys()])
	# Regate fallido: la falta deja la pelota al que atacaba.
	var falta := false
	for s in 300:
		var t := _duel_engine(4000 + s)
		t.zone = MatchEngine.Zone.MEDIO
		t.progress = 1
		var c := Card.from_dict(cat["amague"])
		t.deck.hand.append(c)
		t.deck.hand.append(Card.from_dict(cat["amague"]))
		var ev := t.play_card(t.deck.hand.find(c))
		if String(ev.get("outcome", "")) == "falta":
			falta = true
			_check(not t.moment_over and t.zone == MatchEngine.Zone.MEDIO, "falta: sigues con la pelota en esa zona")
			break
	_check(falta, "se vio una falta")
	# Apagado: el robo de D-36, sin desenlaces.
	var off := _duel_engine(482)
	off.duel_outcomes = false
	var oc := Card.from_dict(cat["pase_corto"])
	off.deck.hand.append(oc)
	var oev := off.play_card(0, off.best_receiver(oc))
	_check(not oev.has("outcome"), "con duel_outcomes apagado no hay desenlaces")
