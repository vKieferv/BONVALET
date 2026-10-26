# Prueba de humo del bucle semanal: calendario → partido → calendario, dos semanas seguidas.
# Semana 1: Telnet, acepta la fiesta, entrenamiento táctico. Semana 2: Cerveza Glaciar, rechaza, kinesiología.
# Uso: godot --headless --path . -s res://tests/smoke_career.gd
# Sale con código 1 si algún paso no ocurre o el partido se cuelga.
extends SceneTree

const CALENDAR := "res://scenes/calendar_view.tscn"
const MATCH := "res://scenes/match_view.tscn"
const TIME_SCALE := 20.0
const MAX_FRAMES := 120000
const WEEKS := 2

var frames := 0
var step := "boot"
var week_done := 0
var errors: Array[String] = []
var _wait := 0


func _initialize() -> void:
	Engine.time_scale = TIME_SCALE
	Career.current = null
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
				print("smoke_career: %d semanas · presupuesto $%d M · fatiga %d%% · popularidad %d · disciplina %d" % [
					week_done, int(c.budget), int(c.fatigue), c.popularity, c.discipline])
				return _finish()
	return false


# Mismo criterio que smoke_match: primera carta jugable; en defensa, si no hay, deja pasar.
func _autoplay(view: Node) -> void:
	if view._busy:
		return
	if view._in_defense or view._in_moment:
		for ui in view._hand_box.get_children():
			if view._engine.can_play(ui.card):
				view._on_card_chosen(ui)
				return
		if view._in_defense:
			view._on_yield_pressed()


func _finish() -> bool:
	for e in errors:
		print("  ERROR: " + e)
	quit(1 if errors.size() > 0 else 0)
	return true
