# Prueba de humo de la escena del partido: juega partidos completos de match_view
# (un rival por arquetipo, alternando postura) eligiendo siempre la primera carta jugable.
# Uso: godot --headless --path futbolista -s res://tests/smoke_match.gd [-- --matches=5]
# Sale con código 1 si un partido se cuelga, el marcador no cuadra o la postura cambia en un Momento Clave.
extends SceneTree

const TIME_SCALE := 20.0
const MAX_FRAMES_PER_MATCH := 60000

var view: Control
var frames := 0
var match_frames := 0
var started := false
var total_matches := 5
var played := 0
var rivals: Array = []         # índices del menú, uno por arquetipo
var errors: Array[String] = []
var lock_checks := 0
var exploit_seen := false
var exploit_expected := false


func _initialize() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--matches="):
			total_matches = maxi(1, int(arg.get_slice("=", 1)))
	view = load("res://scenes/match_view.tscn").instantiate()
	root.add_child(view)
	Engine.time_scale = TIME_SCALE


func _process(_delta: float) -> bool:
	frames += 1
	if frames < 2:
		return false   # los @onready de la escena se resuelven tras el primer frame
	if not started:
		started = true
		_pick_rivals()
		_start_match()
		return false

	match_frames += 1
	if match_frames > MAX_FRAMES_PER_MATCH:
		errors.append("Partido %d colgado (minuto %d)" % [played + 1, int(view._minute)])
		return _finish()

	if view._menu.visible and not view._busy:
		_check_result()
		played += 1
		if played >= total_matches:
			return _finish()
		_start_match()
		return false

	if view._rival_engine != null and view._rival_engine.exploit_rival_space:
		exploit_seen = true
	if view._in_moment and not view._busy:
		_check_posture_lock()
		for ui in view._hand_box.get_children():
			if ui.card.playable and float(view._engine.cost_of(ui.card)) <= view._player.energy:
				view._on_card_chosen(ui)
				break
	return false


func _pick_rivals() -> void:
	var seen := {}
	for i in view._rival_option.item_count:
		var t: Dictionary = view._league.get_team(view._rival_option.get_item_metadata(i))
		if not seen.has(t["archetype"]):
			seen[t["archetype"]] = true
			rivals.append(i)
	if rivals.is_empty():
		errors.append("El menú de rivales está vacío (¿fallaron los JSON de liga?)")


func _start_match() -> void:
	if rivals.is_empty():
		return
	match_frames = 0
	view._rival_option.selected = rivals[played % rivals.size()]
	var posture := played % 3   # LOW, NORMAL, HIGH
	var team: Dictionary = view._league.get_team(view._rival_option.get_item_metadata(view._rival_option.selected))
	if view._league.profile_for_team(team).punishes_passivity:
		posture = MatchEngine.Posture.LOW   # para que se pruebe exploit_rival_space
		exploit_expected = true
	view._posture_buttons[posture].button_pressed = true
	view._set_posture(posture)
	view._on_start_pressed()


func _check_posture_lock() -> void:
	lock_checks += 1
	var before: int = view._posture
	view._set_posture((before + 1) % 3)
	if view._posture != before:
		errors.append("La postura cambió durante un Momento Clave (partido %d)" % (played + 1))


func _check_result() -> void:
	var shown := int(view._local_goals.text)
	var real: int = view._engine.stats["goals"]
	if shown != real:
		errors.append("Marcador local %d ≠ goles del motor %d (partido %d)" % [shown, real, played + 1])
	if int(view._away_goals.text) != view._rival_goals:
		errors.append("Marcador visitante no cuadra (partido %d)" % (played + 1))
	print("  Partido %d: %s" % [played + 1, view._menu_summary.text.replace("\n", " | ")])


func _finish() -> bool:
	if exploit_expected and not exploit_seen:
		errors.append("Se jugó en LOW contra un Contragolpe y exploit_rival_space nunca se activó")
	print("smoke_match: %d partidos, %d chequeos de postura, contragolpe visto: %s" % [
		played, lock_checks, "sí" if exploit_seen else "no"])
	for e in errors:
		print("  ERROR: " + e)
	quit(1 if errors.size() > 0 else 0)
	return true
