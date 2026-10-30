# Medición temporal (playtest 2026-10-29): ¿el rival acierta más que tú con las reglas de match_view?
# Juega Colo-Colo (bot) contra cada club de Primera A con las mismas dificultades que match_view y
# separa ataque y defensa de cada lado: % mostrado promedio, % de acierto real y goles.
# Uso: ..\Godot_v4.7.2-stable_win64_console.exe --headless --path . -s res://tests/lab/medir_rival.gd [-- --zonas]
# Con --zonas, los dos juegan el partido por zonas (D-36, T-10).
extends SceneTree

const BASE := 0.15
const N := 100
const ME := "colo_colo"

var league: LeagueManager
var squads: SquadManager
var zonas := false


func _initialize() -> void:
	zonas = OS.get_cmdline_user_args().has("--zonas")
	if zonas:
		print("PARTIDO POR ZONAS")
	league = LeagueManager.new()
	league.load_all()
	squads = SquadManager.new()
	squads.load_all(league)
	var me_team := league.get_team(ME)
	var tot := _acc()
	print("rival | dif. tu ataque / su ataque | tu ataque: %mostrado %real | su ataque: %mostrado %real | tu def %real | goles tú-él")
	for t in league.get_teams("Primera A"):
		if t.get("suspended", false) or t["id"] == ME:
			continue
		var a := _acc()
		for s in N:
			_match(me_team, t, s, a)
		_merge(tot, a)
		print("%s | %.2f / %.2f | %s | %s | %s | %.2f-%.2f" % [t["short_name"],
			LeagueManager.attack_difficulty_vs(t, league.profile_for_team(t), BASE),
			LeagueManager.team_attack_difficulty(t, BASE),
			_pair(a, "my_att"), _pair(a, "rv_att"), _pair(a, "my_def"),
			a["my_goals"] / float(N), a["rv_goals"] / float(N)])
	print("TOTAL | tu ataque %s | su ataque %s | tu defensa %s | su defensa %s | goles %.2f-%.2f" % [
		_pair(tot, "my_att"), _pair(tot, "rv_att"), _pair(tot, "my_def"), _pair(tot, "rv_def"),
		tot["my_goals"] / float(tot["n"]), tot["rv_goals"] / float(tot["n"])])
	print("Momentos jugados por partido tú %.2f / él %.2f · ataques cortados por ti %.2f / por él %.2f" % [tot["my_moments"] / float(tot["n"]), tot["rv_moments"] / float(tot["n"]), tot["my_cut"] / float(tot["n"]), tot["rv_cut"] / float(tot["n"])])
	print("Robos con contragolpe por partido: los tuyos %.2f / los de él %.2f" % [tot["my_steals"] / float(tot["n"]), tot["rv_steals"] / float(tot["n"])])
	quit(0)


func _acc() -> Dictionary:
	var d := {"n": 0, "my_goals": 0.0, "rv_goals": 0.0, "my_moments": 0, "rv_moments": 0, "my_cut": 0, "rv_cut": 0,
		"my_steals": 0, "rv_steals": 0}
	for k in ["my_att", "rv_att", "my_def", "rv_def"]:
		d[k + "_n"] = 0
		d[k + "_p"] = 0.0
		d[k + "_ok"] = 0
	return d


func _merge(into: Dictionary, a: Dictionary) -> void:
	for k in a:
		into[k] += a[k]


func _pair(a: Dictionary, k: String) -> String:
	var n: int = maxi(1, a[k + "_n"])
	return "%d%% %d%%" % [roundi(a[k + "_p"] / n * 100.0), roundi(float(a[k + "_ok"]) / n * 100.0)]


func _rec(a: Dictionary, k: String, ev: Dictionary) -> void:
	if not ev.has("chance"):
		return
	a[k + "_n"] += 1
	a[k + "_p"] += float(ev["chance"])
	if ev["success"]:
		a[k + "_ok"] += 1


func _engine(team: Dictionary, diff: float, seed: int) -> MatchEngine:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed
	var id := String(team["id"])
	var deck := DeckManager.new(squads.build_match_deck(id, squads.starter_templates(id)), [], rng)
	var player := PlayerStats.new()
	player.lineup = squads.lineup_ids(id)
	var e := MatchEngine.new(player, deck, rng, diff)
	league.profile_for_team(team).configure_engine(e)
	if zonas:
		var z := squads.zone_data(id)
		e.zone_mode = true
		e.formation = z["formation"]
		e.line_strength = z["line_strength"]
	e.start()
	return e


func _match(me_team: Dictionary, rv_team: Dictionary, s: int, a: Dictionary) -> void:
	var me_prof := league.profile_for_team(me_team)
	var rv_prof := league.profile_for_team(rv_team)
	var me := _engine(me_team, LeagueManager.attack_difficulty_vs(rv_team, rv_prof, BASE), s * 2 + 1)
	me.moment_steps = me_prof.moment_steps
	var rv := _engine(rv_team, LeagueManager.team_attack_difficulty(rv_team, BASE), s * 2 + 2)
	a["n"] += 1
	while not (me.finished and rv.finished):
		var mm := 9999 if me.finished else int(me.current_moment()["minute"])
		var rm := 9999 if rv.finished else int(rv.current_moment()["minute"])
		if mm < rm:
			_attack(me, me_prof, rv, rv_prof, LeagueManager.defense_difficulty_vs(me_team, BASE), a, "my", "rv")
		else:
			_attack(rv, rv_prof, me, me_prof, LeagueManager.defense_difficulty_vs(rv_team, BASE), a, "rv", "my")
		if me.injured or rv.injured:
			break


func _attack(att: MatchEngine, ap: BotProfile, def: MatchEngine, dp: BotProfile, def_diff: float,
		a: Dictionary, at: String, dt: String) -> void:
	att.exploit_rival_space = ap.punishes_passivity and def.posture == MatchEngine.Posture.LOW
	var r := CoachBot.run_defense(def, dp, def_diff)
	for ev in r["plays"]:
		_rec(a, dt + "_def", ev)
	if r["cancelled"]:
		a[dt + "_cut"] += 1
		att.skip_moment()
		att.advance(ap.default_posture as MatchEngine.Posture)
		return
	att.opponent_pressure = r["pressure"]
	att.opponent_block = r["block"]
	a[at + "_moments"] += 1
	var goals_before: int = att.stats["goals"]
	if att.zone_mode:
		att.set_zone_rival(def)
	att.begin_moment()
	while not att.moment_over:
		var ev := CoachBot.act(att, ap)
		_rec(a, at + "_att", ev)
		if ev.get("stolen", false):
			def.counter_ready = true   # robo (al aguantar o, por zonas, al fallar): contragolpe del que defendía
			a[dt + "_steals"] += 1
	a[at + "_goals"] += att.stats["goals"] - goals_before
	att.advance(ap.default_posture as MatchEngine.Posture)
