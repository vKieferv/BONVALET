class_name SimRunner
extends RefCounted

# Simula `n` partidos con un perfil. Usa semillas 1..n, así que dos perfiles
# comparados juegan exactamente los mismos partidos (comparación pareada).
# Seguro para ejecutar en un hilo.
# cfg (opcional): energy_max (tope con Stamina 60), regen_normal_pct, rival_difficulty, defense_influence
static func run(profile: BotProfile, n: int, cfg: Dictionary, templates: Array, progress: Callable = Callable()) -> Dictionary:
	var totals := {}
	var goals := PackedInt32Array()
	goals.resize(n)
	for s in n:
		var rng := RandomNumberGenerator.new()
		rng.seed = s + 1
		var player := PlayerStats.new()
		player.set_energy_cap(cfg.get("energy_max", 58.0))
		player.regen_normal_pct = cfg.get("regen_normal_pct", 0.22)
		var deck := DeckManager.new(CardDB.build_deck(templates), [], rng)
		var e := MatchEngine.new(player, deck, rng, cfg.get("rival_difficulty", 0.15))
		profile.configure_engine(e)
		e.exploit_rival_space = profile.punishes_passivity \
				and int(cfg.get("rival_posture", MatchEngine.Posture.NORMAL)) == MatchEngine.Posture.LOW
		e.start()
		while not e.finished:
			e.begin_moment()
			while not e.moment_over:
				var idx := CoachBot.choose(e, profile)
				if idx < 0:
					e.abort_moment()
					break
				e.play_card(idx)
			e.advance(profile.default_posture as MatchEngine.Posture)
		goals[s] = e.stats["goals"]
		for k in e.stats:
			totals[k] = totals.get(k, 0) + e.stats[k]
		if progress.is_valid() and s % 50 == 0:
			progress.call(float(s) / float(n))
	return {"totals": totals, "goals": goals, "matches": n}


# Dificultad base + ajuste por la defensa del rival.
# defense_influence = 0 -> el rival no importa (comparación pareada pura).
static func difficulty_vs(cfg: Dictionary, rival: BotProfile) -> float:
	var base: float = cfg.get("rival_difficulty", 0.15)
	var influence: float = cfg.get("defense_influence", 0.0)
	return maxf(0.0, base + influence * (2.0 * rival.defense_rating() - 1.0))


# Configuración para jugar contra un rival concreto (dificultad + su postura).
static func cfg_vs(cfg: Dictionary, rival: BotProfile) -> Dictionary:
	var c := cfg.duplicate()
	c["rival_difficulty"] = difficulty_vs(cfg, rival)
	c["rival_posture"] = rival.default_posture
	return c


static func metrics(r: Dictionary) -> Dictionary:
	var t: Dictionary = r["totals"]
	var n := float(r["matches"])
	var moments := maxf(1.0, float(t["moments"]))
	var plays := maxf(1.0, float(t["plays"]))
	var by_moment: Array = []
	for m in MatchEngine.MAX_MOMENTS:
		var pm := float(t.get("plays_m%d" % m, 0))
		var tm := float(t.get("tired_m%d" % m, 0))
		by_moment.append({"pct": 100.0 * tm / maxf(1.0, pm), "per_match": tm / n})
	return {
		"by_moment": by_moment,
		"goals_per_match": t["goals"] / n,
		"goal_pct": 100.0 * t["goals"] / moments,
		"flow_pct": 100.0 * t["flow_moments"] / moments,
		"tired_pct": 100.0 * t["tired_plays"] / plays,
		"injury_pct": 100.0 * t["injuries"] / n,
		"elite_per_match": t["elite_plays"] / n,
		"flow_breaks_per_match": t["flow_breaks"] / n,
	}
