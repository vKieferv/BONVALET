# Versión de terminal (opcional): godot --headless --path . -s core/sim.gd
extends SceneTree

const MATCHES := 2000


func _init() -> void:
	var tpl := CardDB.load_templates("res://data/cards.json")
	for p in BotProfile.presets():
		var m := SimRunner.metrics(SimRunner.run(p, MATCHES, {}, tpl))
		print("%-10s | goles/partido %.2f | gol/momento %.0f%% | Flow %.0f%% | cansancio %.0f%% | lesiones %.1f%% | élite/partido %.2f" % [
			p.profile_name, m["goals_per_match"], m["goal_pct"], m["flow_pct"],
			m["tired_pct"], m["injury_pct"], m["elite_per_match"]])
	quit()
