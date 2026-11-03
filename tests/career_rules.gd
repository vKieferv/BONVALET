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
	_test_event_effects()
	_test_event_match_effects()
	_test_promises()
	_test_event_deck()
	_test_event_conditions()
	_test_branch_returns()
	_test_bautizazo_same()
	_test_save_events()
	_test_save_v2_migration()
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


# El Bautizazo (el evento de antes de T-14) como evento de la semana: aceptar = opción 0, negarse = 1.
# Las pruebas de antes lo fuerzan para seguir midiendo lo mismo.
func _bautizazo(c: Career, accept: bool) -> Dictionary:
	c.set_week_event("bautizazo")
	return c.resolve_event(0 if accept else 1)


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
	var ev := _bautizazo(c, true)
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
				_bautizazo(c, false)
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
		_bautizazo(x, true)
		x.take_offer(0)
		x.prepare_match()
		x.record_match(2, 0)
	_check(a.training_offer == b.training_offer and a.deck == b.deck, "misma semilla y mismas decisiones: misma oferta en la semana 2")
	var week_offer := a.training_offer.duplicate()
	a.choose_sponsor("cerveza_glaciar")
	_bautizazo(a, true)   # la funa usa el azar
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
	_bautizazo(c, false)
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
		if _bautizazo(t, true)["funa"]:
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
	_bautizazo(c, true)
	_check(c.take_offer(0), "la semana 1 de la prueba de guardado toma una carta")
	_check(c.prepare_match()["ok"], "la semana 1 de la prueba de guardado debería poder jugarse")
	c.record_match(2, 1, 0.3)
	c.choose_sponsor("cerveza_glaciar")
	_bautizazo(c, false)
	_check(c.upgrade_card(_index_of(c, "remate_simple"), "acierto"), "la semana 2 de la prueba de guardado mejora una carta")
	c.prepare_match()
	c.record_match(0, 1, 0.5)
	c.choose_sponsor("cerveza_glaciar")
	_bautizazo(c, true)   # semana 3 a medias: evento resuelto, Bloque 2 por hacer (con su oferta)
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
		_bautizazo(x, true)
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
	_bautizazo(c, false)
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
	_bautizazo(c, false)
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


# ------------------------------------------------------------------ Eventos de la semana (T-14)

func _new_career(seed: int, team: String = "colo_colo") -> Career:
	var c := Career.new()
	c.setup(league, squads, team, seed)
	return c


func _apply(c: Career, effects: Array) -> Dictionary:
	var out := {"funa": false, "funado_id": "", "lines": []}
	c._apply_effects(effects, out)
	return out


# Un efecto de cada tipo de la tabla 1 de docs/eventos.md, aplicado sobre la carrera.
func _test_event_effects() -> void:
	var c := _new_career(11)
	c.choose_sponsor("telnet")
	var pop := c.popularity
	var disc := c.discipline
	var budget := c.budget
	var fatigue := c.fatigue
	_apply(c, [{"tipo": "popularidad", "valor": 5}, {"tipo": "disciplina", "valor": -3}, {"tipo": "presupuesto", "valor": -30},
		{"tipo": "fatiga", "valor": 15}])
	_check(c.popularity == pop + 5 and c.discipline == disc - 3, "popularidad y disciplina se suman")
	_check(is_equal_approx(c.budget, budget - 30.0) and is_equal_approx(c.fatigue, fatigue + 15.0), "presupuesto y fatiga se suman")
	_apply(c, [{"tipo": "arranque", "valor": 0.03}, {"tipo": "arranque", "valor": -0.05, "momentos": 3}])
	_check(is_equal_approx(c.match_mods["opening_bonus"], -0.02) and c.match_mods["opening_moments"] == 3,
			"dos arranques se suman (también negativo) y valen en los Momentos del más largo: %s" % [c.match_mods])
	_apply(c, [{"tipo": "rival_motivado", "valor": 0.05}])
	_check(is_equal_approx(c.match_mods["rival_bonus"], 0.05) and c.match_mods["rival_moments"] == 2, "el rival motivado queda para el partido")

	var funa := _apply(c, [{"tipo": "funa", "chance": 1.0, "disciplina": -10, "extra": 0.5, "clausula": true, "quien": "capitan"}])
	_check(funa["funa"] and c.match_mods["funado_id"] == c.event_names["capitan"] and c.sponsor_week_lost,
			"una funa segura: el capitán funado y Telnet (cláusula) no paga")
	var safe := _new_career(11)
	var none := _apply(safe, [{"tipo": "funa", "chance": 0.0, "quien": "capitan"}])
	_check(not none["funa"] and not safe.match_mods.has("funado_id"), "una funa con 0% nunca pasa")

	var d := _new_career(12)
	_apply(d, [{"tipo": "desgaste", "quien": "arquero", "extra": 0.5}])
	var gk := String(d.event_names.get("arquero", ""))
	_check(gk != "" and d.squads.find_player("colo_colo", gk)["role"] == "POR" and is_equal_approx(d.match_mods["owner_mults"][gk], 1.5),
			"el desgaste cae sobre el arquero titular")

	var t := _new_career(13)
	var size := t.build_deck().size()
	_apply(t, [{"tipo": "carta_temporal", "carta": "promesa_control", "quien": "juvenil"}])
	_check(t.build_deck().size() == size + 1 and t.deck.size() == 11, "una carta temporal buena entra al mazo del partido, no a tu mazo")
	_check(t.prepare_match()["errors"].filter(func(e): return String(e).contains("mazo")).is_empty(), "el mazo con la carta temporal sigue siendo válido")
	t.pending_match = true
	t.record_match(1, 0)
	_check(t.build_deck().size() == size and t.temp_cards.is_empty(), "la carta temporal dura una semana")

	var n := _new_career(14)
	_apply(n, [{"tipo": "carta_nueva", "carta": "remate_primera"}])
	_check(n.deck.size() == 12 and n.deck.back()["id"] == "remate_primera", "una carta nueva entra a tu mazo")

	var s := _new_career(15)
	s.choose_sponsor("cerveza_glaciar")
	_apply(s, [{"tipo": "sin_pago_sponsor"}])
	_check(not s.sponsor_week_lost, "sin cláusula de conducta el sponsor paga igual")
	s.choose_sponsor("telnet")
	_apply(s, [{"tipo": "sin_pago_sponsor"}])
	_check(s.sponsor_week_lost, "con cláusula de conducta, el sponsor no paga la semana")

	var a := _new_career(16)
	var pa := a.popularity
	_apply(a, [{"tipo": "azar", "chance": 1.0, "efectos": [{"tipo": "popularidad", "valor": 4}], "si_no": [{"tipo": "popularidad", "valor": -9}]},
		{"tipo": "azar", "chance": 0.0, "efectos": [{"tipo": "popularidad", "valor": 4}], "si_no": [{"tipo": "popularidad", "valor": -1}]}])
	_check(a.popularity == pa + 3, "el azar aplica sus efectos o los de si_no (%d -> %d)" % [pa, a.popularity])

	var v := _new_career(17)
	_apply(v, [{"tipo": "vender", "quien": "nueve"}])
	var nine_id := String(v.event_names.get("nueve", ""))
	var sig := v.squads.signature_card_for(v.squads.find_player("colo_colo", nine_id))
	_check(nine_id != "" and not sig.is_empty(), "tu 9 es un delantero titular con carta firma (%s)" % nine_id)
	_check(not v.build_deck().any(func(x: Card): return x.owner_id == nine_id and x.id == String(sig.get("id", ""))),
			"vender a tu 9 saca su carta firma del mazo")
	_check(v.deck_size() == v.build_deck().size(), "deck_size cuenta sin la firma del vendido (%d vs %d)" % [v.deck_size(), v.build_deck().size()])

	var r := _new_career(18)
	_apply(r, [{"tipo": "rama", "evento": "c7_fotos", "semanas": 2}, {"tipo": "rama", "evento": "c5_multa", "semanas": 1, "chance": 0.0}])
	_check(r.event_marks.size() == 1 and r.event_marks[0]["evento"] == "c7_fotos" and r.event_marks[0]["semana"] == 3,
			"una rama segura deja su marca para la semana 3 y una con 0%% no: %s" % [r.event_marks])
	for e in Career.EFFECTS:
		var probe := {"tipo": e, "quien": "nueve", "carta": "nervios", "evento": "c7_fotos"}
		_check(not c._effect_line(probe).is_empty() and not String(c._badge(probe)["texto"]).is_empty(),
				"el efecto %s debería tener su texto y su timbre" % e)


# Lo que llega al partido: arranque negativo, rival motivado y Nervios (configure_match y
# configure_rival_match, sin tocar el motor).
func _test_event_match_effects() -> void:
	var c := _new_career(21)
	_apply(c, [{"tipo": "arranque", "valor": -0.03}, {"tipo": "rival_motivado", "valor": 0.05},
		{"tipo": "carta_temporal", "carta": "nervios", "quien": "nueve"}])
	var rng := RandomNumberGenerator.new()
	rng.seed = 3
	var player := PlayerStats.new()
	var deck := c.build_deck()
	var e := MatchEngine.new(player, DeckManager.new(deck, [], rng), rng, 0.15)
	c.configure_match(e, player)
	_check(is_equal_approx(e.opening_bonus, -0.03) and e.opening_moments == 2, "el arranque negativo llega al partido")
	var nervios: Array = e.deck.active.filter(func(x: Card): return x.type == Card.Type.PENALTY)
	_check(nervios.size() == 1 and nervios[0].display_name.begins_with("Nervios: "), "la carta de Nervios entra al mazo del partido con su nombre")
	_check(e.deck.active.size() == c.build_deck().size() + 1, "los Nervios no cuentan al validar el mazo, solo entran al partido")
	e.start()
	var items: Array = e.chance_breakdown(deck[0])
	_check(items.any(func(i): return i["label"] == "Apertura" and is_equal_approx(i["value"], -0.03)), "la apertura negativa resta en el desglose")

	var profile := league.profile_for_team(league.get_team(c.rival_id))
	var rival := MatchEngine.new(PlayerStats.new(), DeckManager.new([], [], rng), rng, 0.15)
	profile.configure_engine(rival)
	var before := rival.opening_bonus
	c.configure_rival_match(rival)
	_check(is_equal_approx(rival.opening_bonus, before + 0.05) and rival.opening_moments >= 2, "el rival motivado suma a la apertura de su perfil")
	var calm := _new_career(21)
	var r2 := MatchEngine.new(PlayerStats.new(), DeckManager.new([], [], rng), rng, 0.15)
	profile.configure_engine(r2)
	calm.configure_rival_match(r2)
	_check(is_equal_approx(r2.opening_bonus, before), "sin rival motivado su apertura no cambia")


# C2 «Ganamos seguro»: si ganas, popularidad +8; si no, −8 (además de lo de siempre por el resultado).
func _test_promises() -> void:
	var m: Dictionary = _new_career(1).data["match"]
	for won in [true, false]:
		var c := _new_career(31)
		c.choose_sponsor("telnet")
		_check(c.set_week_event("c2_ganan_domingo"), "C2 debería poder ser el evento de la semana")
		c.resolve_event(0)
		_check(c.promises.size() == 1, "prometer ganar deja una promesa pendiente")
		c.choose_physio()
		_check(c.prepare_match()["ok"], "la semana de la promesa se juega")
		var pop := c.popularity
		var entry := c.record_match(2 if won else 0, 1)
		var expected: int = pop + (8 + int(m["popularity_win"]) if won else -8 + int(m["popularity_loss"]))
		_check(c.popularity == clampi(expected, 0, 100), "promesa %s: popularidad %d -> %d (se esperaba %d)" % [
			"cumplida" if won else "rota", pop, c.popularity, expected])
		_check(c.promises.is_empty() and entry.get("promesas", []).size() > 0, "la promesa se cobra una vez y queda en el historial")


# El mazo de la temporada: no repite hasta que salen todos, cambia con la semilla y deja afuera los
# eventos que solo llegan por una rama.
func _test_event_deck() -> void:
	var deck_ids: Array = []
	for ev in _new_career(1).events["eventos"]:
		if not ev.get("solo_rama", false):
			deck_ids.append(ev["id"])
	var orders := {}
	for seed in [41, 42, 43]:
		var c := _new_career(seed)
		var seen: Array = []
		for w in 20:
			var ev := c.week_event()
			_check(not ev.is_empty(), "semilla %d, semana %d: siempre hay evento" % [seed, c.week])
			if not ev.get("solo_rama", false):
				_check(not seen.has(c.event_id), "semilla %d: %s se repite en la semana %d antes de salir todos" % [seed, c.event_id, c.week])
				seen.append(c.event_id)
			c.choose_sponsor("cerveza_glaciar")
			c.resolve_event(c.event_options().size() - 1)
			c.choose_physio()
			c.prepare_match()
			c.record_match(1, 1)
		orders[",".join(seen.slice(0, 6))] = true
		_check(seen.all(func(id): return deck_ids.has(id)), "semilla %d: solo salen eventos del mazo" % seed)
	_check(orders.size() == 3, "el orden de los eventos cambia con la semilla")
	var all := _new_career(44)._shuffled_events()
	all.sort()
	deck_ids.sort()
	_check(all == deck_ids and deck_ids.size() == 25, "el mazo trae los 25 eventos sin rama (%d)" % deck_ids.size())


# Las condiciones: H4 (mural) solo después de una derrota y H2 (banderazo) solo antes de un clásico;
# cuando se cumplen, salen antes que el resto del mazo.
func _test_event_conditions() -> void:
	var c := _new_career(51)
	c.history = [{"week": 1, "rival_id": "x", "gf": 0, "ga": 2, "income": 0, "fatigue_gained": 0}]
	c.event_deck = ["h3_supermercado", "h4_mural"]
	_check(c._take_from_deck() == "h4_mural", "tras una derrota, el mural sale primero")
	c.history[0]["gf"] = 3
	c.event_deck = ["h4_mural", "h3_supermercado"]
	_check(c._take_from_deck() == "h3_supermercado" and c.event_deck == ["h4_mural"], "sin derrota, el mural espera")
	_check(c._take_from_deck() == "", "si solo queda un evento cuya condición no se cumple, no sale")
	_check(c.is_clasico("colo_colo", "universidad_de_chile") and not c.is_clasico("colo_colo", "everton"), "el clásico sale de los pares de clasicos")
	c.rival_id = "universidad_de_chile"
	c.event_deck = ["h3_supermercado", "h2_banderazo"]
	_check(c._take_from_deck() == "h2_banderazo", "antes del clásico, el banderazo sale primero")


# V2 «Prometer para fin de mes»: el 9 vuelve a las 4 semanas a pedir salir, con el mismo nombre.
func _test_branch_returns() -> void:
	var c := _new_career(61)
	_check(c.set_week_event("v2_aumento"), "V2 debería poder ser el evento de la semana")
	var nine := c.target_name("nueve")
	_check(nine != "" and c.event_title().contains(nine), "el título nombra a tu 9 del plantel real (%s)" % c.event_title())
	c.resolve_event(2)
	_check(c.event_marks.size() == 1, "prometer deja la marca de la rama")
	for w in 4:
		_check(c.event_id != "v2_pide_salir", "la rama no vuelve antes de tiempo (semana %d)" % c.week)
		c.choose_sponsor("cerveza_glaciar")
		if c.event_result.is_empty():
			c.resolve_event(c.event_options().size() - 1)
		c.choose_physio()
		c.prepare_match()
		c.record_match(1, 0)
	_check(c.week == 5 and c.event_id == "v2_pide_salir", "a las 4 semanas vuelve el 9 a pedir salir (semana %d: %s)" % [c.week, c.event_id])
	_check(c.target_name("nueve") == nine and c.event_title().contains(nine), "la rama hereda el nombre del 9")
	_check(c.event_marks.is_empty(), "la marca se consume al volver")
	c.resolve_event(0)
	_check(c.sold.has(c.event_names["nueve"]), "venderlo lo deja en la lista de vendidos")


# El Bautizazo reescrito en el formato genérico da lo mismo que antes: aceptar = +5% en M1-2,
# popularidad +5 y 30% de funa (disciplina −10, +50% de desgaste, Telnet no paga); negarse = disciplina +2,
# popularidad −2.
func _test_bautizazo_same() -> void:
	var funas := 0
	for seed in range(1, 201):
		var c := _new_career(seed)
		c.choose_sponsor("telnet")
		var pop := c.popularity
		var disc := c.discipline
		var res := _bautizazo(c, true)
		_check(is_equal_approx(c.match_mods["opening_bonus"], 0.05) and c.match_mods["opening_moments"] == 2 and c.popularity == pop + 5,
				"aceptar el Bautizazo: +5% en M1-2 y popularidad +5")
		if res["funa"]:
			funas += 1
			_check(c.discipline == disc - 10 and is_equal_approx(c.match_mods["funado_stamina_mult"], 1.5) and c.sponsor_week_lost,
					"la funa del Bautizazo: disciplina −10, +50% de desgaste y Telnet no paga")
		else:
			_check(res["sello"] == "PASÓ PIOLA" and not c.sponsor_week_lost, "sin funa, el Bautizazo pasa piola")
	_check(funas > 35 and funas < 85, "la funa del Bautizazo sale cerca del 30%% (%d de 200)" % funas)
	var d := _new_career(7)
	var pop := d.popularity
	var disc := d.discipline
	var res := _bautizazo(d, false)
	_check(d.discipline == disc + 2 and d.popularity == pop - 2 and res["sello"] == "CONCENTRADOS" and d.match_mods.is_empty(),
			"negarse al Bautizazo: disciplina +2, popularidad −2")


# Guardar y cargar a mitad de temporada, con una rama, una promesa y una carta temporal pendientes:
# todo vuelve igual y la rama vuelve en su semana en las dos carreras.
func _test_save_events() -> void:
	var c := _new_career(71)
	c.choose_sponsor("telnet")
	c.set_week_event("c7_actriz")
	c.resolve_event(2)   # abandonar la sala: El Chisme vuelve en 2 semanas
	c.choose_physio()
	c.prepare_match()
	c.record_match(1, 1)
	c.set_week_event("c2_ganan_domingo")
	c.resolve_event(0)   # promesa pendiente
	c.temp_cards.append({"carta": "nervios", "quien": String(c.squads.lineup_ids("colo_colo")[9])})
	_check(c.save(), "save() con eventos pendientes")
	var loaded := Career.load_saved(league, squads)
	_check(loaded != null, "la carrera con ramas pendientes debería cargar: %s" % [Career.last_load_errors])
	if loaded == null:
		return
	_check_same_save(c.to_dict(), loaded.to_dict(), "con eventos pendientes")
	_check(int(loaded.to_dict()["version"]) == 3 and typeof(loaded.event_marks[0]["semana"]) == TYPE_INT, "guardado v3 con la semana de la rama entera")
	for x in [c, loaded]:
		x.choose_physio()
		x.prepare_match()
		x.record_match(2, 0)
	_check(c.event_id == "c7_fotos" and loaded.event_id == "c7_fotos", "la rama vuelve en la semana 3 en las dos (%s / %s)" % [c.event_id, loaded.event_id])
	_check(c.popularity == loaded.popularity and c.event_deck == loaded.event_deck, "la promesa se cobra igual y el mazo sigue igual")

	var cases := {}
	var bad_event := c.to_dict()
	bad_event["event_id"] = "evento_inventado"
	cases["evento desconocido"] = bad_event
	var bad_mark := c.to_dict()
	bad_mark["event_marks"] = [{"evento": "evento_inventado", "semana": 4, "nombres": {}}]
	cases["rama a un evento que no existe"] = bad_mark
	var bad_card := c.to_dict()
	bad_card["temp_cards"] = [{"carta": "carta_inventada", "quien": ""}]
	cases["carta temporal desconocida"] = bad_card
	var no_deck := c.to_dict()
	no_deck.erase("event_deck")
	cases["v3 sin mazo de eventos"] = no_deck
	for name in cases:
		_write_save(JSON.stringify(cases[name]))
		_check(Career.load_saved(league, squads) == null and not Career.last_load_errors.is_empty(),
				"guardado con %s: la carga debería devolver null con motivo" % name)


# Un guardado v2 (antes de T-14: un solo evento, resultado con "accepted") se migra con el Bautizazo.
func _test_save_v2_migration() -> void:
	var c := _new_career(81)
	c.choose_sponsor("telnet")
	_bautizazo(c, true)
	var v2 := c.to_dict()
	v2["version"] = 2
	for k in Career.V2_MISSING:
		v2.erase(k)
	v2["event_result"] = {"accepted": true, "funa": false, "funado_id": "", "lines": ["La fiesta prende."]}
	_write_save(JSON.stringify(v2))
	var loaded := Career.load_saved(league, squads)
	_check(loaded != null, "un guardado v2 debería migrarse: %s" % [Career.last_load_errors])
	if loaded == null:
		return
	_check(loaded.event_id == "bautizazo" and int(loaded.event_result["option"]) == 0 and loaded.event_result["sello"] == "PASÓ PIOLA",
			"el v2 vuelve con el Bautizazo aceptado: %s" % [loaded.event_result])
	_check(loaded.blocks_done()["block1"] and loaded.event_marks.is_empty() and loaded.promises.is_empty(), "el v2 sigue con el Bloque 1 hecho")
	loaded.choose_physio()
	loaded.prepare_match()
	loaded.record_match(1, 0)
	_check(not loaded.week_event().is_empty() and loaded.event_deck.size() == 24, "tras el v2 el mazo de eventos se baraja en la semana siguiente")
