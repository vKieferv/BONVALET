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
# Constructibilidad: % de inicios de Momento (postura NORMAL, 3 PA) cuya mano permite un plan de gol
# (CoachBot.best_plan). Objetivo con estamina llena en Momentos de 3 jugadas.
const CONSTRUCT_SAMPLES := 4000
const CONSTRUCT_TARGET := 85
# Etapas de la temporada para la matriz: cartas de crecimiento (data/decks.json) sobre el mazo estándar.
const STAGES := [["INICIO", 0], ["MITAD", 4], ["FINAL", 8]]


func _init() -> void:
	# Todos juegan con el mazo estándar de su estilo y su carta de rasgo (D-23): el arquetipo sin
	# plantel, con una firma genérica (CardDB.club_like_templates), o el club con las firmas de sus
	# titulares (SquadManager).
	var catalog := CardDB.load_catalog()
	var decks := CardDB.load_decks()
	print("Arquetipos (2000 partidos c/u, mazo estándar con su rasgo y una firma genérica, rival en postura NORMAL):")
	for p in BotProfile.presets():
		var m := SimRunner.metrics(SimRunner.run(p, MATCHES, {}, CardDB.club_like_templates(catalog, decks, p.profile_name)))
		print("%-11s | goles/partido %.2f | gol/momento %.0f%% | Flow %.0f%% | cansancio %.0f%% | lesiones %.1f%% | élite/partido %.2f" % [
			p.profile_name, m["goals_per_match"], m["goal_pct"], m["flow_pct"],
			m["tired_pct"], m["injury_pct"], m["elite_per_match"]])

	# Peligro de cada club cuando tú juegas en LOW (contragolpe), con su dificultad de ataque real.
	var league := LeagueManager.new()
	if not league.load_all():
		print("No se pudo cargar la liga: %s" % [league.load_errors])
		quit(1)
		return
	# Peligro de cada club atacándote, con su dificultad de ataque real. "Genérico" = el mazo estándar
	# de su estilo con una firma genérica y sin dueños; "plantel" = su mazo real con cartas firma y
	# Ejecutor Natural de sus titulares (como juega en match_view).
	var squads := SquadManager.new()
	squads.load_all(league)
	print("Peligro del rival (goles/partido del rival, sin tu defensa) · mazo genérico → con plantel:")
	for id in ["colo_colo", "universidad_de_chile", "universidad_catolica", "cobreloa", "huachipato", "magallanes"]:
		var team := league.get_team(id)
		if team.is_empty():
			continue
		var prof := league.profile_for_team(team)
		var tpl := CardDB.club_like_templates(catalog, decks, String(team["archetype"]))
		var team_tpl := squads.build_match_templates(id, squads.starter_templates(id))
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
		var a := {"profile": league.profile_for_team(you), "templates": squads.build_match_templates(you_id, squads.starter_templates(you_id)),
			"lineup": squads.lineup_ids(you_id), "defends": true,
			"attack_difficulty": LeagueManager.attack_difficulty_vs(opp, opp_prof, BASE_DIFFICULTY),
			"defense_difficulty": LeagueManager.defense_difficulty_vs(opp, BASE_DIFFICULTY)}
		var b := {"profile": opp_prof, "templates": squads.build_match_templates(id, squads.starter_templates(id)),
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
	# defensa en ambos lados y dificultades simétricas. Referencia del ritmo de goles de la liga, en
	# tres etapas de la temporada: el mazo estándar y el mismo mazo con 4 y 8 cartas de su crecimiento.
	var clubs: Array = ["colo_colo"]
	var seen_archetypes := {"Tiki-Taka": true}
	for t in league.get_teams("Primera A"):
		if not t.get("suspended", false) and not seen_archetypes.has(t["archetype"]):
			seen_archetypes[t["archetype"]] = true
			clubs.append(t["id"])
	for stage in STAGES:
		_matrix(league, squads, clubs, String(stage[0]), int(stage[1]))

	# Constructibilidad de mano con el mazo real de Colo-Colo.
	print("Constructibilidad de mano (Colo-Colo con su mazo de inicio, %d inicios de Momento en NORMAL · %% con jugada de gol armable):" % CONSTRUCT_SAMPLES)
	for steps in [3, 2]:
		var cells: Array = []
		for zone_pct in [1.0, 0.5, 0.2]:
			cells.append("%s %d%%" % [{1.0: "llena", 0.5: "cansado", 0.2: "agotado"}[zone_pct],
					_constructibility(squads, "colo_colo", steps, zone_pct)])
		print("  Momentos de %d jugadas · %s" % [steps, " · ".join(cells)])
	var fresh := _constructibility(squads, "colo_colo", 3, 1.0)
	print("  CONSTRUCTIBILIDAD (3 jugadas, estamina llena): %d%% (objetivo ≥%d%%) → %s" % [
		fresh, CONSTRUCT_TARGET, "EN RANGO" if fresh >= CONSTRUCT_TARGET else "FUERA DE RANGO"])
	quit()


# Una etapa de la matriz neutral: todos contra todos con `extra` cartas de crecimiento, y sus líneas
# de goles, lesiones y cansancio (la de goles dice si queda en el rango objetivo).
func _matrix(league: LeagueManager, squads: SquadManager, clubs: Array, stage: String, extra: int) -> void:
	var total := {"goals": 0, "matches": 0, "injuries": 0, "m1": 0, "t1": 0, "m2": 0, "t2": 0}
	var rows: Array = []
	var sizes: Array = []
	for id in clubs:
		sizes.append(squads.build_match_templates(id, squads.season_templates(id, extra)).size())
	for i in clubs.size():
		for j in range(i + 1, clubs.size()):
			var r := DuelRunner.run(_neutral_side(league, squads, clubs[i], clubs[j], extra),
					_neutral_side(league, squads, clubs[j], clubs[i], extra), MATRIX_DUELS)
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
	print("Matriz bot vs bot · %s de temporada (+%d cartas de crecimiento, mazos de %d-%d) · %d clubes, %d partidos por cruce: %s" % [
		stage, extra, sizes.min(), sizes.max(), clubs.size(), MATRIX_DUELS, " · ".join(rows)])
	print("  %s · PROMEDIO DE GOLES TOTALES POR PARTIDO: %.2f (objetivo %.1f-%.1f) → %s" % [
		stage, avg, GOALS_TARGET_MIN, GOALS_TARGET_MAX,
		"EN RANGO" if avg >= GOALS_TARGET_MIN and avg <= GOALS_TARGET_MAX else "FUERA DE RANGO"])
	print("  %s · LESIONES: %.1f%% de los equipos por partido (objetivo %d-%d%%) → %s" % [
		stage, injuries, INJURY_TARGET_MIN, INJURY_TARGET_MAX,
		"EN RANGO" if injuries >= INJURY_TARGET_MIN and injuries <= INJURY_TARGET_MAX else "FUERA DE RANGO"])
	print("  %s · CANSANCIO: Momentos que empiezan en CANSADO o AGOTADO · primer tiempo %d%% · segundo tiempo %d%%" % [
		stage, roundi(100.0 * total["t1"] / maxf(1.0, total["m1"])), roundi(100.0 * total["t2"] / maxf(1.0, total["m2"]))])


# % de manos iniciales (postura NORMAL) con un plan de gol para un Momento de `steps` jugadas,
# arrancando con `zone_pct` de estamina (define cuántas cartas se roban). Mazo de inicio del club.
func _constructibility(squads: SquadManager, team_id: String, steps: int, zone_pct: float) -> int:
	var profile := BotProfile.directo()
	var templates := squads.build_match_templates(team_id, squads.starter_templates(team_id))
	var ok := 0
	for i in CONSTRUCT_SAMPLES:
		var rng := RandomNumberGenerator.new()
		rng.seed = i + 1
		var player := PlayerStats.new()
		player.lineup = squads.lineup_ids(team_id)
		var e := MatchEngine.new(player, DeckManager.new(CardDB.build_deck(templates), [], rng), rng, BASE_DIFFICULTY)
		e.start()
		e.current_moment()["steps_required"] = steps
		player.energy = player.max_energy() * zone_pct
		e.begin_moment()
		if not CoachBot.best_plan(e, profile).is_empty():
			ok += 1
	return roundi(100.0 * ok / CONSTRUCT_SAMPLES)


# Un lado de la matriz neutral: ataca contra la defensa del rival y defiende contra su ataque, con el
# mazo estándar de su estilo más `extra` cartas de su crecimiento.
func _neutral_side(league: LeagueManager, squads: SquadManager, id: String, opp_id: String, extra: int) -> Dictionary:
	var team := league.get_team(id)
	var opp := league.get_team(opp_id)
	return {"profile": league.profile_for_team(team), "templates": squads.build_match_templates(id, squads.season_templates(id, extra)),
		"lineup": squads.lineup_ids(id), "defends": true,
		"attack_difficulty": LeagueManager.attack_difficulty_vs(opp, league.profile_for_team(opp), BASE_DIFFICULTY),
		"defense_difficulty": LeagueManager.defense_difficulty_vs(opp, BASE_DIFFICULTY)}
