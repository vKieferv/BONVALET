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
	print("Peligro del rival según tu postura (goles/partido del rival, sin tu defensa):")
	for id in ["colo_colo", "universidad_de_chile", "universidad_catolica", "cobreloa", "huachipato", "magallanes"]:
		var team := league.get_team(id)
		if team.is_empty():
			continue
		var prof := league.profile_for_team(team)
		var cfg := {"rival_difficulty": LeagueManager.team_attack_difficulty(team, BASE_DIFFICULTY)}
		var cfg_low := cfg.duplicate()
		cfg_low["rival_posture"] = MatchEngine.Posture.LOW
		var g_normal: float = SimRunner.metrics(SimRunner.run(prof, MATCHES, cfg, tpl))["goals_per_match"]
		var g_low: float = SimRunner.metrics(SimRunner.run(prof, MATCHES, cfg_low, tpl))["goals_per_match"]
		print("%-12s (%s, inst. %d%s) | vs tu NORMAL %.2f | vs tu LOW %.2f (%+.0f%%)" % [
			team["short_name"], team["archetype"], team["facilities_level"],
			", castiga LOW" if prof.punishes_passivity else "",
			g_normal, g_low, 100.0 * (g_low - g_normal) / maxf(0.01, g_normal)])
	quit()
