# Versión de terminal (opcional): godot --headless --path . -s core/sim.gd
# Métricas de balance con semillas fijas (comparables entre corridas).
extends SceneTree

const MATCHES := 2000
const DUELS := 1000
const MATRIX_DUELS := 400
const GOALS_TARGET_MIN := 2.3   # goles totales por partido (ambos equipos)
const GOALS_TARGET_MAX := 2.6
const INJURY_TARGET_MIN := 2    # % de equipos que terminan el partido lesionados
const INJURY_TARGET_MAX := 5
const BASE_DIFFICULTY := 0.15


func _init() -> void:
	var tpl := CardDB.load_templates("res://data/cards.json")
	print("Arquetipos (2000 partidos c/u, rival en postura NORMAL):")
	for p in BotProfile.presets():
		var m := SimRunner.metrics(SimRunner.run(p, MATCHES, {}, tpl))
		print("%-11s | goles/partido %.2f | gol/momento %.0f%% | Flow %.0f%% | cansancio %.0f%% | lesiones %.1f%% | élite/partido %.2f" % [
			p.profile_name, m["goals_per_match"], m["goal_pct"], m["flow_pct"],
			m["tired_pct"], m["injury_pct"], m["elite_per_match"]])

	# Peligro de cada club cuando tú juegas en LOW (contragolpe), con su dificultad de ataque real.
	var league := LeagueManager.new()
	if not league.load_all():
		print("No se pudo cargar la liga: %s" % [league.load_errors])
		quit(1)
		return
	# Peligro de cada club atacándote, con su dificultad de ataque real. "Genérico" = mazo de
	# cards.json sin dueños (como antes); "plantel" = su mazo real con cartas firma y Ejecutor
	# Natural de sus titulares (como juega ahora en match_view).
	var squads := SquadManager.new()
	squads.load_all(league)
	print("Peligro del rival (goles/partido del rival, sin tu defensa) · mazo genérico → con plantel:")
	for id in ["colo_colo", "universidad_de_chile", "universidad_catolica", "cobreloa", "huachipato", "magallanes"]:
		var team := league.get_team(id)
		if team.is_empty():
			continue
		var prof := league.profile_for_team(team)
		var team_tpl := squads.build_match_templates(id, tpl)
		var cfg := {"rival_difficulty": LeagueManager.team_attack_difficulty(team, BASE_DIFFICULTY)}
		var cfg_squad := cfg.duplicate()
		cfg_squad["lineup"] = squads.lineup_ids(id)
		var cfg_low := cfg_squad.duplicate()
		cfg_low["rival_posture"] = MatchEngine.Posture.LOW
		var g_generic: float = SimRunner.metrics(SimRunner.run(prof, MATCHES, cfg, tpl))["goals_per_match"]
		var r_squad := SimRunner.run(prof, MATCHES, cfg_squad, team_tpl)
		var g_squad: float = SimRunner.metrics(r_squad)["goals_per_match"]
		var g_low: float = SimRunner.metrics(SimRunner.run(prof, MATCHES, cfg_low, team_tpl))["goals_per_match"]
		var cfg_block := cfg_squad.duplicate()
		cfg_block["opponent_block"] = MatchEngine.BLOCK_EFFECT   # tu fase defensiva con un Bloqueo exitoso
		var g_block: float = SimRunner.metrics(SimRunner.run(prof, MATCHES, cfg_block, team_tpl))["goals_per_match"]
		var natural := float(r_squad["totals"].get("natural_plays", 0)) / MATCHES
		print("%-12s (%s, inst. %d%s) | vs tu NORMAL %.2f → %.2f (%+.0f%%) | vs tu LOW %.2f | contra tu Bloqueo %.2f | Ejecutor Natural %.1f/partido" % [
			team["short_name"], team["archetype"], team["facilities_level"],
			", castiga LOW" if prof.punishes_passivity else "",
			g_generic, g_squad, 100.0 * (g_squad - g_generic) / maxf(0.01, g_generic), g_low, g_block, natural])

	# Partidos completos (DuelRunner): tu club contra cada rival, con bots en ambos lados y las
	# mismas dificultades que match_view. "Antes" = solo tú defiendes; "ahora" = ambos defienden.
	var your_goals_total := 0.0
	var you_id := "colo_colo"
	var you := league.get_team(you_id)
	print("Partidos completos de %s (bot) · %d por rival · antes (solo tú defiendes) → ahora (ambos defienden):" % [
		you["short_name"], DUELS])
	for id in ["universidad_de_chile", "universidad_catolica", "cobreloa", "audax_italiano", "palestino", "huachipato"]:
		var opp := league.get_team(id)
		var opp_prof := league.profile_for_team(opp)
		var a := {"profile": league.profile_for_team(you), "templates": squads.build_match_templates(you_id, tpl),
			"lineup": squads.lineup_ids(you_id), "defends": true,
			"attack_difficulty": LeagueManager.attack_difficulty_vs(opp, opp_prof, BASE_DIFFICULTY),
			"defense_difficulty": LeagueManager.defense_difficulty_vs(opp, BASE_DIFFICULTY)}
		var b := {"profile": opp_prof, "templates": squads.build_match_templates(id, tpl),
			"lineup": squads.lineup_ids(id), "defends": false,
			"attack_difficulty": LeagueManager.team_attack_difficulty(opp, BASE_DIFFICULTY),
			"defense_difficulty": LeagueManager.defense_difficulty_vs(you, BASE_DIFFICULTY)}
		var before := DuelRunner.run(a, b, DUELS)
		b["defends"] = true
		var now := DuelRunner.run(a, b, DUELS)
		print("vs %-12s (%s, defensa %s) | tus goles %.2f → %.2f | goles rival %.2f → %.2f | ganas %d%% → %d%% · empatas %d%% → %d%% | te corta %.2f ataques/partido" % [
			opp["short_name"], opp["archetype"], BotProfile.DEFENSE_FOCUS_NAMES[opp_prof.defense_focus],
			float(before["goals_a"]) / DUELS, float(now["goals_a"]) / DUELS,
			float(before["goals_b"]) / DUELS, float(now["goals_b"]) / DUELS,
			roundi(100.0 * before["wins_a"] / DUELS), roundi(100.0 * now["wins_a"] / DUELS),
			roundi(100.0 * before["draws"] / DUELS), roundi(100.0 * now["draws"] / DUELS),
			float(now["cuts_by_b"]) / DUELS])
		your_goals_total += float(now["goals_a"] + now["goals_b"]) / DUELS
	print("  promedio de goles totales en tus partidos: %.2f" % (your_goals_total / 6.0))

	# Matriz neutral: un club de Primera A por arquetipo (más Colo-Colo), todos contra todos, con
	# defensa en ambos lados y dificultades simétricas. Referencia del ritmo de goles de la liga.
	var clubs: Array = ["colo_colo"]
	var seen_archetypes := {"Tiki-Taka": true}
	for t in league.get_teams("Primera A"):
		if not t.get("suspended", false) and not seen_archetypes.has(t["archetype"]):
			seen_archetypes[t["archetype"]] = true
			clubs.append(t["id"])
	var total := {"goals": 0, "matches": 0, "injuries": 0, "m1": 0, "t1": 0, "m2": 0, "t2": 0}
	var rows: Array = []
	for i in clubs.size():
		for j in range(i + 1, clubs.size()):
			var r := DuelRunner.run(_neutral_side(league, squads, tpl, clubs[i], clubs[j]),
					_neutral_side(league, squads, tpl, clubs[j], clubs[i]), MATRIX_DUELS)
			total["goals"] += r["goals_a"] + r["goals_b"]
			total["matches"] += MATRIX_DUELS
			total["injuries"] += r["injuries"]
			total["m1"] += r["moments_1h"]
			total["t1"] += r["tired_1h"]
			total["m2"] += r["moments_2h"]
			total["t2"] += r["tired_2h"]
			rows.append("%s %.2f-%.2f %s" % [league.get_team(clubs[i])["short_name"], float(r["goals_a"]) / MATRIX_DUELS,
					float(r["goals_b"]) / MATRIX_DUELS, league.get_team(clubs[j])["short_name"]])
	var matches := float(total["matches"])
	var avg: float = float(total["goals"]) / matches
	var injuries: float = 100.0 * float(total["injuries"]) / (2.0 * matches)   # % de equipos que terminan lesionados
	print("Matriz bot vs bot (%d clubes, %d partidos por cruce): %s" % [clubs.size(), MATRIX_DUELS, " · ".join(rows)])
	print("  PROMEDIO DE GOLES TOTALES POR PARTIDO: %.2f (objetivo %.1f-%.1f) → %s" % [
		avg, GOALS_TARGET_MIN, GOALS_TARGET_MAX,
		"EN RANGO" if avg >= GOALS_TARGET_MIN and avg <= GOALS_TARGET_MAX else "FUERA DE RANGO"])
	print("  LESIONES: %.1f%% de los equipos por partido (objetivo %d-%d%%) → %s" % [
		injuries, INJURY_TARGET_MIN, INJURY_TARGET_MAX,
		"EN RANGO" if injuries >= INJURY_TARGET_MIN and injuries <= INJURY_TARGET_MAX else "FUERA DE RANGO"])
	print("  CANSANCIO: Momentos que empiezan en CANSADO o AGOTADO · primer tiempo %d%% · segundo tiempo %d%%" % [
		roundi(100.0 * total["t1"] / maxf(1.0, total["m1"])), roundi(100.0 * total["t2"] / maxf(1.0, total["m2"]))])
	quit()


# Un lado de la matriz neutral: ataca contra la defensa del rival y defiende contra su ataque.
func _neutral_side(league: LeagueManager, squads: SquadManager, tpl: Array, id: String, opp_id: String) -> Dictionary:
	var team := league.get_team(id)
	var opp := league.get_team(opp_id)
	return {"profile": league.profile_for_team(team), "templates": squads.build_match_templates(id, tpl),
		"lineup": squads.lineup_ids(id), "defends": true,
		"attack_difficulty": LeagueManager.attack_difficulty_vs(opp, league.profile_for_team(opp), BASE_DIFFICULTY),
		"defense_difficulty": LeagueManager.defense_difficulty_vs(opp, BASE_DIFFICULTY)}
