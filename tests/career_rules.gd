# Pruebas del modo carrera sin escenas: planteles, mazo por club, Ejecutor Natural por titulares,
# reglas de la semana (sponsor, evento social, Bloque 2 con tu mazo propio, partido) y el guardado.
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
	_test_training_offer()
	_test_take_offer()
	_test_video_upgrades()
	_test_career_stamina()
	_test_rivals_and_sponsor_scale()
	_test_rival_growth()
	_test_save_round_trip()
	_test_save_pending_match()
	_test_save_v1_migration()
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


# Mazo de inicio (D-23) de los 32 clubes: pasa las reglas de liga (máx. 6 extranjeros, mín. 2 Sub-21)
# y el tamaño 10-20, y el de final de temporada (+8 cartas de su crecimiento) no pasa de 20.
func _test_decks_for_every_club() -> void:
	var limit := int(league.get_rules(LEAGUE_ID).get("sub21_age_limit", 21))
	for t in league.teams:
		var deck := squads.build_match_deck(t["id"], squads.starter_templates(t["id"]))
		var size_error := DeckManager.new(deck, [], RandomNumberGenerator.new()).size_error()
		_check(size_error == "", "%s: %s" % [t["id"], size_error])
		_check(deck.size() >= DeckManager.DECK_MIN and deck.size() <= DeckManager.DECK_MAX,
				"%s: el mazo de inicio tiene %d cartas" % [t["id"], deck.size()])
		var r := league.validate_deck(deck, LEAGUE_ID)
		_check(r["valid"], "%s: el mazo no pasa validate_deck: %s" % [t["id"], r["errors"]])
		for c in deck:
			if c.tags.has("canterano"):
				var p := squads.find_player(t["id"], c.owner_id)
				_check(not p.is_empty() and int(p["age"]) < limit, "%s: la carta de canterano debería ser de un Sub-21 del plantel" % t["id"])
		var late := squads.season_templates(t["id"], 8)
		var late_deck := squads.build_match_deck(t["id"], late)
		_check(late.size() <= DeckManager.DECK_MAX and late_deck.size() <= DeckManager.DECK_MAX,
				"%s: con +8 cartas el mazo no debería pasar de %d (tiene %d)" % [t["id"], DeckManager.DECK_MAX, late_deck.size()])
		_check(late.size() > squads.starter_templates(t["id"]).size(), "%s: el crecimiento debería sumar cartas" % t["id"])
		_check(league.validate_deck(late_deck, LEAGUE_ID)["valid"], "%s: el mazo de final de temporada no pasa validate_deck" % t["id"])
	# La carrera arranca con el mazo de inicio de tu club como mazo propio (entradas sin mejora).
	var c := Career.new()
	_check(c.setup(league, squads, "colo_colo", 99), "Career no arranca: %s" % [c.load_errors])
	var mine := c.build_deck()
	_check(mine.size() == 12 and mine.any(func(x: Card) -> bool: return x.id == "toque_toque"),
			"Colo-Colo (Tiki-Taka) debería arrancar la carrera con 12 cartas y su Toque-toque (tiene %d)" % mine.size())
	var starter_ids: Array = squads.starter_templates("colo_colo").map(func(d): return d["id"])
	_check(c.deck.size() == 11 and c.deck.map(func(e): return e["id"]) == starter_ids
			and c.deck.all(func(e): return e["mejora"] == ""),
			"tu mazo propio debería arrancar con las 11 cartas del DT del mazo de inicio, sin mejoras")
	_check(c.deck_size() == mine.size() and not c.deck_full(), "deck_size cuenta las cartas del DT y las firmas")


func _test_natural_executor_by_lineup() -> void:
	var deck := squads.build_match_deck("colo_colo", squads.starter_templates("colo_colo"))
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
	for id in REAL_SQUADS:
		var as_dicts := squads.build_match_templates(id, squads.starter_templates(id))
		var deck := squads.build_match_deck(id, squads.starter_templates(id))
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
	_check(not c.prepare_match()["ok"], "sin el Bloque 2 no se debería poder jugar")
	_check(c.take_offer(0), "debería poder quedarse con una carta del entrenamiento táctico")
	var fatigue_before := c.fatigue
	var r := c.prepare_match()
	_check(r["ok"], "con los bloques completos el partido debería validarse: %s" % [r["errors"]])
	_check(c.pending_match and c.fatigue == fatigue_before + 10.0, "el entrenamiento táctico suma 10 de fatiga")
	_check(r["deck_size"] == 13, "el partido se juega con la carta nueva (13 cartas, tiene %d)" % r["deck_size"])

	var rng := RandomNumberGenerator.new()
	var player := PlayerStats.new()
	var e := MatchEngine.new(player, DeckManager.new(c.build_deck(), [], rng), rng, 0.15)
	c.configure_match(e, player)
	_check(e.form_bonus == 0.0 and not c.match_mods.has("form_bonus"), "el entrenamiento táctico ya no da forma (D-21)")
	_check(player.lineup.size() == 11 and player.fatigue == c.fatigue, "configure_match debería pasar titulares y fatiga al partido")

	var budget := c.budget
	var rival := c.rival_id
	var lost := c.sponsor_week_lost
	var entry := c.record_match(2, 1)
	_check(entry.get("rival_id", "") == rival and c.week == 2 and not c.pending_match, "record_match cierra la semana")
	# Con funa + cláusula de conducta se pierde el fijo, pero el bono por victoria se paga igual.
	_check(c.budget > budget, "ganar con sponsor debería sumar presupuesto (pago perdido: %s)" % lost)
	_check(c.event_result.is_empty() and c.training == "" and c.rival_id != rival, "la semana 2 empieza limpia y con otro rival")
	_check(c.deck.size() == 12 and c.training_offer.size() == Career.OFFER_SIZE, "la semana 2 conserva el mazo y trae oferta nueva")


# Entrenamiento táctico (D-20): 3 cartas distintas, 2 de la lista de tu estilo y 1 de la general
# (decks.json "ofertas"), nunca una carta de rasgo; misma semilla, mismas ofertas, y la oferta de la
# semana no cambia aunque se use el azar (evento social).
func _test_training_offer() -> void:
	var offers: Dictionary = squads.deck_lists["ofertas"]
	var traits: Array = squads.deck_lists["rasgos"].values()
	var archetypes := {}
	for t in league.teams:
		var arch := String(t["archetype"])
		if archetypes.has(arch) or t.get("suspended", false):
			continue
		archetypes[arch] = true
		var variety := {}
		for seed in range(1, 21):
			var c := Career.new()
			c.setup(league, squads, t["id"], seed)
			for w in 3:
				var offer: Array = c.training_offer
				var distinct := {}
				for id in offer:
					distinct[id] = true
				_check(offer.size() == Career.OFFER_SIZE and distinct.size() == offer.size(),
						"%s: la oferta debería tener %d cartas distintas: %s" % [t["id"], Career.OFFER_SIZE, offer])
				if offer.size() == 3:
					_check(offers[arch].has(offer[0]) and offers[arch].has(offer[1]) and offers["general"].has(offer[2]),
							"%s: la oferta debería ser 2 cartas de %s + 1 general: %s" % [t["id"], arch, offer])
				_check(not offer.any(func(id): return traits.has(id)), "%s: la oferta no debería traer una carta de rasgo: %s" % [t["id"], offer])
				variety[",".join(offer)] = true
				c.decline_offer()
				c.choose_sponsor("telnet")
				c.resolve_event(false)
				c.prepare_match()
				c.record_match(1, 1)
		_check(variety.size() > 5, "%s: las ofertas deberían variar con la semilla y la semana (%d distintas)" % [arch, variety.size()])
	_check(archetypes.size() == 5, "deberían probarse los 5 arquetipos (%d)" % archetypes.size())

	var a := Career.new()
	a.setup(league, squads, "colo_colo", 555)
	var b := Career.new()
	b.setup(league, squads, "colo_colo", 555)
	_check(a.training_offer == b.training_offer, "misma semilla, misma oferta en la semana 1")
	for x in [a, b]:
		x.choose_sponsor("telnet")
		x.resolve_event(true)
		x.take_offer(0)
		x.prepare_match()
		x.record_match(2, 0)
	_check(a.training_offer == b.training_offer and a.deck == b.deck, "misma semilla y mismas decisiones: misma oferta en la semana 2")
	var week_offer := a.training_offer.duplicate()
	a.choose_sponsor("cerveza_glaciar")
	a.resolve_event(true)   # la funa usa el azar
	_check(a.training_offer == week_offer, "la oferta de la semana no cambia al usar el azar en el Bloque 1")


# Quedarse con la carta la agrega; con 20 cartas hay que elegir cuál sale (y no una que deje el mazo
# fuera de las reglas de liga); no tomar ninguna también cierra el Bloque 2. Una opción por semana.
func _test_take_offer() -> void:
	var c := Career.new()
	c.setup(league, squads, "colo_colo", 31)
	var before := c.deck.size()
	var id := String(c.training_offer[1])
	_check(not c.take_offer(Career.OFFER_SIZE) and not c.take_offer(-1), "una carta fuera de la oferta no se puede tomar")
	_check(not c.take_offer(1, 0), "con espacio en el mazo no se reemplaza ninguna carta")
	_check(c.take_offer(1) and c.training == "tactical" and c.blocks_done()["block2"], "elegir una carta resuelve el Bloque 2")
	_check(c.deck.size() == before + 1 and c.deck.back() == {"id": id, "mejora": ""}, "la carta elegida se agrega al mazo")
	var built := c.build_deck()
	_check(built.size() == 13 and built[before].id == id, "la carta nueva entra al mazo del partido (antes de las firmas)")
	_check(not c.take_offer(0) and not c.decline_offer() and not c.choose_physio() and not c.upgrade_card(0, "acierto"),
			"el Bloque 2 es una opción por semana")

	var d := Career.new()
	d.setup(league, squads, "colo_colo", 31)
	_check(d.decline_offer() and d.training == "tactical" and d.blocks_done()["block2"] and d.deck == d.starter_deck(),
			"no tomar ninguna carta cierra el Bloque 2 sin cambiar el mazo")
	var dk := Career.new()
	dk.setup(league, squads, "colo_colo", 31)
	_check(dk.choose_physio() and dk.training == "physio" and not dk.take_offer(0), "la kinesiología también cierra el Bloque 2")

	# Mazo en su tope (20 con la firma de Suazo): la nueva reemplaza a una de tus cartas del DT.
	var f := Career.new()
	f.setup(league, squads, "colo_colo", 32)
	while f.deck_size() < DeckManager.DECK_MAX:
		f.deck.append({"id": "pase_al_pie", "mejora": ""})
	_check(f.deck_full() and f.build_deck().size() == DeckManager.DECK_MAX, "el mazo de prueba debería estar en el tope")
	_check(not f.take_offer(0), "con %d cartas hay que elegir cuál sale" % DeckManager.DECK_MAX)
	_check(f.replace_error(0, -1) != "" and f.replace_error(0, f.deck.size()) != "", "hay que elegir una de tus cartas del DT")
	var youth := _index_of(f, "promesa_control")
	var pass_index := _index_of(f, "pase_corto")
	_check(f.replace_error(0, youth) != "" and not f.take_offer(0, youth),
			"sacar una Promesa deja el mazo con menos de 2 Sub-21: no se puede")
	var incoming := String(f.training_offer[0])
	_check(f.replace_error(0, pass_index) == "" and f.take_offer(0, pass_index), "reemplazar un Pase corto debería valer")
	_check(f.deck_size() == DeckManager.DECK_MAX and f.deck[pass_index] == {"id": incoming, "mejora": ""} and f.training == "tactical",
			"con el mazo en su tope, la carta nueva toma el lugar de la que sale")
	_check(league.validate_deck(f.build_deck(), LEAGUE_ID)["valid"], "el mazo con el reemplazo sigue cumpliendo las reglas de liga")


# Sesión de video (D-21): +10 de acierto o −1 PA (solo si cuesta 1 o más), una mejora por carta, la
# carta construida lo refleja con "+" en el nombre (también una Promesa) y el video no suma fatiga.
func _test_video_upgrades() -> void:
	var c := Career.new()
	c.setup(league, squads, "colo_colo", 41)
	var shot := _index_of(c, "remate_simple")
	var pass_index := _index_of(c, "pase_corto")
	var youth := _index_of(c, "promesa_control")
	var base: Card = c.build_deck()[shot]
	_check(c.can_upgrade(pass_index, "acierto") and not c.can_upgrade(pass_index, "pa") and not c.upgrade_card(pass_index, "pa"),
			"un Pase corto (0 PA) solo admite la mejora de acierto")
	_check(not c.upgrade_card(shot, "turbo") and not c.upgrade_card(-1, "acierto"), "una mejora o una carta desconocida no vale")
	_check(c.upgrade_card(shot, "acierto") and c.training == "video" and c.blocks_done()["block2"], "mejorar una carta resuelve el Bloque 2")
	var up: Card = c.build_deck()[shot]
	_check(is_equal_approx(up.bonus, base.bonus + 0.10) and up.ap_cost == base.ap_cost and up.display_name == "Remate simple+",
			"la mejora de acierto suma 10 pts al bono y un + al nombre (%s, %.2f -> %.2f)" % [up.display_name, base.bonus, up.bonus])
	_check(not c.upgrade_card(youth, "acierto"), "una mejora por semana")
	var fatigue := c.fatigue
	c.choose_sponsor("telnet")
	c.resolve_event(false)
	_check(c.prepare_match()["ok"] and c.fatigue == fatigue, "la sesión de video no suma fatiga")
	c.record_match(1, 0)
	_check(not c.can_upgrade(shot, "pa") and not c.upgrade_card(shot, "pa"), "una carta ya mejorada no se mejora otra vez")
	_check(c.upgrade_card(youth, "acierto"), "la semana siguiente se puede mejorar otra carta")
	var promise: Card = c.build_deck()[youth]
	_check(promise.display_name.begins_with("Promesa: ") and promise.display_name.ends_with("+") and promise.owner_id != "",
			"una Promesa mejorada sigue siendo de un Sub-21 y lleva el + (%s)" % promise.display_name)

	var p := Career.new()
	p.setup(league, squads, "colo_colo", 42)
	var cheap_index := _index_of(p, "remate_simple")
	_check(p.upgrade_card(cheap_index, "pa"), "un Remate simple (1 PA) admite la mejora de PA")
	var cheap: Card = p.build_deck()[cheap_index]
	_check(cheap.ap_cost == base.ap_cost - 1 and is_equal_approx(cheap.bonus, base.bonus) and cheap.display_name == "Remate simple+",
			"la mejora de PA resta 1 PA y no toca el bono (%d PA)" % cheap.ap_cost)
	_check(not p.can_upgrade(cheap_index, "acierto"), "una carta admite una sola mejora")


func _index_of(c: Career, id: String) -> int:
	for i in c.deck.size():
		if c.deck[i]["id"] == id:
			return i
	return -1


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
	_check(c.choose_physio() and c.prepare_match()["ok"], "la semana con funa debería poder jugarse")

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


# T-06 (D-22): el rival de la semana N juega con su mazo de inicio + las primeras N − 1 cartas del
# crecimiento de su arquetipo, en orden, sin pasar de DeckManager.DECK_MAX con sus firmas.
func _test_rival_growth() -> void:
	var c := Career.new()
	_check(c.setup(league, squads, "colo_colo", 7), "Career no arranca: %s" % [c.load_errors])
	var growth_all: Dictionary = squads.deck_lists.get("crecimiento", {})
	for t in league.teams:
		var id := String(t["id"])
		var start_ids: Array = squads.starter_templates(id).map(func(d): return d["id"])
		var growth: Array = growth_all.get(String(t.get("archetype", "")), [])
		var firmas := squads.signature_count(id)
		for week in [1, 2, 5, 9, 10, 30]:
			c.week = week
			var ids: Array = c.rival_templates(id).map(func(d): return d["id"])
			var deck := c.build_rival_deck(id)
			var room := DeckManager.DECK_MAX - start_ids.size() - firmas
			var added := mini(week - 1, mini(growth.size(), room))
			_check(ids.slice(0, start_ids.size()) == start_ids, "%s semana %d: el rival debería conservar su mazo de inicio" % [id, week])
			_check(ids.slice(start_ids.size()) == growth.slice(0, added),
					"%s semana %d: las cartas agregadas deberían ser las primeras %d de su crecimiento, en orden (tiene %s)" % [id, week, added, ids.slice(start_ids.size())])
			_check(deck.size() == start_ids.size() + added + firmas and deck.size() <= DeckManager.DECK_MAX,
					"%s semana %d: el mazo del rival tiene %d cartas" % [id, week, deck.size()])
			_check(league.validate_deck(deck, LEAGUE_ID)["valid"], "%s semana %d: el mazo del rival no pasa validate_deck" % [id, week])
	# Semana 1 = mazo de inicio (12 con la firma); semana 5 = inicio + 4.
	c.week = 1
	_check(c.build_rival_deck("universidad_de_chile").size() == 12, "en la semana 1 el rival juega con su mazo de inicio (12)")
	c.week = 5
	_check(c.build_rival_deck("universidad_de_chile").size() == 16, "en la semana 5 el rival suma 4 cartas (16)")
	c.week = 1
	_check(c.build_rival_deck().size() == squads.build_match_deck(c.rival_id, squads.starter_templates(c.rival_id)).size(),
			"sin argumento, build_rival_deck usa el rival de la semana")


# Guardado: dos semanas completas (una carta nueva y una mejora) y otra a medias, guardar, cargar →
# mismo estado (mazo y oferta incluidos), y el azar sigue igual (el evento y la oferta de la semana
# siguiente salen iguales en la original y en la cargada).
func _test_save_round_trip() -> void:
	var c := Career.new()
	c.setup(league, squads, "colo_colo", 4321)
	c.choose_sponsor("telnet")
	c.resolve_event(true)
	_check(c.take_offer(0), "la semana 1 de la prueba de guardado toma una carta")
	_check(c.prepare_match()["ok"], "la semana 1 de la prueba de guardado debería poder jugarse")
	c.record_match(2, 1, 0.3)
	c.choose_sponsor("cerveza_glaciar")
	c.resolve_event(false)
	_check(c.upgrade_card(_index_of(c, "remate_simple"), "acierto"), "la semana 2 de la prueba de guardado mejora una carta")
	c.prepare_match()
	c.record_match(0, 1, 0.5)
	c.choose_sponsor("cerveza_glaciar")
	c.resolve_event(true)   # semana 3 a medias: evento resuelto, Bloque 2 por hacer (con su oferta)
	_check(c.save(), "save() debería escribir %s" % TEST_SAVE)
	var loaded := Career.load_saved(league, squads)
	_check(loaded != null, "la carrera guardada debería cargar: %s" % [Career.last_load_errors])
	if loaded == null:
		return
	_check_same_save(c.to_dict(), loaded.to_dict(), "tras cargar")
	_check(loaded.history.size() == 2 and typeof(loaded.history[0]["gf"]) == TYPE_INT, "el historial vuelve con enteros")
	_check(loaded.blocks_done()["block1"] and not loaded.blocks_done()["block2"], "la semana a medias sigue a medias")
	var names_a: Array = c.build_deck().map(func(x: Card) -> String: return x.display_name)
	var names_b: Array = loaded.build_deck().map(func(x: Card) -> String: return x.display_name)
	_check(loaded.deck.size() == 12 and names_a == names_b and names_b.has("Remate simple+"),
			"el mazo vuelve con la carta nueva y la mejora: %s" % [names_b])
	_check(loaded.training_offer == c.training_offer and loaded.training_offer.size() == Career.OFFER_SIZE,
			"la oferta guardada no cambia al cargar")

	# El azar sigue igual: misma semana 4, mismo resultado del evento y misma oferta en las dos.
	for x in [c, loaded]:
		x.choose_physio()
		x.prepare_match()
		x.record_match(0, 0)
		x.choose_sponsor("telnet")
		x.resolve_event(true)
	_check(c.week == 4 and loaded.week == 4, "ambas carreras deberían llegar a la semana 4")
	_check(c.event_result == loaded.event_result and c.match_mods == loaded.match_mods,
			"el evento de la semana 4 debería salir igual tras cargar: %s vs %s" % [c.event_result, loaded.event_result])
	_check(c.training_offer == loaded.training_offer, "la oferta de la semana 4 debería salir igual tras cargar")
	_check(c.rng.state == loaded.rng.state and c.rng.randi() == loaded.rng.randi(),
			"el estado del azar debería seguir igual tras cargar")


# Mismos campos, con el mismo tipo y valor, en dos to_dict().
func _check_same_save(a: Dictionary, b: Dictionary, what: String) -> void:
	_check(a.size() == b.size(), "to_dict debería tener los mismos campos %s" % what)
	for key in a:
		_check(b.has(key) and typeof(a[key]) == typeof(b[key]) and a[key] == b[key],
				"campo %s distinto %s: %s -> %s" % [key, what, a[key], b.get(key)])


# Si se cerró el juego durante el partido, la carrera vuelve al Bloque 3 con ese partido por jugar,
# sin volver a sumar la fatiga del entrenamiento.
func _test_save_pending_match() -> void:
	var c := Career.new()
	c.setup(league, squads, "universidad_catolica", 77)
	c.choose_sponsor("telnet")
	c.resolve_event(false)
	c.take_offer(0)
	c.prepare_match()
	c.save()
	var loaded := Career.load_saved(league, squads)
	_check(loaded != null and loaded.pending_match, "el partido pendiente debería seguir pendiente tras cargar")
	if loaded == null:
		return
	var fatigue := loaded.fatigue
	_check(loaded.prepare_match()["ok"] and loaded.fatigue == fatigue, "el partido pendiente se juega sin sumar fatiga otra vez")
	_check(not loaded.choose_physio() and not loaded.take_offer(1) and not loaded.upgrade_card(0, "acierto"),
			"con el partido pendiente los bloques 1 y 2 quedan cerrados")
	_check(loaded.deck == c.deck, "el partido pendiente se juega con el mazo que tenía la carta nueva")
	_check(loaded.rival_id == c.rival_id and not loaded.record_match(1, 1).is_empty() and loaded.week == 2,
			"el partido pendiente cierra la semana al jugarse")


# Un guardado v1 (antes de T-05: sin mazo propio ni oferta, y el táctico daba forma) se migra en vez
# de rechazarse: mazo de inicio del club y oferta nueva; un táctico elegido sin partido pendiente se
# vuelve a elegir con las reglas nuevas, y uno con partido pendiente se respeta.
func _test_save_v1_migration() -> void:
	var c := Career.new()
	c.setup(league, squads, "universidad_de_chile", 808)
	c.choose_sponsor("telnet")
	c.resolve_event(false)
	var v1 := c.to_dict()
	v1["version"] = 1
	v1.erase("deck")
	v1.erase("training_offer")
	v1["training"] = "tactical"
	v1["match_mods"] = {"form_bonus": 0.03}
	_write_save(JSON.stringify(v1))
	var loaded := Career.load_saved(league, squads)
	_check(loaded != null, "un guardado v1 debería migrarse: %s" % [Career.last_load_errors])
	if loaded == null:
		return
	_check(loaded.deck == loaded.starter_deck() and loaded.build_deck().size() == 12, "el guardado v1 arranca con el mazo de inicio del club")
	var offers: Dictionary = squads.deck_lists["ofertas"]
	_check(loaded.training_offer.size() == Career.OFFER_SIZE and loaded.training_offer.all(func(id): return offers["general"].has(id) \
			or offers["Contragolpe"].has(id)), "el guardado v1 recibe una oferta nueva: %s" % [loaded.training_offer])
	_check(loaded.training == "" and loaded.block2_open() and not loaded.match_mods.has("form_bonus"),
			"un táctico v1 sin partido pendiente se vuelve a elegir y sin la forma de antes")
	_check(loaded.sponsor_id == "telnet" and loaded.blocks_done()["block1"] and loaded.week == 1, "el resto de la semana se conserva")
	_check(loaded.save(), "la carrera migrada debería poder guardarse")
	var again := Career.load_saved(league, squads)
	_check(again != null and int(again.to_dict()["version"]) == Career.SAVE_VERSION, "la carrera migrada se guarda como v%d" % Career.SAVE_VERSION)
	if again != null:
		_check_same_save(loaded.to_dict(), again.to_dict(), "tras guardar la carrera migrada")

	v1["pending_match"] = true   # se cerró el juego durante el partido: el Bloque 2 ya se pagó en fatiga
	_write_save(JSON.stringify(v1))
	var pending := Career.load_saved(league, squads)
	_check(pending != null and pending.pending_match and pending.training == "tactical" and pending.prepare_match()["ok"],
			"un guardado v1 con partido pendiente se juega igual")
	v1["pending_match"] = false
	v1["training"] = "physio"
	_write_save(JSON.stringify(v1))
	var physio := Career.load_saved(league, squads)
	_check(physio != null and physio.training == "physio", "un guardado v1 con kinesiología la conserva")


func _write_save(text: String) -> void:
	var f := FileAccess.open(TEST_SAVE, FileAccess.WRITE)
	f.store_string(text)
	f.close()


# Errores de carga: devuelven null con el motivo en Career.last_load_errors, sin errores de script.
func _test_save_errors() -> void:
	if FileAccess.file_exists(TEST_SAVE):
		DirAccess.remove_absolute(TEST_SAVE)
	_check(Career.load_saved(league, squads) == null and not Career.last_load_errors.is_empty(),
			"sin archivo de guardado la carga debería devolver null con motivo")

	var good := Career.new()
	good.setup(league, squads, "colo_colo", 5)
	var cases := {"JSON roto": "{\"version\": 2, \"team_id\": "}
	var other_version := good.to_dict()
	other_version["version"] = 99
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
	var no_deck := good.to_dict()
	no_deck.erase("deck")
	cases["v2 sin mazo"] = JSON.stringify(no_deck)
	var unknown_card := good.to_dict()
	unknown_card["deck"][0] = {"id": "carta_inventada", "mejora": ""}
	cases["carta desconocida en el mazo"] = JSON.stringify(unknown_card)
	var bad_upgrade := good.to_dict()
	bad_upgrade["deck"][0] = {"id": "pase_corto", "mejora": "pa"}   # 0 PA: no admite la mejora de PA
	cases["mejora imposible"] = JSON.stringify(bad_upgrade)
	var unknown_upgrade := good.to_dict()
	unknown_upgrade["deck"][0] = {"id": "pase_corto", "mejora": "turbo"}
	cases["mejora desconocida"] = JSON.stringify(unknown_upgrade)
	var tiny_deck := good.to_dict()
	tiny_deck["deck"] = []
	cases["mazo vacío"] = JSON.stringify(tiny_deck)
	var bad_offer := good.to_dict()
	bad_offer["training_offer"] = ["carta_inventada"]
	cases["oferta con una carta desconocida"] = JSON.stringify(bad_offer)
	for name in cases:
		_write_save(cases[name])
		var loaded := Career.load_saved(league, squads)
		_check(loaded == null and not Career.last_load_errors.is_empty(),
				"guardado con %s: la carga debería devolver null con motivo" % name)
	DirAccess.remove_absolute(TEST_SAVE)
