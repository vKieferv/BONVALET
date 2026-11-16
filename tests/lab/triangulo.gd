# T-18 (D-49): medición liviana del triángulo de estilos. Un solo cruce por proceso: Colo-Colo (mismo plantel y
# mismo mazo de inicio) contra sí mismo, pero cada lado con un estilo distinto (su perfil de bot y su estilo de
# marca), en el modo de duelos con defensa en ambos lados. Así lo único que cambia entre los lados es el estilo.
# Uso: ..\Godot_v4.7.2-stable_win64_console.exe --headless --path . -s res://tests/lab/triangulo.gd -- --a=Tiki-Taka --b=Catenaccio [--on=1] [--pts=6] [--n=150]
# Imprime una línea: cruce | ventaja | n | puntos de A % (3-1-0) | victorias A/empates/B | goles A y B por partido.
extends SceneTree

const BASE := 0.15
const ID := "colo_colo"


func _arg(nombre: String, defecto: String) -> String:
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--%s=" % nombre):
			return a.substr(nombre.length() + 3)
	return defecto


func _perfil(estilo: String) -> BotProfile:
	for p: BotProfile in BotProfile.presets():
		if p.profile_name == estilo:
			return p
	return null


func _lado(squads: SquadManager, estilo: String, defiende_vs: Dictionary) -> Dictionary:
	var mazo: Array = squads.starter_templates(ID)
	# T-17: --cartas=ofertas suma las cartas de estilo (decks.json "ofertas") de ese estilo; --cartas=crecimiento, las del crecimiento.
	var cartas := _arg("cartas", "")
	if cartas != "":
		mazo.append_array(CardDB.templates_from_ids(squads.deck_lists.get("ofertas" if cartas == "ofertas" else "crecimiento", {}).get(estilo, []), squads.catalog))
	var lado := {"profile": _perfil(estilo), "templates": squads.build_match_templates(ID, mazo),
		"lineup": squads.lineup_ids(ID), "defends": true, "attack_difficulty": BASE, "defense_difficulty": BASE,
		"zone_mode": true, "duel_mode": true}
	lado.merge(squads.zone_data(ID))
	lado.merge(squads.duel_data(ID))
	lado["style"] = estilo
	return lado


func _initialize() -> void:
	var a_estilo := _arg("a", "Tiki-Taka")
	var b_estilo := _arg("b", "Catenaccio")
	var n := int(_arg("n", "150"))
	var on := _arg("on", "1") == "1"
	StyleTriangle.override_activo = 1 if on else 0
	if _arg("pts", "") != "":
		StyleTriangle.override_puntos = float(_arg("pts", "6")) / 100.0
	var league := LeagueManager.new()
	league.load_all()
	var squads := SquadManager.new()
	squads.load_all(league)
	var a := _lado(squads, a_estilo, {})
	var b := _lado(squads, b_estilo, {})
	var r := DuelRunner.run(a, b, n)
	var pa: int = 3 * int(r["wins_a"]) + int(r["draws"])
	var pb: int = 3 * int(r["wins_b"]) + int(r["draws"])
	print("CRUCE %s vs %s | ventaja %s | n=%d | puntos de A %.1f%% | A %d - E %d - B %d | goles A %.2f B %.2f total %.2f" % [
		a_estilo, b_estilo, "ON" if on else "OFF", n, 100.0 * pa / maxf(1.0, pa + pb), r["wins_a"], r["draws"], r["wins_b"],
		float(r["goals_a"]) / n, float(r["goals_b"]) / n, float(r["goals_a"] + r["goals_b"]) / n])
	quit()
