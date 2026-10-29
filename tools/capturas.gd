# Capturas de la UI para revisar cambios visuales: semana (inicio, prensa, prensa resuelta, entrenamiento
# táctico, sesión de video, Ver mazo) y partido (menú, ataque, defensa). Necesita pantalla: NO se corre con --headless.
# Uso (desde futbolista/):
#   ..\Godot_v4.7.2-stable_win64_console.exe --path . -s res://tools/capturas.gd -- --out=C:/ruta/capturas
# Sin --out guarda en user://capturas. Guarda la carrera en su propia ruta y la borra al final.
extends SceneTree

const SAVE := "user://test_capturas.json"
const MAX_FRAMES := 20000
const SETTLE_FRAMES := 90   # frames para que la mano termine de aparecer antes de capturarla
const LAMP_FRAMES := 40     # frames para que la luz de la lámpara llegue a lo que toca decidir

var out := "user://capturas"
var frames := 0
var step := "boot"
var view: Node
var _wait := 0
var _taken := {}
var _settled := ""   # captura del partido que ya esperó a que la mano terminara de entrar


func _initialize() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--out="):
			out = arg.get_slice("=", 1)
	DirAccess.make_dir_recursive_absolute(out)
	Career.current = null
	Career.save_path = SAVE
	change_scene_to_file("res://scenes/calendar_view.tscn")


func _shot(shot_name: String) -> void:
	root.get_texture().get_image().save_png(out.path_join(shot_name + ".png"))
	_taken[shot_name] = true
	print("captura: ", out.path_join(shot_name + ".png"))


func _process(_delta: float) -> bool:
	frames += 1
	if frames > MAX_FRAMES:
		print("capturas: tiempo agotado en el paso '%s'" % step)
		return _finish(1)
	if _wait > 0:
		_wait -= 1
		return false
	var scene := current_scene
	if scene == null:
		return false
	match step:
		"boot":
			if frames > 10:
				_shot("1_inicio")
				scene._on_start_career()
				step = "week"
				_wait = LAMP_FRAMES
		"week":
			_shot("2_semana")
			scene._on_sponsor("telnet")
			scene._on_event(true)
			step = "press_done"
			_wait = LAMP_FRAMES
		"press_done":
			_shot("2b_prensa_resuelta")
			scene._on_training("tactical")
			step = "tactical"
			_wait = LAMP_FRAMES
		"tactical":
			_shot("3_entrenamiento_tactico")
			scene._on_training("video")
			step = "video"
			_wait = LAMP_FRAMES
		"video":
			_shot("3b_sesion_video")
			scene._on_view_deck()
			step = "deck"
			_wait = LAMP_FRAMES
		"deck":
			_shot("3c_ver_mazo")
			Career.current = null
			change_scene_to_file("res://scenes/match_view.tscn")
			step = "menu"
			_wait = 20
		"menu":
			view = current_scene
			_shot("4_partido_menu")
			view._on_start_pressed()
			step = "play"
			_wait = 5
		"play":
			if view._busy:
				return false
			# La mano entra con una animación: se espera a que termine antes de capturar.
			var pending := ""
			if view._in_moment and not _taken.has("5_partido_ataque"):
				pending = "5_partido_ataque"
			elif view._in_defense and not _taken.has("6_partido_defensa"):
				pending = "6_partido_defensa"
			if pending != "":
				if _settled != pending:
					_settled = pending
					_wait = SETTLE_FRAMES
					return false
				_shot(pending)
			if _taken.has("5_partido_ataque") and _taken.has("6_partido_defensa"):
				return _finish(0)
			if view._in_defense or view._in_moment:
				for ui in view._hand_box.get_children():
					if view._engine.can_play(ui.card):
						view._on_card_chosen(ui)
						_wait = 30
						return false
				view._on_yield_pressed()
				_wait = 30
	return false


func _finish(code: int) -> bool:
	if FileAccess.file_exists(SAVE):
		DirAccess.remove_absolute(SAVE)
	quit(code)
	return true
