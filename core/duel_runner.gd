class_name DuelRunner
extends RefCounted

# Partidos completos entre dos bots con la misma línea de tiempo que match_view: los Momentos de
# ambos se intercalan por minuto y cada ataque puede ir precedido de la fase defensiva del otro
# (CoachBot.run_defense). Semillas fijas por partido, como SimRunner, para comparar escenarios.
#
# side: {profile: BotProfile, templates: Array (mazo como diccionarios), lineup: Array (titulares),
#        attack_difficulty: float, defense_difficulty: float (dificultad de sus jugadas defensivas),
#        defends: bool}
static func run(a: Dictionary, b: Dictionary, n: int) -> Dictionary:
	var out := {"matches": n, "goals_a": 0, "goals_b": 0, "wins_a": 0, "draws": 0, "wins_b": 0,
		"cuts_by_a": 0, "cuts_by_b": 0, "def_plays_a": 0, "def_plays_b": 0}
	for s in n:
		var ea := _engine(a, s * 2 + 1)
		var eb := _engine(b, s * 2 + 2)
		ea.start()
		eb.start()
		while not (ea.finished and eb.finished):
			var ma := 9999 if ea.finished else int(ea.current_moment()["minute"])
			var mb := 9999 if eb.finished else int(eb.current_moment()["minute"])
			if ma <= mb:
				_attack(ea, a, eb, b, out, "b")
			else:
				_attack(eb, b, ea, a, out, "a")
		var ga: int = ea.stats["goals"]
		var gb: int = eb.stats["goals"]
		out["goals_a"] += ga
		out["goals_b"] += gb
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
	return e


# Un ataque de `att`, con la fase defensiva previa de `def` si ese lado defiende.
# def_tag = "a" o "b": a quién se le cuentan los cortes y las jugadas defensivas.
static func _attack(att: MatchEngine, att_side: Dictionary, def: MatchEngine, def_side: Dictionary,
		out: Dictionary, def_tag: String) -> void:
	var att_profile: BotProfile = att_side["profile"]
	att.exploit_rival_space = att_profile.punishes_passivity and def.posture == MatchEngine.Posture.LOW
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
	att.begin_moment()
	while not att.moment_over:
		var idx := CoachBot.choose(att, att_profile)
		if idx < 0:
			att.abort_moment()
			break
		att.play_card(idx)
	att.advance(att_profile.default_posture as MatchEngine.Posture)
