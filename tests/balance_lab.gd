# Laboratorio de balance: la matriz neutral de sim.gd (mismos clubes, semillas y DuelRunner) con
# variantes aplicadas desde afuera del motor, para separar el efecto de cada cambio y probar palancas
# antes de tocar constantes. La variante sin cambios reproduce exacto la matriz de inicio de sim.gd
# (mazo estándar de data/decks.json con la carta de rasgo de cada club y las firmas de sus titulares).
#
# Uso (desde la raíz del repo):
#   godot --headless --path . -s res://tests/balance_lab.gd -- --variants=res://tests/lab/ejemplo.json [--per-pair=400]
# Sin --variants corre solo la línea base. Guía y formato de variantes: .claude/skills/balance-lab/SKILL.md
#
# Claves de una variante (todas opcionales salvo "name"):
#   no_hold: true                    desactiva Aguantar el Balón
#   steps: 2 | 3                     fija las jugadas que pide cada Momento
#   steps3_p: 0.0-1.0                probabilidad de que un Momento pida 3 jugadas (si no, 2)
#   diff_add: 0.03                   suma puntos de dificultad a los ataques (0.03 = +3 pts)
#   stamina_mult: 0.85               multiplica el desgaste de todas las cartas (= STAMINA_SCALE × 0.85)
#   cards: {"id": {"ap": 3, "bonus": 0.34, "stamina": 5}}   cambia campos de cartas por id;
#                                    "@sello" = la carta firma genérica "Sello de [figura]"
#   steps_by_archetype: {"Tiki-Taka": [3, 4], "Catenaccio": 2}   jugadas por Momento según el
#                                    arquetipo del que ataca (número fijo o [mín, máx] al azar)
#   profile: {"Kamikaze": {"late_injury_mult": 2.0}}   cambia campos del BotProfile de un arquetipo
#                                    (IA y lo que configure_engine pasa al motor)
#   cards_for: {"colo_colo": {"remate_primera": {"count": 2}}}   cambia cartas de un solo club (por
#                                    id; "count" agrega o quita copias); sirve para medir cuánto vale
#                                    ganar, quitar o mejorar una carta
#   player_for: {"colo_colo": {"vision": 75}}   atributos de PlayerStats de un club (vision = tamaño
#                                    de mano, tecnica = acierto base, stamina = tope de estamina)
# Mazos (por defecto, los de data/decks.json, como el juego):
#   card_defs: {"remate_simple": {...carta completa...}}   cartas nuevas o redefinidas (se suman al
#                                    catálogo de cards.json, por id)
#   deck: ["pase_corto", "pase_corto", ..., "@rasgo"]   reemplaza el mazo estándar de todos los clubes
#                                    (una entrada por copia); las firmas de los titulares y la asignación
#                                    de canteranos siguen igual. "clasico" = el mazo de 19 de cards.json
#                                    (por "count"), el de antes de T-04, sin rasgos ni crecimiento
#   rasgos: {"Tiki-Taka": "toque_toque", ...}   cambia la carta de rasgo ("@rasgo") de un arquetipo
#   picks: 4                         suma las primeras N cartas del crecimiento de cada arquetipo (4 =
#                                    mitad de temporada, 8 = final, como las etapas de sim.gd)
#   pick_pools: {"Tiki-Taka": [ids en orden]}   cambia la lista de crecimiento de un arquetipo
# Un elemento {"defaults": {...}} en la lista se aplica a todas las variantes que lo siguen (las
# claves de la variante mandan; los diccionarios se mezclan).
# Además de la línea total, imprime una línea por club: goles a favor-en contra, % de partidos con
# lesión, ataques que le cortaron por partido, tamaño del mazo y constructibilidad (% de inicios de
# Momento con plan de gol, estamina llena, con su propio perfil).
# Las constantes del motor (INJURY_CHANCE_*, HOLD_*, AP_BY_POSTURE...) no se pueden variar desde
# aquí: se cambian en match_engine.gd, se corre el laboratorio y se restauran.
extends SceneTree

const BASE_DIFFICULTY := 0.15
const DEFAULT_PER_PAIR := 400
const CONSTRUCT_SAMPLES := 600


func _init() -> void:
	var per_pair := DEFAULT_PER_PAIR
	var variants: Array = [{"name": "línea base"}]
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--per-pair="):
			per_pair = maxi(1, int(arg.get_slice("=", 1)))
		elif arg.begins_with("--variants="):
			var path := arg.get_slice("=", 1)
			var f := FileAccess.open(path, FileAccess.READ)
			if f == null:
				print("No se pudo abrir %s" % path)
				quit(1)
				return
			var parsed = JSON.parse_string(f.get_as_text())
			if not parsed is Array:
				print("%s debe ser una lista de variantes" % path)
				quit(1)
				return
			variants = []
			var defaults := {}
			for item in parsed:
				if (item as Dictionary).has("defaults"):
					defaults = item["defaults"]
				else:
					variants.append(_merge(defaults, item))

	var tpl := CardDB.load_templates(CardDB.CARDS_PATH)   # mazo clásico, para "deck": "clasico"
	var league := LeagueManager.new()
	if not league.load_all():
		print("No se pudo cargar la liga: %s" % [league.load_errors])
		quit(1)
		return
	var squads := SquadManager.new()
	squads.load_all(league)
	var clubs: Array = ["colo_colo"]   # misma selección que la matriz de sim.gd
	var seen := {"Tiki-Taka": true}
	for t in league.get_teams("Primera A"):
		if not t.get("suspended", false) and not seen.has(t["archetype"]):
			seen[t["archetype"]] = true
			clubs.append(t["id"])

	print("Laboratorio de balance · %d clubes · %d partidos por cruce · objetivo 2.3-2.6 goles, 2-5%% lesiones" % [clubs.size(), per_pair])
	for v in variants:
		var t0 := Time.get_ticks_msec()
		var acc := {"goals": 0, "matches": 0, "injuries": 0, "m1": 0, "t1": 0, "m2": 0, "t2": 0, "holds": 0, "holds_lost": 0}
		var per_club := {}   # id -> {gf, ga, inj, cut, n}
		for id in clubs:
			per_club[id] = {"gf": 0, "ga": 0, "inj": 0, "cut": 0, "n": 0}
		var hooks := _hooks(v)
		var deck_size := {}
		var construct := {}
		for id in clubs:
			var own := _side(league, squads, tpl, id, clubs[0] if id != clubs[0] else clubs[1], v)
			deck_size[id] = (own["templates"] as Array).size()
			construct[id] = _constructibility(own, v)
		for i in clubs.size():
			for j in range(i + 1, clubs.size()):
				var r := DuelRunner.run(_side(league, squads, tpl, clubs[i], clubs[j], v),
						_side(league, squads, tpl, clubs[j], clubs[i], v), per_pair, hooks)
				var ca: Dictionary = per_club[clubs[i]]
				var cb: Dictionary = per_club[clubs[j]]
				ca["gf"] += r["goals_a"]; ca["ga"] += r["goals_b"]; ca["inj"] += r["injuries_a"]; ca["cut"] += r["cuts_by_b"]; ca["n"] += per_pair
				cb["gf"] += r["goals_b"]; cb["ga"] += r["goals_a"]; cb["inj"] += r["injuries_b"]; cb["cut"] += r["cuts_by_a"]; cb["n"] += per_pair
				acc["goals"] += r["goals_a"] + r["goals_b"]
				acc["matches"] += per_pair
				acc["injuries"] += r["injuries"]
				acc["m1"] += r["moments_1h"]
				acc["t1"] += r["tired_1h"]
				acc["m2"] += r["moments_2h"]
				acc["t2"] += r["tired_2h"]
				acc["holds"] += r["holds"]
				acc["holds_lost"] += r["holds_lost"]
		var n := float(acc["matches"])
		var moments := float(acc["m1"] + acc["m2"])
		print("%-44s | goles %.2f | lesiones %.1f%% | cansancio 1T %d%% / 2T %d%% | Momentos/equipo %.2f | gol/Momento %d%% | aguantar/equipo %.2f (%.2f robados) | %d s" % [
			v.get("name", "?"), acc["goals"] / n, 100.0 * acc["injuries"] / (2.0 * n),
			roundi(100.0 * acc["t1"] / maxf(1.0, acc["m1"])), roundi(100.0 * acc["t2"] / maxf(1.0, acc["m2"])),
			moments / (2.0 * n), roundi(100.0 * acc["goals"] / maxf(1.0, moments)),
			acc["holds"] / (2.0 * n), acc["holds_lost"] / (2.0 * n), (Time.get_ticks_msec() - t0) / 1000])
		var cells: Array = []
		for id in clubs:
			var c: Dictionary = per_club[id]
			var team := league.get_team(id)
			var cn := float(c["n"])
			cells.append("%s (%s) %.2f-%.2f les %d%% cortes %.1f mazo %d constr %d%%" % [team["short_name"], String(team["archetype"]).left(5),
				c["gf"] / cn, c["ga"] / cn, roundi(100.0 * c["inj"] / cn), c["cut"] / cn, deck_size[id], construct[id]])
		print("    " + " · ".join(cells))
	quit()


# Mezcla superficial: las claves de b mandan; si ambas son diccionarios, se combinan.
func _merge(a: Dictionary, b: Dictionary) -> Dictionary:
	var out := a.duplicate(true)
	for k in b:
		if out.has(k) and out[k] is Dictionary and b[k] is Dictionary:
			var inner: Dictionary = (out[k] as Dictionary).duplicate(true)
			inner.merge(b[k], true)
			out[k] = inner
		else:
			out[k] = b[k]
	return out


# Cartas del DT de un club: las de data/decks.json para su arquetipo (mazo estándar con su carta de
# rasgo + las primeras "picks" de su crecimiento, con el mismo tope de 20 que el juego) con los cambios
# de la variante ("deck", "rasgos", "pick_pools", "card_defs"), o el mazo clásico con "deck": "clasico".
# Las cartas desconocidas se avisan y se omiten.
func _club_deck(tpl: Array, squads: SquadManager, v: Dictionary, id: String, arch: String) -> Array:
	if v.get("deck") is String and v["deck"] == "clasico":
		return tpl
	var catalog := CardDB.load_catalog()
	for cid in v.get("card_defs", {}):
		var def: Dictionary = (v["card_defs"][cid] as Dictionary).duplicate(true)
		def["id"] = cid
		catalog[cid] = def
	var decks := CardDB.load_decks()
	if v.get("deck") is Array:
		decks["estandar"] = v["deck"]
	(decks["rasgos"] as Dictionary).merge(v.get("rasgos", {}), true)
	(decks["crecimiento"] as Dictionary).merge(v.get("pick_pools", {}), true)
	var named: Array = (decks["estandar"] as Array).filter(func(cid): return cid != CardDB.RASGO)
	if (decks["estandar"] as Array).has(CardDB.RASGO) and decks["rasgos"].has(arch):
		named.append(decks["rasgos"][arch])
	named.append_array(decks["crecimiento"].get(arch, []))
	for cid in named:
		if not catalog.has(cid):
			print("  AVISO: carta desconocida '%s' (se omite)" % cid)
	var starter := CardDB.archetype_templates(catalog, decks, arch, 0)
	var room := DeckManager.DECK_MAX - starter.size() - squads.signature_count(id)
	return CardDB.archetype_templates(catalog, decks, arch, clampi(int(v.get("picks", 0)), 0, maxi(0, room)))


# % de inicios de Momento con plan de gol para un club (estamina llena, su perfil y su postura).
func _constructibility(side: Dictionary, v: Dictionary) -> int:
	var profile: BotProfile = side["profile"]
	var attrs: Dictionary = v.get("player_for", {}).get(side["id"], {})
	var ok := 0
	for i in CONSTRUCT_SAMPLES:
		var rng := RandomNumberGenerator.new()
		rng.seed = 100000 + i
		var player := PlayerStats.new()
		player.lineup.assign(side["lineup"])
		for attr in attrs:
			player.set(attr, attrs[attr])
		var e := MatchEngine.new(player, DeckManager.new(CardDB.build_deck(side["templates"]), [], rng), rng,
				side["attack_difficulty"])
		profile.configure_engine(e)
		e.start()
		e.begin_moment()
		if not e.moment_over and not CoachBot.best_plan(e, profile).is_empty():
			ok += 1
	return roundi(100.0 * ok / CONSTRUCT_SAMPLES)


func _side(league: LeagueManager, squads: SquadManager, tpl: Array, id: String, opp_id: String, v: Dictionary) -> Dictionary:
	var team := league.get_team(id)
	var opp := league.get_team(opp_id)
	var arch := String(team["archetype"])
	var overrides: Dictionary = v.get("cards", {})
	var club_overrides: Dictionary = v.get("cards_for", {}).get(id, {})
	var club_tpl := _club_deck(tpl, squads, v, id, arch)
	var cards: Array = []
	for d in squads.build_match_templates(id, club_tpl):
		var c: Dictionary = (d as Dictionary).duplicate(true)
		var key: String = "@sello" if String(c.get("name", "")).begins_with("Sello de") else String(c.get("id", ""))
		for o in [overrides, club_overrides]:
			if o.has(key):
				for field in o[key]:
					c[field] = o[key][field]
		if v.has("stamina_mult") and c.has("stamina"):
			c["stamina"] = float(c["stamina"]) * float(v["stamina_mult"])
		cards.append(c)
	# Las plantillas ya vienen una por copia: "count" se aplica agregando o quitando copias.
	for o in [overrides, club_overrides]:
		for key in o:
			if not o[key].has("count"):
				continue
			var copies: Array = cards.filter(func(c): return String(c.get("id", "")) == key)
			if copies.is_empty():
				continue
			var target := int(o[key]["count"])
			while copies.size() > target:
				cards.erase(copies.pop_back())
			while copies.size() < target:
				var extra: Dictionary = (copies[0] as Dictionary).duplicate(true)
				copies.append(extra)
				cards.append(extra)
	var profile: BotProfile = league.profile_for_team(team)   # su profile_name es el nombre del club
	var prof_overrides: Dictionary = v.get("profile", {})
	if prof_overrides.has(arch):
		for field in prof_overrides[arch]:
			profile.set(field, prof_overrides[arch][field])
	return {"id": id, "profile": profile, "archetype": arch, "templates": cards,
		"lineup": squads.lineup_ids(id), "defends": true,
		"attack_difficulty": LeagueManager.attack_difficulty_vs(opp, league.profile_for_team(opp), BASE_DIFFICULTY) + float(v.get("diff_add", 0.0)),
		"defense_difficulty": LeagueManager.defense_difficulty_vs(opp, BASE_DIFFICULTY)}


func _hooks(v: Dictionary) -> Dictionary:
	var hooks := {}
	if v.has("steps") or v.has("steps3_p") or v.has("steps_by_archetype") or v.has("player_for"):
		var by_arch: Dictionary = v.get("steps_by_archetype", {})
		var player_for: Dictionary = v.get("player_for", {})
		hooks["after_start"] = func(e: MatchEngine, side: Dictionary) -> void:
			if player_for.has(side["id"]):
				for attr in player_for[side["id"]]:
					e.player.set(attr, player_for[side["id"]][attr])
				e.player.start_match_energy()   # por si cambió stamina
			var arch: String = side["archetype"]
			for m in e.moments:
				if by_arch.has(arch):
					var s = by_arch[arch]
					m["steps_required"] = e.rng.randi_range(int(s[0]), int(s[1])) if s is Array else int(s)
				elif v.has("steps"):
					m["steps_required"] = int(v["steps"])
				elif v.has("steps3_p"):
					m["steps_required"] = 3 if e.rng.randf() < float(v["steps3_p"]) else 2
	if v.get("no_hold", false):
		hooks["after_begin"] = func(e: MatchEngine, _side: Dictionary) -> void:
			e.holds = MatchEngine.MAX_HOLDS
			if not e.moment_over and e.playable_indices().is_empty():
				e.abort_moment()
	return hooks
