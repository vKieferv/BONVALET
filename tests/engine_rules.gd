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
