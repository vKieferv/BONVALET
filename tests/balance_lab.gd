# Laboratorio de balance: la matriz neutral de sim.gd (mismos clubes, semillas y DuelRunner) con
# variantes aplicadas desde afuera del motor, para separar el efecto de cada cambio y probar palancas
# antes de tocar constantes. La variante sin cambios reproduce exacto la matriz de sim.gd.
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
# Las constantes del motor (INJURY_CHANCE_*, HOLD_*, AP_BY_POSTURE...) no se pueden variar desde
# aquí: se cambian en match_engine.gd, se corre el laboratorio y se restauran.
extends SceneTree

const BASE_DIFFICULTY := 0.15
const DEFAULT_PER_PAIR := 400


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
			variants = parsed

	var tpl := CardDB.load_templates("res://data/cards.json")
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
		var hooks := _hooks(v)
		for i in clubs.size():
			for j in range(i + 1, clubs.size()):
				var r := DuelRunner.run(_side(league, squads, tpl, clubs[i], clubs[j], v),
						_side(league, squads, tpl, clubs[j], clubs[i], v), per_pair, hooks)
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
	quit()


func _side(league: LeagueManager, squads: SquadManager, tpl: Array, id: String, opp_id: String, v: Dictionary) -> Dictionary:
	var team := league.get_team(id)
	var opp := league.get_team(opp_id)
	var overrides: Dictionary = v.get("cards", {})
	var cards: Array = []
	for d in squads.build_match_templates(id, tpl):
		var c: Dictionary = (d as Dictionary).duplicate(true)
		var key: String = "@sello" if String(c.get("name", "")).begins_with("Sello de") else String(c.get("id", ""))
		if overrides.has(key):
			for field in overrides[key]:
				c[field] = overrides[key][field]
		if v.has("stamina_mult") and c.has("stamina"):
			c["stamina"] = float(c["stamina"]) * float(v["stamina_mult"])
		cards.append(c)
	return {"profile": league.profile_for_team(team), "templates": cards,
		"lineup": squads.lineup_ids(id), "defends": true,
		"attack_difficulty": LeagueManager.attack_difficulty_vs(opp, league.profile_for_team(opp), BASE_DIFFICULTY) + float(v.get("diff_add", 0.0)),
		"defense_difficulty": LeagueManager.defense_difficulty_vs(opp, BASE_DIFFICULTY)}


func _hooks(v: Dictionary) -> Dictionary:
	var hooks := {}
	if v.has("steps") or v.has("steps3_p"):
		hooks["after_start"] = func(e: MatchEngine) -> void:
			for m in e.moments:
				if v.has("steps"):
					m["steps_required"] = int(v["steps"])
				else:
					m["steps_required"] = 3 if e.rng.randf() < float(v["steps3_p"]) else 2
	if v.get("no_hold", false):
		hooks["after_begin"] = func(e: MatchEngine) -> void:
			e.holds = MatchEngine.MAX_HOLDS
			if not e.moment_over and e.playable_indices().is_empty():
				e.abort_moment()
	return hooks
