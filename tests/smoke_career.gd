# Prueba de humo del bucle semanal: calendario → partido → calendario, dos semanas seguidas.
# Semana 1: Telnet, acepta la fiesta, entrenamiento táctico. Semana 2: Cerveza Glaciar, rechaza, kinesiología.
# Al final reabre el calendario como si se hubiera cerrado el juego y usa "Continuar carrera".
# Guarda en su propia ruta (TEST_SAVE), nunca en la partida real del usuario, y la borra al final.
# Uso: godot --headless --path . -s res://tests/smoke_career.gd
# Sale con código 1 si algún paso no ocurre o el partido se cuelga.
extends SceneTree

const CALENDAR := "res://scenes/calendar_view.tscn"
const MATCH := "res://scenes/match_view.tscn"
const TIME_SCALE := 20.0
const MAX_FRAMES := 120000
const WEEKS := 2
const TEST_SAVE := "user://test_smoke_carrera.json"
const REAL_SAVE := "user://carrera.json"

var frames := 0
var step := "boot"
var week_done := 0
var errors: Array[String] = []
var _wait := 0
var _real_save_time := 0   # fecha de modificación de la partida real (0 = no existe)
var _closed_scene_id := 0  # calendario de antes de "cerrar el juego"


func _initialize() -> void:
	Engine.time_scale = TIME_SCALE
	Career.current = null
	Career.save_path = TEST_SAVE
	_remove_test_save()
	_real_save_time = FileAccess.get_modified_time(REAL_SAVE) if FileAccess.file_exists(REAL_SAVE) else 0
	change_scene_to_file(CALENDAR)


func _process(_delta: float) -> bool:
	frames += 1
	if frames > MAX_FRAMES:
		errors.append("Tiempo agotado en el paso '%s'" % step)
		return _finish()
	if _wait > 0:
		_wait -= 1
		return false
	var scene := current_scene
	if scene == null:
		return false
	match step:
		"boot":
			if scene.scene_file_path == CALENDAR:
				if not scene._continue_button.disabled:
					errors.append("Sin guardado, CONTINUAR debería estar deshabilitado")
				scene._on_start_career()
				if Career.current == null:
					errors.append("No se pudo comenzar la carrera")
					return _finish()
				step = "week"
		"week":
			if scene.scene_file_path != CALENDAR:
				return false
			var c := Career.current
			var first := c.week == 1
			var sponsor_index := 2 if first else 1   # 0 = "elige", 1 = Cerveza Glaciar, 2 = Telnet
			scene._sponsor_option.select(sponsor_index)
			scene._on_sponsor_selected(sponsor_index)
			scene._on_event(first)
			scene._on_training("tactical" if first else "physio")
			if not c.blocks_done()["block1"] or not c.blocks_done()["block2"]:
				errors.append("Semana %d: los bloques 1 y 2 deberían quedar completos" % c.week)
				return _finish()
			if scene._go_button.disabled:
				errors.append("Semana %d: IR AL PARTIDO debería estar habilitado" % c.week)
				return _finish()
			scene._on_go()
			if not c.pending_match:
				errors.append("Semana %d: el Bloque 3 rechazó el mazo: %s" % [c.week, scene._check_label.text])
				return _finish()
			step = "match"
			_wait = 2
		"match":
			if scene.scene_file_path != MATCH:
				return false
			_autoplay(scene)
			if scene._menu.visible and not scene._busy and not Career.current.pending_match:
				week_done += 1
				print("  Semana %d: %s" % [week_done, scene._menu_summary.text.replace("\n", " | ")])
				scene._on_start_pressed()   # VOLVER AL CALENDARIO
				step = "week" if week_done < WEEKS else "done"
				_wait = 2
		"done":
			if scene.scene_file_path == CALENDAR:
				var c := Career.current
				if c.week != WEEKS + 1 or c.history.size() != WEEKS:
					errors.append("Tras %d partidos la carrera debería estar en la semana %d (está en %d, %d resultados)" % [
						WEEKS, WEEKS + 1, c.week, c.history.size()])
				var saved := Career.load_saved(c.league, c.squads)
				if saved == null or saved.week != WEEKS + 1 or saved.history.size() != WEEKS:
					errors.append("El guardado al volver del partido debería estar en la semana %d: %s" % [
						WEEKS + 1, "; ".join(Career.last_load_errors)])
				print("smoke_career: %d semanas · presupuesto $%d M · fatiga %d%% · popularidad %d · disciplina %d" % [
					week_done, int(c.budget), int(c.fatigue), c.popularity, c.discipline])
				Career.current = null   # como si se cerrara el juego
				_closed_scene_id = scene.get_instance_id()
				change_scene_to_file(CALENDAR)
				step = "continue"
				_wait = 2
		"continue":
			if scene.scene_file_path != CALENDAR or scene.get_instance_id() == _closed_scene_id:
				return false
			var button: Button = scene._continue_button
			if button.disabled or not button.text.contains("SEMANA %d" % (WEEKS + 1)):
				errors.append("CONTINUAR debería ofrecer la semana %d (texto: '%s', deshabilitado: %s)" % [
					WEEKS + 1, button.text, button.disabled])
				return _finish()
			scene._on_continue_career()
			var c := Career.current
			if c == null or c.week != WEEKS + 1 or c.history.size() != WEEKS or scene._go_button.disabled == false:
				errors.append("Continuar debería recuperar la semana %d con los bloques por hacer" % (WEEKS + 1))
			else:
				print("smoke_career: continuar · %s" % button.text)
			return _finish()
	return false


# Mismo criterio que smoke_match: primera carta jugable; si no hay, en defensa deja pasar y en
# ataque aguanta el balón (si queda) o cede.
func _autoplay(view: Node) -> void:
	if view._busy:
		return
	if view._in_defense or view._in_moment:
		for ui in view._hand_box.get_children():
			if view._engine.can_play(ui.card):
				view._on_card_chosen(ui)
				return
		if view._in_moment and view._engine.can_hold():
			view._on_hold_pressed()
		else:
			view._on_yield_pressed()


func _remove_test_save() -> void:
	if FileAccess.file_exists(TEST_SAVE):
		DirAccess.remove_absolute(TEST_SAVE)


func _finish() -> bool:
	_remove_test_save()
	var real_now := FileAccess.get_modified_time(REAL_SAVE) if FileAccess.file_exists(REAL_SAVE) else 0
	if real_now != _real_save_time:
		errors.append("La prueba no debería escribir en %s" % REAL_SAVE)
	for e in errors:
		print("  ERROR: " + e)
	quit(1 if errors.size() > 0 else 0)
	return true
