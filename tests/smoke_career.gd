# Prueba de humo del bucle semanal: calendario → partido → calendario, dos semanas seguidas.
# Semana 1: Telnet, acepta la fiesta, entrenamiento táctico (se queda con la primera carta ofrecida).
# Semana 2: Cerveza Glaciar, rechaza, abre la sesión de video y "Ver mazo" y termina en kinesiología.
# Al final reabre el calendario como si se hubiera cerrado el juego, usa "Continuar carrera" y
# comprueba que el mazo vuelve con la carta nueva.
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
var _new_card := ""        # id de la carta que se tomó en el entrenamiento táctico de la semana 1
var _rival_checked := 0    # semanas en que se comprobó el mazo del rival (T-06)


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
			if first:
				_take_first_offer(scene, c)
			else:
				_look_and_rest(scene, c)
			if not errors.is_empty():
				return _finish()
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
			# T-06: el rival de la semana N juega con su mazo de inicio + N − 1 cartas de su crecimiento.
			if _rival_checked == week_done and scene._rival_engine != null:
				var c := Career.current
				var rid := c.rival_id
				var expected := _rival_deck_size(c, rid)
				var got: int = scene._rival_engine.deck.active.size()
				if got != expected:
					errors.append("Semana %d: el rival juega con %d cartas y debería tener %d" % [c.week, got, expected])
					return _finish()
				print("  Semana %d: rival %s con mazo de %d cartas" % [c.week, rid, got])
				_rival_checked += 1
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
			elif scene._club_option.get_item_metadata(scene._club_option.selected) != c.team_id:
				errors.append("Al continuar, el selector debería mostrar el club de la carrera (%s)" % c.team_id)
			elif c.deck.size() != 12 or c.deck[11]["id"] != _new_card or c.build_deck().size() != 13:
				errors.append("Continuar debería recuperar el mazo con la carta nueva (%s): %s" % [_new_card, c.deck])
			elif not _deck_shows(scene, String(c.squads.catalog[_new_card]["name"])):
				errors.append("Al continuar, Ver mazo debería mostrar la carta nueva")
			else:
				print("smoke_career: continuar · %s · mazo de %d cartas con %s" % [
					button.text, c.deck_size(), c.squads.catalog[_new_card]["name"]])
			return _finish()
	return false


# Semana 1, Bloque 2: abre el entrenamiento táctico (3 cartas + "No tomar ninguna") y se queda con la primera.
func _take_first_offer(scene: Node, c: Career) -> void:
	scene._on_training("tactical")
	var buttons: Array = scene._b2_detail.get_children().filter(func(n): return n is Button)
	if buttons.size() != Career.OFFER_SIZE + 1:
		errors.append("El táctico debería mostrar %d cartas y \"No tomar ninguna\" (hay %d botones)" % [Career.OFFER_SIZE, buttons.size()])
		return
	if c.blocks_done()["block2"]:
		errors.append("Abrir el táctico no debería resolver el Bloque 2 antes de elegir")
		return
	_new_card = String(c.training_offer[0])
	scene._on_offer_chosen(0)
	if c.deck.size() != 12 or c.deck.back()["id"] != _new_card or c.training != "tactical":
		errors.append("Elegir la primera carta debería agregarla al mazo (%s): %s" % [_new_card, c.deck])
	print("  Bloque 2 · semana 1: %s" % scene._training_status.text.get_slice("\n", 0))


# Semana 2, Bloque 2: mira la sesión de video y "Ver mazo" (con la carta de la semana 1) y se va a kinesiología.
func _look_and_rest(scene: Node, c: Career) -> void:
	scene._on_training("video")
	var upgrade_buttons: Array = []
	for row in scene._b2_detail.get_children():
		if row is HBoxContainer:
			upgrade_buttons.append_array(row.get_children())
	if upgrade_buttons.is_empty() or c.blocks_done()["block2"]:
		errors.append("La sesión de video debería mostrar tu mazo con sus mejoras, sin resolver el Bloque 2")
		return
	scene._on_view_deck()
	if not _deck_shows(scene, String(c.squads.catalog[_new_card]["name"])):
		errors.append("Ver mazo debería mostrar la carta tomada en la semana 1")
	scene._on_view_deck()
	scene._on_training("physio")
	if c.training != "physio" or c.deck.size() != 12:
		errors.append("La kinesiología debería resolver el Bloque 2 sin tocar el mazo")


# ¿El panel "Ver mazo" está abierto y nombra la carta?
func _deck_shows(scene: Node, card_name: String) -> bool:
	if not scene._deck_panel.visible:
		scene._on_view_deck()
	return scene._deck_panel.visible and scene._deck_list.get_children().any(
			func(n): return n is Label and n.text.contains(card_name))


# Mazo esperado del rival: el de inicio del club + week − 1 cartas de su crecimiento, con sus firmas.
func _rival_deck_size(c: Career, rid: String) -> int:
	var start := c.squads.build_match_deck(rid, c.squads.starter_templates(rid)).size()
	return mini(start + c.week - 1, DeckManager.DECK_MAX)


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
