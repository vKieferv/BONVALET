# Versión de terminal (opcional): godot --headless --path . -s core/sim.gd
# Métricas de balance con semillas fijas (comparables entre corridas).
extends SceneTree

const MATCHES := 2000
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
	quit()
