class_name DuelRunner
extends RefCounted

# Partidos completos entre dos bots con la misma línea de tiempo que match_view: los Momentos de
# ambos se intercalan por minuto y cada ataque puede ir precedido de la fase defensiva del otro
# (CoachBot.run_defense). Semillas fijas por partido, como SimRunner, para comparar escenarios.
#
# side: {profile: BotProfile, templates: Array (mazo como diccionarios), lineup: Array (titulares),
#        attack_difficulty: float, defense_difficulty: float (dificultad de sus jugadas defensivas),
#        defends: bool,
#        zone_mode: bool, formation: Array, line_strength: Array (partido por zonas, D-36: los dos de
#        SquadManager.zone_data; sin zone_mode, el partido de siempre),
#        duel_mode: bool, players: Array, style: String (modo de duelos, D-40: los de
#        SquadManager.duel_data; exige zone_mode)}
#
# hooks (opcional, para experimentos de tests/balance_lab.gd; sin hooks el partido es el de siempre):
#   "after_start": Callable(e: MatchEngine, side: Dictionary) tras start();
#   "after_begin": Callable(e, side) tras begin_moment(). side es el diccionario de ese equipo.
static func run(a: Dictionary, b: Dictionary, n: int, hooks: Dictionary = {}) -> Dictionary:
	# moments_1h/2h: Momentos de ataque jugados en cada tiempo (ambos equipos); tired_1h/2h: de ellos,
	# los que empezaron en CANSADO o AGOTADO. injuries: equipos que terminaron lesionados.
	# holds / holds_lost: veces que se aguantó el balón y cuántas terminaron en robo (ambos equipos).
	# counters: Momentos que arrancaron con contragolpe; steals / saves / rebounds: fallos que fueron
	# robo, atajada o rebote (modo de zonas); no_cards: Momentos perdidos sin cartas ni Aguantar.
	var out := {"matches": n, "goals_a": 0, "goals_b": 0, "wins_a": 0, "draws": 0, "wins_b": 0,
		"cuts_by_a": 0, "cuts_by_b": 0, "def_plays_a": 0, "def_plays_b": 0,
		"moments_1h": 0, "tired_1h": 0, "moments_2h": 0, "tired_2h": 0, "injuries": 0,
		"injuries_a": 0, "injuries_b": 0, "holds": 0, "holds_lost": 0,
		"counters": 0, "steals": 0, "saves": 0, "rebounds": 0, "no_cards": 0,
		"dribble_entries": 0, "dribble_doubled": 0, "back_plays": 0, "transition_moments": 0, "transition_goals": 0,
		"salida_steals": 0, "salida_steals_fwd": 0, "salida_steal_skill": 0, "short_moments": 0, "short_goals": 0, "same_zone_passes": 0,
		"touch_total": 0, "touch_top": 0, "touch_distinct": 0, "touch_teams": 0, "touches_a": {}, "touches_b": {},
		"divididas": 0, "divididas_won": 0, "laterales": 0, "faltas": 0, "afueras": 0, "corners": 0, "corner_crosses": 0, "corner_goals": 0}
	for s in n:
		var ea := _engine(a, s * 2 + 1)
		var eb := _engine(b, s * 2 + 2)
		ea.start()
		eb.start()
		if hooks.has("after_start"):
			hooks["after_start"].call(ea, a)
			hooks["after_start"].call(eb, b)
		while not (ea.finished and eb.finished):
			var ma := 9999 if ea.finished else int(ea.current_moment()["minute"])
			var mb := 9999 if eb.finished else int(eb.current_moment()["minute"])
			if ma <= mb:
				_attack(ea, a, eb, b, out, "b", hooks)
			else:
				_attack(eb, b, ea, a, out, "a", hooks)
		out["holds"] += int(ea.stats["holds"]) + int(eb.stats["holds"])
		out["holds_lost"] += int(ea.stats["holds_lost"]) + int(eb.stats["holds_lost"])
		for k in ["counters", "steals", "saves", "rebounds", "dribble_entries", "dribble_doubled", "back_plays",
				"transition_moments", "transition_goals", "salida_steals", "salida_steals_fwd", "salida_steal_skill",
				"short_moments", "short_goals", "same_zone_passes", "divididas", "divididas_won", "laterales", "faltas",
				"afueras", "corners", "corner_crosses", "corner_goals"]:
			out[k] += int(ea.stats[k]) + int(eb.stats[k])
		out["no_cards"] += int(ea.stats["out_of_ap"]) + int(eb.stats["out_of_ap"])
		# Modo de duelos: cuánto se reparte el balón (veces que cada titular fue portador).
		for pair in [[ea, "touches_a"], [eb, "touches_b"]]:
			var t: Dictionary = (pair[0] as MatchEngine).touches
			if t.is_empty():
				continue
			var top := 0
			var distinct := 0
			for id in t:
				var c := int(t[id])
				out["touch_total"] += c
				top = maxi(top, c)
				distinct += 1 if c > 0 else 0
				out[pair[1]][id] = int(out[pair[1]].get(id, 0)) + c
			out["touch_top"] += top
			out["touch_distinct"] += distinct
			out["touch_teams"] += 1
		var ga: int = ea.stats["goals"]
		var gb: int = eb.stats["goals"]
		out["goals_a"] += ga
		out["goals_b"] += gb
		out["injuries"] += int(ea.injured) + int(eb.injured)
		out["injuries_a"] += int(ea.injured)
		out["injuries_b"] += int(eb.injured)
		if ga > gb:
			out["wins_a"] += 1
		elif gb > ga:
			out["wins_b"] += 1
		else:
			out["draws"] += 1
	return out


static func _engine(side: Dictionary, seed: int) -> MatchEngine:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed
	var player := PlayerStats.new()
	player.lineup.assign(side.get("lineup", []))
	var deck := DeckManager.new(CardDB.build_deck(side["templates"]), [], rng)
	var e := MatchEngine.new(player, deck, rng, side.get("attack_difficulty", 0.15))
	(side["profile"] as BotProfile).configure_engine(e)
	if side.get("zone_mode", false):
		e.zone_mode = true
		e.formation = side.get("formation", [])
		e.line_strength = side.get("line_strength", [])
		if side.get("duel_mode", false):
			e.duel_mode = true
			e.duel_players = side.get("players", [])
			e.mark_style = side.get("style", "")
	return e


# Un ataque de `att`, con la fase defensiva previa de `def` si ese lado defiende.
# def_tag = "a" o "b": a quién se le cuentan los cortes y las jugadas defensivas.
static func _attack(att: MatchEngine, att_side: Dictionary, def: MatchEngine, def_side: Dictionary,
		out: Dictionary, def_tag: String, hooks: Dictionary = {}) -> void:
	var att_profile: BotProfile = att_side["profile"]
	att.exploit_rival_space = att_profile.punishes_passivity and def.posture == MatchEngine.Posture.LOW
	if def_side.get("defends", true) and def.defends_by_duels(att):
		_duel_attack(att, att_side, def, def_side, out, def_tag, hooks)
		return
	if def_side.get("defends", true):
		var r := CoachBot.run_defense(def, def_side["profile"], def_side.get("defense_difficulty", 0.15))
		out["def_plays_" + def_tag] += r["plays"].size()
		if r["cancelled"]:
			out["cuts_by_" + def_tag] += 1
			att.skip_moment()
			att.advance(att_profile.default_posture as MatchEngine.Posture)
			return
		att.opponent_pressure = r["pressure"]
		att.opponent_block = r["block"]
	var half := "2h" if int(att.current_moment()["minute"]) >= 45 else "1h"
	if att.zone_mode:
		att.set_zone_rival(def)
	att.begin_moment()
	if hooks.has("after_begin"):
		hooks["after_begin"].call(att, att_side)
	out["moments_" + half] += 1
	if att.player.zone() != PlayerStats.Zone.SAFE:
		out["tired_" + half] += 1
	while not att.moment_over:
		var ev := CoachBot.act(att, att_profile)
		if ev.get("stolen", false):
			def.counter_ready = true   # le robaron el balón (al aguantar o, por zonas, al fallar): contragolpe del que defendía
	att.advance(att_profile.default_posture as MatchEngine.Posture)


# D-44 (T-15): ataque por duelos contra una defensa jugada a jugada, como match_view: empieza el Momento,
# el que defiende abre su mano y antes de cada jugada ve la anunciada y responde (CoachBot.defended_step).
static func _duel_attack(att: MatchEngine, att_side: Dictionary, def: MatchEngine, def_side: Dictionary,
		out: Dictionary, def_tag: String, hooks: Dictionary = {}) -> void:
	var att_profile: BotProfile = att_side["profile"]
	var def_profile: BotProfile = def_side["profile"]
	att.opponent_pressure = 0.0
	att.opponent_block = 0.0
	var half := "2h" if int(att.current_moment()["minute"]) >= 45 else "1h"
	att.set_zone_rival(def)
	att.begin_moment()
	if hooks.has("after_begin"):
		hooks["after_begin"].call(att, att_side)
	out["moments_" + half] += 1
	if att.player.zone() != PlayerStats.Zone.SAFE:
		out["tired_" + half] += 1
	if not def.injured and not att.moment_over:
		def.begin_defense(def_side.get("defense_difficulty", 0.15), att)
	while not att.moment_over:
		var step := CoachBot.defended_step(att, att_profile, def, def_profile)
		for d in step["defense"]:
			out["def_plays_" + def_tag] += 1
			if d.get("cancelled", false):
				out["cuts_by_" + def_tag] += 1
		if step["ev"].get("stolen", false):
			def.counter_ready = true
	def.end_defense()
	att.advance(att_profile.default_posture as MatchEngine.Posture)
